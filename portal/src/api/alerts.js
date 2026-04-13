import api from './axios';

export const getAdminAlerts = (params) =>
  api.get('/alerts', { params }).then(r => r.data);

export const getAlertStats = () =>
  api.get('/alerts/stats').then(r => r.data);

export const markAlertRead = (id, admin_note) =>
  api.patch(`/alerts/${id}/read`, { admin_note }).then(r => r.data);

export const markAllAlertsRead = () =>
  api.patch('/alerts/read-all').then(r => r.data);

export const exportAlertsCsv = (params) =>
  api.get('/alerts/export', { params, responseType: 'blob' });

export const getEmergencyRequests = (params) =>
  api.get('/emergency/requests', { params }).then(r => r.data);

export const updateEmergencyStatus = (id, data) =>
  api.patch(`/emergency/requests/${id}/status`, data).then(r => r.data);
