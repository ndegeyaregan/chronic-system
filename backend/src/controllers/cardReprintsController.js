const pool = require('../config/db');
const {
  sendSMS,
  sendEmail,
  sendPush,
} = require('../services/notificationService');
const onafriq = require('../services/onafriqService');

const REPRINT_FEE_UGX = 20000;
const MEMBERSHIP_INBOX = 'membership@ug.sanlamallianz.com';

const ALLOWED_REASONS = new Set(['lost', 'damaged', 'stolen', 'other']);

const sanitize = (v) => (typeof v === 'string' ? v.trim() : '');

// Sends member SMS/email + team email + push for a reprint request.
// Idempotent: marks notifications_sent_at and returns early on second call.
const fulfilCardReprintPayment = async (requestId) => {
  const r = await pool.query(
    `SELECT cr.*, m.first_name, m.last_name, m.email, m.phone, m.fcm_token,
            m.member_number
       FROM card_reprint_requests cr
       JOIN members m ON m.id = cr.member_id
      WHERE cr.id = $1`,
    [requestId]
  );
  if (!r.rows.length) return;
  const req = r.rows[0];
  if (req.notifications_sent_at) return; // already done

  const memberFullName = `${req.first_name || ''} ${req.last_name || ''}`.trim();
  const friendlyReason =
    req.reason === 'other' && req.reason_notes ? req.reason_notes : req.reason;
  const targetLabel = req.is_for_dependant
    ? `${req.target_member_name} (${req.target_relation}, ${req.target_member_no})`
    : `${req.target_member_name} (Principal, ${req.target_member_no})`;

  const smsBody =
    `Sanlam: Card reprint payment of UGX ${Number(req.amount).toLocaleString()} ` +
    `received for ${targetLabel}. Ref: ${req.id.slice(0, 8).toUpperCase()}.`;

  const memberEmailHtml = `
    <p>Hi ${req.first_name || 'Member'},</p>
    <p>Your card reprint payment has been received. Details:</p>
    <ul>
      <li><strong>Card for:</strong> ${req.target_member_name} (${req.target_relation})</li>
      <li><strong>Member number:</strong> ${req.target_member_no}</li>
      <li><strong>Reason:</strong> ${friendlyReason}</li>
      <li><strong>Amount paid:</strong> UGX ${Number(req.amount).toLocaleString()}</li>
      <li><strong>Reference:</strong> ${req.id}</li>
      ${req.payment_confirmation_code ? `<li><strong>Confirmation:</strong> ${req.payment_confirmation_code}</li>` : ''}
    </ul>
    <p>Our membership team has been notified and will process your new card.</p>
    <p>Sanlam Allianz Health</p>
  `;

  const teamEmailHtml = `
    <h3>New PAID Card Reprint Request</h3>
    <table cellpadding="6" style="border-collapse:collapse">
      <tr><td><strong>Reference</strong></td><td>${req.id}</td></tr>
      <tr><td><strong>Submitted by</strong></td><td>${memberFullName} (${req.member_number})</td></tr>
      <tr><td><strong>Card for</strong></td><td>${req.target_member_name}</td></tr>
      <tr><td><strong>Member number</strong></td><td>${req.target_member_no}</td></tr>
      <tr><td><strong>Relation</strong></td><td>${req.target_relation}</td></tr>
      <tr><td><strong>Reason</strong></td><td>${friendlyReason}</td></tr>
      <tr><td><strong>Amount paid</strong></td><td>UGX ${Number(req.amount).toLocaleString()}</td></tr>
      <tr><td><strong>Payment method</strong></td><td>${req.payment_method_used || 'Mobile Money'}</td></tr>
      <tr><td><strong>Payment phone</strong></td><td>${req.payment_phone}</td></tr>
      <tr><td><strong>Confirmation code</strong></td><td>${req.payment_confirmation_code || '-'}</td></tr>
      <tr><td><strong>Member email</strong></td><td>${req.email || '-'}</td></tr>
      <tr><td><strong>Member phone</strong></td><td>${req.phone || '-'}</td></tr>
      <tr><td><strong>Submitted at</strong></td><td>${req.created_at}</td></tr>
      <tr><td><strong>Paid at</strong></td><td>${req.paid_at || ''}</td></tr>
    </table>
  `;

  const log = async (channel, title, message, fn) => {
    let status = 'failed';
    try { await fn(); status = 'sent'; }
    catch (e) { console.error(`reprint notify ${channel} failed:`, e.message); }
    try {
      await pool.query(
        `INSERT INTO notifications (member_id, type, channel, title, message, status, sent_at)
         VALUES ($1,$2,$3,$4,$5,$6, NOW())`,
        [req.member_id, 'card_reprint', channel, title, message, status]
      );
    } catch (e) { console.error('notification log insert failed:', e.message); }
  };

  const tasks = [];
  if (req.phone) {
    tasks.push(log('sms', 'Card Reprint Paid', smsBody, () => sendSMS(req.phone, smsBody)));
  }
  if (req.email) {
    tasks.push(log('email', 'Card Reprint Payment Received', 'See HTML', () =>
      sendEmail(req.email, 'Sanlam Card Reprint Payment Received', memberEmailHtml)));
  }
  tasks.push(log('email', 'PAID Card Reprint Request (team)', 'See HTML', () =>
    sendEmail(MEMBERSHIP_INBOX,
      `PAID Card Reprint Request — ${req.target_member_name} (${req.target_member_no})`,
      teamEmailHtml)));
  if (req.fcm_token) {
    tasks.push(log('push', 'Card Reprint Paid',
      `Payment received for ${req.target_member_name}'s card.`, () =>
        sendPush(req.fcm_token, 'Card Reprint Paid',
          `Payment received for ${req.target_member_name}'s card.`)));
  }

  await Promise.allSettled(tasks);

  await pool.query(
    `UPDATE card_reprint_requests SET notifications_sent_at = NOW() WHERE id = $1`,
    [requestId]
  );
};

