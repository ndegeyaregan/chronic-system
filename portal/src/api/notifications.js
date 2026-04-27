import api from './axios';

export const sendCampaign = (data) => api.post('/notifications/campaign', data);
export const getNotificationLogs = (params) =>
  api.get('/notifications/logs', { params });
export const getAdminNotifications = (params) =>
  api.get('/notifications/admin', { params });
export const markAdminNotificationRead = (id) =>
  api.put(`/notifications/admin/${id}/read`);
