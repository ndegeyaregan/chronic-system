const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const pool = require('../config/db');
const { sendMail } = require('../utils/mailer');
const { createAuthRequest, listMyAuthRequests, cancelAuthRequest, listAllAuthRequestsAdmin, reviewAuthRequest } = require('../controllers/authorizationController');

router.post('/', authenticate, createAuthRequest);
router.get('/mine', authenticate, listMyAuthRequests);
router.patch('/:id/cancel', authenticate, cancelAuthRequest);

// Admin routes
router.get('/admin/stats', authenticate, requireAdmin, async (req, res) => {
  try {
    const pool = require('../config/db');
    const result = await pool.query(`
      SELECT
        COUNT(*)::int                                                        AS total,
        COUNT(*) FILTER (WHERE status = 'pending')::int                     AS pending,
        COUNT(*) FILTER (WHERE status = 'approved')::int                    AS approved,
        COUNT(*) FILTER (WHERE status = 'rejected')::int                    AS rejected,
        COUNT(*) FILTER (WHERE status = 'cancelled')::int                   AS cancelled,
        COUNT(*) FILTER (WHERE status = 'approved'
          AND updated_at::date = CURRENT_DATE)::int                         AS approved_today,
        COUNT(*) FILTER (WHERE status = 'pending'
          AND scheduled_date < CURRENT_DATE)::int                           AS overdue
      FROM authorization_requests
    `);
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('authStats error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});
router.get('/admin/all', authenticate, requireAdmin, listAllAuthRequestsAdmin);
router.patch('/admin/:id/review', authenticate, requireAdmin, reviewAuthRequest);

router.patch('/admin/:id/review', authenticate, requireAdmin, reviewAuthRequest);

// Get facility email by provider_id + provider_type (for email pre-fill)
router.get('/admin/:id/facility-email', authenticate, requireAdmin, async (req, res) => {
  try {
    const authResult = await pool.query(
      'SELECT provider_id, provider_type, provider_name FROM authorization_requests WHERE id = $1',
      [req.params.id]
    );
    if (!authResult.rows.length) return res.status(404).json({ email: null });
    const { provider_id, provider_type, provider_name } = authResult.rows[0];
    if (!provider_id) return res.json({ email: null, name: provider_name });
    const table = provider_type === 'pharmacy' ? 'pharmacies' : 'hospitals';
    const fac = await pool.query(
      `SELECT email, contact_person FROM ${table} WHERE id = $1`, [provider_id]
    );
    const row = fac.rows[0] || {};
    return res.json({ email: row.email || null, contact: row.contact_person || null, name: provider_name });
  } catch (err) {
    console.error('facilityEmail error:', err);
    return res.status(500).json({ email: null });
  }
});

// Send authorization email to provider
router.post('/admin/:id/send-auth-email',authenticate, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { to, cc, subject, body, reply_to } = req.body;

    if (!to || !subject || !body) {
      return res.status(400).json({ message: 'to, subject and body are required' });
    }

    // Verify the authorization exists and is approved
    const authResult = await pool.query(
      `SELECT ar.*,
         m.first_name, m.last_name, m.member_number
       FROM authorization_requests ar
       JOIN members m ON m.id = ar.member_id
       WHERE ar.id = $1`, [id]
    );
    if (!authResult.rows.length) return res.status(404).json({ message: 'Authorization not found' });
    if (authResult.rows[0].status !== 'approved') {
      return res.status(409).json({ message: 'Only approved authorizations can have emails sent' });
    }

    // Send the email
    const htmlBody = body
      .replace(/\n/g, '<br>')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');

    await sendMail({
      to,
      cc:      cc      || undefined,
      replyTo: reply_to || undefined,
      subject,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 680px; margin: 0 auto; color: #1e293b;">
          <div style="background: #1d4ed8; padding: 20px 28px;">
            <h2 style="color: #fff; margin: 0; font-size: 18px;">Sanlam Chronic Care Programme</h2>
            <p style="color: #bfdbfe; margin: 4px 0 0; font-size: 13px;">Authorization Letter</p>
          </div>
          <div style="padding: 28px; background: #fff; border: 1px solid #e2e8f0; border-top: none;">
            ${htmlBody}
          </div>
          <div style="padding: 14px 28px; background: #f8fafc; border: 1px solid #e2e8f0; border-top: none;
            font-size: 12px; color: #94a3b8; text-align: center;">
            This is an official communication from Sanlam Chronic Care. Ref: ${id.split('-')[0].toUpperCase()}
          </div>
        </div>`,
    });

    // Mark email sent
    await pool.query(
      'UPDATE authorization_requests SET auth_email_sent_at = NOW() WHERE id = $1',
      [id]
    );

    return res.json({ message: 'Authorization email sent successfully' });
  } catch (err) {
    console.error('sendAuthEmail error:', err);
    return res.status(500).json({ message: err.message || 'Failed to send email' });
  }
});

module.exports = router;

