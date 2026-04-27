import api from './axios';

export const getAdminConversations = () =>
  api.get('/chat/admin/all').then((r) => r.data);

export const getConversationMessages = (memberId) =>
  api.get(`/chat/admin/messages/${memberId}`).then((r) => r.data);

export const sendAdminReply = (data) =>
  api.post('/chat/admin/reply', data).then((r) => r.data);

export const markMessagesRead = (memberId) =>
  api.patch(`/chat/admin/read/${memberId}`).then((r) => r.data);

export const updateConversationStatus = (memberId, status) =>
  api.patch(`/chat/admin/status/${memberId}`, { status }).then((r) => r.data);

export const getMemberChatInfo = (memberId) =>
  api.get(`/chat/admin/member-info/${memberId}`).then((r) => r.data);