// POST /api/card-reprints
// body: { targetMemberNo, targetMemberName, targetRelation,
//         isForDependant, reason, reasonNotes, paymentPhone }
//
// Creates a pending reprint record and immediately fires an Onafriq
// pay-in request against paymentPhone -- on supported networks this pops
// a USSD PIN prompt on the member's phone with no manual dialing or
// screenshot proof needed. The app polls GET /:id/payment-status until
// the pay-in resolves.
const create = async (req, res) => {
  try {
    const memberId = req.user.id;
    const body = req.body || {};
    const targetMemberNo = sanitize(body.targetMemberNo);
    const targetMemberName = sanitize(body.targetMemberName);
    const targetRelation = sanitize(body.targetRelation) || 'Principal';
    const isForDependant =
      body.isForDependant === true ||
      body.isForDependant === 'true' ||
      body.isForDependant === '1';
    const reason = sanitize(body.reason).toLowerCase();
    const reasonNotes = sanitize(body.reasonNotes) || null;
    const paymentPhone = sanitize(body.paymentPhone);

    if (!targetMemberNo || !targetMemberName) {
      return res.status(400).json({ message: 'targetMemberNo and targetMemberName are required' });
    }
    if (!ALLOWED_REASONS.has(reason)) {
      return res.status(400).json({
        message: "reason must be one of: 'lost', 'damaged', 'stolen', 'other'",
      });
    }
    if (reason === 'other' && !reasonNotes) {
      return res.status(400).json({ message: 'reasonNotes is required when reason is "other"' });
    }
    if (!paymentPhone || paymentPhone.replace(/\D/g, '').length < 9) {
      return res.status(400).json({ message: 'A valid mobile money phone number is required' });
    }

    const memberRes = await pool.query(
      `SELECT id, member_number, first_name, last_name, email, phone
         FROM members WHERE id = $1`,
      [memberId]
    );
    if (!memberRes.rows.length) {
      return res.status(404).json({ message: 'Member not found' });
    }

    const insertRes = await pool.query(
      `INSERT INTO card_reprint_requests
         (member_id, target_member_no, target_member_name, target_relation,
          is_for_dependant, reason, reason_notes, payment_method,
          payment_phone, amount, currency, status, payment_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'mobile_money_pin',$8,$9,'UGX','pending_payment','pending')
       RETURNING id, created_at`,
      [
        memberId, targetMemberNo, targetMemberName, targetRelation,
        isForDependant, reason, reasonNotes,
        paymentPhone, REPRINT_FEE_UGX,
      ]
    );
    const request = insertRes.rows[0];

    try {
      const collectionRequest = await onafriq.createCollectionRequest({
        phonenumber: paymentPhone,
        liveAmount: REPRINT_FEE_UGX,
        reason: 'Card Reprint Fee',
        partnerTransactionId: request.id,
      });
      await pool.query(
        `UPDATE card_reprint_requests SET onafriq_request_id = $1 WHERE id = $2`,
        [String(collectionRequest.id), request.id]
      );
      return res.status(201).json({
        id: request.id,
        status: 'pending_payment',
        paymentStatus: 'pending',
        amount: REPRINT_FEE_UGX,
        currency: 'UGX',
        createdAt: request.created_at,
        sandbox: onafriq.isSandbox(),
        message: onafriq.isSandbox()
          ? 'Test payment request sent (sandbox mode).'
          : 'Check your phone and enter your Mobile Money PIN to approve the payment.',
      });
    } catch (payErr) {
      console.error(
        'cardReprints onafriq createCollectionRequest error:',
        payErr.response?.data || payErr.message
      );
      await pool.query(
        `UPDATE card_reprint_requests SET payment_status = 'failed' WHERE id = $1`,
        [request.id]
      );
      return res.status(502).json({
        id: request.id,
        message: 'Could not start the mobile money payment. Please try again.',
      });
    }
  } catch (err) {
    console.error('cardReprints.create error:', err);
    return res.status(500).json({ message: 'Failed to submit reprint request' });
  }
};

