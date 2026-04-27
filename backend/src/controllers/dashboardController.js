const pool = require('../config/db');

const getDashboardSummary = async (req, res) => {
  try {
    const [
      countsRes, adherenceRes, recentAlertsRes,
      todayApptsRes, memberGrowthRes, conditionsRes,
      adherenceTrendRes, alertsBySeverityRes, labStatusRes,
      recentMembersRes, unreadChatRes,
    ] = await Promise.all([
      // Quick counts
      pool.query(`
        SELECT
          (SELECT COUNT(*)::int FROM admin_alerts WHERE is_read = false)                                     AS open_alerts,
          (SELECT COUNT(*)::int FROM authorization_requests WHERE status = 'pending')                        AS pending_auths,
          (SELECT COUNT(*)::int FROM lab_tests WHERE status IN ('ordered','pending','processing'))            AS pending_labs,
          (SELECT COUNT(*)::int FROM appointments WHERE appointment_date = CURRENT_DATE)                     AS today_appts_count,
          (SELECT COUNT(*)::int FROM members)                                                                AS total_members,
          (SELECT COUNT(*)::int FROM members WHERE is_active = true)                                        AS active_members,
          (SELECT COUNT(*)::int FROM members WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW())) AS new_this_month,
          (SELECT COUNT(*)::int FROM appointments WHERE status = 'pending')                                  AS pending_appts,
          (SELECT COUNT(*)::int FROM appointments WHERE status = 'confirmed')                                AS confirmed_appts,
          (SELECT COUNT(*)::int FROM appointments WHERE DATE_TRUNC('month', appointment_date) = DATE_TRUNC('month', NOW())) AS appts_this_month,
          (SELECT COUNT(*)::int FROM appointments WHERE status = 'completed')                                AS completed_appts
      `),

      // Medication adherence rate (last 30 days)
      pool.query(`
        SELECT
          ROUND(
            100.0 * COUNT(*) FILTER (WHERE status = 'taken') /
            NULLIF(COUNT(*) FILTER (WHERE status IN ('taken','skipped')), 0)
          , 1) AS adherence_rate
        FROM medication_logs
        WHERE scheduled_time >= NOW() - INTERVAL '30 days'
      `),

      // Recent alerts (last 5)
      pool.query(`
        SELECT a.id, a.alert_type, a.severity, a.notes, a.created_at,
               m.first_name || ' ' || m.last_name AS member_name
        FROM admin_alerts a
        LEFT JOIN members m ON m.id = a.member_id
        ORDER BY a.created_at DESC
        LIMIT 5
      `),

      // Today's appointments
      pool.query(`
        SELECT ap.id, ap.appointment_date, ap.preferred_time, ap.confirmed_time, ap.status, ap.reason,
               m.first_name || ' ' || m.last_name AS member_name,
               m.member_number,
               h.name AS hospital,
               c.name AS condition
        FROM appointments ap
        LEFT JOIN members m ON m.id = ap.member_id
        LEFT JOIN hospitals h ON h.id = ap.hospital_id
        LEFT JOIN conditions c ON c.id = ap.condition_id
        WHERE ap.appointment_date = CURRENT_DATE
        ORDER BY COALESCE(ap.confirmed_time, ap.preferred_time) ASC NULLS LAST
        LIMIT 10
      `),

      // Member growth last 6 months
      pool.query(`
        SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'Mon YY') AS month,
               COUNT(*)::int AS count
        FROM members
        WHERE created_at >= NOW() - INTERVAL '6 months'
        GROUP BY DATE_TRUNC('month', created_at)
        ORDER BY DATE_TRUNC('month', created_at) ASC
      `),

      // Members by condition
      pool.query(`
        SELECT c.name AS condition, COUNT(mc.member_id)::int AS count
        FROM conditions c
        LEFT JOIN member_conditions mc ON mc.condition_id = c.id
        GROUP BY c.name
        ORDER BY count DESC
        LIMIT 6
      `),

      // Medication adherence trend — monthly rate last 6 months
      pool.query(`
        SELECT
          TO_CHAR(DATE_TRUNC('month', scheduled_time), 'Mon YY') AS month,
          DATE_TRUNC('month', scheduled_time) AS month_ts,
          ROUND(
            100.0 * COUNT(*) FILTER (WHERE status = 'taken') /
            NULLIF(COUNT(*) FILTER (WHERE status IN ('taken','skipped')), 0)
          , 1) AS rate
        FROM medication_logs
        WHERE scheduled_time >= NOW() - INTERVAL '6 months'
        GROUP BY DATE_TRUNC('month', scheduled_time)
        ORDER BY month_ts ASC
      `),

      // Alerts by severity (all time, unread)
      pool.query(`
        SELECT severity, COUNT(*)::int AS count
        FROM admin_alerts
        WHERE is_read = false
        GROUP BY severity
        ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END
      `),

      // Lab tests by status
      pool.query(`
        SELECT status, COUNT(*)::int AS count
        FROM lab_tests
        GROUP BY status
        ORDER BY count DESC
      `),

      // Recent members (last 5 enrolled)
      pool.query(`
        SELECT m.id, m.member_number, m.first_name || ' ' || m.last_name AS full_name,
               m.plan_type, m.created_at,
               STRING_AGG(c.name, ', ') AS conditions
        FROM members m
        LEFT JOIN member_conditions mc ON mc.member_id = m.id
        LEFT JOIN conditions c ON c.id = mc.condition_id
        GROUP BY m.id, m.member_number, m.first_name, m.last_name, m.plan_type, m.created_at
        ORDER BY m.created_at DESC
        LIMIT 5
      `),

      // Unread member chat messages
      pool.query(`
        SELECT COUNT(*)::int AS unread_chats
        FROM chat_messages
        WHERE is_read = false AND is_from_admin = false
      `),
    ]);

    const counts = countsRes.rows[0];
    res.json({
      total_members:      counts.total_members,
      active_members:     counts.active_members,
      new_this_month:     counts.new_this_month,
      pending_appts:      counts.pending_appts,
      confirmed_appts:    counts.confirmed_appts,
      appts_this_month:   counts.appts_this_month,
      completed_appts:    counts.completed_appts,
      today_appts_count:  counts.today_appts_count,
      open_alerts:        counts.open_alerts,
      pending_auths:      counts.pending_auths,
      pending_labs:       counts.pending_labs,
      adherence_rate:     parseFloat(adherenceRes.rows[0]?.adherence_rate ?? 0),
      recent_alerts:      recentAlertsRes.rows,
      today_appointments: todayApptsRes.rows,
      member_growth:      memberGrowthRes.rows,
      by_condition:       conditionsRes.rows,
      adherence_trend:    adherenceTrendRes.rows.map(r => ({ month: r.month, rate: parseFloat(r.rate ?? 0) })),
      alerts_by_severity: alertsBySeverityRes.rows,
      lab_by_status:      labStatusRes.rows,
      recent_members:     recentMembersRes.rows,
      unread_chats:       unreadChatRes.rows[0]?.unread_chats ?? 0,
    });
  } catch (err) {
    console.error('getDashboardSummary error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { getDashboardSummary };
