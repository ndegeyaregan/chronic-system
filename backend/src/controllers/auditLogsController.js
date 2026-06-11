const pool = require('../config/db');

const getAuditLogs = async (req, res) => {
  try {
    const { entity, entity_id, page = 1, limit = 50 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const params = [];
    const filters = [];
    let idx = 1;

    if (entity) { filters.push(`al.entity = $${idx++}`); params.push(entity); }
    if (entity_id) { filters.push(`al.entity_id = $${idx++}`); params.push(entity_id); }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    params.push(parseInt(limit), offset);
    const result = await pool.query(
      `SELECT al.*,
              COALESCE(a.name, a.email, 'System') AS actor_name
       FROM audit_logs al
       LEFT JOIN admins a ON a.id = al.actor_id
       ${whereClause}
       ORDER BY al.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      params
    );

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM audit_logs al ${whereClause}`,
      params.slice(0, params.length - 2)
    );

    return res.json({
      logs: result.rows,
      total: parseInt(countResult.rows[0].count),
      page: parseInt(page),
      pages: Math.ceil(parseInt(countResult.rows[0].count) / parseInt(limit)),
    });
  } catch (err) {
    console.error('getAuditLogs error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMemberAuditLogs = async (req, res) => {
  try {
    const { memberId } = req.params;
    const result = await pool.query(
      `SELECT al.*,
              COALESCE(a.name, a.email, 'System') AS actor_name
       FROM audit_logs al
       LEFT JOIN admins a ON a.id = al.actor_id
       WHERE al.entity_id = $1
          OR (al.details->>'member_id' = $1)
       ORDER BY al.created_at DESC
       LIMIT 50`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getMemberAuditLogs error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMemberLogins = async (req, res) => {
  try {
    const { search, from, to, page = 1, limit = 50 } = req.query;
    const pageNum = Math.max(parseInt(page) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit) || 50, 1), 200);
    const offset = (pageNum - 1) * limitNum;

    const params = [];
    const filters = [`al.actor_type = 'member'`, `al.action = 'login'`];
    let idx = 1;

    if (search) {
      filters.push(
        `(m.first_name ILIKE $${idx} OR m.last_name ILIKE $${idx} OR m.member_number ILIKE $${idx} OR m.email ILIKE $${idx})`
      );
      params.push(`%${search}%`);
      idx++;
    }
    if (from) { filters.push(`al.created_at >= $${idx++}`); params.push(from); }
    if (to)   { filters.push(`al.created_at <= $${idx++}`); params.push(to); }

    const whereClause = `WHERE ${filters.join(' AND ')}`;

    const dataParams = [...params, limitNum, offset];
    const result = await pool.query(
      `SELECT al.id, al.created_at, al.ip_address, al.details,
              m.id AS member_id, m.member_number, m.first_name, m.last_name,
              m.email, m.phone
       FROM audit_logs al
       LEFT JOIN members m ON m.id = al.actor_id
       ${whereClause}
       ORDER BY al.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      dataParams
    );

    const countResult = await pool.query(
      `SELECT COUNT(*)
       FROM audit_logs al
       LEFT JOIN members m ON m.id = al.actor_id
       ${whereClause}`,
      params
    );

    const total = parseInt(countResult.rows[0].count, 10);
    return res.json({
      logins: result.rows,
      total,
      page: pageNum,
      pages: Math.ceil(total / limitNum) || 1,
    });
  } catch (err) {
    console.error('getMemberLogins error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { getAuditLogs, getMemberAuditLogs, getMemberLogins };
