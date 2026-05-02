const pool = require('../config/db');

// GET /api/cycle/mine — list this member's cycle entries
const getMine = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, client_id, start_date, end_date, flow, symptoms, mood, notes,
              created_at, updated_at
         FROM cycle_entries
        WHERE member_id = $1
        ORDER BY start_date ASC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('cycle.getMine error:', err);
    res.status(500).json({ message: 'Failed to fetch cycle entries' });
  }
};

// POST /api/cycle — upsert one entry (idempotent per client_id)
const upsertEntry = async (req, res) => {
  try {
    const {
      client_id,
      start_date,
      end_date,
      flow,
      symptoms,
      mood,
      notes,
    } = req.body || {};

    if (!start_date) {
      return res.status(400).json({ message: 'start_date is required' });
    }

    const symptomsJson = JSON.stringify(Array.isArray(symptoms) ? symptoms : []);

    const result = await pool.query(
      `INSERT INTO cycle_entries
         (member_id, client_id, start_date, end_date, flow, symptoms, mood, notes)
       VALUES ($1, $2, $3, $4, COALESCE($5, 'medium'), $6::jsonb, $7, $8)
       ON CONFLICT (member_id, client_id) DO UPDATE SET
         start_date = EXCLUDED.start_date,
         end_date   = EXCLUDED.end_date,
         flow       = EXCLUDED.flow,
         symptoms   = EXCLUDED.symptoms,
         mood       = EXCLUDED.mood,
         notes      = EXCLUDED.notes,
         updated_at = NOW()
       RETURNING *`,
      [
        req.user.id,
        client_id || null,
        start_date,
        end_date || null,
        flow || null,
        symptomsJson,
        mood || null,
        notes || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('cycle.upsertEntry error:', err);
    res.status(500).json({ message: 'Failed to save cycle entry' });
  }
};

// DELETE /api/cycle/:clientId — delete by client-side id
const deleteByClientId = async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM cycle_entries
        WHERE member_id = $1 AND client_id = $2
        RETURNING id`,
      [req.user.id, req.params.clientId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Cycle entry not found' });
    }
    res.json({ message: 'Cycle entry deleted' });
  } catch (err) {
    console.error('cycle.deleteByClientId error:', err);
    res.status(500).json({ message: 'Failed to delete cycle entry' });
  }
};

module.exports = { getMine, upsertEntry, deleteByClientId };
