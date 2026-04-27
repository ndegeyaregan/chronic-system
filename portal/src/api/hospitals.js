import api from './axios';

export const getHospitals = (params) => api.get('/hospitals', { params });
export const getHospitalById = (id) => api.get(`/hospitals/${id}`);
export const createHospital = (data) => api.post('/hospitals', data);
export const updateHospital = (id, data) => api.put(`/hospitals/${id}`, data);
export const deleteHospital = (id) => api.delete(`/hospitals/${id}`);
