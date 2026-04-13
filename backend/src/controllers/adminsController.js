const bcrypt = require('bcryptjs');
const pool = require('../config/db');

const ADMIN_SELECT = `SELECT
  id,
  email,
  COALESCE(first_name, split_part(COALESCE(name, ''), ' ', 1), name) AS first_name,
  COALESCE(last_name, NULLIF(btrim(regexp_replace(COALESCE(name, ''), '^\\S+\\s*', '')), '')) AS last_name,
  TRIM(
    COALESCE(first_name, split_part(COALESCE(name, ''), ' ', 1), name, '')
    || ' ' ||
    COALESCE(last_name, NULLIF(btrim(regexp_replace(COALESCE(name, ''), '^\\S+\\s*', '')), ''), '')
  ) AS name,
  role,
  is_active,
  created_at
FROM admins`;

const listAdmins = async (req, res) => {
  try {
    const result = await pool.query(
      `${ADMIN_SELECT}
       ORDER BY created_at DESC`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listAdmins error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createAdmin = async (req, res) => {
  try {
    const {
      email,
      first_name,
      last_name,
      role = 'support_admin',
      password,
    } = req.body;
    if (!email || !password || !first_name || !last_name) {
      return res.status(400).json({ message: 'email, password, first_name, last_name are required' });
    }
    const existing = await pool.query('SELECT id FROM admins WHERE email = $1', [email]);
    if (existing.rows.length) {
      return res.status(409).json({ message: 'Email already registered' });
    }
    const hash = await bcrypt.hash(password, 12);
    const fullName = `${first_name} ${last_name}`.trim();
    const result = await pool.query(
      `INSERT INTO admins (email, name, first_name, last_name, role, password_hash, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,TRUE)
       RETURNING
         id,
         email,
         first_name,
         last_name,
         TRIM(CONCAT_WS(' ', first_name, last_name)) AS name,
         role,
         is_active,
         created_at`,
      [email, fullName, first_name, last_name, role, hash]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createAdmin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { first_name, last_name, role } = req.body;
    const result = await pool.query(
      `UPDATE admins SET
         first_name = COALESCE($1, first_name),
         last_name  = COALESCE($2, last_name),
         name       = TRIM(CONCAT_WS(' ', COALESCE($1, first_name), COALESCE($2, last_name))),
         role       = COALESCE($3, role),
         updated_at = NOW()
       WHERE id = $4
       RETURNING
         id,
         email,
         first_name,
         last_name,
         TRIM(CONCAT_WS(' ', first_name, last_name)) AS name,
         role,
         is_active`,
      [first_name || null, last_name || null, role || null, id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Admin not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateAdmin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const toggleAdminStatus = async (req, res) => {
  try {
    const { id } = req.params;
    // Prevent self-deactivation
    if (id === req.user.id) {
      return res.status(400).json({ message: 'Cannot deactivate your own account' });
    }
    const current = await pool.query('SELECT is_active FROM admins WHERE id = $1', [id]);
    if (!current.rows.length) return res.status(404).json({ message: 'Admin not found' });
    const newStatus = !current.rows[0].is_active;
    await pool.query('UPDATE admins SET is_active = $1, updated_at = NOW() WHERE id = $2', [newStatus, id]);
    return res.json({ message: `Admin ${newStatus ? 'activated' : 'deactivated'}`, is_active: newStatus });
  } catch (err) {
    console.error('toggleAdminStatus error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const resetAdminPassword = async (req, res) => {
  try {
    const { id } = req.params;
    const { new_password } = req.body;
    if (!new_password || new_password.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }
    const hash = await bcrypt.hash(new_password, 12);
    const result = await pool.query(
      'UPDATE admins SET password_hash = $1, updated_at = NOW() WHERE id = $2 RETURNING id',
      [hash, id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Admin not found' });
    return res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error('resetAdminPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listAdmins, createAdmin, updateAdmin, toggleAdminStatus, resetAdminPassword };
