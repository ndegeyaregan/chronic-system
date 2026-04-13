const pool = require('../config/db');

const buildWhereClause = (search, city) => {
  const params = [];
  const conditions = ['p.is_active = TRUE'];
  let idx = 1;

  if (search) {
    conditions.push(`(p.name ILIKE $${idx} OR p.address ILIKE $${idx} OR p.city ILIKE $${idx})`);
    params.push(`%${search}%`);
    idx += 1;
  }

  if (city) {
    conditions.push(`p.city ILIKE $${idx}`);
    params.push(`%${city}%`);
  }

  return {
    params,
    where: `WHERE ${conditions.join(' AND ')}`,
  };
};

const listPharmacies = async (req, res) => {
  try {
    const { name, search, city } = req.query;
    const { params, where } = buildWhereClause(search || name, city);

    const result = await pool.query(
      `SELECT p.*
       FROM pharmacies p
       ${where}
       ORDER BY p.name`,
      params
    );

    return res.json(result.rows);
  } catch (err) {
    console.error('listPharmacies error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getPharmacy = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM pharmacies WHERE id = $1', [id]);
    if (!result.rows.length) {
      return res.status(404).json({ message: 'Pharmacy not found' });
    }
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('getPharmacy error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createPharmacy = async (req, res) => {
  try {
    const {
      name,
      address,
      city,
      phone,
      email,
      contact_person,
      working_hours,
    } = req.body;

    if (!name || !city) {
      return res.status(400).json({ message: 'name and city are required' });
    }

    const result = await pool.query(
      `INSERT INTO pharmacies
         (name, address, city, phone, email, contact_person, working_hours)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [
        name.trim(),
        address || null,
        city.trim(),
        phone || null,
        email || null,
        contact_person || null,
        working_hours || null,
      ]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createPharmacy error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updatePharmacy = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name,
      address,
      city,
      phone,
      email,
      contact_person,
      working_hours,
    } = req.body;

    const existing = await pool.query('SELECT id FROM pharmacies WHERE id = $1', [id]);
    if (!existing.rows.length) {
      return res.status(404).json({ message: 'Pharmacy not found' });
    }

    const result = await pool.query(
      `UPDATE pharmacies SET
         name = COALESCE($1, name),
         address = COALESCE($2, address),
         city = COALESCE($3, city),
         phone = COALESCE($4, phone),
         email = COALESCE($5, email),
         contact_person = COALESCE($6, contact_person),
         working_hours = COALESCE($7, working_hours),
         updated_at = NOW()
       WHERE id = $8
       RETURNING *`,
      [
        name?.trim(),
        address,
        city?.trim(),
        phone,
        email,
        contact_person,
        working_hours,
        id,
      ]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updatePharmacy error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deletePharmacy = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE pharmacies SET is_active = FALSE, updated_at = NOW() WHERE id = $1 RETURNING id',
      [id]
    );
    if (!result.rows.length) {
      return res.status(404).json({ message: 'Pharmacy not found' });
    }
    return res.json({ message: 'Pharmacy deactivated' });
  } catch (err) {
    console.error('deletePharmacy error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getPharmacyMetrics = async (req, res) => {
  try {
    const { search, city } = req.query;
    const { params, where } = buildWhereClause(search, city);

    const result = await pool.query(
      `WITH medication_base AS (
         SELECT
           mm.id,
           mm.pharmacy_id,
           mm.member_id,
           mm.end_date,
           mm.next_refill_date,
           mm.created_at,
           COALESCE((
             SELECT ROUND(
               LEAST(
                 (
                   COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0
                 ) / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0),
                 100
               )::numeric,
               1
             )
             FROM medication_logs ml
             WHERE ml.member_medication_id = mm.id
               AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
           ), 0) AS adherence_percent
         FROM member_medications mm
         WHERE mm.pharmacy_id IS NOT NULL
       ),
       medication_metrics AS (
         SELECT
           pharmacy_id,
           COUNT(DISTINCT member_id)::int AS members_served,
           COUNT(*) FILTER (WHERE end_date IS NULL)::int AS active_prescriptions,
           COUNT(*) FILTER (
             WHERE end_date IS NULL
               AND next_refill_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
           )::int AS refills_due_7d,
           COALESCE(ROUND(AVG(adherence_percent)::numeric, 1), 0) AS avg_adherence,
           MAX(created_at) AS last_assignment_at
         FROM medication_base
         GROUP BY pharmacy_id
       ),
       authorization_metrics AS (
         SELECT
           provider_id AS pharmacy_id,
           COUNT(*) FILTER (WHERE status = 'pending')::int AS pending_authorizations,
           COUNT(*) FILTER (WHERE status = 'approved')::int AS approved_authorizations,
           COUNT(*) FILTER (WHERE status = 'rejected')::int AS rejected_authorizations
         FROM authorization_requests
         WHERE provider_type = 'pharmacy'
           AND provider_id IS NOT NULL
         GROUP BY provider_id
       )
       SELECT
         p.*,
         COALESCE(mm.members_served, 0) AS members_served,
         COALESCE(mm.active_prescriptions, 0) AS active_prescriptions,
         COALESCE(mm.refills_due_7d, 0) AS refills_due_7d,
         COALESCE(mm.avg_adherence, 0) AS avg_adherence,
         mm.last_assignment_at,
         COALESCE(am.pending_authorizations, 0) AS pending_authorizations,
         COALESCE(am.approved_authorizations, 0) AS approved_authorizations,
         COALESCE(am.rejected_authorizations, 0) AS rejected_authorizations
       FROM pharmacies p
       LEFT JOIN medication_metrics mm ON mm.pharmacy_id = p.id
       LEFT JOIN authorization_metrics am ON am.pharmacy_id = p.id
       ${where}
       ORDER BY p.name`,
      params
    );

    const pharmacies = result.rows.map((row) => {
      const totalReviewed =
        Number(row.pending_authorizations || 0) +
        Number(row.approved_authorizations || 0) +
        Number(row.rejected_authorizations || 0);
      const processedAuthorizations =
        Number(row.approved_authorizations || 0) +
        Number(row.rejected_authorizations || 0);

      return {
        ...row,
        approval_rate: processedAuthorizations > 0
          ? Number(((Number(row.approved_authorizations || 0) / processedAuthorizations) * 100).toFixed(1))
          : 0,
        authorization_volume: totalReviewed,
      };
    });

    const summary = pharmacies.reduce((acc, pharmacy) => {
      acc.total_pharmacies += 1;
      acc.members_served += Number(pharmacy.members_served || 0);
      acc.active_prescriptions += Number(pharmacy.active_prescriptions || 0);
      acc.refills_due_7d += Number(pharmacy.refills_due_7d || 0);
      acc.pending_authorizations += Number(pharmacy.pending_authorizations || 0);
      acc.approved_authorizations += Number(pharmacy.approved_authorizations || 0);
      acc.rejected_authorizations += Number(pharmacy.rejected_authorizations || 0);
      acc.avg_adherence_total += Number(pharmacy.avg_adherence || 0);
      if (Number(pharmacy.active_prescriptions || 0) > 0) {
        acc.engaged_pharmacies += 1;
      }
      return acc;
    }, {
      total_pharmacies: 0,
      engaged_pharmacies: 0,
      members_served: 0,
      active_prescriptions: 0,
      refills_due_7d: 0,
      pending_authorizations: 0,
      approved_authorizations: 0,
      rejected_authorizations: 0,
      avg_adherence_total: 0,
    });

    const processedTotal = summary.approved_authorizations + summary.rejected_authorizations;

    return res.json({
      summary: {
        total_pharmacies: summary.total_pharmacies,
        engaged_pharmacies: summary.engaged_pharmacies,
        members_served: summary.members_served,
        active_prescriptions: summary.active_prescriptions,
        refills_due_7d: summary.refills_due_7d,
        pending_authorizations: summary.pending_authorizations,
        avg_adherence: summary.total_pharmacies > 0
          ? Number((summary.avg_adherence_total / summary.total_pharmacies).toFixed(1))
          : 0,
        approval_rate: processedTotal > 0
          ? Number(((summary.approved_authorizations / processedTotal) * 100).toFixed(1))
          : 0,
      },
      pharmacies,
    });
  } catch (err) {
    console.error('getPharmacyMetrics error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  listPharmacies,
  getPharmacy,
  createPharmacy,
  updatePharmacy,
  deletePharmacy,
  getPharmacyMetrics,
};
