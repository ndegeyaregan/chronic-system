const { mockQuery, generateMemberToken, generateAdminToken } = require('./setup');
const request = require('supertest');
const app = require('../src/app');

describe('Appointments Endpoints', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  const memberId = '11111111-1111-1111-1111-111111111111';
  const hospitalId = 'aaaa-bbbb-cccc-dddd';
  const appointmentId = 'appt-1111-2222-3333';

  // ── Create Appointment (Member) ────────────────────────────────────────────

  describe('POST /api/appointments', () => {
    it('should allow member to create appointment', async () => {
      const token = generateMemberToken();

      // Hospital lookup
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: hospitalId,
          name: 'Test Hospital',
          is_active: true,
          email: 'hospital@test.com',
          contact_person: 'Dr Smith',
        }],
      });
      // INSERT appointment
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: appointmentId,
          member_id: memberId,
          hospital_id: hospitalId,
          appointment_date: '2025-08-15',
          status: 'pending',
        }],
      });
      // Member lookup for hospital email notification
      mockQuery.mockResolvedValueOnce({
        rows: [{ first_name: 'John', last_name: 'Doe', member_number: '333307-00' }],
      });
      // Admin notification insert
      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/appointments')
        .set('Authorization', `Bearer ${token}`)
        .send({ hospital_id: hospitalId, appointment_date: '2025-08-15' });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('status', 'pending');
      expect(res.body).toHaveProperty('hospital_id', hospitalId);
    });

    it('should return 400 when hospital_id is missing', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/appointments')
        .set('Authorization', `Bearer ${token}`)
        .send({ appointment_date: '2025-08-15' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/hospital_id and appointment_date are required/);
    });

    it('should return 400 when appointment_date is missing', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/appointments')
        .set('Authorization', `Bearer ${token}`)
        .send({ hospital_id: hospitalId });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/hospital_id and appointment_date are required/);
    });

    it('should return 404 when hospital not found', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/appointments')
        .set('Authorization', `Bearer ${token}`)
        .send({ hospital_id: 'nonexistent', appointment_date: '2025-08-15' });

      expect(res.status).toBe(404);
      expect(res.body.message).toBe('Hospital not found');
    });

    it('should return 401 with no token', async () => {
      const res = await request(app)
        .post('/api/appointments')
        .send({ hospital_id: hospitalId, appointment_date: '2025-08-15' });

      expect(res.status).toBe(401);
    });
  });

  // ── List My Appointments (Member) ──────────────────────────────────────────

  describe('GET /api/appointments/mine', () => {
    it('should return member appointments', async () => {
      const token = generateMemberToken();

      // Data query + count query (called via Promise.all)
      mockQuery.mockResolvedValueOnce({
        rows: [
          {
            id: appointmentId,
            member_id: memberId,
            hospital_name: 'Test Hospital',
            appointment_date: '2025-08-15',
            status: 'pending',
          },
        ],
      });
      mockQuery.mockResolvedValueOnce({ rows: [{ count: '1' }] });

      const res = await request(app)
        .get('/api/appointments/mine')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(res.body).toHaveProperty('total', 1);
      expect(res.body.data).toHaveLength(1);
    });

    it('should return 401 without token', async () => {
      const res = await request(app).get('/api/appointments/mine');

      expect(res.status).toBe(401);
    });
  });

  // ── Cancel Appointment (Member) ────────────────────────────────────────────

  describe('PATCH /api/appointments/:id/cancel', () => {
    it('should allow member to cancel their appointment', async () => {
      const token = generateMemberToken();

      // SELECT existing appointment
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: appointmentId,
          member_id: memberId,
          status: 'pending',
        }],
      });
      // UPDATE status
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: appointmentId,
          member_id: memberId,
          status: 'cancelled',
        }],
      });

      const res = await request(app)
        .patch(`/api/appointments/${appointmentId}/cancel`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('status', 'cancelled');
    });

    it('should return 404 when appointment not found', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .patch('/api/appointments/nonexistent/cancel')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.message).toBe('Appointment not found');
    });

    it('should return 409 when appointment already cancelled', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: appointmentId,
          member_id: memberId,
          status: 'cancelled',
        }],
      });

      const res = await request(app)
        .patch(`/api/appointments/${appointmentId}/cancel`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(409);
      expect(res.body.message).toMatch(/already cancelled/);
    });
  });

  // ── Admin Update Appointment Status ────────────────────────────────────────

  describe('PATCH /api/appointments/:id/status', () => {
    it('should allow admin to update appointment status', async () => {
      const token = generateAdminToken();

      // SELECT existing appointment with joins
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: appointmentId,
          member_id: memberId,
          hospital_name: 'Test Hospital',
          hospital_email: 'hospital@test.com',
          contact_person: 'Dr Smith',
          first_name: 'John',
          last_name: 'Doe',
          member_number: '333307-00',
          status: 'pending',
        }],
      });
      // UPDATE appointment
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: appointmentId,
          status: 'confirmed',
          confirmed_date: '2025-08-15',
        }],
      });
      // Notification log insert
      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .patch(`/api/appointments/${appointmentId}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'confirmed', confirmed_date: '2025-08-15' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('status', 'confirmed');
    });

    it('should return 400 for invalid status', async () => {
      const token = generateAdminToken();

      const res = await request(app)
        .patch(`/api/appointments/${appointmentId}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'invalid_status' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/status must be one of/);
    });

    it('should return 404 when appointment not found', async () => {
      const token = generateAdminToken();

      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .patch('/api/appointments/nonexistent/status')
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'confirmed' });

      expect(res.status).toBe(404);
      expect(res.body.message).toBe('Appointment not found');
    });

    it('should return 403 for member token on admin route', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .patch(`/api/appointments/${appointmentId}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'confirmed' });

      expect(res.status).toBe(403);
    });
  });
});
