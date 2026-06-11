const pool = require('../config/db');
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
const axios = require('axios');

const SANLAM_API_BASE =
  process.env.SANLAM_API_URL || 'https://ehosccs.net/SanlamMemberApi/api/member/';
const SYNC_USERNAME = process.env.SANLAM_SYNC_USERNAME;
const SYNC_PASSWORD = process.env.SANLAM_SYNC_PASSWORD;

const sanlamUrl = (p) =>
  SANLAM_API_BASE.replace(/\/+$/, '') + '/' + p.replace(/^\/+/, '');

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

const institutionFileToPublicPath = (file) => {
  if (!file) return null;
  return `/uploads/institution-price-lists/${path.basename(file.path)}`;
};

const deleteLocalFileIfExists = (filePath) => {
  if (!filePath || typeof filePath !== 'string') return;
  const uploadsRoot = path.join(__dirname, '../../uploads');
  const absolute = path.join(__dirname, '../../', filePath.replace(/^\//, ''));
  if (!absolute.startsWith(uploadsRoot)) return;
  if (fs.existsSync(absolute)) {
    fs.unlinkSync(absolute);
  }
};

/**
 * Parse an uploaded price-list spreadsheet (.xlsx / .xls / .csv) and
 * upsert the rows into `services` + `institution_service_prices`.
 *
 * Expected columns (case-insensitive, flexible aliases):
 *   - "Service" / "Service Name" / "Procedure" / "Test"   (required)
 *   - "Price" / "Cost" / "Amount" / "Tariff"               (required, numeric)
 *   - "Category" / "Group"                                  (optional)
 *   - "Currency"                                            (optional, default UGX)
 *
 * Returns { created, updated, skipped, total }.
 * Safe to call on any file — returns null if mime/extension isn't a spreadsheet.
 */
const PARSEABLE_MIMES = new Set([
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/csv',
  'application/csv',
  'text/plain', // some CSVs get reported as text/plain
]);

const parseAndImportPriceList = async ({ absoluteFilePath, mimeType, fileName, institutionId, institutionType, priceListId, adminId }) => {
  const ext = (path.extname(fileName || '') || '').toLowerCase();
  const isSpreadsheet = PARSEABLE_MIMES.has((mimeType || '').toLowerCase())
    || ['.xlsx', '.xls', '.csv'].includes(ext);
  if (!isSpreadsheet) return null;

  let rows;
  try {
    const wb = XLSX.readFile(absoluteFilePath, { cellDates: false });
    const firstSheet = wb.Sheets[wb.SheetNames[0]];
    if (!firstSheet) return { created: 0, updated: 0, skipped: 0, total: 0, error: 'No sheets in file' };
    rows = XLSX.utils.sheet_to_json(firstSheet, { defval: '' });
  } catch (err) {
    console.warn('parseAndImportPriceList: read failed:', err.message);
    return { created: 0, updated: 0, skipped: 0, total: 0, error: 'Could not read spreadsheet' };
  }

  const pickField = (row, aliases) => {
    for (const k of Object.keys(row)) {
      const key = k.toString().trim().toLowerCase();
      if (aliases.includes(key)) return row[k];
    }
    return undefined;
  };

  const summary = { created: 0, updated: 0, skipped: 0, total: rows.length };

  for (const raw of rows) {
    const name = (pickField(raw, ['service', 'service name', 'procedure', 'test', 'item', 'description']) || '').toString().trim();
    const priceRaw = pickField(raw, ['price', 'cost', 'amount', 'tariff', 'fee']);
    const category = (pickField(raw, ['category', 'group', 'section']) || '').toString().trim() || null;
    const currency = ((pickField(raw, ['currency', 'ccy']) || 'UGX').toString().trim().toUpperCase()) || 'UGX';

    if (!name) { summary.skipped += 1; continue; }
    const price = Number(String(priceRaw).replace(/[^\d.\-]/g, ''));
    if (!Number.isFinite(price) || price < 0) { summary.skipped += 1; continue; }

    try {
      // Upsert the service (case-insensitive de-dup: normalise to upper-case for the unique key).
      const normalisedName = name.replace(/\s+/g, ' ').trim();
      const svc = await pool.query(
        `INSERT INTO services (name, category)
           VALUES ($1, $2)
         ON CONFLICT (name) DO UPDATE
           SET category = COALESCE(services.category, EXCLUDED.category),
               updated_at = NOW()
         RETURNING id`,
        [normalisedName, category]
      );
      const serviceId = svc.rows[0].id;

      // Upsert the price for this institution + service (today's effective date).
      const ins = await pool.query(
        `INSERT INTO institution_service_prices
           (institution_id, institution_type, service_id, price, currency,
            effective_from, source_price_list_id, uploaded_by, updated_by)
         VALUES ($1, $2, $3, $4, $5, CURRENT_DATE, $6, $7, $7)
         ON CONFLICT (institution_id, institution_type, service_id, effective_from, currency)
         DO UPDATE SET
           price = EXCLUDED.price,
           source_price_list_id = EXCLUDED.source_price_list_id,
           updated_by = EXCLUDED.updated_by,
           updated_at = NOW()
         RETURNING (xmax = 0) AS inserted`,
        [institutionId, institutionType, serviceId, price, currency, priceListId, adminId]
      );
      if (ins.rows[0].inserted) summary.created += 1; else summary.updated += 1;
    } catch (err) {
      summary.skipped += 1;
      console.warn('parseAndImportPriceList row skipped:', name, err.message);
    }
  }

  return summary;
};

const absolutePathForUpload = (file) => {
  if (!file) return null;
  if (file.path && fs.existsSync(file.path)) return file.path;
  return path.join(__dirname, '../../uploads/institution-price-lists', path.basename(file.path || file.filename || ''));
};


const findInstitutionById = async (institutionId) => {
  const hospitalRes = await pool.query(
    `SELECT id, name, category, 'hospital'::text AS institution_type
       FROM hospitals
      WHERE id = $1`,
    [institutionId]
  );
  if (hospitalRes.rows.length) return hospitalRes.rows[0];

  const pharmacyRes = await pool.query(
    `SELECT id, name, COALESCE(category, 'pharmacy') AS category, 'pharmacy'::text AS institution_type
       FROM pharmacies
      WHERE id = $1`,
    [institutionId]
  );
  return pharmacyRes.rows[0] || null;
};

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
      hospWhere += ' AND (h.name ILIKE $1 OR h.city ILIKE $1 OR h.address ILIKE $1 OR h.area ILIKE $1)';
      hospParams.push(`%${search}%`);
      pharmWhere += ' AND (p.name ILIKE $1 OR p.city ILIKE $1 OR p.address ILIKE $1 OR p.area ILIKE $1)';
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
                h.is_deleted, h.is_user_added,
                h.area, h.contact_person, h.working_hours,
                h.created_at, h.suspended_at, h.unsuspended_at,
                h.added_by, h.suspended_by, h.unsuspended_by,
                added_admin.name      AS added_by_name,
                suspended_admin.name  AS suspended_by_name,
                unsuspended_admin.name AS unsuspended_by_name
           FROM hospitals h
           LEFT JOIN admins added_admin       ON added_admin.id       = h.added_by
           LEFT JOIN admins suspended_admin   ON suspended_admin.id   = h.suspended_by
           LEFT JOIN admins unsuspended_admin ON unsuspended_admin.id = h.unsuspended_by
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
                p.latitude, p.longitude,
                NULL::text[] AS specialties,
                FALSE AS direct_booking_capable,
                p.is_suspended, p.suspended_reason,
                p.is_deleted, p.is_user_added,
                p.area, p.contact_person, p.working_hours,
                p.created_at, p.suspended_at, p.unsuspended_at,
                p.added_by, p.suspended_by, p.unsuspended_by,
                added_admin.name      AS added_by_name,
                suspended_admin.name  AS suspended_by_name,
                unsuspended_admin.name AS unsuspended_by_name
           FROM pharmacies p
           LEFT JOIN admins added_admin       ON added_admin.id       = p.added_by
           LEFT JOIN admins suspended_admin   ON suspended_admin.id   = p.suspended_by
           LEFT JOIN admins unsuspended_admin ON unsuspended_admin.id = p.unsuspended_by
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
/**
 * Core upsert logic for Sanlam institutions. Used by both:
 *  - the HTTP handler `sanlamSync` (called from the Flutter app's
 *    "Sync from Sanlam" button), and
 *  - the backend cron job that pulls Sanlam directly every 3 days.
 *
 * Returns `{ received, hospitals_upserted, pharmacies_upserted, skipped }`.
 * Throws on DB error so the caller can decide how to surface it.
 */
const upsertSanlamInstitutions = async (institutions) => {
  if (!Array.isArray(institutions)) {
    throw new Error('institutions must be an array');
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
        const existsRes = await client.query(
          'SELECT id FROM pharmacies WHERE sanlam_id = $1',
          [common.sanlam_id]
        );

        if (existsRes.rows.length > 0) {
          await client.query(
            `UPDATE pharmacies SET
               name = $1, first_name = $2, last_name = $3, title = $4, email = $5,
               phone = $6, street = $7, address = $8, city = $9, postal_code = $10,
               short_id = $11, m_field = $12, category = $13,
               is_deleted = FALSE, deleted_at = NULL,
               updated_at = NOW()
             WHERE sanlam_id = $14`,
            [
              common.name, common.first_name, common.last_name, common.title, common.email,
              common.phone, common.street, common.address, common.city, common.postal_code,
              common.short_id, common.m_field, common.category, common.sanlam_id,
            ]
          );
        } else {
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
        const existsRes = await client.query(
          'SELECT id FROM hospitals WHERE sanlam_id = $1',
          [common.sanlam_id]
        );

        if (existsRes.rows.length > 0) {
          await client.query(
            `UPDATE hospitals SET
               name = $1, first_name = $2, last_name = $3, title = $4, email = $5,
               phone = $6, street = $7, address = $8, city = $9, postal_code = $10,
               short_id = $11, m_field = $12, category = $13,
               is_deleted = FALSE, deleted_at = NULL,
               updated_at = NOW()
             WHERE sanlam_id = $14`,
            [
              common.name, common.first_name, common.last_name, common.title, common.email,
              common.phone, common.street, common.address, common.city, common.postal_code,
              common.short_id, common.m_field, common.category, common.sanlam_id,
            ]
          );
        } else {
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
    return {
      received: institutions.length,
      hospitals_upserted: hospitalsUpserted,
      pharmacies_upserted: pharmaciesUpserted,
      skipped,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const sanlamSync = async (req, res) => {
  const { institutions } = req.body || {};
  if (!Array.isArray(institutions)) {
    return res.status(400).json({ message: 'institutions must be an array' });
  }
  try {
    const result = await upsertSanlamInstitutions(institutions);
    return res.json({ message: 'Sanlam institutions synced', ...result });
  } catch (err) {
    console.error('sanlamSync error:', err);
    return res.status(500).json({ message: 'Sanlam sync failed', error: err.message });
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
    const adminId = req.user?.id || null;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Try hospitals first, then pharmacies
      let result = await client.query(
        `UPDATE hospitals
            SET is_suspended = TRUE,
                suspended_reason = $1,
                suspended_at = NOW(),
                suspended_by = $2,
                unsuspended_by = NULL,
                unsuspended_at = NULL
          WHERE id = $3
          RETURNING id, name, category`,
        [reason || null, adminId, id]
      );

      if (result.rows.length === 0) {
        result = await client.query(
          `UPDATE pharmacies
              SET is_suspended = TRUE,
                  suspended_reason = $1,
                  suspended_at = NOW(),
                  suspended_by = $2,
                  unsuspended_by = NULL,
                  unsuspended_at = NULL
            WHERE id = $3
            RETURNING id, name, category`,
          [reason || null, adminId, id]
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
    const adminId = req.user?.id || null;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Try hospitals first, then pharmacies
      let result = await client.query(
        `UPDATE hospitals
            SET is_suspended = FALSE,
                suspended_reason = NULL,
                suspended_at = NULL,
                suspended_by = NULL,
                unsuspended_by = $1,
                unsuspended_at = NOW()
          WHERE id = $2
          RETURNING id, name, category`,
        [adminId, id]
      );

      if (result.rows.length === 0) {
        result = await client.query(
          `UPDATE pharmacies
              SET is_suspended = FALSE,
                  suspended_reason = NULL,
                  suspended_at = NULL,
                  suspended_by = NULL,
                  unsuspended_by = $1,
                  unsuspended_at = NOW()
            WHERE id = $2
            RETURNING id, name, category`,
          [adminId, id]
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
      area, contact_person, working_hours, latitude, longitude,
    } = req.body;

    if (!name || !category) {
      return res.status(400).json({ message: 'name and category are required' });
    }

    if (!VALID_CATEGORIES.includes(category.toLowerCase())) {
      return res.status(400).json({ message: `Invalid category: ${category}` });
    }

    const client = await pool.connect();
    let institution;
    try {
      await client.query('BEGIN');

      const cat = category.toLowerCase();
      const table = cat === 'pharmacy' ? 'pharmacies' : 'hospitals';
      const adminId = req.user?.id || null;

      const result = await client.query(
        `INSERT INTO ${table}
          (name, category, phone, email, address, city, street, postal_code,
           first_name, last_name, title, area, contact_person, working_hours,
           latitude, longitude,
           is_user_added, is_active, is_deleted, is_suspended, added_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
                 TRUE, TRUE, FALSE, FALSE, $17)
         RETURNING id, name, category, phone, email, address, city, area, contact_person,
                   working_hours, latitude, longitude, is_user_added, added_by, created_at`,
        [name, cat, phone || null, email || null, address || null, city || null,
         street || null, postalCode || null, firstName || null, lastName || null,
         title || null, area || null, contact_person || null, working_hours || null,
         latitude || null, longitude || null, adminId]
      );
      institution = result.rows[0];

      // Save uploaded documents
      if (req.files && req.files.length > 0) {
        const instType = cat === 'pharmacy' ? 'pharmacy' : 'hospital';
        for (const file of req.files) {
          await client.query(
            `INSERT INTO institution_documents
               (institution_id, institution_type, file_name, file_path, file_size, mime_type, uploaded_by)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [institution.id, instType, file.originalname, file.path, file.size, file.mimetype, adminId]
          );
        }
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    // Send notification email to IT team (non-blocking — don't fail the response)
    setImmediate(async () => {
      try {
        const { sendMail } = require('../utils/mailer');

        const formatVal = (v) => v || '<em style="color:#94a3b8">—</em>';
        const rows = [
          ['Institution Name', institution.name],
          ['Category',         institution.category],
          ['Area / Location',  institution.area],
          ['Address',          institution.address],
          ['Street',           institution.street],
          ['City',             institution.city],
          ['Phone',            institution.phone],
          ['Email',            institution.email],
          ['Contact Person',   institution.contact_person || [firstName, lastName].filter(Boolean).join(' ')],
          ['Working Hours',    institution.working_hours],
          ['Latitude',         institution.latitude],
          ['Longitude',        institution.longitude],
        ];

        const tableRows = rows.map(([label, val]) => `
          <tr>
            <td style="padding:8px 12px;font-weight:600;color:#374151;background:#f9fafb;border:1px solid #e5e7eb;white-space:nowrap">${label}</td>
            <td style="padding:8px 12px;color:#1f2937;border:1px solid #e5e7eb">${formatVal(val)}</td>
          </tr>`).join('');

        const html = `
          <div style="font-family:Arial,sans-serif;max-width:680px;margin:0 auto">
            <div style="background:#1d4ed8;padding:20px 24px;border-radius:8px 8px 0 0">
              <h1 style="margin:0;color:#fff;font-size:20px">New Provider Addition Request</h1>
              <p style="margin:4px 0 0;color:#bfdbfe;font-size:14px">SanCare+ Admin Portal</p>
            </div>
            <div style="background:#fff;padding:24px;border:1px solid #e5e7eb;border-top:none">
              <p style="margin:0 0 16px;color:#374151;font-size:15px">
                Hi IT Team,<br><br>
                A new healthcare provider has been added to the SanCare+ system by an admin.
                Please add this provider to <strong>Ehealth One</strong> so that members can access services under this provider.
              </p>
              <table style="border-collapse:collapse;width:100%;margin-bottom:20px">
                <thead>
                  <tr>
                    <th colspan="2" style="padding:10px 12px;text-align:left;background:#eff6ff;color:#1e40af;border:1px solid #e5e7eb;font-size:13px;text-transform:uppercase;letter-spacing:0.05em">
                      Provider Details
                    </th>
                  </tr>
                </thead>
                <tbody>${tableRows}</tbody>
              </table>
              ${req.files && req.files.length > 0 ? `
              <p style="margin:0 0 8px;color:#374151;font-size:14px">
                <strong>${req.files.length} document(s)</strong> are attached to this email (see attachments below).
              </p>` : ''}
              <p style="margin:16px 0 0;font-size:13px;color:#6b7280">
                This is an automated notification from the SanCare+ Admin Portal.
                Please do not reply to this email. For queries contact the SanCare+ team.
              </p>
            </div>
          </div>`;

        const emailAttachments = (req.files || []).map((f) => ({
          filename: f.originalname,
          path: f.path,
        }));

        await sendMail({
          to: 'it@ug.sanlamallianz.com',
          subject: `New Provider Request – ${institution.name} (${institution.category || 'institution'})`,
          html,
          attachments: emailAttachments,
        });
      } catch (mailErr) {
        console.error('[createInstitution] Email notification failed:', mailErr.message);
      }
    });

    return res.status(201).json({
      message: 'Institution created',
      institution,
    });
  } catch (err) {
    console.error('createInstitution error:', err);
    return res.status(500).json({ message: 'Failed to create institution' });
  }
};

/**
 * GET /api/institutions/price-lists
 * Query: institutionId, search
 */
const listInstitutionPriceLists = async (req, res) => {
  try {
    const { institutionId, search } = req.query || {};
    const params = [];
    const where = [];

    if (institutionId) {
      params.push(institutionId);
      where.push(`ipl.institution_id = $${params.length}`);
    }

    if (search) {
      params.push(`%${String(search).trim()}%`);
      where.push(`(COALESCE(i.name, '') ILIKE $${params.length} OR COALESCE(ipl.file_name, '') ILIKE $${params.length})`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const result = await pool.query(
      `SELECT ipl.id, ipl.institution_id, ipl.institution_type, ipl.file_name, ipl.file_path,
              ipl.file_size, ipl.mime_type, ipl.notes, ipl.uploaded_by, ipl.updated_by,
              ipl.created_at, ipl.updated_at,
              i.name AS institution_name, i.category AS institution_category,
              uploader.name AS uploaded_by_name,
              updater.name AS updated_by_name
         FROM institution_price_lists ipl
         JOIN (
           SELECT id, name, category, 'hospital'::text AS institution_type
             FROM hospitals
           UNION ALL
           SELECT id, name, COALESCE(category, 'pharmacy') AS category, 'pharmacy'::text AS institution_type
             FROM pharmacies
         ) i
           ON i.id = ipl.institution_id AND i.institution_type = ipl.institution_type
         LEFT JOIN admins uploader ON uploader.id = ipl.uploaded_by
         LEFT JOIN admins updater ON updater.id = ipl.updated_by
         ${whereSql}
        ORDER BY ipl.created_at DESC`,
      params
    );

    return res.json(result.rows);
  } catch (err) {
    console.error('listInstitutionPriceLists error:', err);
    return res.status(500).json({ message: 'Failed to load institution price lists' });
  }
};

/**
 * POST /api/institutions/price-lists
 * multipart/form-data:
 * - institutionId (required)
 * - notes (optional)
 * - priceList file (required)
 */
const createInstitutionPriceList = async (req, res) => {
  try {
    const institutionId = String(req.body?.institutionId || '').trim();
    const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim() : null;
    const adminId = req.user?.id || null;
    const uploadedFile = req.file || null;

    if (!institutionId) {
      return res.status(400).json({ message: 'institutionId is required' });
    }
    if (!uploadedFile) {
      return res.status(400).json({ message: 'priceList file is required' });
    }

    const institution = await findInstitutionById(institutionId);
    if (!institution) {
      deleteLocalFileIfExists(institutionFileToPublicPath(uploadedFile));
      return res.status(404).json({ message: 'Institution not found' });
    }

    const filePath = institutionFileToPublicPath(uploadedFile);
    const insert = await pool.query(
      `INSERT INTO institution_price_lists
         (institution_id, institution_type, file_name, file_path, file_size, mime_type, notes, uploaded_by, updated_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8)
       RETURNING id, institution_id, institution_type, file_name, file_path, file_size, mime_type, notes,
                 uploaded_by, updated_by, created_at, updated_at`,
      [
        institution.id,
        institution.institution_type,
        uploadedFile.originalname,
        filePath,
        uploadedFile.size || 0,
        uploadedFile.mimetype || 'application/octet-stream',
        notes || null,
        adminId,
      ]
    );

    return res.status(201).json({
      message: 'Institution price list uploaded',
      priceList: {
        ...insert.rows[0],
        institution_name: institution.name,
        institution_category: institution.category,
      },
      importSummary: await parseAndImportPriceList({
        absoluteFilePath: absolutePathForUpload(uploadedFile),
        mimeType: uploadedFile.mimetype,
        fileName: uploadedFile.originalname,
        institutionId: institution.id,
        institutionType: institution.institution_type,
        priceListId: insert.rows[0].id,
        adminId,
      }),
    });
  } catch (err) {
    if (req.file) deleteLocalFileIfExists(institutionFileToPublicPath(req.file));
    console.error('createInstitutionPriceList error:', err);
    return res.status(500).json({ message: 'Failed to upload institution price list' });
  }
};

/**
 * PUT /api/institutions/price-lists/:id
 * multipart/form-data:
 * - institutionId (required)
 * - notes (optional)
 * - priceList file (optional, replaces existing file)
 */
const updateInstitutionPriceList = async (req, res) => {
  try {
    const { id } = req.params;
    const institutionId = String(req.body?.institutionId || '').trim();
    const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim() : null;
    const adminId = req.user?.id || null;
    const newFile = req.file || null;

    if (!institutionId) {
      return res.status(400).json({ message: 'institutionId is required' });
    }

    const existingRes = await pool.query(
      `SELECT id, file_path
         FROM institution_price_lists
        WHERE id = $1`,
      [id]
    );

    if (!existingRes.rows.length) {
      if (newFile) deleteLocalFileIfExists(institutionFileToPublicPath(newFile));
      return res.status(404).json({ message: 'Price list not found' });
    }

    const institution = await findInstitutionById(institutionId);
    if (!institution) {
      if (newFile) deleteLocalFileIfExists(institutionFileToPublicPath(newFile));
      return res.status(404).json({ message: 'Institution not found' });
    }

    const current = existingRes.rows[0];
    const nextFilePath = newFile ? institutionFileToPublicPath(newFile) : current.file_path;
    const nextFileName = newFile ? newFile.originalname : null;
    const nextFileSize = newFile ? (newFile.size || 0) : null;
    const nextMimeType = newFile ? (newFile.mimetype || 'application/octet-stream') : null;

    const update = await pool.query(
      `UPDATE institution_price_lists
          SET institution_id = $1,
              institution_type = $2,
              file_name = COALESCE($3, file_name),
              file_path = COALESCE($4, file_path),
              file_size = COALESCE($5, file_size),
              mime_type = COALESCE($6, mime_type),
              notes = $7,
              updated_by = $8,
              updated_at = NOW()
        WHERE id = $9
        RETURNING id, institution_id, institution_type, file_name, file_path, file_size, mime_type, notes,
                  uploaded_by, updated_by, created_at, updated_at`,
      [
        institution.id,
        institution.institution_type,
        nextFileName,
        nextFilePath,
        nextFileSize,
        nextMimeType,
        notes || null,
        adminId,
        id,
      ]
    );

    if (newFile && current.file_path && current.file_path !== nextFilePath) {
      deleteLocalFileIfExists(current.file_path);
    }

    return res.json({
      message: 'Institution price list updated',
      priceList: {
        ...update.rows[0],
        institution_name: institution.name,
        institution_category: institution.category,
      },
      importSummary: newFile ? await parseAndImportPriceList({
        absoluteFilePath: absolutePathForUpload(newFile),
        mimeType: newFile.mimetype,
        fileName: newFile.originalname,
        institutionId: institution.id,
        institutionType: institution.institution_type,
        priceListId: update.rows[0].id,
        adminId,
      }) : null,
    });
  } catch (err) {
    if (req.file) deleteLocalFileIfExists(institutionFileToPublicPath(req.file));
    console.error('updateInstitutionPriceList error:', err);
    return res.status(500).json({ message: 'Failed to update institution price list' });
  }
};

/**
 * PUT /api/institutions/:id
 * Update an institution's details.
 *
 * For Sanlam-synced institutions (is_user_added = FALSE) only admin-managed
 * fields may be changed: area, contact_person, working_hours, latitude, longitude.
 * User-added institutions allow updating all fields.
 */
const updateInstitution = async (req, res) => {
  try {
    const { id } = req.params;

    const inst = await findInstitutionById(id);
    if (!inst) return res.status(404).json({ message: 'Institution not found' });

    const table = inst.institution_type === 'pharmacy' ? 'pharmacies' : 'hospitals';

    const {
      // Admin-managed fields (editable on all institutions)
      area, contact_person, working_hours, latitude, longitude,
      // Identity fields (only editable on user-added institutions)
      name, category, phone, email, address, street, city, province,
      postal_code, first_name, last_name, title, direct_booking_capable,
    } = req.body;

    // Build SET clauses dynamically so only provided fields are updated and
    // null/empty string genuinely clears a value.
    const setClauses = [];
    const params = [];
    let idx = 1;

    const addField = (col, val) => {
      setClauses.push(`${col} = $${idx++}`);
      // Treat empty string as null for optional fields
      params.push(val === '' ? null : val === undefined ? null : val);
    };

    // Always allow these admin-managed fields
    if (area !== undefined)            addField('area', area);
    if (contact_person !== undefined)  addField('contact_person', contact_person);
    if (working_hours !== undefined)   addField('working_hours', working_hours);
    if (latitude !== undefined)        addField('latitude', latitude === '' ? null : Number(latitude) || null);
    if (longitude !== undefined)       addField('longitude', longitude === '' ? null : Number(longitude) || null);

    // For user-added institutions allow full edits
    const isUserAdded = await pool.query(
      `SELECT is_user_added FROM ${table} WHERE id = $1`,
      [id]
    );
    if (isUserAdded.rows[0]?.is_user_added) {
      if (name !== undefined)                    addField('name', name);
      if (category !== undefined && VALID_CATEGORIES.includes(String(category).toLowerCase())) {
        // Disallow cross-table moves (hospital ↔ pharmacy)
        const newCat = String(category).toLowerCase();
        const isPharmacy = newCat === 'pharmacy';
        const wasPharmacy = table === 'pharmacies';
        if (isPharmacy === wasPharmacy) addField('category', newCat);
      }
      if (phone !== undefined)                   addField('phone', phone);
      if (email !== undefined)                   addField('email', email);
      if (address !== undefined)                 addField('address', address);
      if (street !== undefined)                  addField('street', street);
      if (city !== undefined)                    addField('city', city);
      if (province !== undefined && table === 'hospitals') addField('province', province);
      if (postal_code !== undefined)             addField('postal_code', postal_code);
      if (first_name !== undefined)              addField('first_name', first_name);
      if (last_name !== undefined)               addField('last_name', last_name);
      if (title !== undefined)                   addField('title', title);
      if (direct_booking_capable !== undefined && table === 'hospitals') {
        addField('direct_booking_capable', direct_booking_capable === true || direct_booking_capable === 'true');
      }
    }

    if (setClauses.length === 0) {
      return res.status(400).json({ message: 'No updatable fields provided' });
    }

    setClauses.push(`updated_at = NOW()`);
    params.push(id);

    const result = await pool.query(
      `UPDATE ${table}
          SET ${setClauses.join(', ')}
        WHERE id = $${idx}
        RETURNING id, name, category, phone, email, address, street, city, province,
                  postal_code, area, contact_person, working_hours, latitude, longitude,
                  first_name, last_name, title, direct_booking_capable,
                  is_user_added, is_suspended, is_deleted, updated_at`,
      params
    );

    return res.json({ message: 'Institution updated', institution: result.rows[0] });
  } catch (err) {
    console.error('updateInstitution error:', err);
    return res.status(500).json({ message: 'Failed to update institution' });
  }
};

/**
 * POST /api/institutions/copays/sync
 * Logs into the Sanlam API with the configured service account, fetches
 * GetInstCoPay and upserts results into institution_copays.
 */
const syncInstitutionCopays = async (req, res) => {
  try {
    if (!SYNC_USERNAME || !SYNC_PASSWORD) {
      return res.status(503).json({ message: 'Sanlam sync credentials not configured (SANLAM_SYNC_USERNAME / SANLAM_SYNC_PASSWORD)' });
    }

    // Login to get token + member number
    const loginResp = await axios.post(
      sanlamUrl('login'),
      { username: SYNC_USERNAME, password: SYNC_PASSWORD },
      { timeout: 20000 }
    );
    const loginData = loginResp.data || {};
    if ((loginData.status || '').toString() !== 'OK') {
      return res.status(502).json({ message: `Sanlam login failed: ${loginData.description || ''}` });
    }
    const payload = loginData.data || {};
    const token = payload.token || payload.Token || payload.accessToken || payload.access_token;
    if (!token) {
      return res.status(502).json({ message: 'Sanlam login: no token in response' });
    }
    // Prefer member number from login response, fall back to env var or username
    const memberNo = (payload.memberNo || payload.MemberNo || payload.memberno ||
      process.env.SANLAM_SYNC_MEMBER_NO || SYNC_USERNAME).toString();

    // Call GetInstCoPay
    const coPayResp = await axios.post(
      sanlamUrl('GetInstCoPay'),
      { MemberNo: memberNo },
      { headers: { Authorization: `Bearer ${token}` }, timeout: 30000 }
    );
    const coPayData = coPayResp.data || {};
    const status = (coPayData.status || '').toString();
    const desc = (coPayData.description || '').toString().toLowerCase();
    const looksEmpty = desc.includes('not found') || desc.includes('no record') ||
      /\bno\b.*\b(found|exist|available)\b/.test(desc);

    let list = [];
    if (status === 'OK') {
      list = Array.isArray(coPayData.data) ? coPayData.data : coPayData.data ? [coPayData.data] : [];
    } else if (!looksEmpty) {
      return res.status(502).json({ message: `GetInstCoPay failed: ${coPayData.description || status}` });
    }

    const toD = (v) => {
      if (v == null) return null;
      const s = v.toString().replace(/[%,]/g, '').trim();
      const n = parseFloat(s);
      return isFinite(n) ? n : null;
    };

    const adminId = req.user?.id || null;
    let upserted = 0;

    for (const row of list) {
      const sanlamId = (row.InstId || row.instId || '').toString().trim();
      if (!sanlamId) continue;

      await pool.query(
        `INSERT INTO institution_copays
           (sanlam_id, institution_name, short_id, benefit_schemes, copay_for,
            excluded_schemes, out_patient, out_patient_percent, out_patient_max,
            in_patient, in_patient_percent, in_patient_max,
            dental, dental_percent, optical, optical_percent,
            pharma, pharma_percent, raw_data, synced_by, synced_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,NOW(),NOW())
         ON CONFLICT (sanlam_id) DO UPDATE SET
           institution_name    = EXCLUDED.institution_name,
           short_id            = EXCLUDED.short_id,
           benefit_schemes     = EXCLUDED.benefit_schemes,
           copay_for           = EXCLUDED.copay_for,
           excluded_schemes    = EXCLUDED.excluded_schemes,
           out_patient         = EXCLUDED.out_patient,
           out_patient_percent = EXCLUDED.out_patient_percent,
           out_patient_max     = EXCLUDED.out_patient_max,
           in_patient          = EXCLUDED.in_patient,
           in_patient_percent  = EXCLUDED.in_patient_percent,
           in_patient_max      = EXCLUDED.in_patient_max,
           dental              = EXCLUDED.dental,
           dental_percent      = EXCLUDED.dental_percent,
           optical             = EXCLUDED.optical,
           optical_percent     = EXCLUDED.optical_percent,
           pharma              = EXCLUDED.pharma,
           pharma_percent      = EXCLUDED.pharma_percent,
           raw_data            = EXCLUDED.raw_data,
           synced_by           = EXCLUDED.synced_by,
           synced_at           = NOW(),
           updated_at          = NOW()`,
        [
          sanlamId,
          (row.Institution || row.institution || '').toString() || null,
          (row.ShortId || row.shortId || null),
          (row.Benefitschemes || row.benefitSchemes || null),
          (row.CoPay_for || row.copayFor || null),
          (row.ExcludedSchemes || row.excludedSchemes || null),
          toD(row.OutPatient),
          toD(row.OutPatientPer),
          toD(row.OutPatientMax),
          toD(row.InPatient),
          toD(row.InPatientPer),
          toD(row.InPatientMax),
          toD(row.Dental),
          toD(row.DentalPer),
          toD(row.Optical),
          toD(row.OpticalPer),
          toD(row.Pharma),
          toD(row.PharmaPer),
          JSON.stringify(row),
          adminId,
        ]
      );
      upserted++;
    }

    return res.json({ message: 'Copays synced', received: list.length, upserted });
  } catch (err) {
    console.error('syncInstitutionCopays error:', err);
    return res.status(500).json({ message: 'Failed to sync copays' });
  }
};

/**
 * GET /api/institutions/copays
 * Returns all cached institution co-pays joined with institution names/sanlam_ids.
 */
const listInstitutionCopays = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ic.*,
              COALESCE(h.name, p.name) AS matched_institution_name,
              COALESCE(h.id, p.id)     AS institution_id
         FROM institution_copays ic
         LEFT JOIN hospitals  h ON h.sanlam_id = ic.sanlam_id
         LEFT JOIN pharmacies p ON p.sanlam_id = ic.sanlam_id
        ORDER BY ic.institution_name`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listInstitutionCopays error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  listInstitutions,
  sanlamSync,
  upsertSanlamInstitutions,
  mapMFieldToCategory,
  suspendInstitution,
  unsuspendInstitution,
  deleteInstitution,
  createInstitution,
  updateInstitution,
  listInstitutionPriceLists,
  createInstitutionPriceList,
  updateInstitutionPriceList,
  syncInstitutionCopays,
  listInstitutionCopays,
};
