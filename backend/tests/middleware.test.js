const { generateMemberToken, generateAdminToken } = require('./setup');
const jwt = require('jsonwebtoken');

const { authenticate, requireAdmin, requireSuperAdmin } = require('../src/middleware/auth');

describe('Auth Middleware', () => {
  let req, res, next;

  beforeEach(() => {
    req = { headers: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    next = jest.fn();
  });

  // ── authenticate ──────────────────────────────────────────────────────────

  describe('authenticate', () => {
    it('should return 401 when no Authorization header', () => {
      authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ message: expect.stringContaining('No token') })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 401 when Authorization header does not start with Bearer', () => {
      req.headers.authorization = 'Basic sometoken';

      authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 401 for an invalid/expired token', () => {
      req.headers.authorization = 'Bearer invalidtoken123';

      authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ message: expect.stringContaining('Invalid token') })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should populate req.user and call next for valid member token', () => {
      const token = generateMemberToken();
      req.headers.authorization = `Bearer ${token}`;

      authenticate(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.user).toBeDefined();
      expect(req.user.type).toBe('member');
      expect(req.user.id).toBe('11111111-1111-1111-1111-111111111111');
      expect(req.user.member_number).toBe('333307-00');
    });

    it('should populate req.user and call next for valid admin token', () => {
      const token = generateAdminToken();
      req.headers.authorization = `Bearer ${token}`;

      authenticate(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.user).toBeDefined();
      expect(req.user.type).toBe('admin');
      expect(req.user.role).toBe('super_admin');
      expect(req.user.email).toBe('admin@test.com');
    });

    it('should return 401 for expired token', () => {
      const expiredToken = jwt.sign(
        { id: 'test', type: 'member' },
        process.env.JWT_SECRET,
        { expiresIn: '0s' }
      );
      req.headers.authorization = `Bearer ${expiredToken}`;

      authenticate(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });
  });

  // ── requireAdmin ──────────────────────────────────────────────────────────

  describe('requireAdmin', () => {
    it('should return 403 when user type is not admin', () => {
      req.user = { type: 'member', id: '11111111-1111-1111-1111-111111111111' };

      requireAdmin(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ message: expect.stringContaining('Admins only') })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 403 when req.user is undefined', () => {
      req.user = undefined;

      requireAdmin(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(next).not.toHaveBeenCalled();
    });

    it('should call next when user type is admin', () => {
      req.user = { type: 'admin', role: 'admin', id: '22222222-2222-2222-2222-222222222222' };

      requireAdmin(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });
  });

  // ── requireSuperAdmin ─────────────────────────────────────────────────────

  describe('requireSuperAdmin', () => {
    it('should return 403 when role is not super_admin', () => {
      req.user = { type: 'admin', role: 'admin', id: '22222222-2222-2222-2222-222222222222' };

      requireSuperAdmin(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ message: expect.stringContaining('Super admins only') })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 403 when req.user is undefined', () => {
      req.user = undefined;

      requireSuperAdmin(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(next).not.toHaveBeenCalled();
    });

    it('should call next when role is super_admin', () => {
      req.user = { type: 'admin', role: 'super_admin', id: '22222222-2222-2222-2222-222222222222' };

      requireSuperAdmin(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });
  });
});
