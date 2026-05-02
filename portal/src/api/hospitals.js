import api from './axios';

// Get all institutions (hospitals & pharmacies from Sanlam + user-added)
export const getInstitutions = (params) => api.get('/institutions', { params });
export const getInstitutionById = (id) => api.get(`/institutions/${id}`);
export const createInstitution = (data) => api.post('/institutions', data);
export const suspendInstitution = (id, reason) => api.post(`/institutions/${id}/suspend`, { reason });
export const unsuspendInstitution = (id) => api.post(`/institutions/${id}/unsuspend`);
export const deleteInstitution = (id) => api.delete(`/institutions/${id}`);

// Legacy endpoints (kept for backward compatibility)
export const getHospitals = (params) => api.get('/hospitals', { params });
export const getHospitalById = (id) => api.get(`/hospitals/${id}`);
export const createHospital = (data) => api.post('/hospitals', data);
export const updateHospital = (id, data) => api.put(`/hospitals/${id}`, data);
export const deleteHospital = (id) => api.delete(`/hospitals/${id}`);
