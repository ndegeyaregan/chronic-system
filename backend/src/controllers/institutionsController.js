const pool = require('../config/db');

/**
 * Map a Sanlam `mField` value to the local `category` enum.
 * Returns null if the value cannot be mapped.
 */
const mapMFieldToCategory = (mField) => {
  if (!mField) return null;
  const v = String(mField).toLowerCase();
  if (v.includes('out-patient only')) return 'outpatient';
  if (v.includes('in and out-patient')) return 'inpatient';
  if (v.includes('pharmacy')) return 'pharmacy';
  if (v.includes('dental')) return 'dental';
  if (v.includes('optical')) return 'optical';
  return null;
};

const VALID_CATEGORIES = ['outpatient', 'inpatient', 'pharmacy', 'dental', 'optical'];

/**
 * GET /api/institutions
 * Query: category, search, includeDeleted (default: false), includeSuspended (default: false)
 * Returns a unified list across hospitals and pharmacies.
 */
const listInstitutions = async (req, res) => {
  try {
    const { category, search, includeDeleted, includeSuspended } = req.query;
    const cat = category ? String(category).toLowerCase() : null;
    const showDeleted = includeDeleted === 'true';
    const showSuspended = includeSuspended === 'true';

    if (cat && !VALID_CATEGORIES.includes(cat)) {
      return res.status(400).json({ message: `Invalid category. Use one of ${VALID_CATEGORIES.join(', ')}` });
    }

    // We carefully build two separate parameter slots because each subquery
    // gets its own copy of the search %term%.
    const hospParams = [];
    const pharmParams = [];
    let hospWhere = 'h.is_active = TRUE';
    let pharmWhere = 'p.is_active = TRUE';

    // Filter out deleted unless explicitly requested
    if (!showDeleted) {
      hospWhere += ' AND h.is_deleted = FALSE';
      pharmWhere += ' AND p.is_deleted = FALSE';
    }

    // Filter out suspended unless explicitly requested
    if (!showSuspended) {
      hospWhere += ' AND h.is_suspended = FALSE';
      pharmWhere += ' AND p.is_suspended = FALSE';
    }

    if (search) {
      hospWhere += ' AND (h.name ILIKE $1 OR h.city ILIKE $1 OR h.address ILIKE $1)';
      hospParams.push(`%${search}%`);
      pharmWhere += ' AND (p.name ILIKE $1 OR p.city ILIKE $1 OR p.address ILIKE $1)';
      pharmParams.push(`%${search}%`);
    }

    let hospitals = [];
    let pharmacies = [];

    const wantHospitals = !cat || ['outpatient', 'inpatient', 'dental', 'optical'].includes(cat);
    const wantPharmacies = !cat || cat === 'pharmacy';

    if (wantHospitals) {
      let where = hospWhere;
      const p = [...hospParams];
      if (cat && cat !== 'pharmacy') {
        p.push(cat);
        where += ` AND h.category = $${p.length}`;
      }
      const r = await pool.query(
        `SELECT h.id, h.sanlam_id, h.name, h.category, h.address, h.street,
                h.city, h.province, h.postal_code, h.phone, h.email,
                h.first_name, h.last_name, h.title, h.short_id,
                h.latitude, h.longitude, h.specialties,
                h.direct_booking_capable, h.is_suspended, h.suspended_reason,
                h.is_deleted, h.is_user_added
           FROM hospitals h
          WHERE ${where}
          ORDER BY h.name`,
        p
      );
      hospitals = r.rows;
    }

    if (wantPharmacies) {
      let where = pharmWhere;
      const p = [...pharmParams];
      const r = await pool.query(
        `SELECT p.id, p.sanlam_id, p.name,
                COALESCE(p.category, 'pharmacy') AS category,
                p.address, p.street, p.city, NULL::text AS province, p.postal_code,
                p.phone, p.email, p.first_name, p.last_name, p.title, p.short_id,
                NULL::numeric AS latitude, NULL::numeric AS longitude,
                NULL::text[] AS specialties,
                FALSE AS direct_booking_capable,
                p.is_suspended, p.suspended_reason,
                p.is_deleted, p.is_user_added
           FROM pharmacies p
          WHERE ${where}
          ORDER BY p.name`,
        p
      );
      pharmacies = r.rows;
    }

    const merged = [...hospitals, ...pharmacies].sort((a, b) =>
      (a.name || '').localeCompare(b.name || '')
    );

    return res.json(merged);
  } catch (err) {
    console.error('listInstitutions error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

/**
 * POST /api/institutions/sanlam-sync
 * Body: { institutions: [{ id, name, firstName, lastName, title, email,
 *                          telephone, mobile, street, address, city,
 *                          postalCode, shortId, mField }, ...] }
 *
 * Upserts each institution into the appropriate local table based on
 * its `mField`, keyed by `sanlam_id`.
 */
const sanlamSync = async (req, res) => {
  const { institutions } = req.body || {};
  if (!Array.isArray(institutions)) {
    return res.status(400).json({ message: 'institutions must be an array' });
  }

  let hospitalsUpserted = 0;
  let pharmaciesUpserted = 0;
  let skipped = 0;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const it of institutions) {
      const sanlamId = it.id != null ? String(it.id) : null;
      if (!sanlamId || !it.name) { skipped++; continue; }

      const category = mapMFieldToCategory(it.mField);
      if (!category) { skipped++; continue; }

      const phone = it.mobile || it.telephone || null;
      const common = {
        sanlam_id:   sanlamId,
        name:        String(it.name).trim(),
        first_name:  it.firstName || null,
        last_name:   it.lastName  || null,
        title:       it.title     || it.tittle || null, // upstream typo tolerated
        email:       it.email     || null,
        phone,
        street:      it.street    || null,
        address:     it.address   || it.street || null,
        city:        it.city      || null,
        postal_code: it.postalCode || null,
        short_id:    it.shortId   || null,
        m_field:     it.mField    || null,
        category,
      };

      if (category === 'pharmacy') {
        // Check if already exists
        const existsRes = await client.query(
          'SELECT id FROM pharmacies WHERE sanlam_id = $1',
          [common.sanlam_id]
        );

        if (existsRes.rows.length > 0) {
          // Update
          await client.query(
            `UPDATE pharmacies SET
               name = $1, first_name = $2, last_name = $3, title = $4, email = $5,
               phone = $6, street = $7, address = $8, city = $9, postal_code = $10,
               short_id = $11, m_field = $12, category = $13, updated_at = NOW()
             WHERE sanlam_id = $14`,
            [
              common.name, common.first_name, common.last_name, common.title, common.email,
              common.phone, common.street, common.address, common.city, common.postal_code,
              common.short_id, common.m_field, common.category, common.sanlam_id,
            ]
          );
        } else {
          // Insert
          await client.query(
            `INSERT INTO pharmacies
               (sanlam_id, name, first_name, last_name, title, email, phone,
                street, address, city, postal_code, short_id, m_field, category, is_active)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,TRUE)`,
            [
              common.sanlam_id, common.name, common.first_name, common.last_name,
              common.title, common.email, common.phone, common.street,
              common.address, common.city, common.postal_code, common.short_id,
              common.m_field, common.category,
            ]
          );
        }
        pharmaciesUpserted++;
      } else {
        // Check if already exists
        const existsRes = await client.query(
          'SELECT id FROM hospitals WHERE sanlam_id = $1',
          [common.sanlam_id]
        );

        if (existsRes.rows.length > 0) {
          // Update
          await client.query(
            `UPDATE hospitals SET
               name = $1, first_name = $2, last_name = $3, title = $4, email = $5,
               phone = $6, street = $7, address = $8, city = $9, postal_code = $10,
               short_id = $11, m_field = $12, category = $13, updated_at = NOW()
             WHERE sanlam_id = $14`,
            [
              common.name, common.first_name, common.last_name, common.title, common.email,
              common.phone, common.street, common.address, common.city, common.postal_code,
              common.short_id, common.m_field, common.category, common.sanlam_id,
            ]
          );
        } else {
          // Insert
          await client.query(
            `INSERT INTO hospitals
               (sanlam_id, name, first_name, last_name, title, email, phone,
                street, address, city, postal_code, short_id, m_field, category, is_active)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,TRUE)`,
            [
              common.sanlam_id, common.name, common.first_name, common.last_name,
              common.title, common.email, common.phone, common.street,
              common.address, common.city, common.postal_code, common.short_id,
              common.m_field, common.category,
            ]
          );
        }
        hospitalsUpserted++;
      }
    }

    await client.query('COMMIT');
    return res.json({
      message: 'Sanlam institutions synced',
      received: institutions.length,
      hospitals_upserted: hospitalsUpserted,
      pharmacies_upserted: pharmaciesUpserted,
      skipped,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('sanlamSync error:', err);
    return res.status(500).json({ message: 'Sanlam sync failed', error: err.message });
  } finally {
    client.release();
  }
};

/**
 * POST /api/institutions/:id/suspend
 * Body: { reason: string (optional) }
 * Suspends an institution (marks as not available for selection)
 */
const suspendInstitution = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Try hospitals first, then pharmacies
      let result = await client.query(
        `UPDATE hospitals SET is_suspended = TRUE, suspended_reason = $1, suspended_at = NOW()
         WHERE id = $2 RETURNING id, name, category`,
        [reason || null, id]
      );

      if (result.rows.length === 0) {
        result = await client.query(
          `UPDATE pharmacies SET is_suspended = TRUE, suspended_reason = $1, suspended_at = NOW()
           WHERE id = $2 RETURNING id, name, category`,
          [reason || null, id]
        );
      }

      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Institution not found' });
      }

      await client.query('COMMIT');
      return res.json({
        message: 'Institution suspended',
        institution: result.rows[0],
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('suspendInstitution error:', err);
    return res.status(500).json({ message: 'Failed to suspend institution' });
  }
};

/**
 * POST /api/institutions/:id/unsuspend
 * Unsuspends a suspended institution
 */
const unsuspendInstitution = async (req, res) => {
  try {
    const { id } = req.params;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Try hospitals first, then pharmacies
      let result = await client.query(
        `UPDATE hospitals SET is_suspended = FALSE, suspended_reason = NULL, suspended_at = NULL
         WHERE id = $1 RETURNING id, name, category`,
        [id]
      );

      if (result.rows.length === 0) {
        result = await client.query(
          `UPDATE pharmacies SET is_suspended = FALSE, suspended_reason = NULL, suspended_at = NULL
           WHERE id = $1 RETURNING id, name, category`,
          [id]
        );
      }

      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Institution not found' });
      }

      await client.query('COMMIT');
      return res.json({
        message: 'Institution unsuspended',
        institution: result.rows[0],
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('unsuspendInstitution error:', err);
    return res.status(500).json({ message: 'Failed to unsuspend institution' });
  }
};

/**
 * DELETE /api/institutions/:id
 * Soft delete: marks as deleted (sets is_deleted = TRUE)
 */
const deleteInstitution = async (req, res) => {
  try {
    const { id } = req.params;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Try hospitals first, then pharmacies
      let result = await client.query(
        `UPDATE hospitals SET is_deleted = TRUE, deleted_at = NOW()
         WHERE id = $1 RETURNING id, name, category`,
        [id]
      );

      if (result.rows.length === 0) {
        result = await client.query(
          `UPDATE pharmacies SET is_deleted = TRUE, deleted_at = NOW()
           WHERE id = $1 RETURNING id, name, category`,
          [id]
        );
      }

      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Institution not found' });
      }

      await client.query('COMMIT');
      return res.json({
        message: 'Institution deleted',
        institution: result.rows[0],
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('deleteInstitution error:', err);
    return res.status(500).json({ message: 'Failed to delete institution' });
  }
};

/**
 * POST /api/institutions
 * Body: { name, category, phone, email, address, city, ... }
 * Creates a new user-added institution
 */
const createInstitution = async (req, res) => {
  try {
    const {
      name, category, phone, email, address, city,
      street, postalCode, firstName, lastName, title,
    } = req.body;

    if (!name || !category) {
      return res.status(400).json({ message: 'name and category are required' });
    }

    if (!VALID_CATEGORIES.includes(category.toLowerCase())) {
      return res.status(400).json({ message: `Invalid category: ${category}` });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const cat = category.toLowerCase();
      const table = cat === 'pharmacy' ? 'pharmacies' : 'hospitals';

      const result = await client.query(
        `INSERT INTO ${table}
          (name, category, phone, email, address, city, street, postal_code,
           first_name, last_name, title, is_user_added, is_active, is_deleted, is_suspended)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, TRUE, TRUE, FALSE, FALSE)
         RETURNING id, name, category, phone, email, address, city, is_user_added`,
        [name, cat, phone || null, email || null, address || null, city || null,
         street || null, postalCode || null, firstName || null, lastName || null,
         title || null]
      );

      await client.query('COMMIT');
      return res.status(201).json({
        message: 'Institution created',
        institution: result.rows[0],
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('createInstitution error:', err);
    return res.status(500).json({ message: 'Failed to create institution' });
  }
};

module.exports = {
  listInstitutions,
  sanlamSync,
  mapMFieldToCategory,
  suspendInstitution,
  unsuspendInstitution,
  deleteInstitution,
  createInstitution,
};
