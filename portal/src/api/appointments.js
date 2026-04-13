import api from './axios';

export const getAllAppointments = (params) =>
  api.get('/appointments', { params });
export const updateAppointmentStatus = (id, data) =>
  api.patch(`/appointments/${id}/status`, data);
export const createAppointmentForMember = (data) =>
  api.post('/appointments/admin', data);
