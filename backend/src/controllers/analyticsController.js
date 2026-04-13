const pool = require('../config/db');

const getMemberStats = async (req, res) => {
  try {
    const [totalResult, byConditionResult, statusResult, newThisMonthResult, prevMonthNewResult] = await Promise.all([
      pool.query('SELECT COUNT(*) AS total FROM members'),
      pool.query(
        `SELECT c.name AS condition, COUNT(mc.member_id) AS count
         FROM member_conditions mc
         JOIN conditions c ON c.id = mc.condition_id
         GROUP BY c.name ORDER BY count DESC`
      ),
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE is_active = TRUE) AS active,
           COUNT(*) FILTER (WHERE is_active = FALSE) AS inactive
         FROM members`
      ),
      pool.query(
        `SELECT COUNT(*) AS new_this_month
         FROM members
         WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW())`
      ),
      pool.query(
        `SELECT COUNT(*) AS prev_month_new
         FROM members
         WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW()) - INTERVAL '1 month'`
      ),
    ]);

    const newThisMonth = parseInt(newThisMonthResult.rows[0].new_this_month);
    const prevMonthNew = parseInt(prevMonthNewResult.rows[0].prev_month_new);

    return res.json({
      total: parseInt(totalResult.rows[0].total),
      by_condition: byConditionResult.rows,
      active: parseInt(statusResult.rows[0].active),
      inactive: parseInt(statusResult.rows[0].inactive),
      new_this_month: newThisMonth,
      prev_month_new: prevMonthNew,
      new_member_change_pct: prevMonthNew > 0
        ? Math.round(((newThisMonth - prevMonthNew) / prevMonthNew) * 100)
        : null,
    });
  } catch (err) {
    console.error('getMemberStats error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getAppointmentStats = async (req, res) => {
  try {
    const [
      byStatusResult,
      byHospitalResult,
      byMonthResult,
      summaryResult,
      recentResult,
    ] = await Promise.all([
      pool.query(
        `SELECT status, COUNT(*) AS count FROM appointments GROUP BY status ORDER BY count DESC`
      ),
      pool.query(
        `SELECT h.name AS hospital, COUNT(a.id) AS count
         FROM appointments a
         JOIN hospitals h ON h.id = a.hospital_id
         GROUP BY h.name ORDER BY count DESC LIMIT 10`
      ),
      pool.query(
        `SELECT TO_CHAR(DATE_TRUNC('month', appointment_date), 'YYYY-MM') AS month,
                COUNT(*) AS count
         FROM appointments
         WHERE appointment_date >= NOW() - INTERVAL '12 months'
         GROUP BY month ORDER BY month`
      ),
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE status = 'pending') AS pending,
           COUNT(*) FILTER (WHERE status = 'confirmed') AS confirmed,
           COUNT(*) FILTER (WHERE status = 'completed') AS completed,
           COUNT(*) FILTER (
             WHERE DATE_TRUNC('month', appointment_date) = DATE_TRUNC('month', NOW())
           ) AS this_month
         FROM appointments`
      ),
      pool.query(
        `SELECT
           a.id,
           a.appointment_date,
           a.preferred_time,
           a.confirmed_date,
           a.confirmed_time,
           a.reason,
           a.status,
           a.created_at,
           m.member_number,
           m.first_name,
           m.last_name,
           h.name AS hospital,
           c.name AS condition
         FROM appointments a
         JOIN members m ON m.id = a.member_id
         JOIN hospitals h ON h.id = a.hospital_id
         LEFT JOIN conditions c ON c.id = a.condition_id
         ORDER BY a.appointment_date DESC, a.created_at DESC
         LIMIT 8`
      )
    ]);

    const summary = summaryResult.rows[0] || {};
    const pending   = parseInt(summary.pending   || 0, 10);
    const confirmed = parseInt(summary.confirmed || 0, 10);
    const completed = parseInt(summary.completed || 0, 10);

    return res.json({
      by_status: byStatusResult.rows.map(r => ({
        name: r.status.charAt(0).toUpperCase() + r.status.slice(1),
        value: parseInt(r.count, 10),
      })),
      by_hospital: byHospitalResult.rows,
      by_month: byMonthResult.rows.map(r => ({
        month: r.month,
        count: parseInt(r.count, 10),
      })),
      total: pending + confirmed + completed,
      pending,
      confirmed,
      completed,
      this_month: parseInt(summary.this_month || 0, 10),
      recent: recentResult.rows.map((row) => ({
        ...row,
        member_name: `${row.first_name || ''} ${row.last_name || ''}`.trim(),
      })),
    });
  } catch (err) {
    console.error('getAppointmentStats error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMedicationAdherence = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'taken') AS taken,
         COUNT(*) FILTER (WHERE status = 'skipped') AS skipped,
         COUNT(*) AS total
       FROM medication_logs
       WHERE logged_at >= NOW() - INTERVAL '30 days'`
    );

    const { taken, skipped, total } = result.rows[0];
    const takenNum = parseInt(taken);
    const totalNum = parseInt(total);
    const adherence_pct = totalNum > 0 ? Math.round((takenNum / totalNum) * 100) : null;

    return res.json({
      taken: takenNum,
      skipped: parseInt(skipped),
      total: totalNum,
      adherence_pct,
    });
  } catch (err) {
    console.error('getMedicationAdherence error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getNotificationStats = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT channel, status, COUNT(*) AS count
       FROM notifications
       WHERE sent_at >= NOW() - INTERVAL '30 days'
       GROUP BY channel, status
       ORDER BY channel, status`
    );

    const raw = {};
    for (const row of result.rows) {
      if (!raw[row.channel]) raw[row.channel] = { sent: 0, failed: 0 };
      raw[row.channel][row.status] = parseInt(row.count);
    }

    const by_channel = Object.entries(raw).map(([ch, d]) => ({
      channel: ch.charAt(0).toUpperCase() + ch.slice(1),
      sent:   d.sent   || 0,
      failed: d.failed || 0,
    }));
    const totalSent   = by_channel.reduce((s, r) => s + r.sent + r.failed, 0);
    const totalFailed = by_channel.reduce((s, r) => s + r.failed, 0);
    const success_rate = totalSent > 0 ? Math.round(((totalSent - totalFailed) / totalSent) * 100) : null;

    return res.json({ by_channel, success_rate });
  } catch (err) {
    console.error('getNotificationStats error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMemberHealthSummary = async (req, res) => {
  try {
    const memberId = req.user.id;

    const [vitalsResult, adherenceResult, appointmentsResult] = await Promise.all([
      pool.query(
        `SELECT DATE(recorded_at) AS date,
                AVG(blood_sugar_mmol) AS avg_blood_sugar,
                AVG(systolic_bp) AS avg_systolic,
                AVG(diastolic_bp) AS avg_diastolic,
                AVG(heart_rate) AS avg_heart_rate,
                AVG(weight_kg) AS avg_weight
         FROM vitals
         WHERE member_id = $1 AND recorded_at >= NOW() - INTERVAL '30 days'
         GROUP BY DATE(recorded_at) ORDER BY date`,
        [memberId]
      ),
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE ml.status = 'taken') AS taken,
           COUNT(*) AS total
         FROM medication_logs ml
         JOIN member_medications mm ON mm.id = ml.member_medication_id
         WHERE mm.member_id = $1
           AND ml.logged_at >= NOW() - INTERVAL '30 days'`,
        [memberId]
      ),
      pool.query(
        `SELECT a.*, h.name AS hospital_name
         FROM appointments a
         JOIN hospitals h ON h.id = a.hospital_id
         WHERE a.member_id = $1
           AND DATE_TRUNC('month', a.appointment_date) = DATE_TRUNC('month', NOW())
         ORDER BY a.appointment_date`,
        [memberId]
      ),
    ]);

    const taken = parseInt(adherenceResult.rows[0].taken);
    const total = parseInt(adherenceResult.rows[0].total);
    const adherence_pct = total > 0 ? Math.round((taken / total) * 100) : null;

    return res.json({
      vitals_trend: vitalsResult.rows,
      medication_adherence: { taken, total, adherence_pct },
      appointments_this_month: appointmentsResult.rows,
    });
  } catch (err) {
    console.error('getMemberHealthSummary error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

/* ─── New analytics endpoints ─────────────────────────────────────────────── */

const getLabTestStats = async (req, res) => {
  try {
    const [summary, byType] = await Promise.all([
      pool.query(`
        SELECT
          COUNT(*) FILTER (WHERE status = 'pending')                                   AS pending,
          COUNT(*) FILTER (WHERE status = 'completed')                                 AS completed,
          COUNT(*) FILTER (WHERE status = 'in_progress')                               AS in_progress,
          COUNT(*) FILTER (WHERE status IN ('pending','in_progress') AND due_date < NOW()) AS overdue,
          COUNT(*)                                                                      AS total
        FROM lab_tests
      `),
      pool.query(`
        SELECT test_type AS type, COUNT(*) AS count
        FROM lab_tests
        GROUP BY test_type
        ORDER BY count DESC
        LIMIT 8
      `),
    ]);
    const s = summary.rows[0];
    res.json({
      pending:     parseInt(s.pending     || 0),
      completed:   parseInt(s.completed   || 0),
      in_progress: parseInt(s.in_progress || 0),
      overdue:     parseInt(s.overdue     || 0),
      total:       parseInt(s.total       || 0),
      by_type: byType.rows.map(r => ({ type: r.type, count: parseInt(r.count) })),
    });
  } catch (err) {
    console.error('getLabTestStats error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getAuthorizationStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status = 'pending')  AS pending,
        COUNT(*) FILTER (WHERE status = 'approved') AS approved,
        COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
        COUNT(*)                                    AS total
      FROM authorization_requests
    `);
    const s        = result.rows[0];
    const total    = parseInt(s.total    || 0);
    const approved = parseInt(s.approved || 0);
    const rejected = parseInt(s.rejected || 0);
    const pending  = parseInt(s.pending  || 0);
    res.json({
      pending, approved, rejected, total,
      approval_rate: total > 0 ? Math.round((approved / total) * 100) : null,
      chart: [
        { name: 'Approved', value: approved },
        { name: 'Pending',  value: pending  },
        { name: 'Rejected', value: rejected },
      ],
    });
  } catch (err) {
    console.error('getAuthorizationStats error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getVitalsPopulationStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        ROUND(AVG(blood_sugar_mmol)::numeric, 1) AS avg_blood_sugar,
        ROUND(AVG(systolic_bp)::numeric,      0) AS avg_systolic,
        ROUND(AVG(diastolic_bp)::numeric,     0) AS avg_diastolic,
        ROUND(AVG(heart_rate)::numeric,       0) AS avg_heart_rate,
        ROUND(AVG(weight_kg)::numeric,        1) AS avg_weight,
        COUNT(DISTINCT member_id)                 AS members_with_vitals
      FROM vitals
      WHERE recorded_at >= NOW() - INTERVAL '30 days'
    `);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('getVitalsPopulationStats error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getTreatmentPlanStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status = 'active')    AS active,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed,
        COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
        COUNT(*) FILTER (WHERE status = 'pending')   AS pending,
        COUNT(*)                                     AS total
      FROM treatment_plans
    `);
    const s         = result.rows[0];
    const active    = parseInt(s.active    || 0);
    const completed = parseInt(s.completed || 0);
    const cancelled = parseInt(s.cancelled || 0);
    const pending   = parseInt(s.pending   || 0);
    res.json({
      active, completed, cancelled, pending,
      total: parseInt(s.total || 0),
      chart: [
        { name: 'Active',    value: active    },
        { name: 'Completed', value: completed },
        { name: 'Cancelled', value: cancelled },
        { name: 'Pending',   value: pending   },
      ],
    });
  } catch (err) {
    console.error('getTreatmentPlanStats error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getTopMedications = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT m.name, m.generic_name, COUNT(mm.id) AS prescriptions
      FROM member_medications mm
      JOIN medications m ON m.id = mm.medication_id
      WHERE mm.end_date IS NULL OR mm.end_date >= CURRENT_DATE
      GROUP BY m.id, m.name, m.generic_name
      ORDER BY prescriptions DESC
      LIMIT 5
    `);
    res.json(result.rows.map(r => ({
      name:         r.name,
      generic_name: r.generic_name,
      prescriptions: parseInt(r.prescriptions),
    })));
  } catch (err) {
    console.error('getTopMedications error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getAlertSeverityStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT COALESCE(severity, 'unknown') AS severity, COUNT(*) AS count
      FROM admin_alerts
      WHERE created_at >= NOW() - INTERVAL '30 days'
      GROUP BY severity
      ORDER BY count DESC
    `);
    res.json(result.rows.map(r => ({
      name:  r.severity.charAt(0).toUpperCase() + r.severity.slice(1),
      value: parseInt(r.count),
    })));
  } catch (err) {
    console.error('getAlertSeverityStats error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getMemberGrowthTrend = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        TO_CHAR(DATE_TRUNC('month', created_at), 'Mon ''YY') AS month,
        TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM')  AS sort_key,
        COUNT(*)                                              AS count
      FROM members
      WHERE created_at >= NOW() - INTERVAL '12 months'
      GROUP BY DATE_TRUNC('month', created_at)
      ORDER BY sort_key
    `);
    res.json(result.rows.map(r => ({ month: r.month, count: parseInt(r.count) })));
  } catch (err) {
    console.error('getMemberGrowthTrend error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getMemberDemographics = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT COALESCE(gender, 'Unknown') AS gender, COUNT(*) AS count
      FROM members
      GROUP BY gender
      ORDER BY count DESC
    `);
    res.json({
      by_gender: result.rows.map(r => ({
        name:  r.gender.charAt(0).toUpperCase() + r.gender.slice(1),
        value: parseInt(r.count),
      })),
    });
  } catch (err) {
    console.error('getMemberDemographics error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

/* ─── Phase-2 additions ────────────────────────────────────────────────── */

const getAdherenceTrend = async (req, res) => {
  const days = Math.min(Math.max(parseInt(req.query.days) || 30, 7), 365);
  try {
    const result = await pool.query(`
      SELECT
        DATE(scheduled_time) AS day,
        COUNT(*) FILTER (WHERE status = 'taken')   AS taken,
        COUNT(*) FILTER (WHERE status = 'skipped') AS skipped
      FROM medication_logs
      WHERE scheduled_time >= NOW() - INTERVAL '${days} days'
      GROUP BY day
      ORDER BY day
    `);
    res.json(result.rows.map(r => ({
      day:     r.day,
      taken:   parseInt(r.taken),
      skipped: parseInt(r.skipped),
    })));
  } catch (err) {
    console.error('getAdherenceTrend error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getAgeDistribution = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT bracket, COUNT(*) AS count
      FROM (
        SELECT
          CASE
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 18   THEN 'Under 18'
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) <= 30  THEN '18-30'
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) <= 45  THEN '31-45'
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) <= 60  THEN '46-60'
            ELSE '60+'
          END AS bracket
        FROM members
        WHERE date_of_birth IS NOT NULL
      ) t
      GROUP BY bracket
      ORDER BY
        CASE bracket
          WHEN 'Under 18' THEN 1 WHEN '18-30' THEN 2
          WHEN '31-45'    THEN 3 WHEN '46-60' THEN 4 ELSE 5
        END
    `);
    res.json(result.rows.map(r => ({ bracket: r.bracket, count: parseInt(r.count) })));
  } catch (err) {
    console.error('getAgeDistribution error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getPlanTypeDistribution = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT COALESCE(NULLIF(TRIM(plan_type), ''), 'Unknown') AS plan_type, COUNT(*) AS count
      FROM members
      GROUP BY plan_type
      ORDER BY count DESC
    `);
    res.json(result.rows.map(r => ({ name: r.plan_type, value: parseInt(r.count) })));
  } catch (err) {
    console.error('getPlanTypeDistribution error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getEmergencyStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status = 'pending')                            AS pending,
        COUNT(*) FILTER (WHERE status = 'dispatched')                         AS dispatched,
        COUNT(*) FILTER (WHERE status = 'resolved')                           AS resolved,
        COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days')      AS this_month,
        ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/60)::numeric,0) AS avg_resolve_mins,
        COUNT(*) AS total
      FROM emergency_requests
    `);
    const s = result.rows[0];
    const pending    = parseInt(s.pending    || 0);
    const dispatched = parseInt(s.dispatched || 0);
    const resolved   = parseInt(s.resolved   || 0);
    res.json({
      pending, dispatched, resolved,
      this_month:        parseInt(s.this_month        || 0),
      avg_resolve_mins:  s.avg_resolve_mins ? parseFloat(s.avg_resolve_mins) : null,
      total:             parseInt(s.total             || 0),
      chart: [
        { name: 'Pending',    value: pending    },
        { name: 'Dispatched', value: dispatched },
        { name: 'Resolved',   value: resolved   },
      ],
    });
  } catch (err) {
    console.error('getEmergencyStats error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getAppointmentQuality = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(*)                                                                    AS total,
        COUNT(*) FILTER (WHERE status = 'no_show' OR no_show_reason IS NOT NULL)   AS no_shows,
        COUNT(*) FILTER (WHERE status = 'cancelled')                                AS cancelled,
        COUNT(*) FILTER (WHERE status = 'completed')                                AS completed
      FROM appointments
    `);
    const s         = result.rows[0];
    const total     = parseInt(s.total     || 0);
    const no_shows  = parseInt(s.no_shows  || 0);
    const cancelled = parseInt(s.cancelled || 0);
    const completed = parseInt(s.completed || 0);
    res.json({
      total, no_shows, cancelled, completed,
      no_show_rate:    total > 0 ? Math.round((no_shows  / total) * 100) : 0,
      cancel_rate:     total > 0 ? Math.round((cancelled / total) * 100) : 0,
      completion_rate: total > 0 ? Math.round((completed / total) * 100) : 0,
    });
  } catch (err) {
    console.error('getAppointmentQuality error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getVitalsAlerts = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(DISTINCT member_id) FILTER (WHERE blood_sugar_mmol > 10)           AS high_blood_sugar,
        COUNT(DISTINCT member_id) FILTER (WHERE systolic_bp > 140)                AS high_systolic,
        COUNT(DISTINCT member_id) FILTER (WHERE diastolic_bp > 90)                AS high_diastolic,
        COUNT(DISTINCT member_id) FILTER (WHERE heart_rate > 100 OR heart_rate < 60) AS abnormal_hr,
        COUNT(DISTINCT member_id)                                                  AS members_with_vitals
      FROM vitals
      WHERE recorded_at >= NOW() - INTERVAL '30 days'
    `);
    const r = result.rows[0];
    res.json({
      high_blood_sugar:  parseInt(r.high_blood_sugar  || 0),
      high_systolic:     parseInt(r.high_systolic     || 0),
      high_diastolic:    parseInt(r.high_diastolic    || 0),
      abnormal_hr:       parseInt(r.abnormal_hr       || 0),
      members_with_vitals: parseInt(r.members_with_vitals || 0),
    });
  } catch (err) {
    console.error('getVitalsAlerts error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getCostSummary = async (req, res) => {
  try {
    const [summary, byCondition] = await Promise.all([
      pool.query(`
        SELECT
          ROUND(SUM(cost), 2)  AS total_cost,
          ROUND(AVG(cost), 2)  AS avg_cost,
          ROUND(MAX(cost), 2)  AS max_cost,
          COUNT(*)             AS plan_count,
          COALESCE(MAX(currency), 'UGX') AS currency
        FROM treatment_plans
        WHERE cost IS NOT NULL AND cost > 0
      `),
      pool.query(`
        SELECT c.name AS condition,
               ROUND(AVG(tp.cost), 0) AS avg_cost,
               COUNT(*)               AS plans,
               COALESCE(MAX(tp.currency), 'UGX') AS currency
        FROM treatment_plans tp
        JOIN conditions c ON c.id = tp.condition_id
        WHERE tp.cost IS NOT NULL AND tp.cost > 0
        GROUP BY c.name
        ORDER BY avg_cost DESC
        LIMIT 6
      `),
    ]);
    const s = summary.rows[0] || {};
    res.json({
      total_cost:  parseFloat(s.total_cost  || 0),
      avg_cost:    parseFloat(s.avg_cost    || 0),
      max_cost:    parseFloat(s.max_cost    || 0),
      plan_count:  parseInt(s.plan_count    || 0),
      currency:    s.currency || 'UGX',
      by_condition: byCondition.rows.map(r => ({
        condition: r.condition,
        avg_cost:  parseFloat(r.avg_cost),
        plans:     parseInt(r.plans),
        currency:  r.currency,
      })),
    });
  } catch (err) {
    console.error('getCostSummary error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  getMemberStats,
  getAppointmentStats,
  getMedicationAdherence,
  getNotificationStats,
  getMemberHealthSummary,
  getLabTestStats,
  getAuthorizationStats,
  getVitalsPopulationStats,
  getTreatmentPlanStats,
  getTopMedications,
  getAlertSeverityStats,
  getMemberGrowthTrend,
  getMemberDemographics,
  getAdherenceTrend,
  getAgeDistribution,
  getPlanTypeDistribution,
  getEmergencyStats,
  getAppointmentQuality,
  getVitalsAlerts,
  getCostSummary,
};
