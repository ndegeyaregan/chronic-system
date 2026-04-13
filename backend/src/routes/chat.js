const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  sendMessage, getMessages, getAllConversations, adminReply,
  getMemberConversation, markMessagesRead, updateConversationStatus, getMemberInfo,
} = require('../controllers/chatController');

// Member routes
router.post('/',        authenticate, sendMessage);
router.get('/',         authenticate, getMessages);

// Admin routes
router.get('/admin/all',                   authenticate, requireAdmin, getAllConversations);
router.get('/admin/messages/:memberId',    authenticate, requireAdmin, getMemberConversation);
router.post('/admin/reply',                authenticate, requireAdmin, adminReply);
router.patch('/admin/read/:memberId',      authenticate, requireAdmin, markMessagesRead);
router.patch('/admin/status/:memberId',    authenticate, requireAdmin, updateConversationStatus);
router.get('/admin/member-info/:memberId', authenticate, requireAdmin, getMemberInfo);

module.exports = router;
