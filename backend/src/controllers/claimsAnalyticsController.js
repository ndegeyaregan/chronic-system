/*
 * Analytics endpoints for the claims-analysis page.
 *
 * All endpoints accept the same filter set on the query string:
 *   - from, to           : YYYY-MM-DD on claim_date
 *   - claim_type[]       : e.g. OutPatient, InPatient (mapped to provider_type)
 *   - illness_type[]
 *   - relation[]
 *   - scheme[]
 *   - status[]           : claim_status (Paid, Rejected, ...)
 *
 * Filters are combined with AND. Multi-value params use array notation
 * (e.g. ?claim_type=OutPatient&claim_type=InPatient).
 */
const pool = require('../config/db');

const asArray = (v) => {
  if (v === undefined || v === null || v === '') return [];
  if (Array.isArray(v)) return v.filter(Boolean);
  return [v].filter(Boolean);
};

// Build WHERE clause from query filters. Returns { where, params, nextIdx }.
// Caller is expected to AND additional clauses using `nextIdx` to continue.
// uploadIds can be a string (single ID) or array of IDs (multiple uploads combined)
function buildFilter(uploadIds, q, startIdx = 1) {
  const ids = Array.isArray(uploadIds) ? uploadIds : [uploadIds];
  
  const conds = ids.length > 1 
    ? [`upload_id IN (${ids.map((_, idx) => `$${startIdx + idx}`).join(',')})`]
    : [`upload_id = $${startIdx}`];
  const params = [...ids];
  let i = startIdx + ids.length;

  if (q.from) { conds.push(`claim_date >= $${i++}`); params.push(q.from); }
  if (q.to)   { conds.push(`claim_date <= $${i++}`); params.push(q.to); }

  const inFilter = (col, vals) => {
    if (!vals.length) return;
    const placeholders = vals.map(() => `$${i++}`).join(',');
    conds.push(`${col} IN (${placeholders})`);
    params.push(...vals);
  };
  inFilter('provider_type', asArray(q.claim_type));
  inFilter('illness_type',  asArray(q.illness_type));
  inFilter('relation',      asArray(q.relation));
  inFilter('scheme',        asArray(q.scheme));
  inFilter('claim_status',  asArray(q.status));

  return { where: 'WHERE ' + conds.join(' AND '), params, nextIdx: i };
}

