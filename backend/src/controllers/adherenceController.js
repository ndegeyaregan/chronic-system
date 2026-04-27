const pool = require('../config/db');

// Compute adherence stats for a member
const getMyAdherence = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { days = 30 } = req.query;
    const periodDays = Math.min(parseInt(days) || 30, 365);

    const result = await pool.query(
      `SELECT
         mm.id AS assignment_id,
         med.name AS medication_name,
         mm.dosage,
         mm.frequency,
         COUNT(ml.id) AS total_doses,
         COUNT(ml.id) FILTER (WHERE ml.status = 'taken') AS taken_doses,
         COUNT(ml.id) FILTER (WHERE ml.status = 'skipped') AS skipped_doses,
         COUNT(ml.id) FILTER (WHERE ml.status = 'pending' AND ml.scheduled_time < NOW()) AS missed_doses,
         CASE WHEN COUNT(ml.id) > 0
           THEN ROUND(COUNT(ml.id) FILTER (WHERE ml.status = 'taken') * 100.0 / COUNT(ml.id), 1)
           ELSE 0 END AS adherence_pct
       FROM member_medications mm
       JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN medication_logs ml ON ml.member_medication_id = mm.id
         AND ml.scheduled_time >= NOW() - ($2 || ' days')::INTERVAL
       WHERE mm.member_id = $1
         AND (mm.end_date IS NULL OR mm.end_date >= CURRENT_DATE)
       GROUP BY mm.id, med.name, mm.dosage, mm.frequency
       ORDER BY med.name`,
      [memberId, periodDays.toString()]
    );

    // Overall stats
    const overall = await pool.query(
      `SELECT
         COUNT(ml.id) AS total_doses,
         COUNT(ml.id) FILTER (WHERE ml.status = 'taken') AS taken,
         COUNT(ml.id) FILTER (WHERE ml.status = 'skipped') AS skipped,
         COUNT(ml.id) FILTER (WHERE ml.status = 'pending' AND ml.scheduled_time < NOW()) AS missed
       FROM medication_logs ml
       JOIN member_medications mm ON mm.id = ml.member_medication_id
       WHERE mm.member_id = $1
         AND ml.scheduled_time >= NOW() - ($2 || ' days')::INTERVAL`,
      [memberId, periodDays.toString()]
    );

    const o = overall.rows[0];
    const totalDoses = parseInt(o.total_doses) || 0;

    // Streak calculation
    const streakResult = await pool.query(
      `SELECT ml.scheduled_time::DATE AS dose_date, ml.status
       FROM medication_logs ml
       JOIN member_medications mm ON mm.id = ml.member_medication_id
       WHERE mm.member_id = $1
       ORDER BY ml.scheduled_time DESC`,
      [memberId]
    );

    let currentStreak = 0;
    let longestStreak = 0;
    let tempStreak = 0;
    for (const row of streakResult.rows) {
      if (row.status === 'taken') {
        tempStreak++;
        longestStreak = Math.max(longestStreak, tempStreak);
      } else {
        if (currentStreak === 0) currentStreak = tempStreak;
        tempStreak = 0;
      }
    }
    if (currentStreak === 0) currentStreak = tempStreak;
    longestStreak = Math.max(longestStreak, tempStreak);

    // Daily trend (last N days)
    const trend = await pool.query(
      `SELECT
         ml.scheduled_time::DATE AS date,
         COUNT(ml.id) AS total,
         COUNT(ml.id) FILTER (WHERE ml.status = 'taken') AS taken
       FROM medication_logs ml
       JOIN member_medications mm ON mm.id = ml.member_medication_id
       WHERE mm.member_id = $1
         AND ml.scheduled_time >= NOW() - ($2 || ' days')::INTERVAL
       GROUP BY ml.scheduled_time::DATE
       ORDER BY date`,
      [memberId, periodDays.toString()]
    );

    res.json({
      period_days: periodDays,
      overall: {
        total_doses: totalDoses,
        taken: parseInt(o.taken) || 0,
        skipped: parseInt(o.skipped) || 0,
        missed: parseInt(o.missed) || 0,
        adherence_pct: totalDoses > 0 ? Math.round((parseInt(o.taken) || 0) * 1000 / totalDoses) / 10 : 0,
      },
      streak: { current: currentStreak, longest: longestStreak },
      medications: result.rows,
      daily_trend: trend.rows,
    });
  } catch (err) {
    console.error('getMyAdherence error:', err);
    res.status(500).json({ message: 'Failed to compute adherence' });
  }
};

