const pool = require('../config/db');

// GET /api/vitals/thresholds - List all thresholds with condition names
exports.getThresholds = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT vt.*, c.name as condition_name 
      FROM vital_thresholds vt 
      LEFT JOIN conditions c ON vt.condition_id = c.id 
      ORDER BY vt.metric, c.name
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Get thresholds error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

// POST /api/vitals/thresholds - Create threshold
exports.createThreshold = async (req, res) => {
  try {
    const { condition_id, metric, min_value, max_value } = req.body;

    // Check for duplicate (same metric + condition)
    const existing = await pool.query(
      'SELECT id FROM vital_thresholds WHERE metric = $1 AND condition_id IS NOT DISTINCT FROM $2',
      [metric, condition_id || null]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Threshold already exists for this metric and condition' });
    }

    const result = await pool.query(
      `INSERT INTO vital_thresholds (condition_id, metric, min_value, max_value) 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [condition_id || null, metric, min_value, max_value]
    );

    // Log audit
    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [req.user.id, 'admin', 'create', 'vital_threshold', result.rows[0].id, JSON.stringify({ metric, min_value, max_value })]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create threshold error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

// PUT /api/vitals/thresholds/:id - Update threshold
exports.updateThreshold = async (req, res) => {
  try {
    const { id } = req.params;
    const { condition_id, metric, min_value, max_value } = req.body;

    const result = await pool.query(
      `UPDATE vital_thresholds 
       SET condition_id = $1, metric = $2, min_value = $3, max_value = $4, updated_at = NOW()
       WHERE id = $5 RETURNING *`,
      [condition_id || null, metric, min_value, max_value, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Threshold not found' });
    }

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [req.user.id, 'admin', 'update', 'vital_threshold', id, JSON.stringify({ metric, min_value, max_value })]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update threshold error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

// DELETE /api/vitals/thresholds/:id - Delete threshold
exports.deleteThreshold = async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      'DELETE FROM vital_thresholds WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Threshold not found' });
    }

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [req.user.id, 'admin', 'delete', 'vital_threshold', id, JSON.stringify(result.rows[0])]
    );

    res.json({ message: 'Threshold deleted' });
  } catch (error) {
    console.error('Delete threshold error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};
