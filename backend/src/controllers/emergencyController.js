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
    // Create critical admin alert
    await pool.query(
      `INSERT INTO admin_alerts (member_id, alert_type, severity, value_reported, notes)
       VALUES ($1, 'emergency', 'critical', $2, $3)`,
      [memberId, pain_level || 10, `AMBULANCE REQUESTED. Pain: ${pain_level}. Location: ${address || `${latitude},${longitude}`}`]
    );
    // Notify member
    await notificationService.sendToMember(memberId, {
      type: 'emergency',
      title: '🚑 Emergency Request Received',
      message: 'Your emergency request has been received. Help is on the way. Stay calm.',
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
