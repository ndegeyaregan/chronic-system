const pool = require('../config/db');
const { sendToMember } = require('../services/notificationService');

// GET /notifications — member's own notifications
const getMyNotifications = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { limit = 50, offset = 0 } = req.query;
    const result = await pool.query(
      `SELECT id, type, channel, title, message, status, sent_at,
              read_at, (read_at IS NOT NULL) AS is_read
       FROM notifications
       WHERE member_id = $1
       ORDER BY sent_at DESC
       LIMIT $2 OFFSET $3`,
      [memberId, limit, offset]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getMyNotifications error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// GET /notifications/admin — admin portal notifications (appointment requests, alerts)
const getAdminNotifications = async (req, res) => {
  try {
    const { limit = 30, unread_only } = req.query;
    let query = `
      SELECT n.id, n.type, n.title, n.message, n.status, n.sent_at,
             n.read_at, n.reference_id, n.reference_type,
             (n.read_at IS NULL) AS is_unread,
             m.first_name, m.last_name, m.member_number
      FROM notifications n
      LEFT JOIN members m ON m.id = n.member_id
      WHERE n.channel = 'portal'`;
    const params = [];
    if (unread_only === 'true') {
      query += ' AND n.read_at IS NULL';
    }
    query += ' ORDER BY n.sent_at DESC LIMIT $1';
    params.push(parseInt(limit));

    const result = await pool.query(query, params);
    const unreadCount = result.rows.filter((r) => r.is_unread).length;
    return res.json({ notifications: result.rows, unread_count: unreadCount });
  } catch (err) {
    console.error('getAdminNotifications error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// PUT /notifications/admin/:id/read — admin marks a notification as read
const markAdminNotificationRead = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query(
      `UPDATE notifications SET read_at = NOW() WHERE id = $1 AND channel = 'portal' AND read_at IS NULL`,
      [id]
    );
    return res.json({ message: 'Marked as read' });
  } catch (err) {
    console.error('markAdminNotificationRead error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// PUT /notifications/read-all — mark all as read
const markAllRead = async (req, res) => {
  try {
    const memberId = req.user.id;
    await pool.query(
      `UPDATE notifications SET read_at = NOW()
       WHERE member_id = $1 AND read_at IS NULL`,
      [memberId]
    );
    return res.json({ message: 'All marked as read' });
  } catch (err) {
    console.error('markAllRead error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// PUT /notifications/:id/read — mark one as read
const markRead = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { id } = req.params;
    await pool.query(
      `UPDATE notifications SET read_at = NOW()
       WHERE id = $1 AND member_id = $2 AND read_at IS NULL`,
      [id, memberId]
    );
    return res.json({ message: 'Marked as read' });
  } catch (err) {
    console.error('markRead error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const sendCampaign = async (req, res) => {
  try {
    const { title, message, channel, all_members, condition_id } = req.body;
    console.log('📢 sendCampaign called with:', { title, channel, all_members, condition_id });
    
    if (!title || !message || !channel || channel.length === 0) {
      return res.status(400).json({ message: 'title, message, and channel are required' });
    }
    // Get target members
    let memberQuery = 'SELECT id, fcm_token, phone, email, first_name FROM members WHERE is_active = TRUE';
    const params = [];
    if (!all_members && condition_id) {
      params.push(condition_id);
      memberQuery += ` AND $1 = ANY(conditions)`;
    }
    const members = await pool.query(memberQuery, params);
    console.log(`👥 Found ${members.rows.length} members to notify`);
    
    // Send notifications to each member
    const sendPromises = [];
    for (const m of members.rows) {
      console.log(`📤 Sending to ${m.first_name} (${m.id}) - channels: ${channel.join(', ')}`);
      sendPromises.push(
        sendToMember(m.id, {
          type: 'campaign',
          title,
          message,
          channel,
          fcmToken: m.fcm_token,
          phone: m.phone,
          email: m.email,
          firstName: m.first_name,
        }).catch(err => console.error(`❌ Error sending to ${m.id}:`, err))
      );
    }
    await Promise.all(sendPromises);
    console.log('✅ Campaign sent successfully');
    return res.json({ message: `Campaign sent to ${members.rows.length} members`, count: members.rows.length });
  } catch (err) {
    console.error('❌ sendCampaign error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getNotificationLogs = async (req, res) => {
  try {
    const { limit = 20 } = req.query;
    const result = await pool.query(
      `SELECT n.*, m.first_name || ' ' || m.last_name AS member_name, m.member_number
       FROM notifications n
       LEFT JOIN members m ON m.id = n.member_id
       WHERE n.type = 'campaign'
       ORDER BY n.sent_at DESC
       LIMIT $1`,
      [parseInt(limit)]
    );
    return res.json({ logs: result.rows });
  } catch (err) {
    console.error('getNotificationLogs error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { getMyNotifications, getAdminNotifications, markAdminNotificationRead, markRead, markAllRead, sendCampaign, getNotificationLogs };
