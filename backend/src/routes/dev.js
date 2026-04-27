/**
 * DEV / TEST routes — use these to manually trigger cron jobs and test notifications.
 * These endpoints are protected by requireAdmin so they can't be called by patients.
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { authenticate, requireAdmin } = require('../middleware/auth');
const { sendRefillReminders } = require('../services/refillReminderService');

/**
 * POST /api/dev/test-refill-reminders
 *
 * Body (optional):
 *   { "days": 7 }   — simulate a 7-day reminder (default)
 *   { "days": 2 }   — simulate a 2-day reminder (also auto-creates auth request)
 *   { "memberId": "<uuid>" } — limit to a specific member (default: all)
 *
 * What it does:
 *   1. Finds the first active medication for the member (or all members)
 *   2. Sets next_refill_date to today + days
 *   3. Resets the matching sent flag to false
 *   4. Calls sendRefillReminders() — which fires push/SMS/email and auto-auth if 2-day
 *   5. Returns a summary of what was sent
 */
router.post('/test-refill-reminders', authenticate, requireAdmin, async (req, res) => {
  try {
    const days = parseInt(req.body.days) || 7;
    if (![7, 2].includes(days)) {
      return res.status(400).json({ message: 'days must be 7 or 2' });
    }

    const memberId = req.body.memberId || null;

    const targetDate = new Date();
    targetDate.setDate(targetDate.getDate() + days);
    const fmt = (d) => d.toISOString().split('T')[0];

    // Find active medications to patch
    const medQuery = memberId
      ? `SELECT id FROM member_medications WHERE member_id = $1 AND end_date IS NULL LIMIT 5`
      : `SELECT id FROM member_medications WHERE end_date IS NULL LIMIT 10`;
    const medParams = memberId ? [memberId] : [];
    const meds = await pool.query(medQuery, medParams);

    if (meds.rows.length === 0) {
      return res.status(404).json({ message: 'No active medications found to test with.' });
    }

    const ids = meds.rows.map((r) => r.id);
    const sentFlag = days === 7 ? 'refill_reminder_7d_sent' : 'refill_reminder_2d_sent';

    // Update refill date + reset sent flag
    await pool.query(
      `UPDATE member_medications
       SET next_refill_date = $1, ${sentFlag} = false
       WHERE id = ANY($2::uuid[])`,
      [fmt(targetDate), ids]
    );

    console.log(`[DEV] Set next_refill_date=${fmt(targetDate)} for ${ids.length} medications. Triggering sendRefillReminders()...`);

    // Fire the cron function now
    const results = await sendRefillReminders();

    res.json({
      message: `Test triggered — ${days}-day refill reminder fired`,
      medicationsPatched: ids.length,
      remindersSent: results,
    });
  } catch (err) {
    console.error('[DEV] test-refill-reminders error:', err);
    res.status(500).json({ message: err.message });
  }
});

/**
 * POST /api/dev/reset-refill-flags
 * Resets both sent flags for all member medications so you can re-test.
 */
router.post('/reset-refill-flags', authenticate, requireAdmin, async (req, res) => {
  try {
    const memberId = req.body.memberId || null;
    const q = memberId
      ? `UPDATE member_medications SET refill_reminder_7d_sent = false, refill_reminder_2d_sent = false WHERE member_id = $1`
      : `UPDATE member_medications SET refill_reminder_7d_sent = false, refill_reminder_2d_sent = false`;
    const p = memberId ? [memberId] : [];
    const r = await pool.query(q, p);
    res.json({ message: `Reset ${r.rowCount} medication reminder flags.` });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
