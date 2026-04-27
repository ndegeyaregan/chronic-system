const { mockQuery, mockConnect, generateAdminToken, generateMemberToken } = require('./setup');
const request = require('supertest');
const app = require('../src/app');

describe('Members Endpoints', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockConnect.mockReset();
  });

  // ── List Members (Admin) ───────────────────────────────────────────────────

  describe('GET /api/members', () => {
    it('should allow admin to list members', async () => {
      const token = generateAdminToken();

      // COUNT query
      mockQuery.mockResolvedValueOnce({ rows: [{ count: '2' }] });
      // SELECT query
      mockQuery.mockResolvedValueOnce({
        rows: [
          {
            id: '11111111-1111-1111-1111-111111111111',
            member_number: '333307-00',
            first_name: 'John',
            last_name: 'Doe',
            email: 'john@test.com',
            is_active: true,
            conditions: [],
          },
          {
            id: '22222222-3333-4444-5555-666666666666',
            member_number: '333308-00',
            first_name: 'Jane',
            last_name: 'Smith',
            email: 'jane@test.com',
            is_active: true,
            conditions: [],
          },
        ],
      });

      const res = await request(app)
        .get('/api/members')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('members');
      expect(res.body).toHaveProperty('total', 2);
      expect(res.body.members).toHaveLength(2);
    });

    it('should return 403 for member token (non-admin)', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .get('/api/members')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/Forbidden/);
    });

    it('should return 401 with no token', async () => {
      const res = await request(app).get('/api/members');

      expect(res.status).toBe(401);
    });
  });

  // ── Register Member (Admin) ────────────────────────────────────────────────

  describe('POST /api/members', () => {
    const mockClient = {
      query: jest.fn(),
      release: jest.fn(),
    };

    beforeEach(() => {
      mockClient.query.mockReset();
      mockClient.release.mockReset();
      mockConnect.mockResolvedValue(mockClient);
    });

    it('should allow admin to create a member', async () => {
      const token = generateAdminToken();

      // BEGIN
      mockClient.query.mockResolvedValueOnce({});
      // Check existing member_number
      mockClient.query.mockResolvedValueOnce({ rows: [] });
      // INSERT member
      mockClient.query.mockResolvedValueOnce({
        rows: [{
          id: 'new-member-id',
          member_number: '444401-00',
          first_name: 'Alice',
          last_name: 'Wonder',
          email: 'alice@test.com',
          phone: null,
          plan_type: null,
          scheme_id: null,
          date_of_birth: '1985-06-15',
          id_number: null,
          is_active: true,
          created_at: new Date().toISOString(),
        }],
      });
      // Audit log
      mockClient.query.mockResolvedValueOnce({});
      // COMMIT
      mockClient.query.mockResolvedValueOnce({});

      const res = await request(app)
        .post('/api/members')
        .set('Authorization', `Bearer ${token}`)
        .send({
          member_number: '444401-00',
          first_name: 'Alice',
          last_name: 'Wonder',
          date_of_birth: '1985-06-15',
        });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('member_number', '444401-00');
      expect(res.body).toHaveProperty('first_name', 'Alice');
    });

    it('should return 400 when required fields are missing', async () => {
      const token = generateAdminToken();

      const res = await request(app)
        .post('/api/members')
        .set('Authorization', `Bearer ${token}`)
        .send({ first_name: 'Alice' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/member_number.*first_name.*last_name.*date_of_birth/);
    });

    it('should return 409 when member_number already exists', async () => {
      const token = generateAdminToken();

      mockClient.query.mockResolvedValueOnce({}); // BEGIN
      mockClient.query.mockResolvedValueOnce({ rows: [{ id: 'existing-id' }] }); // Existing check
      mockClient.query.mockResolvedValueOnce({}); // ROLLBACK

      const res = await request(app)
        .post('/api/members')
        .set('Authorization', `Bearer ${token}`)
        .send({
          member_number: '333307-00',
          first_name: 'John',
          last_name: 'Doe',
          date_of_birth: '1990-01-01',
        });

      expect(res.status).toBe(409);
      expect(res.body.message).toMatch(/already exists/);
    });

    it('should return 403 for member token', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/members')
        .set('Authorization', `Bearer ${token}`)
        .send({
          member_number: '444401-00',
          first_name: 'Alice',
          last_name: 'Wonder',
          date_of_birth: '1985-06-15',
        });

      expect(res.status).toBe(403);
    });
  });

  // ── Get Member by ID (Admin) ───────────────────────────────────────────────

  describe('GET /api/members/:id', () => {
    it('should return member detail for admin', async () => {
      const token = generateAdminToken();
      const memberId = '11111111-1111-1111-1111-111111111111';

      // Member query
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: memberId,
          member_number: '333307-00',
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@test.com',
          is_active: true,
          conditions: null,
        }],
      });
      // Medications
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Vitals
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Appointments
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Checkins
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Meals
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Fitness
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Psychosocial
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Lab tests
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Treatment plans
      mockQuery.mockResolvedValueOnce({ rows: [] });
      // Medication adherence
      mockQuery.mockResolvedValueOnce({ rows: [{ taken: '0', total: '0' }] });

      const res = await request(app)
        .get(`/api/members/${memberId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('member');
      expect(res.body.member).toHaveProperty('member_number', '333307-00');
      expect(res.body).not.toHaveProperty('password_hash');
    });

    it('should return 404 for non-existent member', async () => {
      const token = generateAdminToken();

      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .get('/api/members/nonexistent-id')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.message).toBe('Member not found');
    });

    it('should return 403 for member token on admin route', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .get('/api/members/some-id')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
    });
  });
});
