import api from './axios';

export const getMembers = (params) => api.get('/members', { params });
export const getMemberById = (id) => api.get(`/members/${id}`);
export const createMember = (data) => api.post('/members', data);
export const uploadMembersCSV = (formData) =>
  api.post('/members/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
export const toggleMemberStatus = (id) => api.patch(`/members/${id}/status`);
export const exportMembers = () =>
  api.get('/reports/members', { responseType: 'blob' });
