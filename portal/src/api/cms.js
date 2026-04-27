import api from './axios';

export const getContent = (params) => api.get('/cms', { params });
export const getContentById = (id) => api.get(`/cms/${id}`);
export const createContent = (data) => {
  console.log('📨 Sending to POST /cms:', data);
  return api.post('/cms', data).catch(err => {
    console.error('❌ POST /cms error:', err.response?.data || err.message);
    throw err;
  });
};
export const updateContent = (id, data) => {
  console.log('📨 Sending to PUT /cms/:id:', data);
  return api.put(`/cms/${id}`, data).catch(err => {
    console.error('❌ PUT /cms/:id error:', err.response?.data || err.message);
    throw err;
  });
};
export const deleteContent = (id) => api.delete(`/cms/${id}`);
export const publishContent = (id) => api.patch(`/cms/${id}/publish`);
