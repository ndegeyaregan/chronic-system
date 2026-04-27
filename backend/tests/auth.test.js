const { mockQuery, generateMemberToken, generateAdminToken } = require('./setup');
const request = require('supertest');
const app = require('../src/app');
const bcrypt = require('bcryptjs');

describe('Auth Endpoints', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  // ── Admin Login ────────────────────────────────────────────────────────────

  describe('POST /api/auth/login/admin', () => {
    const adminPasswordHash = bcrypt.hashSync('Admin@123', 10);
    const adminRow = {
      id: '22222222-2222-2222-2222-222222222222',
      email: 'admin@test.com',
      name: 'Test Admin',
      first_name: 'Test',
      last_name: 'Admin',
      role: 'super_admin',
      password_hash: adminPasswordHash,
      is_active: true,
    };

    it('should login successfully with valid credentials', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [adminRow] });

      const res = await request(app)
        .post('/api/auth/login/admin')
        .send({ email: 'admin@test.com', password: 'Admin@123' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body.admin).toHaveProperty('email', 'admin@test.com');
      expect(res.body.admin).toHaveProperty('role', 'super_admin');
    });

    it('should return 400 when email is missing', async () => {
      const res = await request(app)
        .post('/api/auth/login/admin')
        .send({ password: 'Admin@123' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/Email and password are required/);
    });

    it('should return 400 when password is missing', async () => {
      const res = await request(app)
        .post('/api/auth/login/admin')
        .send({ email: 'admin@test.com' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/Email and password are required/);
    });

    it('should return 401 for non-existent admin', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/auth/login/admin')
        .send({ email: 'nobody@test.com', password: 'Admin@123' });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Invalid credentials');
    });

    it('should return 401 for wrong password', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [adminRow] });

      const res = await request(app)
        .post('/api/auth/login/admin')
        .send({ email: 'admin@test.com', password: 'wrongpassword' });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Invalid credentials');
    });

    it('should return 403 for inactive admin account', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [{ ...adminRow, is_active: false }] });

      const res = await request(app)
        .post('/api/auth/login/admin')
        .send({ email: 'admin@test.com', password: 'Admin@123' });

      expect(res.status).toBe(403);
      expect(res.body.message).toBe('Account is inactive');
    });
  });

  // ── Member Login ───────────────────────────────────────────────────────────

  describe('POST /api/auth/login/member', () => {
    const memberPasswordHash = bcrypt.hashSync('Member@123', 10);
    const memberRow = {
      id: '11111111-1111-1111-1111-111111111111',
      member_number: '333307-00',
      first_name: 'John',
      last_name: 'Doe',
      email: 'john@test.com',
      password_hash: memberPasswordHash,
      is_active: true,
      is_password_set: true,
    };

    it('should login successfully with member_number', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [memberRow] });

      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ member_number: '333307-00', password: 'Member@123' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body.member).toHaveProperty('member_number', '333307-00');
      expect(res.body.member).toHaveProperty('first_name', 'John');
    });

    it('should login successfully with last_name and date_of_birth', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [memberRow] });

      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ last_name: 'Doe', date_of_birth: '1990-01-15', password: 'Member@123' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body.member).toHaveProperty('last_name', 'Doe');
    });

    it('should return 400 when password is missing', async () => {
      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ member_number: '333307-00' });

      expect(res.status).toBe(400);
    });

    it('should return 400 when neither member_number nor last_name+dob provided', async () => {
      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ password: 'Member@123' });

      expect(res.status).toBe(400);
    });

    it('should return 401 for invalid credentials', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [memberRow] });

      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ member_number: '333307-00', password: 'wrongpassword' });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Invalid credentials');
    });

    it('should return 403 for inactive member', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [{ ...memberRow, is_active: false }] });

      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ member_number: '333307-00', password: 'Member@123' });

      expect(res.status).toBe(403);
      expect(res.body.message).toBe('Account is inactive');
    });

    it('should return 403 when password not yet set', async () => {
      mockQuery.mockResolvedValueOnce({
        rows: [{ ...memberRow, password_hash: null }],
      });

      const res = await request(app)
        .post('/api/auth/login/member')
        .send({ member_number: '333307-00', password: 'Member@123' });

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/Password not yet set/);
    });
  });

  // ── Change Password ────────────────────────────────────────────────────────

  describe('POST /api/auth/change-password', () => {
    const currentHash = bcrypt.hashSync('OldPass@123', 10);

    it('should change password successfully', async () => {
      const token = generateMemberToken();
      // SELECT from members table
      mockQuery.mockResolvedValueOnce({
        rows: [{ id: '11111111-1111-1111-1111-111111111111', password_hash: currentHash }],
      });
      // UPDATE password
      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({ current_password: 'OldPass@123', new_password: 'NewPass@123' });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Password changed successfully');
    });

    it('should return 400 when fields are missing', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({ current_password: 'OldPass@123' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/current_password and new_password are required/);
    });

    it('should return 401 for wrong current password', async () => {
      const token = generateMemberToken();
      mockQuery.mockResolvedValueOnce({
        rows: [{ id: '11111111-1111-1111-1111-111111111111', password_hash: currentHash }],
      });

      const res = await request(app)
        .post('/api/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({ current_password: 'WrongPass', new_password: 'NewPass@123' });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Current password is incorrect');
    });

    it('should return 400 for too-short new password', async () => {
      const token = generateMemberToken();

      const res = await request(app)
        .post('/api/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({ current_password: 'OldPass@123', new_password: 'short' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/at least 8 characters/);
    });

    it('should return 401 when no token provided', async () => {
      const res = await request(app)
        .post('/api/auth/change-password')
        .send({ current_password: 'OldPass@123', new_password: 'NewPass@123' });

      expect(res.status).toBe(401);
    });
  });
});
