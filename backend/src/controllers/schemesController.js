const pool = require('../config/db');

const listSchemes = async (req, res) => {
  try {
    const { include_inactive } = req.query;
    const where = include_inactive === 'true' ? '' : 'WHERE is_active = TRUE';
    const result = await pool.query(
      `SELECT * FROM schemes ${where} ORDER BY name ASC`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listSchemes error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createScheme = async (req, res) => {
  try {
    const { name, code, description } = req.body;
    if (!name) return res.status(400).json({ message: 'Scheme name is required' });

    const result = await pool.query(
      `INSERT INTO schemes (name, code, description) VALUES ($1, $2, $3) RETURNING *`,
      [name.trim(), code?.trim() || null, description?.trim() || null]
    );

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'create', 'scheme', $2, $3, $4)`,
      [req.user.id, result.rows[0].id, JSON.stringify({ name }), req.ip]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ message: 'Scheme name already exists' });
    console.error('createScheme error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateScheme = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, code, description, is_active } = req.body;

    const result = await pool.query(
      `UPDATE schemes SET
        name = COALESCE($1, name),
        code = COALESCE($2, code),
        description = COALESCE($3, description),
        is_active = COALESCE($4, is_active),
        updated_at = NOW()
       WHERE id = $5 RETURNING *`,
      [name?.trim() || null, code?.trim() || null, description?.trim() || null, is_active, id]
    );

    if (!result.rows.length) return res.status(404).json({ message: 'Scheme not found' });

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'update', 'scheme', $2, $3, $4)`,
      [req.user.id, id, JSON.stringify({ name, code, is_active }), req.ip]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ message: 'Scheme name already exists' });
    console.error('updateScheme error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deleteScheme = async (req, res) => {
  try {
    const { id } = req.params;
    // Soft delete — just deactivate
    const result = await pool.query(
      `UPDATE schemes SET is_active = FALSE, updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Scheme not found' });

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'delete', 'scheme', $2, $3, $4)`,
      [req.user.id, id, JSON.stringify({ name: result.rows[0].name }), req.ip]
    );

    return res.json({ message: 'Scheme deactivated' });
  } catch (err) {
    console.error('deleteScheme error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getSchemePerformance = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
        s.id, s.name, s.code, s.is_active, s.created_at,
        COUNT(DISTINCT m.id) AS total_members,
        COUNT(DISTINCT CASE WHEN m.is_active = TRUE THEN m.id END) AS active_members,
        COUNT(DISTINCT ap.id) AS total_appointments,
        COUNT(DISTINCT tp.id) AS total_treatment_plans
      FROM schemes s
      LEFT JOIN members m ON m.scheme_id = s.id
      LEFT JOIN appointments ap ON ap.member_id = m.id
      LEFT JOIN treatment_plans tp ON tp.member_id = m.id
      WHERE s.is_active = TRUE
      GROUP BY s.id, s.name, s.code, s.is_active, s.created_at
      ORDER BY total_members DESC`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getSchemePerformance error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const bulkImportSchemes = async (req, res) => {
  try {
    const { schemes } = req.body;
    if (!Array.isArray(schemes) || schemes.length === 0) {
      return res.status(400).json({ message: 'schemes array is required' });
    }

    const results = { created: 0, skipped: 0, invalid: 0, items: [] };

    for (const raw of schemes) {
      const name = (raw?.name || '').toString().trim();
      const code = (raw?.code || '').toString().trim() || null;
      const description = (raw?.description || '').toString().trim() || null;

      if (!name) {
        results.invalid += 1;
        continue;
      }

      const r = await pool.query(
        `INSERT INTO schemes (name, code, description, is_active)
         VALUES ($1, $2, $3, TRUE)
         ON CONFLICT (name) DO NOTHING
         RETURNING id, name`,
        [name, code, description]
      );

      if (r.rows.length) {
        results.created += 1;
        results.items.push({ name, status: 'created' });
      } else {
        results.skipped += 1;
        results.items.push({ name, status: 'skipped' });
      }
    }

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'bulk_import', 'scheme', NULL, $2, $3)`,
      [req.user.id, JSON.stringify({ created: results.created, skipped: results.skipped, invalid: results.invalid }), req.ip]
    );

    return res.json(results);
  } catch (err) {
    console.error('bulkImportSchemes error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const hardDeleteScheme = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await pool.query('SELECT name FROM schemes WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Scheme not found' });

    const linked = await pool.query('SELECT COUNT(*)::int AS c FROM members WHERE scheme_id = $1', [id]);
    if (linked.rows[0].c > 0) {
      return res.status(409).json({
        message: `Cannot delete — ${linked.rows[0].c} member(s) are linked to this scheme. Reassign or remove them first.`,
      });
    }

    await pool.query('DELETE FROM schemes WHERE id = $1', [id]);

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'hard_delete', 'scheme', $2, $3, $4)`,
      [req.user.id, id, JSON.stringify({ name: existing.rows[0].name }), req.ip]
    );

    return res.json({ message: 'Scheme deleted permanently' });
  } catch (err) {
    console.error('hardDeleteScheme error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listSchemes, createScheme, updateScheme, deleteScheme, getSchemePerformance, bulkImportSchemes, hardDeleteScheme };
