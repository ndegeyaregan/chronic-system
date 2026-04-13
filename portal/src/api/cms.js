import api from './axios';

export const getContent = (params) => api.get('/cms', { params });
export const getContentById = (id) => api.get(`/cms/${id}`);
export const createContent = (data) => api.post('/cms', data);
export const updateContent = (id, data) => api.put(`/cms/${id}`, data);
export const deleteContent = (id) => api.delete(`/cms/${id}`);
export const publishContent = (id) => api.patch(`/cms/${id}/publish`);
