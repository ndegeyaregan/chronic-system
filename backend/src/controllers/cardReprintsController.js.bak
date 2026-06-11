const pool = require('../config/db');
const {
  sendSMS,
  sendEmail,
  sendPush,
} = require('../services/notificationService');

const REPRINT_FEE_UGX = 20000;
const MEMBERSHIP_INBOX = 'membership@ug.sanlamallianz.com';

const ALLOWED_REASONS = new Set(['lost', 'damaged', 'stolen', 'other']);

const sanitize = (v) => (typeof v === 'string' ? v.trim() : '');

/**
 * POST /api/card-reprints
 * body: { targetMemberNo, targetMemberName, targetRelation,
 *         isForDependant, reason, reasonNotes, paymentMethod, paymentPhone }
 */
const create = async (req, res) => {
  try {
    const memberId = req.user.id;
    const targetMemberNo = sanitize(req.body.targetMemberNo);
    const targetMemberName = sanitize(req.body.targetMemberName);
    const targetRelation = sanitize(req.body.targetRelation) || 'Principal';
    const isForDependant = !!req.body.isForDependant;
    const reason = sanitize(req.body.reason).toLowerCase();
    const reasonNotes = sanitize(req.body.reasonNotes) || null;
    const paymentMethod = sanitize(req.body.paymentMethod) || 'mobile_money';
    const paymentPhone = sanitize(req.body.paymentPhone);

    if (!targetMemberNo || !targetMemberName) {
      return res
        .status(400)
        .json({ message: 'targetMemberNo and targetMemberName are required' });
    }
    if (!ALLOWED_REASONS.has(reason)) {
      return res.status(400).json({
        message:
          "reason must be one of: 'lost', 'damaged', 'stolen', 'other'",
      });
    }
    if (reason === 'other' && !reasonNotes) {
      return res
        .status(400)
        .json({ message: 'reasonNotes is required when reason is "other"' });
    }
    if (!paymentPhone || paymentPhone.replace(/\D/g, '').length < 9) {
      return res
        .status(400)
        .json({ message: 'A valid mobile money phone number is required' });
    }

    // Load member for notifications
    const memberRes = await pool.query(
      `SELECT id, member_number, first_name, last_name, email, phone, fcm_token
         FROM members WHERE id = $1`,
      [memberId]
    );
    if (!memberRes.rows.length) {
      return res.status(404).json({ message: 'Member not found' });
    }
    const member = memberRes.rows[0];
    const memberFullName = `${member.first_name || ''} ${member.last_name || ''}`.trim();

    // Insert request (status starts as pending_payment until MoMo confirmed)
    const insertRes = await pool.query(
      `INSERT INTO card_reprint_requests
         (member_id, target_member_no, target_member_name, target_relation,
          is_for_dependant, reason, reason_notes, payment_method,
          payment_phone, amount, currency, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'UGX','pending_payment')
       RETURNING id, created_at`,
      [
        memberId,
        targetMemberNo,
        targetMemberName,
        targetRelation,
        isForDependant,
        reason,
        reasonNotes,
        paymentMethod,
        paymentPhone,
        REPRINT_FEE_UGX,
      ]
    );
    const request = insertRes.rows[0];

    // Notification copy
    const friendlyReason =
      reason === 'other' && reasonNotes ? reasonNotes : reason;
    const targetLabel = isForDependant
      ? `${targetMemberName} (${targetRelation}, ${targetMemberNo})`
      : `${targetMemberName} (Principal, ${targetMemberNo})`;

    const smsBody =
      `Sanlam: Card reprint request received for ${targetLabel}. ` +
      `Amount UGX ${REPRINT_FEE_UGX.toLocaleString()} will be charged via Mobile Money on ${paymentPhone}. ` +
      `Ref: ${request.id.slice(0, 8).toUpperCase()}.`;

    const memberEmailHtml = `
      <p>Hi ${member.first_name || 'Member'},</p>
      <p>We have received your card reprint request. Details:</p>
      <ul>
        <li><strong>Card for:</strong> ${targetMemberName} (${targetRelation})</li>
        <li><strong>Member number:</strong> ${targetMemberNo}</li>
        <li><strong>Reason:</strong> ${friendlyReason}</li>
        <li><strong>Amount:</strong> UGX ${REPRINT_FEE_UGX.toLocaleString()}</li>
        <li><strong>Payment method:</strong> Mobile Money (${paymentPhone})</li>
        <li><strong>Reference:</strong> ${request.id}</li>
      </ul>
      <p>You will be contacted by our membership team once the payment has been confirmed and the new card is ready.</p>
      <p>Sanlam Allianz Health</p>
    `;

    const teamEmailHtml = `
      <h3>New Card Reprint Request</h3>
      <table cellpadding="6" style="border-collapse:collapse">
        <tr><td><strong>Reference</strong></td><td>${request.id}</td></tr>
        <tr><td><strong>Submitted by</strong></td><td>${memberFullName} (${member.member_number})</td></tr>
        <tr><td><strong>Card for</strong></td><td>${targetMemberName}</td></tr>
        <tr><td><strong>Member number</strong></td><td>${targetMemberNo}</td></tr>
        <tr><td><strong>Relation</strong></td><td>${targetRelation}</td></tr>
        <tr><td><strong>Reason</strong></td><td>${friendlyReason}</td></tr>
        <tr><td><strong>Amount</strong></td><td>UGX ${REPRINT_FEE_UGX.toLocaleString()}</td></tr>
        <tr><td><strong>Payment method</strong></td><td>Mobile Money</td></tr>
        <tr><td><strong>Payment phone</strong></td><td>${paymentPhone}</td></tr>
        <tr><td><strong>Member email</strong></td><td>${member.email || '-'}</td></tr>
        <tr><td><strong>Member phone</strong></td><td>${member.phone || '-'}</td></tr>
        <tr><td><strong>Submitted at</strong></td><td>${request.created_at}</td></tr>
      </table>
    `;

    // Fire notifications in parallel (don't fail the request if any one fails)
    const tasks = [];
    const log = async (channel, title, message, fn) => {
      let status = 'failed';
      try {
        await fn();
        status = 'sent';
      } catch (e) {
        console.error(`reprint notify ${channel} failed:`, e.message);
      }
      try {
        await pool.query(
          `INSERT INTO notifications (member_id, type, channel, title, message, status, sent_at)
           VALUES ($1,$2,$3,$4,$5,$6, NOW())`,
          [memberId, 'card_reprint', channel, title, message, status]
        );
      } catch (e) {
        console.error('notification log insert failed:', e.message);
      }
    };

    if (member.phone) {
      tasks.push(
        log('sms', 'Card Reprint Request', smsBody, () =>
          sendSMS(member.phone, smsBody)
        )
      );
    }
    if (member.email) {
      tasks.push(
        log(
          'email',
          'Card Reprint Request Received',
          'See HTML',
          () =>
            sendEmail(
              member.email,
              'Sanlam Card Reprint Request Received',
              memberEmailHtml
            )
        )
      );
    }
    tasks.push(
      log(
        'email',
        'New Card Reprint Request (team)',
        'See HTML',
        () =>
          sendEmail(
            MEMBERSHIP_INBOX,
            `New Card Reprint Request — ${targetMemberName} (${targetMemberNo})`,
            teamEmailHtml
          )
      )
    );
    if (member.fcm_token) {
      tasks.push(
        log(
          'push',
          'Card Reprint Submitted',
          `Your reprint request for ${targetMemberName} has been received.`,
          () =>
            sendPush(
              member.fcm_token,
              'Card Reprint Submitted',
              `Your reprint request for ${targetMemberName} has been received.`
            )
        )
      );
    }
    // Don't await — run in background; respond immediately to the client.
    Promise.allSettled(tasks).catch(() => {});

    return res.status(201).json({
      id: request.id,
      status: 'pending_payment',
      amount: REPRINT_FEE_UGX,
      currency: 'UGX',
      createdAt: request.created_at,
      message:
        'Reprint request submitted. You will receive an SMS and email confirmation shortly.',
    });
  } catch (err) {
    console.error('cardReprints.create error:', err);
    return res
      .status(500)
      .json({ message: 'Failed to submit reprint request' });
  }
};

/** GET /api/card-reprints/mine — list this member's requests */
const listMine = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, target_member_no, target_member_name, target_relation,
              is_for_dependant, reason, reason_notes, payment_method,
              payment_phone, amount, currency, status,
              created_at, paid_at, fulfilled_at
         FROM card_reprint_requests
        WHERE member_id = $1
        ORDER BY created_at DESC`,
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('cardReprints.listMine error:', err);
    return res.status(500).json({ message: 'Failed to list reprint requests' });
  }
};

module.exports = { create, listMine, REPRINT_FEE_UGX };