// GET /api/card-reprints/:id/payment-status
// Polled by the app after create() while waiting for the member to
// approve the USSD PIN prompt. Checks Onafriq once per call and updates
// our record; on success this also triggers the paid notifications.
const getPaymentStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const memberId = req.user.id;

    const existing = await pool.query(
      `SELECT * FROM card_reprint_requests WHERE id = $1 AND member_id = $2`,
      [id, memberId]
    );
    if (!existing.rows.length) {
      return res.status(404).json({ message: 'Reprint request not found' });
    }
    const request = existing.rows[0];

    // Already resolved, or never got an Onafriq request id — nothing to poll.
    const resolved = ['completed', 'failed', 'expired', 'reversed'];
    if (resolved.includes(request.payment_status) || !request.onafriq_request_id) {
      return res.json({
        id: request.id,
        status: request.status,
        paymentStatus: request.payment_status,
      });
    }

    const collectionRequest = await onafriq.getCollectionRequest(request.onafriq_request_id);
    const onafriqStatus = collectionRequest.status;

    if (onafriqStatus === 'successful') {
      await pool.query(
        `UPDATE card_reprint_requests
            SET payment_status = 'completed', payment_completed_at = NOW(),
                status = 'paid', paid_at = COALESCE(paid_at, NOW()),
                payment_method_used = 'Onafriq Mobile Money'
          WHERE id = $1`,
        [id]
      );
      await fulfilCardReprintPayment(id);
      return res.json({ id, status: 'paid', paymentStatus: 'completed' });
    }

    if (['failed', 'expired', 'reversed'].includes(onafriqStatus)) {
      await pool.query(
        `UPDATE card_reprint_requests SET payment_status = $1 WHERE id = $2`,
        [onafriqStatus, id]
      );
      return res.json({ id, status: request.status, paymentStatus: onafriqStatus });
    }

    // new | pending | instructions_sent | processing_started
    return res.json({ id, status: request.status, paymentStatus: 'pending' });
  } catch (err) {
    console.error('cardReprints.getPaymentStatus error:', err.response?.data || err.message);
    return res.status(500).json({ message: 'Failed to check payment status' });
  }
};

// GET /api/card-reprints/mine -- list this member's requests
const listMine = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, target_member_no, target_member_name, target_relation,
              is_for_dependant, reason, reason_notes, payment_method,
              payment_phone, amount, currency, status, payment_status,
              payment_method_used,
              payment_confirmation_code,
              payment_proof_url, payment_proof_name,
              created_at, paid_at, payment_completed_at, fulfilled_at
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

