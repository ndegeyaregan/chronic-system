import api from './axios';

export const getThresholds = () => api.get('/vitals/thresholds').then(r => r.data);
export const createThreshold = (data) => api.post('/vitals/thresholds', data).then(r => r.data);
export const updateThreshold = (id, data) => api.put(`/vitals/thresholds/${id}`, data).then(r => r.data);
export const deleteThreshold = (id) => api.delete(`/vitals/thresholds/${id}`).then(r => r.data);
