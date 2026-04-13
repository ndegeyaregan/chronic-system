const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const pool = require('../config/db');
const notificationService = require('../services/notificationService');

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
    return res.json({
      token,
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
    return res.json({
      token,
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

    // Generate a temporary password: 8-char alphanumeric
    const tempPassword = uuidv4().replace(/-/g, '').slice(0, 10);
    const hash = await bcrypt.hash(tempPassword, 12);

    await pool.query(
      'UPDATE members SET password_hash = $1, is_password_set = FALSE, updated_at = NOW() WHERE id = $2',
      [hash, member_id]
    );

    await notificationService.sendToMember(member_id, {
      type: 'password_reset',
      title: 'Password Reset',
      message: `Your password has been reset. Your temporary password is: ${tempPassword}. Please log in and change it immediately.`,
      channel: ['sms', 'email'],
    });

    return res.json({ message: 'Password reset and sent to member' });
  } catch (err) {
    console.error('resetMemberPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// ── Forgot Password / OTP flow ────────────────────────────────────────────

const requestPasswordReset = async (req, res) => {
  try {
    const { member_number, phone, email } = req.body;

    if (!member_number) {
      return res.status(400).json({ message: 'Member number is required' });
    }
    if (!phone && !email) {
      return res.status(400).json({ message: 'Phone number or email is required' });
    }

    const result = await pool.query(
      'SELECT * FROM members WHERE member_number = $1',
      [member_number]
    );
    const member = result.rows[0];

    // Generic response to avoid member enumeration
    const genericOk = { message: 'If your details match our records, you will receive an OTP shortly.' };

    if (!member || !member.is_active) return res.json(genericOk);

    // Verify the supplied contact matches what is on record
    let contactType = null;
    let contactValue = null;

    if (phone) {
      const normalize = (p) => (p || '').replace(/[\s\-\(\)]/g, '').replace(/^\+27/, '0');
      if (normalize(phone) === normalize(member.phone)) {
        contactType = 'sms';
        contactValue = member.phone;
      }
    }

    if (!contactType && email) {
      if (email.toLowerCase() === (member.email || '').toLowerCase()) {
        contactType = 'email';
        contactValue = member.email;
      }
    }

    if (!contactType) return res.json(genericOk);

    // Generate 6-digit OTP, expire in 10 minutes
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await pool.query('DELETE FROM password_reset_otps WHERE member_id = $1', [member.id]);
    await pool.query(
      'INSERT INTO password_reset_otps (member_id, otp, expires_at) VALUES ($1, $2, $3)',
      [member.id, otp, expiresAt]
    );

    const text = `Your Sanlam Chronic Care password reset OTP is: ${otp}. It expires in 10 minutes. Do not share it with anyone.`;

    if (contactType === 'sms') {
      await notificationService.sendSMS(contactValue, text);
    } else {
      await notificationService.sendEmail(
        contactValue,
        'Password Reset OTP – Sanlam Chronic Care',
        `<p>Hello ${member.first_name},</p>
         <p>Your OTP for resetting your Sanlam Chronic Care password is:</p>
         <h2 style="letter-spacing:8px">${otp}</h2>
         <p>This OTP expires in <strong>10 minutes</strong>. Do not share it with anyone.</p>`
      );
    }

    return res.json({ message: `OTP sent to your ${contactType === 'sms' ? 'phone' : 'email'}.` });
  } catch (err) {
    console.error('requestPasswordReset error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const verifyOtp = async (req, res) => {
  try {
    const { member_number, otp } = req.body;

    if (!member_number || !otp) {
      return res.status(400).json({ message: 'Member number and OTP are required' });
    }

    const memberResult = await pool.query(
      'SELECT * FROM members WHERE member_number = $1',
      [member_number]
    );
    const member = memberResult.rows[0];
    if (!member) {
      return res.status(401).json({ message: 'Invalid OTP or member number' });
    }

    const otpResult = await pool.query(
      `SELECT * FROM password_reset_otps
       WHERE member_id = $1 AND is_used = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [member.id]
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
      { id: member.id, member_number: member.member_number, type: 'password_reset' },
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
    await pool.query(
      'UPDATE members SET password_hash = $1, is_password_set = TRUE, updated_at = NOW() WHERE id = $2',
      [hash, payload.id]
    );

    return res.json({ message: 'Password reset successfully. You can now log in.' });
  } catch (err) {
    console.error('resetPassword error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  memberLogin, adminLogin, createPassword, changePassword, resetMemberPassword,
  requestPasswordReset, verifyOtp, resetPassword,
};
