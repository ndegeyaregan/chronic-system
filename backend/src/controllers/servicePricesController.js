const pool = require('../config/db');

const normalizeCurrency = (value) => {
  if (!value) return 'UGX';
  return String(value).trim().toUpperCase();
};

const resolveInstitution = async (institutionId) => {
  const hospital = await pool.query(
    `SELECT id, name, city, category, 'hospital'::text AS institution_type
       FROM hospitals
      WHERE id = $1`,
    [institutionId]
  );
  if (hospital.rows.length) return hospital.rows[0];

  const pharmacy = await pool.query(
    `SELECT id, name, city, COALESCE(category, 'pharmacy') AS category, 'pharmacy'::text AS institution_type
       FROM pharmacies
      WHERE id = $1`,
    [institutionId]
  );
  return pharmacy.rows[0] || null;
};

const listServices = async (req, res) => {
  try {
    const search = String(req.query?.search || '').trim();
    const params = [];
    let where = 'WHERE s.is_active = TRUE';

    if (search) {
      params.push(`%${search}%`);
      where += ` AND (s.name ILIKE $${params.length} OR COALESCE(s.category, '') ILIKE $${params.length})`;
    }

    const result = await pool.query(
      `SELECT s.id, s.name, s.category, s.created_at, s.updated_at
         FROM services s
         ${where}
        ORDER BY s.name`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listServices error:', err);
    return res.status(500).json({ message: 'Failed to load services' });
  }
};

const createService = async (req, res) => {
  try {
    const name = String(req.body?.name || '').trim();
    const category = String(req.body?.category || '').trim() || null;

    if (!name) {
      return res.status(400).json({ message: 'name is required' });
    }

    const insert = await pool.query(
      `INSERT INTO services (name, category)
       VALUES ($1, $2)
       ON CONFLICT (name)
       DO UPDATE SET
         category = COALESCE(EXCLUDED.category, services.category),
         updated_at = NOW()
       RETURNING id, name, category, created_at, updated_at`,
      [name, category]
    );

    return res.status(201).json({
      message: 'Service saved',
      service: insert.rows[0],
    });
  } catch (err) {
    console.error('createService error:', err);
    return res.status(500).json({ message: 'Failed to save service' });
  }
};

const listInstitutionServicePrices = async (req, res) => {
  try {
    const { serviceId, institutionId } = req.query || {};
    const params = [];
    const where = ['1=1'];

    if (serviceId) {
      params.push(serviceId);
      where.push(`isp.service_id = $${params.length}`);
    }
    if (institutionId) {
      params.push(institutionId);
      where.push(`isp.institution_id = $${params.length}`);
    }

    const result = await pool.query(
      `SELECT isp.id, isp.institution_id, isp.institution_type, isp.service_id,
              isp.price, isp.currency, isp.effective_from, isp.notes,
              isp.source_price_list_id, isp.created_at, isp.updated_at,
              s.name AS service_name, s.category AS service_category,
              i.name AS institution_name, i.city AS institution_city, i.category AS institution_category,
              uploader.name AS uploaded_by_name, updater.name AS updated_by_name
         FROM institution_service_prices isp
         JOIN services s ON s.id = isp.service_id
         JOIN (
           SELECT id, name, city, category, 'hospital'::text AS institution_type
             FROM hospitals
           UNION ALL
           SELECT id, name, city, COALESCE(category, 'pharmacy') AS category, 'pharmacy'::text AS institution_type
             FROM pharmacies
         ) i
           ON i.id = isp.institution_id AND i.institution_type = isp.institution_type
         LEFT JOIN admins uploader ON uploader.id = isp.uploaded_by
         LEFT JOIN admins updater ON updater.id = isp.updated_by
        WHERE ${where.join(' AND ')}
        ORDER BY isp.effective_from DESC, isp.created_at DESC`,
      params
    );

    return res.json(result.rows);
  } catch (err) {
    console.error('listInstitutionServicePrices error:', err);
    return res.status(500).json({ message: 'Failed to load service prices' });
  }
};

const createInstitutionServicePrice = async (req, res) => {
  try {
    const institutionId = String(req.body?.institutionId || '').trim();
    const serviceId = String(req.body?.serviceId || '').trim();
    const priceRaw = req.body?.price;
    const currency = normalizeCurrency(req.body?.currency);
    const effectiveFrom = String(req.body?.effectiveFrom || '').trim() || null;
    const notes = String(req.body?.notes || '').trim() || null;
    const sourcePriceListId = String(req.body?.sourcePriceListId || '').trim() || null;
    const adminId = req.user?.id || null;

    if (!institutionId || !serviceId || priceRaw === undefined || priceRaw === null || priceRaw === '') {
      return res.status(400).json({ message: 'institutionId, serviceId, and price are required' });
    }

    const price = Number(priceRaw);
    if (Number.isNaN(price) || price < 0) {
      return res.status(400).json({ message: 'price must be a valid non-negative number' });
    }

    const institution = await resolveInstitution(institutionId);
    if (!institution) {
      return res.status(404).json({ message: 'Institution not found' });
    }

    const serviceRes = await pool.query('SELECT id, name, category FROM services WHERE id = $1', [serviceId]);
    if (!serviceRes.rows.length) {
      return res.status(404).json({ message: 'Service not found' });
    }

    const insert = await pool.query(
      `INSERT INTO institution_service_prices
         (institution_id, institution_type, service_id, price, currency, effective_from, source_price_list_id, notes, uploaded_by, updated_by)
       VALUES ($1,$2,$3,$4,$5,COALESCE($6::date, CURRENT_DATE),$7,$8,$9,$9)
       ON CONFLICT (institution_id, institution_type, service_id, effective_from, currency)
       DO UPDATE SET
         price = EXCLUDED.price,
         source_price_list_id = EXCLUDED.source_price_list_id,
         notes = EXCLUDED.notes,
         updated_by = EXCLUDED.updated_by,
         updated_at = NOW()
       RETURNING id, institution_id, institution_type, service_id, price, currency,
                 effective_from, source_price_list_id, notes, created_at, updated_at`,
      [
        institution.id,
        institution.institution_type,
        serviceId,
        price,
        currency,
        effectiveFrom || null,
        sourcePriceListId,
        notes,
        adminId,
      ]
    );

    return res.status(201).json({
      message: 'Service price saved',
      servicePrice: {
        ...insert.rows[0],
        service_name: serviceRes.rows[0].name,
        service_category: serviceRes.rows[0].category,
        institution_name: institution.name,
        institution_city: institution.city,
        institution_category: institution.category,
      },
    });
  } catch (err) {
    console.error('createInstitutionServicePrice error:', err);
    return res.status(500).json({ message: 'Failed to save service price' });
  }
};

const updateInstitutionServicePrice = async (req, res) => {
  try {
    const { id } = req.params;
    const priceRaw = req.body?.price;
    const currency = normalizeCurrency(req.body?.currency);
    const effectiveFrom = String(req.body?.effectiveFrom || '').trim() || null;
    const notes = String(req.body?.notes || '').trim() || null;
    const adminId = req.user?.id || null;

    if (priceRaw === undefined || priceRaw === null || priceRaw === '') {
      return res.status(400).json({ message: 'price is required' });
    }

    const price = Number(priceRaw);
    if (Number.isNaN(price) || price < 0) {
      return res.status(400).json({ message: 'price must be a valid non-negative number' });
    }

    const existing = await pool.query(
      `SELECT id
         FROM institution_service_prices
        WHERE id = $1`,
      [id]
    );
    if (!existing.rows.length) {
      return res.status(404).json({ message: 'Service price not found' });
    }

    const update = await pool.query(
      `UPDATE institution_service_prices
          SET price = $1,
              currency = $2,
              effective_from = COALESCE($3::date, effective_from),
              notes = $4,
              updated_by = $5,
              updated_at = NOW()
        WHERE id = $6
        RETURNING id, institution_id, institution_type, service_id, price, currency,
                  effective_from, source_price_list_id, notes, created_at, updated_at`,
      [price, currency, effectiveFrom, notes, adminId, id]
    );

    return res.json({
      message: 'Service price updated',
      servicePrice: update.rows[0],
    });
  } catch (err) {
    console.error('updateInstitutionServicePrice error:', err);
    return res.status(500).json({ message: 'Failed to update service price' });
  }
};

const compareServiceCosts = async (req, res) => {
  try {
    const serviceId = String(req.query?.serviceId || '').trim();
    const city = String(req.query?.city || '').trim();
    const category = String(req.query?.category || '').trim().toLowerCase();

    if (!serviceId) {
      return res.status(400).json({ message: 'serviceId is required' });
    }

    const params = [serviceId];
    const filters = ['isp.service_id = $1'];

    if (city) {
      params.push(`%${city}%`);
      filters.push(`COALESCE(i.city, '') ILIKE $${params.length}`);
    }
    if (category) {
      params.push(category);
      filters.push(`LOWER(COALESCE(i.category, '')) = $${params.length}`);
    }

    const result = await pool.query(
      `SELECT isp.id, isp.institution_id, isp.institution_type, isp.service_id,
              s.name AS service_name, s.category AS service_category,
              i.name AS institution_name, i.city AS institution_city, i.category AS institution_category,
              isp.price, isp.currency, isp.effective_from, isp.notes,
              isp.source_price_list_id, ipl.file_name AS source_file_name, ipl.file_path AS source_file_path,
              isp.created_at, isp.updated_at
         FROM institution_service_prices isp
         JOIN services s ON s.id = isp.service_id
         JOIN (
           SELECT id, name, city, category, is_active, is_deleted, is_suspended, 'hospital'::text AS institution_type
             FROM hospitals
           UNION ALL
           SELECT id, name, city, COALESCE(category, 'pharmacy') AS category, is_active, is_deleted, is_suspended, 'pharmacy'::text AS institution_type
             FROM pharmacies
         ) i
           ON i.id = isp.institution_id AND i.institution_type = isp.institution_type
         LEFT JOIN institution_price_lists ipl ON ipl.id = isp.source_price_list_id
        WHERE ${filters.join(' AND ')}
          AND i.is_active = TRUE
          AND COALESCE(i.is_deleted, FALSE) = FALSE
          AND COALESCE(i.is_suspended, FALSE) = FALSE
        ORDER BY isp.price ASC, isp.effective_from DESC, i.name ASC`,
      params
    );

    return res.json(result.rows);
  } catch (err) {
    console.error('compareServiceCosts error:', err);
    return res.status(500).json({ message: 'Failed to compare service costs' });
  }
};

module.exports = {
  listServices,
  createService,
  listInstitutionServicePrices,
  createInstitutionServicePrice,
  updateInstitutionServicePrice,
  compareServiceCosts,
};
