import api from './axios';

export const getPharmacies = (params) => api.get('/pharmacies', { params });
export const getPharmacyMetrics = (params) => api.get('/pharmacies/metrics', { params });
export const getPharmacyById = (id) => api.get(`/pharmacies/${id}`);
export const createPharmacy = (data) => api.post('/pharmacies', data);
export const updatePharmacy = (id, data) => api.put(`/pharmacies/${id}`, data);
export const deletePharmacy = (id) => api.delete(`/pharmacies/${id}`);
