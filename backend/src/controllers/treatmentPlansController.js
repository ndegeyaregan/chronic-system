const pool = require('../config/db');
const path = require('path');
const fs = require('fs');

// Ensure uploads dir exists
const uploadsDir = path.join(__dirname, '../../uploads/treatment-plans');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

// GET /treatment-plans (member gets their own)
const getMyTreatmentPlans = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT tp.*, c.name AS condition_name
       FROM treatment_plans tp
       LEFT JOIN conditions c ON c.id = tp.condition_id
       WHERE tp.member_id = $1
       ORDER BY tp.plan_date DESC NULLS LAST, tp.created_at DESC`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getMyTreatmentPlans error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// POST /treatment-plans (member submits plan)
// Handles optional file uploads via multer (req.files)
const createTreatmentPlan = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { title, description, cost, currency, plan_date, provider_name, condition_id } = req.body;
    console.log('[createTreatmentPlan] body:', req.body);
    console.log('[createTreatmentPlan] files:', Object.keys(req.files || {}));
    const files = req.files || {};
    const fileUrl = (field) =>
      files[field]?.[0] ? `/uploads/treatment-plans/${files[field][0].filename}` : null;

    const result = await pool.query(
      `INSERT INTO treatment_plans
         (member_id, title, description, document_url, photo_url, audio_url, video_url,
          cost, currency, plan_date, provider_name, condition_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [
        memberId,
        title || null,
        description || null,
        fileUrl('document'),
        fileUrl('photo'),
        fileUrl('audio'),
        fileUrl('video'),
        cost ? parseFloat(cost) : null,
        currency || 'UGX',
        plan_date || null,
        provider_name || null,
        condition_id || null,
      ]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createTreatmentPlan error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// PUT /treatment-plans/:id (member updates their plan)
const updateTreatmentPlan = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { id } = req.params;
    const { title, description, cost, currency, plan_date, provider_name, condition_id, status } = req.body;
    const existing = await pool.query(
      'SELECT id FROM treatment_plans WHERE id = $1 AND member_id = $2',
      [id, memberId]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Treatment plan not found' });

    const files = req.files || {};
    const fileUrl = (field) =>
      files[field]?.[0] ? `/uploads/treatment-plans/${files[field][0].filename}` : undefined;

    const setClauses = [
      'title = COALESCE($1, title)',
      'description = COALESCE($2, description)',
      'cost = COALESCE($3, cost)',
      'currency = COALESCE($4, currency)',
      'plan_date = COALESCE($5, plan_date)',
      'provider_name = COALESCE($6, provider_name)',
      'condition_id = COALESCE($7, condition_id)',
      'status = COALESCE($8, status)',
      'updated_at = NOW()',
    ];
    const params = [
      title || null, description || null,
      cost ? parseFloat(cost) : null, currency || null,
      plan_date || null, provider_name || null,
      condition_id || null, status || null,
    ];

    for (const field of ['document_url', 'photo_url', 'audio_url', 'video_url']) {
      const key = field.replace('_url', '');
      const url = fileUrl(key);
      if (url !== undefined) {
        setClauses.push(`${field} = $${params.length + 1}`);
        params.push(url);
      }
    }

    params.push(id);
    const result = await pool.query(
      `UPDATE treatment_plans SET ${setClauses.join(', ')} WHERE id = $${params.length} RETURNING *`,
      params
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateTreatmentPlan error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// GET /treatment-plans/admin/:memberId (admin views member's plans)
const getMemberTreatmentPlans = async (req, res) => {
  try {
    const { memberId } = req.params;
    const result = await pool.query(
      `SELECT tp.*, c.name AS condition_name,
              m.first_name, m.last_name, m.member_number
       FROM treatment_plans tp
       LEFT JOIN conditions c ON c.id = tp.condition_id
       JOIN members m ON m.id = tp.member_id
       WHERE tp.member_id = $1
       ORDER BY tp.plan_date DESC NULLS LAST, tp.created_at DESC`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getMemberTreatmentPlans error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// GET /treatment-plans/admin (admin lists ALL plans with member info)
const getAllTreatmentPlans = async (req, res) => {
  try {
    const { page = 1, limit = 20, status } = req.query;
    const offset = (page - 1) * limit;
    const params = [];
    const filters = [];
    let idx = 1;
    if (status) { filters.push(`tp.status = $${idx++}`); params.push(status); }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    params.push(limit, offset);
    const result = await pool.query(
      `SELECT tp.*, c.name AS condition_name,
              m.first_name, m.last_name, m.member_number
       FROM treatment_plans tp
       LEFT JOIN conditions c ON c.id = tp.condition_id
       JOIN members m ON m.id = tp.member_id
       ${whereClause}
       ORDER BY tp.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getAllTreatmentPlans error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// POST /treatment-plans/admin (admin creates plan for a member)
const adminCreateTreatmentPlan = async (req, res) => {
  try {
    const { member_id, title, description, cost, currency, plan_date, provider_name, condition_id } = req.body;
    if (!member_id) return res.status(400).json({ message: 'member_id is required' });

    const memberCheck = await pool.query('SELECT id FROM members WHERE id = $1', [member_id]);
    if (!memberCheck.rows.length) return res.status(404).json({ message: 'Member not found' });

    const files = req.files || {};
    const fileUrl = (field) =>
      files[field]?.[0] ? `/uploads/treatment-plans/${files[field][0].filename}` : null;

    const result = await pool.query(
      `INSERT INTO treatment_plans
         (member_id, title, description, document_url, photo_url, audio_url, video_url,
          cost, currency, plan_date, provider_name, condition_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [
        member_id,
        title || null,
        description || null,
        fileUrl('document'),
        fileUrl('photo'),
        fileUrl('audio'),
        fileUrl('video'),
        cost ? parseFloat(cost) : null,
        currency || 'UGX',
        plan_date || null,
        provider_name || null,
        condition_id || null,
      ]
    );

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'create_treatment_plan', 'treatment_plan', $2, $3, $4)`,
      [req.user.id, result.rows[0].id, JSON.stringify({ member_id, title, admin_name: req.user.name || req.user.email }), req.ip]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('adminCreateTreatmentPlan error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// PUT /treatment-plans/admin/:id (admin updates any plan)
const adminUpdateTreatmentPlan = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, cost, currency, plan_date, provider_name, condition_id, status } = req.body;

    const existing = await pool.query('SELECT id FROM treatment_plans WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Treatment plan not found' });

    const files = req.files || {};
    const fileUrl = (field) =>
      files[field]?.[0] ? `/uploads/treatment-plans/${files[field][0].filename}` : undefined;

    const setClauses = [
      'title = COALESCE($1, title)',
      'description = COALESCE($2, description)',
      'cost = COALESCE($3, cost)',
      'currency = COALESCE($4, currency)',
      'plan_date = COALESCE($5, plan_date)',
      'provider_name = COALESCE($6, provider_name)',
      'condition_id = COALESCE($7, condition_id)',
      'status = COALESCE($8, status)',
      'updated_at = NOW()',
    ];
    const params = [
      title || null, description || null,
      cost ? parseFloat(cost) : null, currency || null,
      plan_date || null, provider_name || null,
      condition_id || null, status || null,
    ];

    for (const field of ['document_url', 'photo_url', 'audio_url', 'video_url']) {
      const key = field.replace('_url', '');
      const url = fileUrl(key);
      if (url !== undefined) {
        setClauses.push(`${field} = $${params.length + 1}`);
        params.push(url);
      }
    }

    params.push(id);
    const result = await pool.query(
      `UPDATE treatment_plans SET ${setClauses.join(', ')} WHERE id = $${params.length} RETURNING *`,
      params
    );

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'update_treatment_plan', 'treatment_plan', $2, $3, $4)`,
      [req.user.id, id, JSON.stringify({ title, status, admin_name: req.user.name || req.user.email }), req.ip]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('adminUpdateTreatmentPlan error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  getMyTreatmentPlans,
  createTreatmentPlan,
  updateTreatmentPlan,
  getMemberTreatmentPlans,
  getAllTreatmentPlans,
  adminCreateTreatmentPlan,
  adminUpdateTreatmentPlan,
};
