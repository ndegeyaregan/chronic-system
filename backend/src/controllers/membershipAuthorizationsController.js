const pool = require('../config/db');
const { sendToMember } = require('../services/notificationService');

const PUBLIC_BASE = (process.env.PUBLIC_API_BASE_URL || '').replace(/\/api\/?$/, '');

// Build absolute URL for clients that prefer it (Flutter handles relative too).
const absUrl = (rel) => (PUBLIC_BASE && rel?.startsWith('/') ? `${PUBLIC_BASE}${rel}` : rel);

// POST /api/membership-authorizations  (admin)
// multipart: file + body: member_id, title, description
const issueDocument = async (req, res) => {
  try {
    const { member_id, title, description } = req.body || {};
    if (!member_id || !title || !req.file) {
      return res.status(400).json({ message: 'member_id, title and file are required' });
    }

    const memberCheck = await pool.query(
      'SELECT id, first_name FROM members WHERE id = $1',
      [member_id]
    );
    if (memberCheck.rowCount === 0) {
      return res.status(404).json({ message: 'Member not found' });
    }

    const fileUrl = `/uploads/membership-authorizations/${req.file.filename}`;

    const insert = await pool.query(
      `INSERT INTO membership_authorization_documents
       (member_id, title, description, file_url, file_name, mime_type, file_size, issued_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        member_id,
        title.trim(),
        description?.trim() || null,
        fileUrl,
        req.file.originalname,
        req.file.mimetype,
        req.file.size,
        req.user?.id || null,
      ]
    );

    // Fire-and-forget notification (push + in-app log) so the member knows.
    sendToMember(member_id, {
      type: 'authorization',
      title: 'New Authorization Document',
      message: `Sanlam has issued you a new authorization document: ${title.trim()}`,
      channel: ['push'],
    }).catch((err) => console.error('authorization doc notify error:', err.message));

    return res.status(201).json({ ...insert.rows[0], file_url_abs: absUrl(fileUrl) });
  } catch (err) {
    console.error('issueDocument error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// GET /api/membership-authorizations  (admin) — optional ?member_id=
const listAllDocuments = async (req, res) => {
  try {
    const { member_id, limit = 100 } = req.query;
    const params = [];
    let where = '';
    if (member_id) {
      params.push(member_id);
      where = `WHERE d.member_id = $${params.length}`;
    }
    params.push(Math.min(parseInt(limit, 10) || 100, 500));
    const result = await pool.query(
      `SELECT d.*,
              m.first_name || ' ' || m.last_name AS member_name,
              m.member_number,
              a.name AS issued_by_name
         FROM membership_authorization_documents d
         LEFT JOIN members m ON m.id = d.member_id
         LEFT JOIN admins  a ON a.id = d.issued_by
         ${where}
         ORDER BY d.issued_at DESC
         LIMIT $${params.length}`,
      params
    );
    const rows = result.rows.map((r) => ({ ...r, file_url_abs: absUrl(r.file_url) }));
    return res.json({ documents: rows });
  } catch (err) {
    console.error('listAllDocuments error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// GET /api/membership-authorizations/mine  (member)
const listMyDocuments = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT id, title, description, file_url, file_name, mime_type, file_size, issued_at
         FROM membership_authorization_documents
        WHERE member_id = $1
        ORDER BY issued_at DESC`,
      [memberId]
    );
    const rows = result.rows.map((r) => ({ ...r, file_url_abs: absUrl(r.file_url) }));
    return res.json({ documents: rows });
  } catch (err) {
    console.error('listMyDocuments error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// DELETE /api/membership-authorizations/:id  (admin)
const deleteDocument = async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      'DELETE FROM membership_authorization_documents WHERE id = $1 RETURNING id',
      [id]
    );
    if (r.rowCount === 0) return res.status(404).json({ message: 'Not found' });
    return res.json({ message: 'Deleted' });
  } catch (err) {
    console.error('deleteDocument error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { issueDocument, listAllDocuments, listMyDocuments, deleteDocument };
