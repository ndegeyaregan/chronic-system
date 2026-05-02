const express = require('express');
const pool = require('../config/db');
const { authenticate } = require('../middleware/auth');
const { sendToMember } = require('../services/notificationService');

const router = express.Router();

// GET /api/preauths/me — returns pre-auth events for the authenticated member.
// Matches by member_no against the member's member_number column.
router.get('/me', authenticate, async (req, res) => {
  try {
    // Fetch the member_number for the authenticated user
    const memberRes = await pool.query(
      'SELECT member_number FROM members WHERE id = $1',
      [req.user.id]
    );
    if (!memberRes.rows.length) {
      return res.status(404).json({ message: 'Member not found' });
    }
    const memberNo = memberRes.rows[0].member_number;

    // Gracefully return [] if the table doesn't exist yet
    let rows = [];
    try {
      const result = await pool.query(
        `SELECT id, member_no, request_no, status, approved_amount,
                decided_at, provider_name, condition, created_at
         FROM preauth_events
         WHERE member_no = $1
         ORDER BY created_at DESC`,
        [memberNo]
      );
      rows = result.rows;
    } catch (tableErr) {
      if (tableErr.code === '42P01') {
        // Table does not exist yet — return empty array
        return res.json([]);
      }
      throw tableErr;
    }

    return res.json(rows);
  } catch (err) {
    console.error('GET /preauths/me error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/preauths/sanlam-webhook — receives pre-auth approval payloads
// from Sanlam. Verifies X-Sanlam-Webhook-Secret if SANLAM_PREAUTH_WEBHOOK_SECRET is set.
router.post('/sanlam-webhook', async (req, res) => {
  // Webhook secret verification (optional — skipped in dev if env not set)
  const secret = process.env.SANLAM_PREAUTH_WEBHOOK_SECRET;
  if (secret) {
    const provided = req.headers['x-sanlam-webhook-secret'];
    if (provided !== secret) {
      return res.status(401).json({ message: 'Invalid webhook secret' });
    }
  }

  const {
    memberNo,
    requestNo,
    status,
    approvedAmount,
    decidedAt,
    providerName,
    condition,
  } = req.body;

  if (!memberNo || !requestNo || !status) {
    return res.status(400).json({
      message: 'memberNo, requestNo, and status are required',
    });
  }

  try {
    // Insert the preauth event
    const insertRes = await pool.query(
      `INSERT INTO preauth_events
         (member_no, request_no, status, approved_amount, decided_at, provider_name, condition)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id`,
      [
        memberNo,
        requestNo,
        status,
        approvedAmount ?? null,
        decidedAt ? new Date(decidedAt) : null,
        providerName ?? null,
        condition ?? null,
      ]
    );
    const eventId = insertRes.rows[0].id;

    // Look up the member by member_no to send a push notification
    const memberRes = await pool.query(
      'SELECT id FROM members WHERE member_number = $1',
      [memberNo]
    );
    if (memberRes.rows.length) {
      const memberId = memberRes.rows[0].id;
      const title = 'Pre-Authorisation Update';
      const conditionLabel = condition ? ` for ${condition}` : '';
      const message =
        status.toLowerCase() === 'approved'
          ? `Your pre-authorisation${conditionLabel} has been approved.`
          : status.toLowerCase() === 'rejected'
          ? `Your pre-authorisation${conditionLabel} has been rejected.`
          : `Your pre-authorisation${conditionLabel} status: ${status}.`;

      // Fire-and-forget — do not fail the webhook if notification fails
      sendToMember(memberId, {
        type: 'preauth',
        title,
        message,
        channel: ['push'],
      }).catch((err) => console.warn('preauth notification failed:', err.message));
    }

    return res.status(201).json({ id: eventId, message: 'Recorded' });
  } catch (err) {
    console.error('POST /preauths/sanlam-webhook error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
