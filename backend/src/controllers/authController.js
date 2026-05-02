const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const pool = require('../config/db');
const notificationService = require('../services/notificationService');

const refreshSecret = () => process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET + '-refresh';

const signMemberToken = (member) =>
  jwt.sign(
    { id: member.id, member_number: member.member_number, type: 'member' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );

const signAdminToken = (admin) =>
  jwt.sign(
    { id: admin.id, email: admin.email, role: admin.role, type: 'admin' },
    process.env.JWT_SECRET,
    { expiresIn: '8h' }
  );

const signRefreshToken = (id, type) =>
  jwt.sign({ id, type }, refreshSecret(), { expiresIn: '30d' });

const memberLogin = async (req, res) => {
  try {
    const { member_number, last_name, date_of_birth, password } = req.body;

    if (!password) {
      return res.status(400).json({ message: 'Password is required' });
    }

    let member;

    if (member_number) {
      const result = await pool.query(
        'SELECT * FROM members WHERE member_number = $1',
        [member_number]
      );
      member = result.rows[0];
    } else if (last_name && date_of_birth) {
      const result = await pool.query(
        'SELECT * FROM members WHERE LOWER(last_name) = LOWER($1) AND date_of_birth = $2',
        [last_name, date_of_birth]
      );
      member = result.rows[0];
    } else {
      return res.status(400).json({ message: 'Provide member_number or last_name + date_of_birth' });
    }

    if (!member) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (!member.is_active) {
      return res.status(403).json({ message: 'Account is inactive' });
    }

    if (!member.password_hash) {
      return res.status(403).json({ message: 'Password not yet set. Please create your password first.' });
    }

    const valid = await bcrypt.compare(password, member.password_hash);
    if (!valid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = signMemberToken(member);
    const refreshToken = signRefreshToken(member.id, 'member');
    return res.json({
      token,
      refreshToken,
      member: {
        id: member.id,
        member_number: member.member_number,
        first_name: member.first_name,
        last_name: member.last_name,
        email: member.email,
        is_password_set: member.is_password_set,
      },
    });
  } catch (err) {
    console.error('memberLogin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const result = await pool.query('SELECT * FROM admins WHERE email = $1', [email]);
    const admin = result.rows[0];

    if (!admin) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (!admin.is_active) {
      return res.status(403).json({ message: 'Account is inactive' });
    }

    const valid = await bcrypt.compare(password, admin.password_hash);
    if (!valid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = signAdminToken(admin);
    const refreshToken = signRefreshToken(admin.id, 'admin');
    return res.json({
      token,
      refreshToken,
      admin: {
        id: admin.id,
        email: admin.email,
        first_name: admin.first_name || admin.name?.split(' ')?.[0] || '',
        last_name: admin.last_name || admin.name?.split(' ')?.slice(1)?.join(' ') || '',
        name: admin.name || [admin.first_name, admin.last_name].filter(Boolean).join(' '),
        role: admin.role,
      },
    });
  } catch (err) {
    console.error('adminLogin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createPassword = async (req, res) => {
  try {
    const { password, confirm_password } = req.body;
    const memberId = req.user.id;

    if (!password || !confirm_password) {
      return res.status(400).json({ message: 'password and confirm_password are required' });
    }
    if (password !== confirm_password) {
      return res.status(400).json({ message: 'Passwords do not match' });
    }
    if (password.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }

    const result = await pool.query('SELECT * FROM members WHERE id = $1', [memberId]);
    const member = result.rows[0];

    if (!member) {
      return res.status(404).json({ message: 'Member not found' });
    }
    if (member.is_password_set) {
      return res.status(409).json({ message: 'Password already set. Use change-password instead.' });
    }

    const hash = await bcrypt.hash(password, 12);
    await pool.query(
      'UPDATE members SET password_hash = $1, is_password_set = TRUE, updated_at = NOW() WHERE id = $2',
      [hash, memberId]
    );

    return res.json({ message: 'Password created successfully' });
  } catch (err) {
    console.error('createPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const changePassword = async (req, res) => {
  try {
    const { current_password, new_password } = req.body;
    const userId = req.user.id;
    const userType = req.user.type;

    if (!current_password || !new_password) {
      return res.status(400).json({ message: 'current_password and new_password are required' });
    }
    if (new_password.length < 8) {
      return res.status(400).json({ message: 'New password must be at least 8 characters' });
    }

    const table = userType === 'admin' ? 'admins' : 'members';
    const result = await pool.query(`SELECT * FROM ${table} WHERE id = $1`, [userId]);
    const user = result.rows[0];

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const valid = await bcrypt.compare(current_password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ message: 'Current password is incorrect' });
    }

    const hash = await bcrypt.hash(new_password, 12);
    await pool.query(
      `UPDATE ${table} SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
      [hash, userId]
    );

    return res.json({ message: 'Password changed successfully' });
  } catch (err) {
    console.error('changePassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const resetMemberPassword = async (req, res) => {
  try {
    const { member_id } = req.body;
    if (!member_id) {
      return res.status(400).json({ message: 'member_id is required' });
    }

    const result = await pool.query('SELECT * FROM members WHERE id = $1', [member_id]);
    const member = result.rows[0];
    if (!member) {
      return res.status(404).json({ message: 'Member not found' });
    }

    // Generate a 6-digit OTP instead of plaintext temp password
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // Clear any existing OTPs and store the new one
    await pool.query('DELETE FROM password_reset_otps WHERE member_id = $1', [member.id]);
    await pool.query(
      'INSERT INTO password_reset_otps (member_id, otp, expires_at) VALUES ($1, $2, $3)',
      [member.id, otp, expiresAt]
    );

    // Mark password as not set so user must reset via OTP flow
    await pool.query(
      'UPDATE members SET is_password_set = FALSE, updated_at = NOW() WHERE id = $1',
      [member_id]
    );

    await notificationService.sendToMember(member_id, {
      type: 'password_reset',
      title: 'Password Reset',
      message: `Your password has been reset. Use this OTP to set a new password: ${otp}. It expires in 10 minutes. Do not share it with anyone.`,
      channel: ['sms', 'email'],
    });

    return res.json({ message: 'Password reset OTP sent to member' });
  } catch (err) {
    console.error('resetMemberPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// ── Forgot Password / OTP flow ────────────────────────────────────────────

const requestPasswordReset = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }

    // Generic response to avoid user enumeration
    const genericOk = { message: 'If your email is in our records, you will receive an OTP shortly.' };

    // Check if user is admin (for portal)
    let adminResult = await pool.query(
      'SELECT id, name, email FROM admins WHERE LOWER(email) = LOWER($1)',
      [email]
    );
    const admin = adminResult.rows[0];

    if (!admin) return res.json(genericOk);

    // Generate 6-digit OTP, expire in 10 minutes
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // Create OTP for admin
    await pool.query('DELETE FROM password_reset_otps WHERE admin_id = $1', [admin.id]);
    await pool.query(
      'INSERT INTO password_reset_otps (admin_id, otp, expires_at) VALUES ($1, $2, $3)',
      [admin.id, otp, expiresAt]
    );

    await notificationService.sendEmail(
      email,
      'Password Reset OTP – Sanlam Chronic Care',
      `<p>Hello ${admin.name || admin.email},</p>
       <p>Your OTP for resetting your Sanlam Chronic Care password is:</p>
       <h2 style="letter-spacing:8px">${otp}</h2>
       <p>This OTP expires in <strong>10 minutes</strong>. Do not share it with anyone.</p>`
    );

    return res.json({ message: 'OTP sent to your email.' });
  } catch (err) {
    console.error('requestPasswordReset error:', err.message);
    return res.status(500).json({ message: 'Server error' });
  }
};

const verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ message: 'Email and OTP are required' });
    }

    // Check if user is admin
    let adminResult = await pool.query(
      'SELECT id, name, email FROM admins WHERE LOWER(email) = LOWER($1)',
      [email]
    );
    const admin = adminResult.rows[0];

    if (!admin) {
      return res.status(401).json({ message: 'Invalid OTP or email' });
    }

    const otpResult = await pool.query(
      `SELECT * FROM password_reset_otps WHERE admin_id = $1 AND is_used = FALSE AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1`,
      [admin.id]
    );
    const otpRecord = otpResult.rows[0];

    if (!otpRecord || otpRecord.otp !== otp) {
      return res.status(401).json({ message: 'Invalid or expired OTP' });
    }

    await pool.query(
      'UPDATE password_reset_otps SET is_used = TRUE WHERE id = $1',
      [otpRecord.id]
    );

    // Short-lived reset token (15 minutes)
    const resetToken = jwt.sign(
      { id: admin.id, type: 'password_reset', userType: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '15m' }
    );

    return res.json({ message: 'OTP verified', reset_token: resetToken });
  } catch (err) {
    console.error('verifyOtp error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const resetPassword = async (req, res) => {
  try {
    const { reset_token, new_password, confirm_password } = req.body;

    if (!reset_token || !new_password || !confirm_password) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    if (new_password !== confirm_password) {
      return res.status(400).json({ message: 'Passwords do not match' });
    }
    if (new_password.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }

    let payload;
    try {
      payload = jwt.verify(reset_token, process.env.JWT_SECRET);
    } catch {
      return res.status(401).json({ message: 'Reset session has expired. Please request a new OTP.' });
    }

    if (payload.type !== 'password_reset') {
      return res.status(401).json({ message: 'Invalid reset token' });
    }

    const hash = await bcrypt.hash(new_password, 12);
    
    // Update admin password
    await pool.query(
      'UPDATE admins SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [hash, payload.id]
    );

    return res.json({ message: 'Password reset successfully. You can now log in.' });
  } catch (err) {
    console.error('resetPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const refreshTokenHandler = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token required' });
    }

    const decoded = jwt.verify(refreshToken, refreshSecret());

    let user, newPayload;

    if (decoded.type === 'admin') {
      const result = await pool.query(
        'SELECT id, email, first_name, last_name, role, is_active FROM admins WHERE id = $1',
        [decoded.id]
      );
      if (result.rows.length === 0 || !result.rows[0].is_active) {
        return res.status(401).json({ error: 'Account not found or inactive' });
      }
      user = result.rows[0];
      newPayload = { id: user.id, email: user.email, role: user.role, type: 'admin' };
    } else {
      const result = await pool.query(
        'SELECT id, member_number, first_name, last_name, is_active FROM members WHERE id = $1',
        [decoded.id]
      );
      if (result.rows.length === 0 || !result.rows[0].is_active) {
        return res.status(401).json({ error: 'Account not found or inactive' });
      }
      user = result.rows[0];
      newPayload = { id: user.id, member_number: user.member_number, type: 'member' };
    }

    const expiresIn = decoded.type === 'admin' ? '8h' : '7d';
    const newToken = jwt.sign(newPayload, process.env.JWT_SECRET, { expiresIn });
    const newRefreshToken = signRefreshToken(user.id, decoded.type);

    res.json({ token: newToken, refreshToken: newRefreshToken });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Refresh token expired, please login again' });
    }
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    console.error('Refresh token error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

const maskEmail = (e) => {
  if (!e || !e.includes('@')) return e || '';
  const [u, d] = e.split('@');
  const head = u.length <= 2 ? u[0] || '' : u.slice(0, 2);
  return `${head}${'*'.repeat(Math.max(1, u.length - head.length))}@${d}`;
};

const maskPhone = (p) => {
  if (!p) return '';
  const digits = p.replace(/\D/g, '');
  if (digits.length < 4) return p;
  return `${p.slice(0, p.length - digits.length + 2)}${'*'.repeat(digits.length - 4)}${digits.slice(-2)}`;
};

/**
 * POST /api/auth/sanlam/forgot-password/lookup
 * Body: { member_number }
 * Returns the masked email/phone the system has on file so the user can
 * choose where to receive the OTP.
 */
const sanlamForgotPasswordLookup = async (req, res) => {
  try {
    const memberNumber = (req.body?.member_number || '').toString().trim();
    if (!memberNumber) {
      return res.status(400).json({ message: 'member_number is required' });
    }
    const lookup = await pool.query(
      'SELECT email, phone FROM members WHERE member_number = $1',
      [memberNumber]
    );
    const row = lookup.rows[0];
    if (!row) {
      return res.status(404).json({
        message: 'No account found for that member number. Please register first.',
      });
    }
    const email = (row.email || '').trim();
    const phone = (row.phone || '').trim();
    if (!email && !phone) {
      return res.status(409).json({
        message: 'No contact details on file. Please log in once or contact support.',
      });
    }
    return res.json({
      status: 'OK',
      hasEmail: !!email,
      hasPhone: !!phone,
      maskedEmail: email ? maskEmail(email) : null,
      maskedPhone: phone ? maskPhone(phone) : null,
    });
  } catch (err) {
    console.error('sanlamForgotPasswordLookup error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

/**
 * POST /api/auth/sanlam/forgot-password
 * Body: { member_number, send_mode? }   (send_mode: 1=Email, 2=SMS)
 *
 * If send_mode is provided, only that channel is tried (so the user's
 * choice is honoured). Otherwise we try email first, then SMS.
 */
const sanlamForgotPassword = async (req, res) => {
  try {
    const memberNumber = (req.body?.member_number || '').toString().trim();
    const requestedMode = parseInt(req.body?.send_mode, 10);
    if (!memberNumber) {
      return res.status(400).json({ message: 'member_number is required' });
    }

    const lookup = await pool.query(
      'SELECT email, phone FROM members WHERE member_number = $1',
      [memberNumber]
    );
    const row = lookup.rows[0];
    if (!row) {
      return res.status(404).json({
        message: 'No account found for that member number. Please register first.',
      });
    }

    const email = (row.email || '').trim();
    const phone = (row.phone || '').trim();
    if (!email && !phone) {
      return res.status(409).json({
        message: 'No contact details on file. Please contact support.',
      });
    }

    // Build attempts honouring requested mode if provided.
    const attempts = [];
    if (requestedMode === 1) {
      if (!email) return res.status(400).json({ message: 'No email on file.' });
      attempts.push({ mode: 1, key: 'Email', value: email });
    } else if (requestedMode === 2) {
      if (!phone) return res.status(400).json({ message: 'No phone on file.' });
      attempts.push({ mode: 2, key: 'MobileNo', value: phone });
    } else {
      if (email) attempts.push({ mode: 1, key: 'Email', value: email });
      if (phone) attempts.push({ mode: 2, key: 'MobileNo', value: phone });
    }

    let lastErr = '';
    for (const a of attempts) {
      try {
        const sanlamRes = await axios.post(
          'https://ehosccs.net/SanlamMemberApi/api/member/SendOTP',
          { MemberNo: memberNumber, SendMode: a.mode, [a.key]: a.value },
          { headers: { 'Content-Type': 'application/json' }, timeout: 20000 }
        );
        const status = (sanlamRes.data?.status || '').toString();
        const desc = (sanlamRes.data?.description || '').toString();
        if (status === 'OK') {
          return res.json({
            status: 'OK',
            message: a.mode === 1
              ? `OTP sent to your email ${maskEmail(email)}`
              : `OTP sent to your phone ${maskPhone(phone)}`,
            sendMode: a.mode,
            sentTo: a.mode === 1 ? maskEmail(email) : maskPhone(phone),
          });
        }
        lastErr = desc || lastErr;
      } catch (err) {
        console.error('Sanlam SendOTP error:', err?.response?.data || err.message);
        lastErr = err?.response?.data?.description || err.message || lastErr;
      }
    }

    return res.status(400).json({
      message: lastErr ||
          'Could not send OTP. Please update your contact info and try again.',
    });
  } catch (err) {
    console.error('sanlamForgotPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const sanlamLogin = async (req, res) => {
  try {
    const { member_number, sanlam_token } = req.body;
    if (!member_number || !sanlam_token) {
      return res.status(400).json({ message: 'member_number and sanlam_token are required' });
    }

    let planData = {};
    try {
      const sanlamRes = await axios.post(
        'https://ehosccs.net/SanlamMemberApi/api/member/GetMemberPlanBenefit',
        { MemberNo: member_number },
        { headers: { Authorization: `Bearer ${sanlam_token}` }, timeout: 15000 }
      );
      if (sanlamRes.status !== 200 || (sanlamRes.data?.status ?? '').toString() !== 'OK') {
        return res.status(401).json({ message: 'Invalid or expired Sanlam token' });
      }
      planData = sanlamRes.data?.data ?? {};
    } catch (err) {
      if (err.response) {
        return res.status(401).json({ message: 'Sanlam token verification failed' });
      }
      // Network error reaching Sanlam — fail open would be a security risk; propagate
      throw err;
    }

    let memberRow;
    const lookup = await pool.query(
      'SELECT * FROM members WHERE member_number = $1',
      [member_number]
    );
    memberRow = lookup.rows[0];

    if (!memberRow) {
      const memberName = (planData.memberName || planData.MemberName || '').trim();
      const nameParts = memberName.split(/\s+/);
      const firstName = nameParts[0] || member_number;
      const lastName = nameParts.slice(1).join(' ') || 'Unknown';
      const email = planData.email || planData.Email || null;
      const phone = planData.mobile || planData.Mobile || planData.phone || null;
      const dob =
        planData.dateOfBirth || planData.DateOfBirth || planData.dob || '1900-01-01';

      const insert = await pool.query(
        `INSERT INTO members
           (member_number, first_name, last_name, date_of_birth, email, phone,
            is_active, is_password_set, password_hash)
         VALUES ($1, $2, $3, $4, $5, $6, TRUE, FALSE, '')
         RETURNING *`,
        [member_number, firstName, lastName, dob, email, phone]
      );
      memberRow = insert.rows[0];
    }

    if (!memberRow.is_active) {
      return res.status(403).json({ message: 'Account is inactive' });
    }

    // Refresh email/phone AND name from Sanlam's GetMemberContactInfo so the
    // forgot-password flow can find the member with their current contact
    // and the UI shows the real name (not "Unknown" / member number).
    try {
      const contactRes = await axios.post(
        'https://ehosccs.net/SanlamMemberApi/api/member/GetMemberContactInfo',
        { MemberNo: member_number },
        { headers: { Authorization: `Bearer ${sanlam_token}` }, timeout: 10000 }
      );
      const cd = contactRes.data?.data;
      if ((contactRes.data?.status || '') === 'OK' && cd) {
        const freshEmail = (cd.email || cd.Email || '').toString().trim() || null;
        const freshPhone = (cd.mobile || cd.Mobile || cd.phone || '').toString().trim() || null;
        const memberName = (cd.memberName || cd.MemberName || '').toString().trim();
        let freshFirst = null;
        let freshLast = null;
        if (memberName) {
          const parts = memberName.split(/\s+/);
          freshFirst = parts[0] || null;
          freshLast = parts.length > 1 ? parts.slice(1).join(' ') : null;
        }
        // Detect bogus existing names (the old insert path used member_number /
        // "Unknown" as fallbacks). Overwrite when we now have something real.
        const looksBogus = (memberRow.first_name || '') === member_number
          || (memberRow.last_name || '').toLowerCase() === 'unknown'
          || (memberRow.first_name || '').trim() === ''
          || (memberRow.last_name || '').trim() === '';

        await pool.query(
          `UPDATE members SET
             email      = COALESCE($1, email),
             phone      = COALESCE($2, phone),
             first_name = CASE WHEN $4::boolean THEN COALESCE($3, first_name) ELSE first_name END,
             last_name  = CASE WHEN $4::boolean THEN COALESCE($5, last_name)  ELSE last_name  END,
             updated_at = NOW()
           WHERE id = $6`,
          [freshEmail, freshPhone, freshFirst, looksBogus, freshLast, memberRow.id]
        );
        memberRow.email = freshEmail || memberRow.email;
        memberRow.phone = freshPhone || memberRow.phone;
        if (looksBogus && freshFirst) memberRow.first_name = freshFirst;
        if (looksBogus && freshLast)  memberRow.last_name  = freshLast;
      }
    } catch (e) {
      // Non-fatal — keep going with whatever we have.
      console.warn('GetMemberContactInfo refresh skipped:', e.message);
    }

    const token = signMemberToken(memberRow);
    const refreshToken = signRefreshToken(memberRow.id, 'member');
    return res.json({
      token,
      refreshToken,
      member: {
        id: memberRow.id,
        member_number: memberRow.member_number,
        first_name: memberRow.first_name,
        last_name: memberRow.last_name,
        email: memberRow.email,
        is_password_set: memberRow.is_password_set,
      },
    });
  } catch (err) {
    console.error('sanlamLogin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  memberLogin, adminLogin, createPassword, changePassword, resetMemberPassword,
  requestPasswordReset, verifyOtp, resetPassword, refreshToken: refreshTokenHandler,
  sanlamLogin, sanlamForgotPassword, sanlamForgotPasswordLookup,
};
