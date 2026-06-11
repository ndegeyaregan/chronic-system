import api from './axios';

export const getProductLinks = () => api.get('/product-links');
export const updateProductLink = (key, data) => api.put(`/product-links/${key}`, data);
