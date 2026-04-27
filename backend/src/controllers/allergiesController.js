const pool = require('../config/db');

// Get member's allergies
const getMyAllergies = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM member_allergies WHERE member_id = $1 ORDER BY created_at DESC',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('getMyAllergies error:', err);
    res.status(500).json({ message: 'Failed to fetch allergies' });
  }
};

// Add allergy
const addAllergy = async (req, res) => {
  try {
    const { allergen, allergen_type, severity, reaction, diagnosed_date, notes } = req.body;
    if (!allergen) return res.status(400).json({ message: 'Allergen name is required' });

    const result = await pool.query(
      `INSERT INTO member_allergies (member_id, allergen, allergen_type, severity, reaction, diagnosed_date, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [req.user.id, allergen, allergen_type || 'drug', severity || 'moderate', reaction, diagnosed_date, notes]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('addAllergy error:', err);
    res.status(500).json({ message: 'Failed to add allergy' });
  }
};

// Update allergy
const updateAllergy = async (req, res) => {
  try {
    const { allergen, allergen_type, severity, reaction, diagnosed_date, notes } = req.body;
    const result = await pool.query(
      `UPDATE member_allergies SET
        allergen = COALESCE($1, allergen),
        allergen_type = COALESCE($2, allergen_type),
        severity = COALESCE($3, severity),
        reaction = COALESCE($4, reaction),
        diagnosed_date = COALESCE($5, diagnosed_date),
        notes = COALESCE($6, notes),
        updated_at = NOW()
       WHERE id = $7 AND member_id = $8 RETURNING *`,
      [allergen, allergen_type, severity, reaction, diagnosed_date, notes, req.params.id, req.user.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: 'Allergy not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('updateAllergy error:', err);
    res.status(500).json({ message: 'Failed to update allergy' });
  }
};

// Delete allergy
const deleteAllergy = async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM member_allergies WHERE id = $1 AND member_id = $2 RETURNING id',
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: 'Allergy not found' });
    res.json({ message: 'Allergy deleted' });
  } catch (err) {
    console.error('deleteAllergy error:', err);
    res.status(500).json({ message: 'Failed to delete allergy' });
  }
};

// Check if a medication conflicts with member's allergies
const checkAllergyConflict = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { medication_id } = req.query;
    if (!medication_id) return res.status(400).json({ message: 'medication_id query param required' });

    // Get member allergies
    const allergies = await pool.query(
      'SELECT allergen FROM member_allergies WHERE member_id = $1',
      [memberId]
    );
    if (allergies.rows.length === 0) return res.json({ conflicts: [] });

    const allergenNames = allergies.rows.map(r => r.allergen.toLowerCase());

    // Check medication allergens table
    const medAllergens = await pool.query(
      'SELECT allergen FROM medication_allergens WHERE medication_id = $1',
      [medication_id]
    );

    // Also check medication name/generic_name against allergen list
    const med = await pool.query(
      'SELECT name, generic_name FROM medications WHERE id = $1',
      [medication_id]
    );

    const conflicts = [];
    for (const row of medAllergens.rows) {
      if (allergenNames.includes(row.allergen.toLowerCase())) {
        conflicts.push({ allergen: row.allergen, source: 'medication_allergen' });
      }
    }
    if (med.rows.length > 0) {
      const { name, generic_name } = med.rows[0];
      if (allergenNames.includes(name?.toLowerCase())) {
        conflicts.push({ allergen: name, source: 'drug_name' });
      }
      if (generic_name && allergenNames.includes(generic_name.toLowerCase())) {
        conflicts.push({ allergen: generic_name, source: 'generic_name' });
      }
    }

    res.json({ conflicts });
  } catch (err) {
    console.error('checkAllergyConflict error:', err);
    res.status(500).json({ message: 'Failed to check allergy conflicts' });
  }
};

// Admin: get member allergies
const getMemberAllergies = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM member_allergies WHERE member_id = $1 ORDER BY created_at DESC',
      [req.params.memberId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('getMemberAllergies error:', err);
    res.status(500).json({ message: 'Failed to fetch allergies' });
  }
};

module.exports = { getMyAllergies, addAllergy, updateAllergy, deleteAllergy, checkAllergyConflict, getMemberAllergies };
