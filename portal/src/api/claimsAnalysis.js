import api from './axios';

// Express parses repeated `?key=a&key=b` query strings into arrays — make
// sure axios serialises arrays that way rather than `key[]=a`.
const paramsSerializer = (params) => {
  const usp = new URLSearchParams();
  Object.entries(params || {}).forEach(([k, v]) => {
    if (v === undefined || v === null || v === '') return;
    if (Array.isArray(v)) {
      v.forEach((vi) => {
        if (vi !== undefined && vi !== null && vi !== '') usp.append(k, vi);
      });
    } else {
      usp.append(k, v);
    }
  });
  return usp.toString();
};

export const uploadClaimsFile = (file, onProgress) => {
  const fd = new FormData();
  fd.append('file', file);
  return api.post('/claims-analysis', fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 10 * 60 * 1000,
    onUploadProgress: (e) => {
      if (onProgress && e.total) onProgress(Math.round((e.loaded * 100) / e.total));
    },
  });
};

export const listClaimsUploads      = ()                 => api.get('/claims-analysis');
export const getClaimsUpload        = (id)               => api.get(`/claims-analysis/${id}`);
export const getClaimsUploadPreview = (id, limit = 25)   => api.get(`/claims-analysis/${id}/preview`, { params: { limit } });
export const deleteClaimsUpload     = (id)               => api.delete(`/claims-analysis/${id}`);

// Analytics endpoints accept single ID or array of IDs for combined analysis
export const getClaimsAnalyticsOverview = (uploadIds, params) => {
  const ids = Array.isArray(uploadIds) ? uploadIds : [uploadIds];
  const firstId = ids[0]; // Route requires one ID; others pass as query params
  const queryParams = { ...params };
  if (ids.length > 1) {
    queryParams.upload_id = ids;
  }
  return api.get(`/claims-analysis/${firstId}/analytics/overview`, { params: queryParams, paramsSerializer });
};

export const getClaimsProviderDrilldown = (uploadIds, provider, params) => {
  const ids = Array.isArray(uploadIds) ? uploadIds : [uploadIds];
  const firstId = ids[0]; // Route requires one ID; others pass as query params
  const queryParams = { ...params, provider };
  if (ids.length > 1) {
    queryParams.upload_id = ids;
  }
  return api.get(`/claims-analysis/${firstId}/analytics/provider`, {
    params: queryParams,
    paramsSerializer,
  });
};
