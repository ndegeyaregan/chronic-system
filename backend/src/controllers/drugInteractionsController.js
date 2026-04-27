const pool = require('../config/db');

// Check drug interactions for a member's current medications + a new one
const checkInteractions = async (req, res) => {
  try {
    const memberId = req.user?.id || req.params.memberId;
    const { medication_id } = req.query;
    if (!medication_id) return res.status(400).json({ message: 'medication_id query param required' });

    // Get member's active medications
    const active = await pool.query(
      `SELECT medication_id FROM member_medications
       WHERE member_id = $1 AND (end_date IS NULL OR end_date >= CURRENT_DATE)`,
      [memberId]
    );
    const activeIds = active.rows.map(r => r.medication_id);
    if (activeIds.length === 0) return res.json({ interactions: [] });

    // Find interactions between the new med and existing ones
    const result = await pool.query(
      `SELECT di.*, 
              ma.name AS medication_a_name, ma.generic_name AS medication_a_generic,
              mb.name AS medication_b_name, mb.generic_name AS medication_b_generic
       FROM drug_interactions di
       JOIN medications ma ON ma.id = di.medication_a_id
       JOIN medications mb ON mb.id = di.medication_b_id
       WHERE (di.medication_a_id = $1 AND di.medication_b_id = ANY($2::uuid[]))
          OR (di.medication_b_id = $1 AND di.medication_a_id = ANY($2::uuid[]))`,
      [medication_id, activeIds]
    );

    res.json({ interactions: result.rows });
  } catch (err) {
    console.error('checkInteractions error:', err);
    res.status(500).json({ message: 'Failed to check drug interactions' });
  }
};

// Admin: list all interactions
const listInteractions = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT di.*,
              ma.name AS medication_a_name,
              mb.name AS medication_b_name
       FROM drug_interactions di
       JOIN medications ma ON ma.id = di.medication_a_id
       JOIN medications mb ON mb.id = di.medication_b_id
       ORDER BY di.severity DESC, ma.name`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('listInteractions error:', err);
    res.status(500).json({ message: 'Failed to list interactions' });
  }
};

// Admin: add interaction
const addInteraction = async (req, res) => {
  try {
    const { medication_a_id, medication_b_id, severity, description, recommendation } = req.body;
    if (!medication_a_id || !medication_b_id || !description) {
      return res.status(400).json({ message: 'medication_a_id, medication_b_id, and description are required' });
    }
    const result = await pool.query(
      `INSERT INTO drug_interactions (medication_a_id, medication_b_id, severity, description, recommendation)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (medication_a_id, medication_b_id) DO UPDATE SET
         severity = EXCLUDED.severity,
         description = EXCLUDED.description,
         recommendation = EXCLUDED.recommendation
       RETURNING *`,
      [medication_a_id, medication_b_id, severity || 'moderate', description, recommendation]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('addInteraction error:', err);
    res.status(500).json({ message: 'Failed to add interaction' });
  }
};

// Admin: delete interaction
const deleteInteraction = async (req, res) => {
  try {
    await pool.query('DELETE FROM drug_interactions WHERE id = $1', [req.params.id]);
    res.json({ message: 'Interaction deleted' });
  } catch (err) {
    console.error('deleteInteraction error:', err);
    res.status(500).json({ message: 'Failed to delete interaction' });
  }
};

module.exports = { checkInteractions, listInteractions, addInteraction, deleteInteraction };
