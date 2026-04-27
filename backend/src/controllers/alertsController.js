const pool = require('../config/db');
const notificationService = require('../services/notificationService');

const escapeCsv = (v) => {
  if (v === null || v === undefined) return '';
  const s = String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

const reportMoodAlert = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { mood, notes } = req.body;
    const badMoods = ['bad', 'terrible'];
    if (!badMoods.includes(mood)) {
      return res.status(400).json({ message: 'Alert only for bad or terrible mood' });
    }
    const severity = mood === 'terrible' ? 'high' : 'medium';
    await pool.query(
      `INSERT INTO admin_alerts (member_id, alert_type, severity, notes)
       VALUES ($1, 'mood', $2, $3)`,
      [memberId, severity, `Member reported mood: ${mood}. ${notes || ''}`]
    );
    // Also notify member with support message
    await notificationService.sendToMember(memberId, {
      type: 'support',
      title: '💙 We\'re here for you',
      message: 'We noticed you\'re not feeling great. Our support team has been notified. Please reach out if you need help.',
      channel: ['push'],
    });
    return res.json({ message: 'Alert recorded' });
  } catch (err) {
    console.error('reportMoodAlert error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const reportPainAlert = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { pain_level, notes, description } = req.body;
    const level = parseInt(pain_level, 10);
    if (isNaN(level) || level < 5) {
      return res.status(400).json({ message: 'Pain alert only for level 5 or above' });
    }
    const severity = level >= 9 ? 'critical' : level >= 7 ? 'high' : 'medium';
    const alertNote = description
      ? `Pain level ${level} reported. Description: ${description}. ${notes || ''}`
      : `Pain level ${level} reported. ${notes || ''}`;

    await pool.query(
      `INSERT INTO admin_alerts (member_id, alert_type, severity, value_reported, notes)
       VALUES ($1, 'pain', $2, $3, $4)`,
      [memberId, severity, level, alertNote]
    );

    // Fetch member details for the email
    const memberRes = await pool.query(
      `SELECT first_name, last_name, member_number, phone, email FROM members WHERE id = $1`,
      [memberId]
    );
    const member = memberRes.rows[0];

    // Email admin team
    const severityLabel = severity === 'critical' ? '🔴 CRITICAL' : severity === 'high' ? '🟠 HIGH' : '🟡 MEDIUM';
    await notificationService.sendEmail(
      'sancare@ug.sanlamallianz.com',
      `${severityLabel} Pain Alert – ${member?.first_name || ''} ${member?.last_name || ''} (${member?.member_number || ''})`,
      `
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden">
          <div style="background:#1a4480;padding:20px 24px">
            <h2 style="color:#fff;margin:0">⚠️ Member Pain Alert</h2>
          </div>
          <div style="padding:24px">
            <p><strong>Member:</strong> ${member?.first_name || ''} ${member?.last_name || ''}</p>
            <p><strong>Member No:</strong> ${member?.member_number || 'N/A'}</p>
            <p><strong>Phone:</strong> ${member?.phone || 'N/A'}</p>
            <p><strong>Pain Level:</strong> <span style="font-size:1.4em;font-weight:bold;color:${severity === 'critical' ? '#ef4444' : severity === 'high' ? '#f97316' : '#f59e0b'}">${level}/10</span></p>
            <p><strong>Severity:</strong> ${severityLabel}</p>
            ${description ? `<p><strong>Member's Description:</strong><br/><em style="color:#374151">"${description}"</em></p>` : ''}
            <p style="color:#6b7280;font-size:12px">Reported at ${new Date().toLocaleString('en-UG', { timeZone: 'Africa/Kampala' })}</p>
          </div>
          <div style="background:#f3f4f6;padding:12px 24px;text-align:center">
            <p style="margin:0;color:#6b7280;font-size:12px">Sanlam Allianz Chronic Care · Automated Alert System</p>
          </div>
        </div>
      `
    );

    return res.json({ message: 'Pain alert recorded', severity });
  } catch (err) {
    console.error('reportPainAlert error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const reportPsychosocialAlert = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { stress_level, anxiety_level, notes } = req.body;
    const maxLevel = Math.max(stress_level || 0, anxiety_level || 0);
    const severity = maxLevel >= 9 ? 'high' : 'medium';
    await pool.query(
      `INSERT INTO admin_alerts (member_id, alert_type, severity, value_reported, notes)
       VALUES ($1, 'psychosocial', $2, $3, $4)`,
      [memberId, severity, maxLevel, `Stress: ${stress_level}, Anxiety: ${anxiety_level}. ${notes || ''}`]
    );
    return res.json({ message: 'Psychosocial alert recorded' });
  } catch (err) {
    console.error('reportPsychosocialAlert error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getAdminAlerts = async (req, res) => {
  try {
    const { is_read, alert_type, severity, page = 1, limit = 30 } = req.query;
    const offset = (page - 1) * limit;
    const params = [];
    const filters = [];
    let idx = 1;
    if (is_read !== undefined) { filters.push(`aa.is_read = $${idx++}`); params.push(is_read === 'true'); }
    if (alert_type) { filters.push(`aa.alert_type = $${idx++}`); params.push(alert_type); }
    if (severity) { filters.push(`aa.severity = $${idx++}`); params.push(severity); }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    params.push(limit, offset);
    const result = await pool.query(
      `SELECT aa.*, m.first_name, m.last_name, m.member_number, m.phone, m.email
       FROM admin_alerts aa
       JOIN members m ON m.id = aa.member_id
       ${whereClause}
       ORDER BY aa.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      params
    );
    // Unread count
    const countRes = await pool.query('SELECT COUNT(*) FROM admin_alerts WHERE is_read = FALSE');
    return res.json({ alerts: result.rows, unread_count: parseInt(countRes.rows[0].count, 10) });
  } catch (err) {
    console.error('getAdminAlerts error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const markAlertRead = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { id } = req.params;
    const { admin_note } = req.body || {};
    await pool.query(
      `UPDATE admin_alerts
       SET is_read = TRUE, read_by = $1, read_at = NOW()
         ${admin_note ? ', admin_note = $3, admin_note_by = $1, admin_note_at = NOW()' : ''}
       WHERE id = $2`,
      admin_note ? [adminId, id, admin_note] : [adminId, id]
    );
    return res.json({ message: 'Alert marked as read' });
  } catch (err) {
    console.error('markAlertRead error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getAlertStats = async (req, res) => {
  try {
    const [unreadRes, criticalRes, highRes, todayRes, chartRes, emergencyRes] = await Promise.all([
      pool.query(`SELECT COUNT(*) FROM admin_alerts WHERE is_read = FALSE`),
      pool.query(`SELECT COUNT(*) FROM admin_alerts WHERE severity = 'critical' AND is_read = FALSE`),
      pool.query(`SELECT COUNT(*) FROM admin_alerts WHERE severity = 'high' AND is_read = FALSE`),
      pool.query(`SELECT COUNT(*) FROM admin_alerts WHERE created_at >= CURRENT_DATE`),
      pool.query(`
        SELECT DATE(created_at) AS day, COUNT(*)::int AS count
        FROM admin_alerts
        WHERE created_at >= NOW() - INTERVAL '7 days'
        GROUP BY DATE(created_at)
        ORDER BY day ASC
      `),
      pool.query(`SELECT COUNT(*) FROM emergency_requests WHERE status = 'pending'`),
    ]);
    return res.json({
      unread: parseInt(unreadRes.rows[0].count, 10),
      critical: parseInt(criticalRes.rows[0].count, 10),
      high: parseInt(highRes.rows[0].count, 10),
      today: parseInt(todayRes.rows[0].count, 10),
      pending_emergencies: parseInt(emergencyRes.rows[0].count, 10),
      chart: chartRes.rows,
    });
  } catch (err) {
    console.error('getAlertStats error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const exportAlertsCsv = async (req, res) => {
  try {
    const { is_read, alert_type, severity, start_date, end_date } = req.query;
    const params = [];
    const filters = [];
    let idx = 1;
    if (is_read !== undefined) { filters.push(`aa.is_read = $${idx++}`); params.push(is_read === 'true'); }
    if (alert_type) { filters.push(`aa.alert_type = $${idx++}`); params.push(alert_type); }
    if (severity)   { filters.push(`aa.severity = $${idx++}`);    params.push(severity); }
    if (start_date) { filters.push(`aa.created_at >= $${idx++}`); params.push(start_date); }
    if (end_date)   { filters.push(`aa.created_at <= $${idx++}`); params.push(end_date); }
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const result = await pool.query(
      `SELECT aa.*, m.first_name || ' ' || m.last_name AS member_name,
              m.member_number, m.phone, m.email,
              CONCAT(a.first_name, ' ', a.last_name) AS read_by_name
       FROM admin_alerts aa
       JOIN members m ON m.id = aa.member_id
       LEFT JOIN admins a ON a.id = aa.read_by
       ${where}
       ORDER BY aa.created_at DESC`,
      params
    );
    const headers = ['Date','Member','Member #','Phone','Alert Type','Severity','Value','Notes','Admin Note','Read','Read By','Read At'];
    const rows = [headers.join(','), ...result.rows.map((r) =>
      [
        r.created_at ? new Date(r.created_at).toISOString().split('T')[0] : '',
        r.member_name, r.member_number, r.phone,
        r.alert_type, r.severity, r.value_reported, r.notes,
        r.admin_note, r.is_read ? 'Yes' : 'No', r.read_by_name,
        r.read_at ? new Date(r.read_at).toISOString().split('T')[0] : '',
      ].map(escapeCsv).join(',')
    )];
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="alerts_export.csv"');
    return res.send(rows.join('\n'));
  } catch (err) {
    console.error('exportAlertsCsv error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const markAllAlertsRead = async (req, res) => {
  try {
    const adminId = req.user.id;
    await pool.query(
      `UPDATE admin_alerts SET is_read = TRUE, read_by = $1, read_at = NOW() WHERE is_read = FALSE`,
      [adminId]
    );
    return res.json({ message: 'All alerts marked as read' });
  } catch (err) {
    console.error('markAllAlertsRead error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  reportMoodAlert,
  reportPainAlert,
  reportPsychosocialAlert,
  getAdminAlerts,
  markAlertRead,
  markAllAlertsRead,
  getAlertStats,
  exportAlertsCsv,
};
