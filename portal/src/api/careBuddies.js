import api from './axios';

export const getBuddies = (memberId) => api.get(`/buddies/admin/${memberId}`);
export const addBuddy = (memberId, data) => api.post(`/buddies/admin/${memberId}`, data);
export const updateBuddy = (buddyId, data) => api.put(`/buddies/admin/buddy/${buddyId}`, data);
export const deleteBuddy = (buddyId) => api.delete(`/buddies/admin/buddy/${buddyId}`);
