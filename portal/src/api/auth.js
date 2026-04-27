import api from './axios';

export const loginAdmin = (data) => api.post('/auth/login/admin', data);
export const changePassword = (data) => api.post('/auth/change-password', data);
export const resetMemberPassword = (member_id) =>
  api.post('/auth/admin/reset-member-password', { member_id });
