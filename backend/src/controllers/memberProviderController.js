const pool = require('../config/db');

const getMyProvider = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT mp.*, h.name AS hospital_db_name, h.address AS hospital_db_address, h.phone AS hospital_phone
       FROM member_providers mp
       LEFT JOIN hospitals h ON h.id = mp.hospital_id
       WHERE mp.member_id = $1
       ORDER BY mp.created_at DESC LIMIT 1`,
      [memberId]
    );
    return res.json(result.rows[0] || null);
  } catch (err) {
    console.error('getMyProvider error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const saveProvider = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { provider_type, doctor_name, doctor_contact, doctor_email, hospital_id, hospital_name, hospital_address, notes } = req.body;
    if (!provider_type) return res.status(400).json({ message: 'provider_type is required' });
    if ((provider_type === 'doctor' || provider_type === 'both') && !doctor_contact) {
      return res.status(400).json({ message: 'doctor_contact is required for doctor provider' });
    }
    // Upsert — one provider record per member (delete old, insert new)
    await pool.query('DELETE FROM member_providers WHERE member_id = $1', [memberId]);
    const result = await pool.query(
      `INSERT INTO member_providers
         (member_id, provider_type, doctor_name, doctor_contact, doctor_email, hospital_id, hospital_name, hospital_address, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [memberId, provider_type, doctor_name || null, doctor_contact || null, doctor_email || null,
       hospital_id || null, hospital_name || null, hospital_address || null, notes || null]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('saveProvider error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMemberProvider = async (req, res) => {
  try {
    const { memberId } = req.params;
    const result = await pool.query(
      `SELECT mp.*, h.name AS hospital_db_name
       FROM member_providers mp
       LEFT JOIN hospitals h ON h.id = mp.hospital_id
       WHERE mp.member_id = $1
       ORDER BY mp.created_at DESC LIMIT 1`,
      [memberId]
    );
    return res.json(result.rows[0] || null);
  } catch (err) {
    console.error('getMemberProvider error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { getMyProvider, saveProvider, getMemberProvider };
