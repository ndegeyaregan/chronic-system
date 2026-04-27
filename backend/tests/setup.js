// Mock the pg pool
const mockQuery = jest.fn();
const mockConnect = jest.fn();
const mockPool = { query: mockQuery, connect: mockConnect, end: jest.fn() };

jest.mock('../src/config/db', () => mockPool);

// Mock notification service (don't send real emails/SMS/push)
jest.mock('../src/services/notificationService', () => ({
  sendToMember: jest.fn().mockResolvedValue(undefined),
  sendWelcome: jest.fn().mockResolvedValue(undefined),
  sendCampaign: jest.fn().mockResolvedValue({ sent: 0, failed: 0 }),
  sendPush: jest.fn().mockResolvedValue(undefined),
  sendSMS: jest.fn().mockResolvedValue(undefined),
  sendEmail: jest.fn().mockResolvedValue(undefined),
}));

// Mock alert service
jest.mock('../src/services/alertService', () => ({
  checkVitalAlerts: jest.fn().mockResolvedValue(undefined),
  sendMedicationReminders: jest.fn().mockResolvedValue(undefined),
  sendAppointmentReminders: jest.fn().mockResolvedValue(undefined),
  sendScriptExpiryAlerts: jest.fn().mockResolvedValue(undefined),
  checkLabTestsDue: jest.fn().mockResolvedValue(undefined),
  sendLabTestReminders: jest.fn().mockResolvedValue(undefined),
  sendLabTestDayReminder: jest.fn().mockResolvedValue(undefined),
  sendLabTestDailyPush: jest.fn().mockResolvedValue(undefined),
  sendLabTestWeeklyEmail: jest.fn().mockResolvedValue(undefined),
  sendLabTestMonthlySms: jest.fn().mockResolvedValue(undefined),
  sendTreatmentPlanReminders: jest.fn().mockResolvedValue(undefined),
  sendTreatmentDayReminder: jest.fn().mockResolvedValue(undefined),
}));

// Helper to generate a valid JWT for test requests
const jwt = require('jsonwebtoken');
process.env.JWT_SECRET = 'test-secret-key';
process.env.JWT_EXPIRES_IN = '7d';

const generateMemberToken = (overrides = {}) => {
  const payload = {
    id: '11111111-1111-1111-1111-111111111111',
    member_number: '333307-00',
    type: 'member',
    ...overrides,
  };
  return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '1h' });
};

const generateAdminToken = (overrides = {}) => {
  const payload = {
    id: '22222222-2222-2222-2222-222222222222',
    email: 'admin@test.com',
    role: 'super_admin',
    type: 'admin',
    ...overrides,
  };
  return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '1h' });
};

module.exports = {
  mockQuery,
  mockPool,
  mockConnect,
  generateMemberToken,
  generateAdminToken,
};
