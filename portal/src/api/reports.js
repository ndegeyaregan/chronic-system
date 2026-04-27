import api from './axios';

const data = (path, params) => api.get(`/reports/${path}/data`, { params }).then((r) => r.data);
const csv  = (path, params) => api.get(`/reports/${path}`, { params, responseType: 'blob' });

export const getMembersReportData          = ()       => data('members');
export const getAuthorizationsReportData   = (params) => data('authorizations', params);
export const getLabTestsReportData         = (params) => data('lab-tests', params);
export const getPrescriptionsReportData    = (params) => data('prescriptions', params);
export const getTreatmentPlansReportData   = (params) => data('treatment-plans', params);
export const getAppointmentsReportData     = (params) => data('appointments', params);
export const getVitalsReportData           = (params) => data('vitals', params);
export const getConditionsEnrollmentData   = ()       => data('conditions');

export const downloadMembersCsv            = ()       => csv('members');
export const downloadAuthorizationsCsv     = (params) => csv('authorizations', params);
export const downloadLabTestsCsv           = (params) => csv('lab-tests', params);
export const downloadPrescriptionsCsv      = (params) => csv('prescriptions', params);
export const downloadTreatmentPlansCsv     = (params) => csv('treatment-plans', params);
export const downloadAppointmentsCsv       = (params) => csv('appointments', params);
export const downloadVitalsCsv             = (params) => csv('vitals', params);
export const downloadConditionsCsv         = ()       => csv('conditions');
