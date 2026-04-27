import api from './axios';

export const getConditions = () => api.get('/conditions');
export const getConditionDetail = (id) => api.get(`/conditions/${id}/detail`);
export const syncConditions = () => api.post('/conditions/sync');
export const createCondition = (data) => api.post('/conditions', data);
export const updateCondition = (id, data) => api.put(`/conditions/${id}`, data);
export const deleteCondition = (id) => api.delete(`/conditions/${id}`);
export const toggleCondition = (id) => api.patch(`/conditions/${id}/toggle`);
