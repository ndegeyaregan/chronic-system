const { mockQuery, generateMemberToken } = require('./setup');
const request = require('supertest');
const app = require('../src/app');

describe('Vitals Endpoints', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  const memberId = '11111111-1111-1111-1111-111111111111';

  // ── Log Vitals ─────────────────────────────────────────────────────────────

  describe('POST /api/vitals', () => {
    it('should allow member to log vitals', async () => {
      const token = generateMemberToken();

      const vitalsRow = {
        id: 'vitals-1111',
        member_id: memberId,
        blood_sugar_mmol: 5.6,
        systolic_bp: 120,
        diastolic_bp: 80,
        heart_rate: 72,
        weight_kg: 75,
        height_cm: 175,
        o2_saturation: 98,
        pain_level: 2,
        temperature_c: 36.5,
        notes: 'Feeling good',
        mood: 'good',
        recorded_at: new Date().toISOString(),
      };

      // INSERT vitals
      mockQuery.mockResolvedValueOnce({ rows: [vitalsRow] });

      const res = await request(app)
        .post('/api/vitals')
        .set('Authorization', `Bearer ${token}`)
        .send({
          blood_sugar_mmol: 5.6,
          systolic_bp: 120,
          diastolic_bp: 80,
          heart_rate: 72,
          weight_kg: 75,
          height_cm: 175,
          o2_saturation: 98,
          pain_level: 2,
          temperature_c: 36.5,
          notes: 'Feeling good',
          mood: 'good',
        });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('blood_sugar_mmol', 5.6);
      expect(res.body).toHaveProperty('systolic_bp', 120);
      expect(res.body).toHaveProperty('mood', 'good');
    });

    it('should allow logging with partial vitals', async () => {
      const token = generateMemberToken();

      const vitalsRow = {
        id: 'vitals-2222',
        member_id: memberId,
        systolic_bp: 130,
        diastolic_bp: 85,
        recorded_at: new Date().toISOString(),
      };

      mockQuery.mockResolvedValueOnce({ rows: [vitalsRow] });

      const res = await request(app)
        .post('/api/vitals')
        .set('Authorization', `Bearer ${token}`)
        .send({ systolic_bp: 130, diastolic_bp: 85 });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('systolic_bp', 130);
    });

    it('should return 401 without token', async () => {
      const res = await request(app)
        .post('/api/vitals')
        .send({ systolic_bp: 120 });

      expect(res.status).toBe(401);
    });

    it('should return 400 for out-of-range systolic_bp', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/vitals')
        .set('Authorization', `Bearer ${token}`)
        .send({ systolic_bp: 999 });

      expect(res.status).toBe(400);
    });

    it('should return 400 for invalid mood value', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/vitals')
        .set('Authorization', `Bearer ${token}`)
        .send({ mood: 'invalid_mood' });

      expect(res.status).toBe(400);
    });
  });

  // ── Get Vitals History ─────────────────────────────────────────────────────

  describe('GET /api/vitals', () => {
    it('should return vitals history for member', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({
        rows: [
          { id: 'v1', systolic_bp: 120, diastolic_bp: 80, recorded_at: '2025-07-01T10:00:00Z' },
          { id: 'v2', systolic_bp: 125, diastolic_bp: 82, recorded_at: '2025-07-02T10:00:00Z' },
        ],
      });

      const res = await request(app)
        .get('/api/vitals')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body).toHaveLength(2);
    });

    it('should return empty array when no vitals exist', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .get('/api/vitals')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('should return 401 without token', async () => {
      const res = await request(app).get('/api/vitals');

      expect(res.status).toBe(401);
    });
  });

  // ── Get Latest Vitals ──────────────────────────────────────────────────────

  describe('GET /api/vitals/latest', () => {
    it('should return latest vitals for member', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'v-latest',
          member_id: memberId,
          systolic_bp: 118,
          diastolic_bp: 78,
          blood_sugar_mmol: 5.2,
          recorded_at: '2025-07-10T08:30:00Z',
        }],
      });

      const res = await request(app)
        .get('/api/vitals/latest')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('id', 'v-latest');
      expect(res.body).toHaveProperty('systolic_bp', 118);
    });

    it('should return 404 when no vitals recorded', async () => {
      const token = generateMemberToken();

      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .get('/api/vitals/latest')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.message).toBe('No vitals recorded yet');
    });

    it('should return 401 without token', async () => {
      const res = await request(app).get('/api/vitals/latest');

      expect(res.status).toBe(401);
    });
  });
});
