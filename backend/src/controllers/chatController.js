const pool = require('../config/db');

const notifyMemberAboutReply = (memberId, message, adminName) =>
  pool.query(
    `INSERT INTO notifications
      (member_id, type, channel, title, message, status, sent_at, reference_type)
     VALUES ($1, 'chat_reply', 'push', $2, $3, 'sent', NOW(), 'chat_message')`,
    [memberId, 'New message from care team', `${adminName || 'SanCare Support'} replied: ${message.trim()}`]
  ).catch(() => {});

// POST /api/chat — member sends a message
const sendMessage = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { message } = req.body;
    if (!message || !message.trim()) return res.status(400).json({ message: 'Message cannot be empty.' });
    const memberResult = await pool.query(`SELECT first_name, last_name FROM members WHERE id = $1`, [memberId]);
    const m = memberResult.rows[0];
    const memberName = m ? `${m.first_name || ''} ${m.last_name || ''}`.trim() : 'Member';
    const result = await pool.query(
      `INSERT INTO chat_messages (member_id, member_name, message, is_from_admin, is_read, created_at)
       VALUES ($1, $2, $3, false, false, NOW()) RETURNING *`,
      [memberId, memberName, message.trim()]
    );
    // Ensure conversation status row exists
    await pool.query(
      `INSERT INTO chat_conversation_status (member_id, status, updated_at)
       VALUES ($1, 'open', NOW())
       ON CONFLICT (member_id) DO UPDATE SET updated_at = NOW()`,
      [memberId]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('sendMessage error:', err);
    res.status(500).json({ message: 'Failed to send message.' });
  }
};

// GET /api/chat — get conversation for logged-in member
const getMessages = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT * FROM chat_messages WHERE member_id = $1 ORDER BY created_at ASC`,
      [memberId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('getMessages error:', err);
    res.status(500).json({ message: 'Failed to fetch messages.' });
  }
};

// GET /api/chat/admin/all — admin gets all conversations with unread count and status
const getAllConversations = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        latest.member_id,
        latest.member_name,
        latest.message,
        latest.created_at,
        COALESCE(unread.unread_count, 0)::int AS unread_count,
        COALESCE(cs.status, 'open') AS status
      FROM (
        SELECT DISTINCT ON (member_id) member_id, member_name, message, created_at
        FROM chat_messages
        ORDER BY member_id, created_at DESC
      ) latest
      LEFT JOIN (
        SELECT member_id, COUNT(*) AS unread_count
        FROM chat_messages
        WHERE is_from_admin = false AND is_read = false
        GROUP BY member_id
      ) unread ON unread.member_id = latest.member_id
      LEFT JOIN chat_conversation_status cs ON cs.member_id = latest.member_id
      ORDER BY latest.created_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('getAllConversations error:', err);
    res.status(500).json({ message: 'Failed to fetch conversations.' });
  }
};

// POST /api/chat/admin/reply — admin replies to a member
const adminReply = async (req, res) => {
  try {
    const { member_id, message, admin_name } = req.body;
    if (!member_id || !message?.trim()) return res.status(400).json({ message: 'member_id and message are required.' });
    const memberResult = await pool.query(`SELECT first_name, last_name FROM members WHERE id = $1`, [member_id]);
    const m = memberResult.rows[0];
    const memberName = m ? `${m.first_name || ''} ${m.last_name || ''}`.trim() : 'Member';
    const result = await pool.query(
      `INSERT INTO chat_messages (member_id, member_name, message, is_from_admin, admin_name, is_read, created_at)
       VALUES ($1, $2, $3, true, $4, true, NOW()) RETURNING *`,
      [member_id, memberName, message.trim(), admin_name || 'SanCare Support']
    );
    notifyMemberAboutReply(member_id, message, admin_name);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('adminReply error:', err);
    res.status(500).json({ message: 'Failed to send reply.' });
  }
};

// GET /api/chat/admin/messages/:memberId — admin gets full conversation for a member
const getMemberConversation = async (req, res) => {
  try {
    const { memberId } = req.params;
    const result = await pool.query(
      `SELECT * FROM chat_messages WHERE member_id = $1 ORDER BY created_at ASC`,
      [memberId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('getMemberConversation error:', err);
    res.status(500).json({ message: 'Failed to fetch conversation.' });
  }
};

// PATCH /api/chat/admin/read/:memberId — mark all member messages as read
const markMessagesRead = async (req, res) => {
  try {
    const { memberId } = req.params;
    await pool.query(
      `UPDATE chat_messages SET is_read = true WHERE member_id = $1 AND is_from_admin = false AND is_read = false`,
      [memberId]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('markMessagesRead error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

// PATCH /api/chat/admin/status/:memberId — update conversation status
const updateConversationStatus = async (req, res) => {
  try {
    const { memberId } = req.params;
    const { status } = req.body;
    const allowed = ['open', 'resolved', 'escalated'];
    if (!allowed.includes(status)) return res.status(400).json({ message: 'Invalid status' });
    await pool.query(
      `INSERT INTO chat_conversation_status (member_id, status, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (member_id) DO UPDATE SET status = $2, updated_at = NOW()`,
      [memberId, status]
    );
    res.json({ success: true, status });
  } catch (err) {
    console.error('updateConversationStatus error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

// GET /api/chat/admin/member-info/:memberId — member profile snapshot for sidebar
const getMemberInfo = async (req, res) => {
  try {
    const { memberId } = req.params;
    const [memberRes, conditionsRes, apptRes] = await Promise.all([
      pool.query(`SELECT first_name, last_name, email, phone, date_of_birth, gender FROM members WHERE id = $1`, [memberId]),
      pool.query(
        `SELECT c.name FROM member_conditions mc JOIN conditions c ON c.id = mc.condition_id WHERE mc.member_id = $1 ORDER BY mc.created_at`,
        [memberId]
      ),
      pool.query(
        `SELECT appointment_date, reason, status FROM appointments WHERE member_id = $1 ORDER BY appointment_date DESC LIMIT 1`,
        [memberId]
      ),
    ]);
    const member = memberRes.rows[0];
    if (!member) return res.status(404).json({ message: 'Member not found' });
    res.json({
      ...member,
      conditions: conditionsRes.rows.map(r => r.name),
      last_appointment: apptRes.rows[0] || null,
    });
  } catch (err) {
    console.error('getMemberInfo error:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  sendMessage, getMessages, getAllConversations, adminReply,
  getMemberConversation, markMessagesRead, updateConversationStatus, getMemberInfo,
};
