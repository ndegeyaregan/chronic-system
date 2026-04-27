import api from './axios';

export const getPartners = (params) => api.get('/lifestyle/partners', { params });
export const createPartner = (data) => api.post('/lifestyle/partners', data);
export const updatePartner = (id, data) =>
  api.put(`/lifestyle/partners/${id}`, data);
export const deletePartner = (id) => api.delete(`/lifestyle/partners/${id}`);

export const getPartnerVideos = (partnerId) =>
  api.get(`/lifestyle/partners/${partnerId}/videos`).then(r => r.data);
export const createPartnerVideo = (partnerId, data) =>
  api.post(`/lifestyle/partners/${partnerId}/videos`, data);
export const updatePartnerVideo = (videoId, data) =>
  api.put(`/lifestyle/partners/videos/${videoId}`, data);
export const deletePartnerVideo = (videoId) =>
  api.delete(`/lifestyle/partners/videos/${videoId}`);
