const pool = require('../config/db');
const notificationService = require('./notificationService');

async function sendRefillReminders() {
  const today = new Date();

  const in7 = new Date(today); in7.setDate(today.getDate() + 7);
  const in2 = new Date(today); in2.setDate(today.getDate() + 2);

  const fmt = (d) => d.toISOString().split('T')[0];
  const results = { sevenDay: 0, twoDay: 0, autoAuth: 0 };

  // ── 7-day reminders ─────────────────────────────────────────────────────────
  const seven = await pool.query(
    `SELECT mm.id, mm.member_id, mm.next_refill_date,
            med.name AS med_name, p.name AS pharmacy_name,
            m.first_name, m.email, m.phone, m.fcm_token
     FROM member_medications mm
     JOIN medications med ON med.id = mm.medication_id
     JOIN members m ON m.id = mm.member_id
     LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
     WHERE mm.next_refill_date = $1
       AND mm.refill_reminder_7d_sent = false
       AND mm.end_date IS NULL`,
    [fmt(in7)]
  );

  for (const row of seven.rows) {
    const msg = `Hi ${row.first_name}, your ${row.med_name} refill is due in 7 days${row.pharmacy_name ? ` at ${row.pharmacy_name}` : ''}. Consider requesting Sanlam authorization now so it's approved before pickup.`;
    await notificationService.sendToMember(row.member_id, {
      type: 'refill_reminder',
      title: '💊 Medication Refill in 7 Days',
      message: msg,
      channel: ['push', 'sms', 'email'],
      fcmToken: row.fcm_token,
      phone: row.phone,
      email: row.email,
      firstName: row.first_name,
    });
    await pool.query(
      `UPDATE member_medications SET refill_reminder_7d_sent = true WHERE id = $1`,
      [row.id]
    );
    results.sevenDay++;
    console.log(`[RefillReminder] 7-day sent → ${row.first_name} (${row.med_name})`);
  }

  // ── 2-day reminders + auto-authorization ────────────────────────────────────
  const two = await pool.query(
    `SELECT mm.id, mm.member_id, mm.next_refill_date, mm.pharmacy_id,
            med.name AS med_name, p.name AS pharmacy_name,
            m.first_name, m.email, m.phone, m.fcm_token
     FROM member_medications mm
     JOIN medications med ON med.id = mm.medication_id
     JOIN members m ON m.id = mm.member_id
     LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
     WHERE mm.next_refill_date = $1
       AND mm.refill_reminder_2d_sent = false
       AND mm.end_date IS NULL`,
    [fmt(in2)]
  );

  for (const row of two.rows) {
    const msg = `Hi ${row.first_name}, your ${row.med_name} refill is due in 2 days${row.pharmacy_name ? ` at ${row.pharmacy_name}` : ''}. A Sanlam pre-authorization request has been automatically submitted on your behalf — just show up and collect!`;
    await notificationService.sendToMember(row.member_id, {
      type: 'refill_reminder',
      title: '⚠️ Medication Refill in 2 Days',
      message: msg,
      channel: ['push', 'sms', 'email'],
      fcmToken: row.fcm_token,
      phone: row.phone,
      email: row.email,
      firstName: row.first_name,
    });
    await pool.query(
      `UPDATE member_medications SET refill_reminder_2d_sent = true WHERE id = $1`,
      [row.id]
    );
    results.twoDay++;
    console.log(`[RefillReminder] 2-day sent → ${row.first_name} (${row.med_name})`);

    // Auto-create auth request if none already pending/approved
    const existing = await pool.query(
      `SELECT id FROM authorization_requests
       WHERE member_medication_id = $1
         AND status IN ('pending', 'approved')
       LIMIT 1`,
      [row.id]
    );
    if (existing.rows.length === 0) {
      const authResult = await pool.query(
        `INSERT INTO authorization_requests
           (member_id, request_type, provider_type, provider_id, provider_name,
            scheduled_date, notes, member_medication_id, status)
         VALUES ($1, 'medication_refill', 'pharmacy', $2, $3, $4,
                 'Auto-generated: refill due in 2 days', $5, 'pending')
         RETURNING id`,
        [
          row.member_id,
          row.pharmacy_id || null,
          row.pharmacy_name || null,
          row.next_refill_date,
          row.id,
        ]
      );
      pool.query(
        `INSERT INTO notifications (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
         VALUES ($1, 'auth_request', 'portal', $2, $3, 'sent', $4, 'authorization_request', NOW())`,
        [
          row.member_id,
          '📋 Auto-Authorization Request',
          `Auto-generated refill authorization for ${row.med_name}${row.pharmacy_name ? ` at ${row.pharmacy_name}` : ' (no pharmacy set — please assign one)'}. Refill due in 2 days.`,
          authResult.rows[0].id,
        ]
      ).catch(() => {});
      results.autoAuth++;
      console.log(`[RefillReminder] Auto-auth created → ${row.first_name} (${row.med_name})`);
    }
  }

  return results;
}

module.exports = { sendRefillReminders };