// Admin: get adherence for a specific member
const getMemberAdherence = async (req, res) => {
  try {
    const { memberId } = req.params;
    const { days = 30 } = req.query;
    const periodDays = Math.min(parseInt(days) || 30, 365);

    const result = await pool.query(
      `SELECT
         m.first_name, m.last_name, m.member_number,
         COUNT(ml.id) AS total_doses,
         COUNT(ml.id) FILTER (WHERE ml.status = 'taken') AS taken,
         COUNT(ml.id) FILTER (WHERE ml.status = 'skipped') AS skipped,
         COUNT(ml.id) FILTER (WHERE ml.status = 'pending' AND ml.scheduled_time < NOW()) AS missed
       FROM members m
       LEFT JOIN member_medications mm ON mm.member_id = m.id
       LEFT JOIN medication_logs ml ON ml.member_medication_id = mm.id
         AND ml.scheduled_time >= NOW() - ($2 || ' days')::INTERVAL
       WHERE m.id = $1
       GROUP BY m.id`,
      [memberId, periodDays.toString()]
    );

    if (result.rows.length === 0) return res.status(404).json({ message: 'Member not found' });
    const r = result.rows[0];
    const total = parseInt(r.total_doses) || 0;

    res.json({
      member: { first_name: r.first_name, last_name: r.last_name, member_number: r.member_number },
      period_days: periodDays,
      total_doses: total,
      taken: parseInt(r.taken) || 0,
      skipped: parseInt(r.skipped) || 0,
      missed: parseInt(r.missed) || 0,
      adherence_pct: total > 0 ? Math.round((parseInt(r.taken) || 0) * 1000 / total) / 10 : 0,
    });
  } catch (err) {
    console.error('getMemberAdherence error:', err);
    res.status(500).json({ message: 'Failed to get member adherence' });
  }
};

// Admin: overview of all members' adherence
const getAdherenceOverview = async (req, res) => {
  try {
    const { days = 30 } = req.query;
    const periodDays = Math.min(parseInt(days) || 30, 365);

    const result = await pool.query(
      `SELECT
         m.id, m.first_name, m.last_name, m.member_number,
         COUNT(ml.id) AS total_doses,
         COUNT(ml.id) FILTER (WHERE ml.status = 'taken') AS taken,
         CASE WHEN COUNT(ml.id) > 0
           THEN ROUND(COUNT(ml.id) FILTER (WHERE ml.status = 'taken') * 100.0 / COUNT(ml.id), 1)
           ELSE 0 END AS adherence_pct
       FROM members m
       JOIN member_medications mm ON mm.member_id = m.id
       LEFT JOIN medication_logs ml ON ml.member_medication_id = mm.id
         AND ml.scheduled_time >= NOW() - ($1 || ' days')::INTERVAL
       WHERE mm.end_date IS NULL OR mm.end_date >= CURRENT_DATE
       GROUP BY m.id
       ORDER BY adherence_pct ASC`,
      [periodDays.toString()]
    );

    const members = result.rows;
    const avgAdherence = members.length > 0
      ? Math.round(members.reduce((sum, m) => sum + parseFloat(m.adherence_pct), 0) * 10 / members.length) / 10
      : 0;

    res.json({
      period_days: periodDays,
      total_members: members.length,
      average_adherence_pct: avgAdherence,
      low_adherence: members.filter(m => parseFloat(m.adherence_pct) < 75),
      members,
    });
  } catch (err) {
    console.error('getAdherenceOverview error:', err);
    res.status(500).json({ message: 'Failed to get adherence overview' });
  }
};

module.exports = { getMyAdherence, getMemberAdherence, getAdherenceOverview };