/* ── 1. Overview: summary + filter options + top-N for all dimensions ── */
const overview = async (req, res) => {
  try {
    const { id } = req.params;
    // Accept multiple upload IDs from query params: ?upload_id=id1&upload_id=id2
    // Falls back to route param `id` if no query param (backward compatibility)
    const uploadIds = asArray(req.query.upload_id).length > 0 
      ? asArray(req.query.upload_id) 
      : [id];
    
    const f = buildFilter(uploadIds, req.query);

    // Summary stats
    const summary = await pool.query(
      `SELECT
         COUNT(*)::int                                    AS total_claims,
         COALESCE(SUM(amount), 0)                         AS total_amount,
         COALESCE(SUM(payable_amount), 0)                 AS total_payable,
         COALESCE(AVG(amount), 0)::numeric(18,2)          AS avg_amount,
         COUNT(DISTINCT provider)::int                    AS unique_providers,
         COUNT(DISTINCT member_no)::int                   AS unique_members,
         COUNT(DISTINCT scheme)::int                      AS unique_schemes,
         MIN(claim_date)                                  AS first_date,
         MAX(claim_date)                                  AS last_date
       FROM claims ${f.where}`,
      f.params
    );

    // Available filter values (computed from all selected uploads)
    const uploadIdPlaceholders = uploadIds.map((_, i) => `$${i + 1}`).join(',');
    const filterOpts = await pool.query(
      `SELECT
         (SELECT json_agg(t) FROM (SELECT provider_type AS value, COUNT(*)::int AS count
                                     FROM claims WHERE upload_id IN (${uploadIdPlaceholders}) AND provider_type IS NOT NULL
                                     GROUP BY provider_type ORDER BY count DESC) t)  AS claim_types,
         (SELECT json_agg(t) FROM (SELECT illness_type AS value, COUNT(*)::int AS count
                                     FROM claims WHERE upload_id IN (${uploadIdPlaceholders}) AND illness_type IS NOT NULL
                                     GROUP BY illness_type ORDER BY count DESC) t)   AS illness_types,
         (SELECT json_agg(t) FROM (SELECT relation AS value, COUNT(*)::int AS count
                                     FROM claims WHERE upload_id IN (${uploadIdPlaceholders}) AND relation IS NOT NULL
                                     GROUP BY relation ORDER BY count DESC) t)       AS relations,
         (SELECT json_agg(t) FROM (SELECT scheme AS value, COUNT(*)::int AS count
                                     FROM claims WHERE upload_id IN (${uploadIdPlaceholders}) AND scheme IS NOT NULL
                                     GROUP BY scheme ORDER BY count DESC LIMIT 500) t) AS schemes,
         (SELECT json_agg(t) FROM (SELECT claim_status AS value, COUNT(*)::int AS count
                                     FROM claims WHERE upload_id IN (${uploadIdPlaceholders}) AND claim_status IS NOT NULL
                                     GROUP BY claim_status ORDER BY count DESC) t)   AS statuses`,
      uploadIds
    );

    // Top providers (ranked by total amount); also useful sort: claim count
    const topProvidersByCost = await pool.query(
      `SELECT provider, provider_type,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount,
              COALESCE(AVG(amount), 0)::numeric(18,2)    AS avg_amount,
              COUNT(DISTINCT member_no)::int             AS unique_members,
              COUNT(DISTINCT scheme)::int                AS unique_schemes
         FROM claims ${f.where}
        GROUP BY provider, provider_type
        ORDER BY total_amount DESC
        LIMIT 200`,
      f.params
    );

    // Top diagnoses overall
    const topDiagnoses = await pool.query(
      `SELECT diagnosis, diagnosis_code,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount,
              COUNT(DISTINCT member_no)::int             AS unique_members
         FROM claims ${f.where} AND diagnosis IS NOT NULL
        GROUP BY diagnosis, diagnosis_code
        ORDER BY claim_count DESC
        LIMIT 10`,
      f.params
    );

    // Top schemes
    const topSchemes = await pool.query(
      `SELECT scheme,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount,
              COUNT(DISTINCT member_no)::int             AS unique_members,
              COUNT(DISTINCT provider)::int              AS unique_providers
         FROM claims ${f.where} AND scheme IS NOT NULL
        GROUP BY scheme
        ORDER BY total_amount DESC
        LIMIT 20`,
      f.params
    );

    // Monthly trend
    const monthly = await pool.query(
      `SELECT to_char(date_trunc('month', claim_date), 'YYYY-MM') AS month,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount
         FROM claims ${f.where} AND claim_date IS NOT NULL
        GROUP BY month
        ORDER BY month ASC`,
      f.params
    );

    // Day-of-week + hour-of-day heatmap (from create_at; fallback to claim_date)
    const heatmap = await pool.query(
      `SELECT EXTRACT(DOW  FROM COALESCE(create_at, claim_date::timestamp))::int AS dow,
              EXTRACT(HOUR FROM COALESCE(create_at, claim_date::timestamp))::int AS hour,
              COUNT(*)::int                              AS claim_count
         FROM claims ${f.where} AND (create_at IS NOT NULL OR claim_date IS NOT NULL)
        GROUP BY dow, hour
        ORDER BY dow, hour`,
      f.params
    );

    // Status breakdown
    const byStatus = await pool.query(
      `SELECT claim_status,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount
         FROM claims ${f.where}
        GROUP BY claim_status
        ORDER BY claim_count DESC`,
      f.params
    );

    // Illness type breakdown
    const byIllness = await pool.query(
      `SELECT illness_type,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount
         FROM claims ${f.where}
        GROUP BY illness_type
        ORDER BY claim_count DESC`,
      f.params
    );

    // Relation breakdown
    const byRelation = await pool.query(
      `SELECT relation,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount
         FROM claims ${f.where}
        GROUP BY relation
        ORDER BY claim_count DESC`,
      f.params
    );

    return res.json({
      summary: summary.rows[0],
      filter_options: {
        claim_types:   filterOpts.rows[0].claim_types || [],
        illness_types: filterOpts.rows[0].illness_types || [],
        relations:     filterOpts.rows[0].relations || [],
        schemes:       filterOpts.rows[0].schemes || [],
        statuses:      filterOpts.rows[0].statuses || [],
      },
      top_providers: topProvidersByCost.rows,
      top_diagnoses: topDiagnoses.rows,
      top_schemes:   topSchemes.rows,
      monthly:       monthly.rows,
      heatmap:       heatmap.rows,
      by_status:     byStatus.rows,
      by_illness:    byIllness.rows,
      by_relation:   byRelation.rows,
    });
  } catch (err) {
    console.error('analytics.overview error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

/* ── 2. Provider drill-down: top diagnoses, schemes, members for one facility ── */
const providerDrilldown = async (req, res) => {
  try {
    const { id } = req.params;
    const provider = req.query.provider;
    if (!provider) return res.status(400).json({ message: 'provider query param required' });

    // Accept multiple upload IDs from query params
    const uploadIds = asArray(req.query.upload_id).length > 0 
      ? asArray(req.query.upload_id) 
      : [id];
    
    const f = buildFilter(uploadIds, req.query);
    const providerCond = `provider = $${f.nextIdx}`;
    const params = [...f.params, provider];

    const summary = await pool.query(
      `SELECT
         COUNT(*)::int                                    AS claim_count,
         COALESCE(SUM(amount), 0)                         AS total_amount,
         COALESCE(AVG(amount), 0)::numeric(18,2)          AS avg_amount,
         COUNT(DISTINCT member_no)::int                   AS unique_members,
         COUNT(DISTINCT scheme)::int                      AS unique_schemes,
         provider_type
       FROM claims ${f.where} AND ${providerCond}
       GROUP BY provider_type`,
      params
    );

    const topDiagnoses = await pool.query(
      `SELECT diagnosis, diagnosis_code,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount,
              COUNT(DISTINCT member_no)::int             AS unique_members
         FROM claims ${f.where} AND ${providerCond} AND diagnosis IS NOT NULL
        GROUP BY diagnosis, diagnosis_code
        ORDER BY claim_count DESC
        LIMIT 5`,
      params
    );

    const topSchemes = await pool.query(
      `SELECT scheme,
              COUNT(*)::int                              AS claim_count,
              COALESCE(SUM(amount), 0)                   AS total_amount,
              COUNT(DISTINCT member_no)::int             AS unique_members
         FROM claims ${f.where} AND ${providerCond} AND scheme IS NOT NULL
        GROUP BY scheme
        ORDER BY total_amount DESC
        LIMIT 10`,
      params
    );

    const topMembers = await pool.query(
      `SELECT member_no, member_name, scheme,
              COUNT(*)::int                              AS visit_count,
              COALESCE(SUM(amount), 0)                   AS total_amount,
              MAX(claim_date)                            AS last_visit
         FROM claims ${f.where} AND ${providerCond} AND member_no IS NOT NULL
        GROUP BY member_no, member_name, scheme
        ORDER BY visit_count DESC, total_amount DESC
        LIMIT 20`,
      params
    );

    // Hour-of-day visit distribution for this provider
    // (uses create_at when available — falls back to claim_date midnight)
    const heatmap = await pool.query(
      `SELECT EXTRACT(DOW  FROM COALESCE(create_at, claim_date::timestamp))::int AS dow,
              EXTRACT(HOUR FROM COALESCE(create_at, claim_date::timestamp))::int AS hour,
              COUNT(*)::int AS claim_count
         FROM claims ${f.where} AND ${providerCond}
              AND (create_at IS NOT NULL OR claim_date IS NOT NULL)
        GROUP BY dow, hour
        ORDER BY dow, hour`,
      params
    );

    return res.json({
      provider,
      summary: summary.rows,
      top_diagnoses: topDiagnoses.rows,
      top_schemes:   topSchemes.rows,
      top_members:   topMembers.rows,
      heatmap:       heatmap.rows,
    });
  } catch (err) {
    console.error('analytics.providerDrilldown error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { overview, providerDrilldown };
