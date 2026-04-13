const pool = require('../config/db');

const listContent = async (req, res) => {
  try {
    const { type, condition_id, published } = req.query;
    const isAdmin = req.user && req.user.type === 'admin';
    const params = [];
    const filters = [];
    let idx = 1;

    // Non-admins only see published content
    if (!isAdmin) {
      filters.push('cc.published = TRUE');
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

    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT cc.id, cc.title, cc.type, cc.video_url, cc.condition_id, cc.category,
              cc.tags, cc.published, cc.scheduled_at, cc.views, cc.created_at, cc.updated_at,
              c.name AS condition_name
       FROM content cc
       LEFT JOIN conditions c ON c.id = cc.condition_id
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
      title, type, body, video_url, condition_id, category,
      tags, published, scheduled_at,
    } = req.body;

    if (!title || !type) return res.status(400).json({ message: 'title and type are required' });

    const result = await pool.query(
      `INSERT INTO content
         (title, type, body, video_url, condition_id, category, tags, published, scheduled_at, views)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0) RETURNING *`,
      [
        title,
        type,
        body || null,
        video_url || null,
        condition_id || null,
        category || null,
        tags ? (Array.isArray(tags) ? tags : [tags]) : null,
        published !== undefined ? published : false,
        scheduled_at || null,
      ]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateContent = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      title, type, body, video_url, condition_id, category,
      tags, published, scheduled_at,
    } = req.body;

    const existing = await pool.query('SELECT id FROM content WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Content not found' });

    const result = await pool.query(
      `UPDATE content SET
         title = COALESCE($1, title),
         type = COALESCE($2, type),
         body = COALESCE($3, body),
         video_url = COALESCE($4, video_url),
         condition_id = COALESCE($5, condition_id),
         category = COALESCE($6, category),
         tags = COALESCE($7, tags),
         published = COALESCE($8, published),
         scheduled_at = COALESCE($9, scheduled_at),
         updated_at = NOW()
       WHERE id = $10 RETURNING *`,
      [
        title, type, body, video_url, condition_id, category,
        tags ? (Array.isArray(tags) ? tags : [tags]) : null,
        published, scheduled_at, id,
      ]
    );
    return res.json(result.rows[0]);
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
       WHERE id = $1 RETURNING id, title, published`,
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Content not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('publishContent error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listContent, getContent, createContent, updateContent, deleteContent, publishContent };
