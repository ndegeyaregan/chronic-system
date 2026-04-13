import api from './axios';

export const getAdmins = () => api.get('/admins').then((r) => r.data);
export const createAdmin = (data) => api.post('/admins', data).then((r) => r.data);
export const updateAdmin = (id, data) => api.put(`/admins/${id}`, data).then((r) => r.data);
export const toggleAdminStatus = (id) => api.patch(`/admins/${id}/status`).then((r) => r.data);
export const resetAdminPassword = (id, data) =>
  api.patch(`/admins/${id}/reset-password`, data).then((r) => r.data);
