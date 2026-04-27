const pool = require('../config/db');
const notificationService = require('../services/notificationService');

const requestAmbulance = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { pain_level, latitude, longitude, address, notes } = req.body;
    const result = await pool.query(
      `INSERT INTO emergency_requests (member_id, pain_level, latitude, longitude, address, notes)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [memberId, pain_level || null, latitude || null, longitude || null, address || null, notes || null]
    );
    const emergency = result.rows[0];

    // Fetch member details for the alert
    const memberRes = await pool.query(
      `SELECT first_name, last_name, member_number, phone FROM members WHERE id = $1`,
      [memberId]
    );
    const member = memberRes.rows[0];
    const memberName = member ? `${member.first_name} ${member.last_name}` : 'Unknown';
    const memberNumber = member?.member_number || 'N/A';
    const memberPhone = member?.phone || 'N/A';
    const locationStr = address || (latitude && longitude ? `${latitude}, ${longitude}` : 'Not provided');

    // Create critical admin alert
    await pool.query(
      `INSERT INTO admin_alerts (member_id, alert_type, severity, value_reported, notes)
       VALUES ($1, 'emergency', 'critical', $2, $3)`,
      [memberId, pain_level || 10, `AMBULANCE REQUESTED. Pain: ${pain_level}. Location: ${locationStr}`]
    );

    // Notify all admins via email
    try {
      const adminsRes = await pool.query(`SELECT email, name FROM admins WHERE email IS NOT NULL`);
      const adminEmails = adminsRes.rows.filter(a => a.email).map(a => a.email);
      if (adminEmails.length > 0) {
        const subject = `🚨 EMERGENCY SOS — ${memberName} (${memberNumber})`;
        const html = `
          <div style="font-family:sans-serif;max-width:600px;margin:0 auto;">
            <div style="background:#DC2626;color:white;padding:20px;border-radius:8px 8px 0 0;">
              <h2 style="margin:0;">🚨 Emergency SOS Alert</h2>
            </div>
            <div style="border:1px solid #E5E7EB;padding:20px;border-radius:0 0 8px 8px;">
              <p><strong>Member:</strong> ${memberName}</p>
              <p><strong>Member Number:</strong> ${memberNumber}</p>
              <p><strong>Phone:</strong> ${memberPhone}</p>
              <p><strong>Pain Level:</strong> ${pain_level || 'N/A'}/10</p>
              <p><strong>Location:</strong> ${locationStr}</p>
              ${latitude && longitude ? `<p><strong>Map:</strong> <a href="https://maps.google.com/?q=${latitude},${longitude}">Open in Google Maps</a></p>` : ''}
              ${notes ? `<p><strong>Notes:</strong> ${notes}</p>` : ''}
              <p><strong>Time:</strong> ${new Date().toLocaleString('en-UG', { timeZone: 'Africa/Kampala' })}</p>
              <hr style="border:none;border-top:1px solid #E5E7EB;margin:16px 0;">
              <p style="color:#6B7280;font-size:13px;">Please respond to this emergency immediately. Log in to the admin portal to manage this request.</p>
            </div>
          </div>
        `;
        for (const email of adminEmails) {
          await notificationService.sendEmail(email, subject, html);
        }
      }
    } catch (emailErr) {
      console.error('Failed to email admins for emergency:', emailErr.message);
    }

    // Notify member
    await notificationService.sendToMember(memberId, {
      type: 'emergency',
      title: '🚑 Emergency Request Received',
      message: 'Your emergency request has been received. The Sanlam team has been notified. Help is on the way. Stay calm.',
      channel: ['push', 'sms'],
    });
    return res.status(201).json({ message: 'Emergency request submitted', emergency });
  } catch (err) {
    console.error('requestAmbulance error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getEmergencyRequests = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;
    const params = [];
    const filters = [];
    let idx = 1;
    if (status) { filters.push(`er.status = $${idx++}`); params.push(status); }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    params.push(limit, offset);
    const result = await pool.query(
      `SELECT er.*, m.first_name, m.last_name, m.member_number, m.phone
       FROM emergency_requests er
       JOIN members m ON m.id = er.member_id
       ${whereClause}
       ORDER BY er.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getEmergencyRequests error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateEmergencyStatus = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { id } = req.params;
    const { status, notes } = req.body;
    const validStatuses = ['pending', 'dispatched', 'resolved', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: `status must be one of: ${validStatuses.join(', ')}` });
    }
    const result = await pool.query(
      `UPDATE emergency_requests SET
         status = $1, notes = COALESCE($2, notes),
         dispatched_at = CASE WHEN $1 = 'dispatched' THEN NOW() ELSE dispatched_at END,
         resolved_at = CASE WHEN $1 = 'resolved' THEN NOW() ELSE resolved_at END,
         resolved_by = CASE WHEN $1 = 'resolved' THEN $3 ELSE resolved_by END,
         updated_at = NOW()
       WHERE id = $4 RETURNING *`,
      [status, notes || null, adminId, id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Emergency request not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateEmergencyStatus error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { requestAmbulance, getEmergencyRequests, updateEmergencyStatus };
