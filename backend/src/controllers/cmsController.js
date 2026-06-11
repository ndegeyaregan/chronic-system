const pool = require('../config/db');
const { sendToMember } = require('../services/notificationService');

// Fan-out a published item to members so it lands in their in-app
// notifications bell. Fires for:
//   - any 'news' item (existing behaviour)
//   - any item targeted at a specific scheme (so corporate-targeted
//     articles/tips/videos still reach the chosen audience)
const broadcastNewsItem = async (item) => {
  if (!item || !item.published) return;
  const isNews = item.type === 'news';
  const isSchemeTargeted = !!item.scheme_id;
  if (!isNews && !isSchemeTargeted) return;
  try {
    const schemeFilter = item.scheme_id ? 'AND scheme_id = $1' : '';
    const args = item.scheme_id ? [item.scheme_id] : [];
    const members = await pool.query(
      `SELECT id, fcm_token, phone, email, first_name
       FROM members WHERE is_active = TRUE ${schemeFilter}`,
      args
    );
    const title = item.title || (isNews ? 'News from Sanlam' : 'New content available');
    const message = (item.body || '').toString().replace(/<[^>]*>/g, '').trim().slice(0, 280)
      || (item.image_url ? 'Tap to view the new flyer.' : 'A new update has been published.');
    await Promise.all(members.rows.map((m) =>
      sendToMember(m.id, {
        type: isNews ? 'news' : 'content',
        title,
        message,
        channel: ['push'],
        fcmToken: m.fcm_token,
        phone: m.phone,
        email: m.email,
        firstName: m.first_name,
      }).catch((err) => console.error(`content fan-out error for ${m.id}:`, err.message))
    ));
    console.log(`📰 "${title}" (${item.type}${item.scheme_id ? `, scheme=${item.scheme_id}` : ''}) fanned out to ${members.rows.length} members`);
  } catch (err) {
    console.error('broadcastNewsItem error:', err.message);
  }
};

const listContent = async (req, res) => {
  try {
    const { type, condition_id, scheme_id, published } = req.query;
    const isAdmin = req.user && req.user.type === 'admin';
    const params = [];
    const filters = [];
    let idx = 1;

    // Non-admins only see published content, and only content targeted at
    // their scheme (or general content with no scheme).
    if (!isAdmin) {
      filters.push('cc.published = TRUE');
      let memberSchemeId = null;
      if (req.user && req.user.id) {
        try {
          const m = await pool.query('SELECT scheme_id FROM members WHERE id = $1', [req.user.id]);
          memberSchemeId = m.rows[0]?.scheme_id || null;
        } catch (_) { /* ignore */ }
      }
      if (memberSchemeId) {
        filters.push(`(cc.scheme_id IS NULL OR cc.scheme_id = $${idx++})`);
        params.push(memberSchemeId);
      } else {
        filters.push('cc.scheme_id IS NULL');
      }
    } else if (published !== undefined) {
      filters.push(`cc.published = $${idx++}`);
      params.push(published === 'true');
    }

    if (type) {
      filters.push(`cc.type = $${idx++}`);
      params.push(type);
    }
    if (condition_id) {
      filters.push(`cc.condition_id = $${idx++}`);
      params.push(condition_id);
    }
    if (isAdmin && scheme_id) {
      filters.push(`cc.scheme_id = $${idx++}`);
      params.push(scheme_id);
    }

    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT cc.id, cc.title, cc.type, cc.video_url, cc.image_url, cc.condition_id, cc.scheme_id, cc.category,
              cc.tags, cc.published, cc.scheduled_at, cc.views, cc.created_at, cc.updated_at,
              c.name AS condition_name,
              s.name AS scheme_name
       FROM content cc
       LEFT JOIN conditions c ON c.id = cc.condition_id
       LEFT JOIN schemes s ON s.id = cc.scheme_id
       ${where}
       ORDER BY cc.created_at DESC`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getContent = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT cc.*, c.name AS condition_name
       FROM content cc
       LEFT JOIN conditions c ON c.id = cc.condition_id
       WHERE cc.id = $1`,
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Content not found' });

    // Increment view count asynchronously
    pool.query('UPDATE content SET views = views + 1 WHERE id = $1', [id])
      .catch((err) => console.error('View increment error:', err.message));

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('getContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createContent = async (req, res) => {
  try {
    const {
      title, type, body, video_url, image_url, condition_id, scheme_id, category,
      tags, published, scheduled_at,
    } = req.body;

    // Detailed validation with helpful error messages
    if (!title || !title.toString().trim()) {
      console.warn('CMS: Missing/empty title:', { title });
      return res.status(400).json({ message: 'Title is required' });
    }
    if (!type || !type.toString().trim()) {
      console.warn('CMS: Missing/empty type:', { type });
      return res.status(400).json({ message: 'Content type is required' });
    }

    const result = await pool.query(
      `INSERT INTO content
         (title, type, body, video_url, image_url, condition_id, scheme_id, category, tags, published, scheduled_at, views)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,0) RETURNING *`,
      [
        title,
        type,
        body || null,
        video_url || null,
        image_url || null,
        condition_id || null,
        scheme_id || null,
        category || null,
        tags ? (Array.isArray(tags) ? tags : [tags]) : null,
        published !== undefined ? published : false,
        scheduled_at || null,
      ]
    );
    const created = result.rows[0];
    if (created && created.published && (created.type === 'news' || created.scheme_id)) {
      broadcastNewsItem(created);
    }
    return res.status(201).json(created);
  } catch (err) {
    console.error('createContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateContent = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      title, type, body, video_url, image_url, condition_id, scheme_id, category,
      tags, published, scheduled_at,
    } = req.body;

    const existing = await pool.query('SELECT id, type, published FROM content WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Content not found' });
    const wasPublished = existing.rows[0].published === true;

    const result = await pool.query(
      `UPDATE content SET
         title = COALESCE($1, title),
         type = COALESCE($2, type),
         body = COALESCE($3, body),
         video_url = COALESCE($4, video_url),
         image_url = COALESCE($5, image_url),
         condition_id = COALESCE($6, condition_id),
         scheme_id = $7,
         category = COALESCE($8, category),
         tags = COALESCE($9, tags),
         published = COALESCE($10, published),
         scheduled_at = COALESCE($11, scheduled_at),
         updated_at = NOW()
       WHERE id = $12 RETURNING *`,
      [
        title, type, body, video_url, image_url, condition_id,
        scheme_id || null,
        category,
        tags ? (Array.isArray(tags) ? tags : [tags]) : null,
        published, scheduled_at, id,
      ]
    );
    const updated = result.rows[0];
    if (updated && updated.published && !wasPublished && (updated.type === 'news' || updated.scheme_id)) {
      broadcastNewsItem(updated);
    }
    return res.json(updated);
  } catch (err) {
    console.error('updateContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deleteContent = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'DELETE FROM content WHERE id = $1 RETURNING id',
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Content not found' });
    return res.json({ message: 'Content deleted' });
  } catch (err) {
    console.error('deleteContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const publishContent = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `UPDATE content SET published = TRUE, scheduled_at = NULL, updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Content not found' });
    const item = result.rows[0];
    if (item.type === 'news' || item.scheme_id) {
      broadcastNewsItem(item);
    }
    return res.json({ id: item.id, title: item.title, published: item.published });
  } catch (err) {
    console.error('publishContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listContent, getContent, createContent, updateContent, deleteContent, publishContent };