// GET /api/card-reprints (admin) -- list all reprint requests
const listAll = async (req, res) => {
  try {
    const status = (req.query.status || '').toString().trim();
    const paymentStatus = (req.query.payment_status || '').toString().trim();
    const search = (req.query.search || '').toString().trim();

    const params = [];
    const filters = [];
    let idx = 1;
    if (status) { filters.push(`cr.status = $${idx++}`); params.push(status); }
    if (paymentStatus) { filters.push(`cr.payment_status = $${idx++}`); params.push(paymentStatus); }
    if (search) {
      filters.push(`(m.first_name ILIKE $${idx} OR m.last_name ILIKE $${idx} OR m.member_number ILIKE $${idx} OR cr.target_member_no ILIKE $${idx} OR cr.target_member_name ILIKE $${idx})`);
      params.push(`%${search}%`);
      idx++;
    }
    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT cr.*,
              m.first_name, m.last_name, m.member_number AS principal_member_number,
              m.email, m.phone
         FROM card_reprint_requests cr
         JOIN members m ON m.id = cr.member_id
         ${whereClause}
        ORDER BY cr.created_at DESC
        LIMIT 500`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('cardReprints.listAll error:', err);
    return res.status(500).json({ message: 'Failed to list reprint requests' });
  }
};

// PATCH /api/card-reprints/:id/status (admin) -- move along the fulfilment flow
const updateStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const status = (req.body.status || '').toString().trim();
    const adminNotes = typeof req.body.adminNotes === 'string' ? req.body.adminNotes.trim() : null;
    const allowed = ['pending_payment', 'paid', 'processing', 'fulfilled', 'cancelled'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ message: `status must be one of: ${allowed.join(', ')}` });
    }

    const update = await pool.query(
      `UPDATE card_reprint_requests
          SET status = $1::text,
              paid_at = CASE WHEN $1::text = 'paid' AND paid_at IS NULL THEN NOW() ELSE paid_at END,
              fulfilled_at = CASE WHEN $1::text = 'fulfilled' THEN NOW() ELSE fulfilled_at END
        WHERE id = $2::uuid
        RETURNING *`,
      [status, id]
    );
    if (!update.rows.length) {
      return res.status(404).json({ message: 'Reprint request not found' });
    }

    // Respond immediately, run notifications in background to avoid freeze
    res.json(update.rows[0]);

    setImmediate(async () => {
      try {
        const r = await pool.query(
          `SELECT cr.*, m.first_name, m.last_name, m.email, m.phone, m.fcm_token
             FROM card_reprint_requests cr
             JOIN members m ON m.id = cr.member_id
            WHERE cr.id = $1`, [id]
        );
        if (!r.rows.length) return;
        const c = r.rows[0];
        const refShort = id.slice(0, 8).toUpperCase();
        const target = c.target_member_name || 'your card';

        let title, msg, smsMsg;
        if (status === 'fulfilled') {
          title = 'Card Ready for Pickup';
          msg = `Your reprinted Sanlam medical card for ${target} is ready / has been delivered. Ref ${refShort}.`;
          smsMsg = `Sanlam: ${msg}`;
        } else if (status === 'processing') {
          title = 'Card Reprint In Progress';
          msg = `Your card reprint for ${target} is now being processed. Ref ${refShort}.`;
          smsMsg = null;
        } else if (status === 'paid') {
          title = 'Card Reprint Payment Received';
          msg = `Payment received for your card reprint (${target}). Ref ${refShort}.`;
          smsMsg = null;
        } else if (status === 'cancelled') {
          title = 'Card Reprint Cancelled';
          msg = `Your card reprint request for ${target} has been cancelled. ${adminNotes || 'Please contact membership@ug.sanlamallianz.com if needed.'} Ref ${refShort}.`;
          smsMsg = `Sanlam: ${msg}`;
        } else {
          title = 'Card Reprint Update';
          msg = `Status of your card reprint for ${target} is now: ${status}. Ref ${refShort}.`;
          smsMsg = null;
        }

        const logNotif = async (channel, st) => {
          try {
            await pool.query(
              `INSERT INTO notifications (member_id, type, channel, title, message, status, sent_at)
               VALUES ($1,$2,$3,$4,$5,$6, NOW())`,
              [c.member_id, 'card_reprint', channel, title, msg, st]
            );
          } catch (e) { console.error('reprint notif log:', e.message); }
        };

        await logNotif('in_app', 'sent');

        if (c.fcm_token) {
          try { await sendPush(c.fcm_token, title, msg); await logNotif('push', 'sent'); }
          catch (e) { console.error('reprint push:', e.message); await logNotif('push', 'failed'); }
        }

        // SMS+Email on fulfilled or cancelled
        if (status === 'fulfilled' || status === 'cancelled') {
          if (c.phone && smsMsg) {
            try { await sendSMS(c.phone, smsMsg); await logNotif('sms', 'sent'); }
            catch (e) { console.error('reprint sms:', e.message); await logNotif('sms', 'failed'); }
          }
          if (c.email) {
            try {
              await sendEmail(c.email, title,
                `<p>Hi ${c.first_name || 'Member'},</p><p>${msg}</p>${adminNotes ? `<p><em>${adminNotes}</em></p>` : ''}<p>Sanlam Allianz Health</p>`);
              await logNotif('email', 'sent');
            } catch (e) { console.error('reprint email:', e.message); await logNotif('email', 'failed'); }
          }
        }
      } catch (e) {
        console.error('reprint status notify bg:', e.message);
      }
    });
    return;
  } catch (err) {
    console.error('cardReprints.updateStatus error:', err);
    return res.status(500).json({ message: 'Failed to update status' });
  }
};

module.exports = {
  create,
  listMine,
  listAll,
  updateStatus,
  getPaymentStatus,
  fulfilCardReprintPayment,
  REPRINT_FEE_UGX,
};
