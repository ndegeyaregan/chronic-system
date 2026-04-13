const pool = require('../config/db');

const createAuthRequest = async (req, res) => {
  try {
    const memberId = req.user.id;
    const {
      request_type, provider_type, provider_id, provider_name,
      scheduled_date, notes, member_medication_id, treatment_plan_id,
    } = req.body;

    if (!request_type || !provider_type) {
      return res.status(400).json({ message: 'request_type and provider_type are required' });
    }

    // Resolve provider name from DB if provider_id given but no name
    let resolvedProviderName = provider_name;
    if (!resolvedProviderName && provider_id) {
      const table = provider_type === 'pharmacy' ? 'pharmacies' : 'hospitals';
      const row = await pool.query(`SELECT name FROM ${table} WHERE id = $1`, [provider_id]);
      if (row.rows.length) resolvedProviderName = row.rows[0].name;
    }

    const result = await pool.query(
      `INSERT INTO authorization_requests
         (member_id, request_type, provider_type, provider_id, provider_name,
          scheduled_date, notes, member_medication_id, treatment_plan_id, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'pending') RETURNING *`,
      [
        memberId, request_type, provider_type,
        provider_id || null, resolvedProviderName || null,
        scheduled_date || null, notes || null,
        member_medication_id || null, treatment_plan_id || null,
      ]
    );

    // Notify admin portal
    pool.query(
      `INSERT INTO notifications (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
       VALUES ($1, 'auth_request', 'portal', $2, $3, 'sent', $4, 'authorization_request', NOW())`,
      [
        memberId,
        `📋 New Authorization Request`,
        `Member submitted a ${request_type.replace('_', ' ')} authorization request for ${resolvedProviderName || 'a provider'}.`,
        result.rows[0].id,
      ]
    ).catch(() => {});

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createAuthRequest error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listMyAuthRequests = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT ar.*,
              mm.dosage, mm.frequency, mm.next_refill_date,
              med.name AS medication_name,
              tp.title AS treatment_plan_title
       FROM authorization_requests ar
       LEFT JOIN member_medications mm ON mm.id = ar.member_medication_id
       LEFT JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN treatment_plans tp ON tp.id = ar.treatment_plan_id
       WHERE ar.member_id = $1
       ORDER BY ar.created_at DESC`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listMyAuthRequests error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const cancelAuthRequest = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { id } = req.params;

    const existing = await pool.query(
      'SELECT * FROM authorization_requests WHERE id = $1 AND member_id = $2',
      [id, memberId]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Request not found' });
    if (existing.rows[0].status !== 'pending') {
      return res.status(409).json({ message: 'Only pending requests can be cancelled' });
    }

    const result = await pool.query(
      `UPDATE authorization_requests SET status = 'cancelled', updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id]
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('cancelAuthRequest error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listAllAuthRequestsAdmin = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const fetchAll = `${limit}`.toLowerCase() === 'all';
    const parsedLimit = fetchAll ? null : parseInt(limit, 10);
    const parsedPage = parseInt(page, 10);
    const offset = fetchAll ? null : (parsedPage - 1) * parsedLimit;
    let where = '';
    const params = [];
    if (status) {
      params.push(status);
      where = `WHERE ar.status = $${params.length}`;
    }
    const baseQuery = `SELECT ar.*,
              m.first_name, m.last_name, m.member_number,
              mm.dosage, mm.frequency,
              med.name AS medication_name,
              tp.title AS treatment_plan_title,
              ar.auth_email_sent_at,
              CONCAT(a.first_name, ' ', a.last_name) AS reviewed_by_name
       FROM authorization_requests ar
       JOIN members m ON m.id = ar.member_id
       LEFT JOIN member_medications mm ON mm.id = ar.member_medication_id
       LEFT JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN treatment_plans tp ON tp.id = ar.treatment_plan_id
       LEFT JOIN admins a ON a.id = ar.reviewed_by
       ${where}
       ORDER BY ar.created_at DESC`;
    if (!fetchAll) {
      params.push(parsedLimit, offset);
    }
    const result = await pool.query(
      fetchAll
        ? baseQuery
        : `${baseQuery} LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );
    const countResult = await pool.query(
      `SELECT COUNT(*) FROM authorization_requests ar ${where}`,
      status ? [status] : []
    );
    return res.json({
      requests: result.rows,
      total: parseInt(countResult.rows[0].count),
      pages: fetchAll ? 1 : Math.ceil(parseInt(countResult.rows[0].count) / parsedLimit),
    });
  } catch (err) {
    console.error('listAllAuthRequestsAdmin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const reviewAuthRequest = async (req, res) => {
  try {
    const { id } = req.params;
    const { action, review_note } = req.body; // action: 'approved' | 'rejected'
    if (!['approved', 'rejected'].includes(action)) {
      return res.status(400).json({ message: 'action must be approved or rejected' });
    }
    const existing = await pool.query(
      'SELECT * FROM authorization_requests WHERE id = $1',
      [id]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Request not found' });
    if (existing.rows[0].status !== 'pending') {
      return res.status(409).json({ message: 'Only pending requests can be reviewed' });
    }
    const result = await pool.query(
      `UPDATE authorization_requests
       SET status = $1, admin_comments = $2, reviewed_by = $3, reviewed_at = NOW(), updated_at = NOW()
       WHERE id = $4 RETURNING *`,
      [action, review_note || null, req.user.id, id]
    );
    // Notify member
    const req_type = existing.rows[0].request_type.replace(/_/g, ' ');
    pool.query(
      `INSERT INTO notifications (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
       VALUES ($1, 'auth_review', 'push', $2, $3, 'sent', $4, 'authorization_request', NOW())`,
      [
        existing.rows[0].member_id,
        `Authorization ${action.charAt(0).toUpperCase() + action.slice(1)}`,
        `Your ${req_type} authorization request has been ${action}.${review_note ? ' Note: ' + review_note : ''}`,
        id,
      ]
    ).catch(() => {});
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('reviewAuthRequest error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { createAuthRequest, listMyAuthRequests, cancelAuthRequest, listAllAuthRequestsAdmin, reviewAuthRequest };
