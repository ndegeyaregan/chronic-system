import api from './axios';

export const getPartners = (params) => api.get('/lifestyle/partners', { params });
export const createPartner = (data) => api.post('/lifestyle/partners', data);
export const updatePartner = (id, data) =>
  api.put(`/lifestyle/partners/${id}`, data);
export const deletePartner = (id) => api.delete(`/lifestyle/partners/${id}`);
