const path = require('path');
const fs = require('fs');
const pool = require('../config/db');
const {
  sendSMS,
  sendEmail,
  sendPush,
} = require('../services/notificationService');

const SANCARE_INBOX = 'sancare@ug.sanlamallianz.com';

const sanitize = (v) => (typeof v === 'string' ? v.trim() : '');

const fileToPublicUrl = (req, file) => {
  if (!file) return null;
  // Files saved under uploads/reimbursements/<filename>
  const rel = `/uploads/reimbursements/${path.basename(file.path)}`;
  return rel;
};

const absoluteUrl = (req, rel) => {
  if (!rel) return null;
  if (rel.startsWith('http')) return rel;
  const proto = req.headers['x-forwarded-proto'] || req.protocol;
  const host = req.headers['x-forwarded-host'] || req.get('host');
  return `${proto}://${host}${rel}`;
};

/**
 * POST /api/reimbursements
 * multipart/form-data fields:
 *   hospitalName, reason, amount(optional),
 *   payoutMethod ('mobile_money'|'bank'), payoutAccountName,
 *   payoutPhone (mm) | payoutBankName + payoutAccountNumber + payoutBranch (bank),
 *   invoice (file, REQUIRED), report (file, optional)
 */
const create = async (req, res) => {
  try {
    const memberId = req.user.id;

    const hospitalName = sanitize(req.body.hospitalName);
    const reason = sanitize(req.body.reason);
    const amountRaw = sanitize(req.body.amount);
    const amount = amountRaw ? Number(amountRaw) : null;
    const payoutMethod =
      sanitize(req.body.payoutMethod) === 'bank' ? 'bank' : 'mobile_money';
    const payoutAccountName = sanitize(req.body.payoutAccountName);
    const payoutPhone = sanitize(req.body.payoutPhone);
    const payoutBankName = sanitize(req.body.payoutBankName);
    const payoutAccountNumber = sanitize(req.body.payoutAccountNumber);
    const payoutBranch = sanitize(req.body.payoutBranch);

    const invoiceFile =
      (req.files && req.files.invoice && req.files.invoice[0]) || null;
    const reportFile =
      (req.files && req.files.report && req.files.report[0]) || null;
    const approvalEmailFile =
      (req.files && req.files.approvalEmail && req.files.approvalEmail[0]) ||
      null;

    // --- Sancare authorization gate ----------------------------------------
    // Every reimbursement must reference a prior Sancare authorization,
    // either linked in-app (approved authorization_requests row) OR by
    // uploading the approval email/letter the member received from Sancare.
    let approvalPath = sanitize(req.body.approvalPath);
    if (!['in_app', 'email'].includes(approvalPath)) {
      // Try to infer for backward compatibility with older clients.
      if (sanitize(req.body.authorizationId)) approvalPath = 'in_app';
      else if (approvalEmailFile) approvalPath = 'email';
    }
    let authorizationId = null;
    let approvalReference = null;

    if (approvalPath === 'in_app') {
      authorizationId = sanitize(req.body.authorizationId) || null;
      if (!authorizationId) {
        return res.status(400).json({
          message:
            'Please select the approved authorization this reimbursement relates to.',
        });
      }
      const authRow = await pool.query(
        `SELECT id, status, member_id, provider_name
           FROM authorization_requests
          WHERE id = $1`,
        [authorizationId]
      );
      if (!authRow.rows.length) {
        return res
          .status(400)
          .json({ message: 'Selected authorization not found.' });
      }
      const auth = authRow.rows[0];
      if (auth.member_id !== memberId) {
        return res
          .status(403)
          .json({ message: 'That authorization does not belong to you.' });
      }
      if (auth.status !== 'approved') {
        return res.status(400).json({
          message:
            'Only approved authorizations can be used for a reimbursement.',
        });
      }
    } else if (approvalPath === 'email') {
      approvalReference = sanitize(req.body.approvalReference);
      if (!approvalEmailFile) {
        return res.status(400).json({
          message:
            'Please attach the Sancare approval email or letter you received.',
        });
      }
      if (!approvalReference) {
        return res.status(400).json({
          message:
            'Please provide a Sancare approval reference (officer name or email subject/date).',
        });
      }
    } else {
      return res.status(400).json({
        message:
          'Reimbursement requires prior Sancare authorization. Choose an approved authorization or attach the Sancare approval email.',
      });
    }
    // -----------------------------------------------------------------------

    if (!hospitalName) {
      return res.status(400).json({ message: 'hospitalName is required' });
    }
    if (!reason) {
      return res.status(400).json({ message: 'reason is required' });
    }
    if (!invoiceFile) {
      return res.status(400).json({ message: 'invoice attachment is required' });
    }
    if (!payoutAccountName) {
      return res
        .status(400)
        .json({ message: 'payoutAccountName is required' });
    }
    if (payoutMethod === 'mobile_money') {
      if (!payoutPhone || payoutPhone.replace(/\D/g, '').length < 9) {
        return res
          .status(400)
          .json({ message: 'A valid payout mobile money phone is required' });
      }
    } else {
      if (!payoutBankName || !payoutAccountNumber) {
        return res
          .status(400)
          .json({ message: 'Bank name and account number are required' });
      }
    }

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

    const invoiceUrl = fileToPublicUrl(req, invoiceFile);
    const reportUrl = fileToPublicUrl(req, reportFile);
    const approvalEmailUrl = fileToPublicUrl(req, approvalEmailFile);

    const insert = await pool.query(
      `INSERT INTO reimbursement_claims
         (member_id, hospital_name, reason, amount, currency,
          invoice_url, invoice_filename, report_url, report_filename,
          payout_method, payout_account_name, payout_phone,
          payout_bank_name, payout_account_number, payout_branch,
          status,
          approval_path, authorization_id,
          approval_email_url, approval_email_filename, approval_reference)
       VALUES ($1,$2,$3,$4,'UGX',$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'pending',
               $15,$16,$17,$18,$19)
       RETURNING id, created_at`,
      [
        memberId,
        hospitalName,
        reason,
        amount,
        invoiceUrl,
        invoiceFile.originalname,
        reportUrl,
        reportFile ? reportFile.originalname : null,
        payoutMethod,
        payoutAccountName,
        payoutMethod === 'mobile_money' ? payoutPhone : null,
        payoutMethod === 'bank' ? payoutBankName : null,
        payoutMethod === 'bank' ? payoutAccountNumber : null,
        payoutMethod === 'bank' ? payoutBranch || null : null,
        approvalPath,
        authorizationId,
        approvalEmailUrl,
        approvalEmailFile ? approvalEmailFile.originalname : null,
        approvalReference,
      ]
    );
    const created = insert.rows[0];

    const amountLine = amount
      ? `UGX ${Number(amount).toLocaleString()}`
      : 'Not specified';

    const payoutLines =
      payoutMethod === 'mobile_money'
        ? `Mobile Money — ${payoutAccountName} (${payoutPhone})`
        : `Bank — ${payoutBankName}, A/C ${payoutAccountNumber} (${payoutAccountName})${payoutBranch ? `, ${payoutBranch}` : ''}`;

    const approvalLine =
      approvalPath === 'in_app'
        ? `In-app authorization #${authorizationId}`
        : `Email approval — ${approvalReference}`;

    // Email to sancare team
    const teamHtml = `
      <h3>New Reimbursement Request</h3>
      <table cellpadding="6" style="border-collapse:collapse">
        <tr><td><strong>Reference</strong></td><td>${created.id}</td></tr>
        <tr><td><strong>Member</strong></td><td>${memberFullName} (${member.member_number})</td></tr>
        <tr><td><strong>Member email</strong></td><td>${member.email || '-'}</td></tr>
        <tr><td><strong>Member phone</strong></td><td>${member.phone || '-'}</td></tr>
        <tr><td><strong>Hospital</strong></td><td>${hospitalName}</td></tr>
        <tr><td><strong>Reason</strong></td><td>${reason}</td></tr>
        <tr><td><strong>Amount claimed</strong></td><td>${amountLine}</td></tr>
        <tr><td><strong>Sancare authorization</strong></td><td>${approvalLine}</td></tr>
        <tr><td><strong>Payout</strong></td><td>${payoutLines}</td></tr>
        <tr><td><strong>Submitted at</strong></td><td>${created.created_at}</td></tr>
      </table>
      <p><strong>Attachments:</strong></p>
      <ul>
        <li>Invoice: <a href="${absoluteUrl(req, invoiceUrl)}">${invoiceFile.originalname}</a></li>
        ${
          reportUrl
            ? `<li>Medical report: <a href="${absoluteUrl(req, reportUrl)}">${reportFile.originalname}</a></li>`
            : ''
        }
        ${
          approvalEmailUrl
            ? `<li>Sancare approval email: <a href="${absoluteUrl(req, approvalEmailUrl)}">${approvalEmailFile.originalname}</a></li>`
            : ''
        }
      </ul>
    `;

    const memberHtml = `
      <p>Hi ${member.first_name || 'Member'},</p>
      <p>We have received your reimbursement request. Details:</p>
      <ul>
        <li><strong>Hospital:</strong> ${hospitalName}</li>
        <li><strong>Reason:</strong> ${reason}</li>
        <li><strong>Amount claimed:</strong> ${amountLine}</li>
        <li><strong>Payout to:</strong> ${payoutLines}</li>
        <li><strong>Reference:</strong> ${created.id}</li>
      </ul>
      <p>Our team will review your claim and notify you once payment is processed.</p>
      <p>Sanlam Allianz Health</p>
    `;

    const smsBody =
      `Sanlam: Reimbursement request for ${hospitalName} received. ` +
      `Ref ${created.id.slice(0, 8).toUpperCase()}. ` +
      `You'll be notified once it's processed.`;

    const log = async (channel, title, message, fn) => {
      let status = 'failed';
      try {
        await fn();
        status = 'sent';
      } catch (e) {
        console.error(`reimbursement notify ${channel} failed:`, e.message);
      }
      try {
        await pool.query(
          `INSERT INTO notifications (member_id, type, channel, title, message, status, sent_at)
           VALUES ($1,$2,$3,$4,$5,$6, NOW())`,
          [memberId, 'reimbursement', channel, title, message, status]
        );
      } catch (e) {
        console.error('notification log insert failed:', e.message);
      }
    };

    const tasks = [];
    tasks.push(
      log(
        'email',
        'New Reimbursement Request (team)',
        'See HTML',
        () =>
          sendEmail(
            SANCARE_INBOX,
            `New Reimbursement Request — ${hospitalName} (${memberFullName})`,
            teamHtml
          )
      )
    );
    if (member.email) {
      tasks.push(
        log('email', 'Reimbursement Request Received', 'See HTML', () =>
          sendEmail(
            member.email,
            'Sanlam Reimbursement Request Received',
            memberHtml
          )
        )
      );
    }
    if (member.phone) {
      tasks.push(
        log('sms', 'Reimbursement Request', smsBody, () =>
          sendSMS(member.phone, smsBody)
        )
      );
    }
    if (member.fcm_token) {
      tasks.push(
        log(
          'push',
          'Reimbursement Submitted',
          'Your reimbursement request has been received.',
          () =>
            sendPush(
              member.fcm_token,
              'Reimbursement Submitted',
              'Your reimbursement request has been received.'
            )
        )
      );
    }
    Promise.allSettled(tasks).catch(() => {});

    return res.status(201).json({
      id: created.id,
      status: 'pending',
      createdAt: created.created_at,
      message:
        'Reimbursement request submitted. You will be contacted once it is processed.',
    });
  } catch (err) {
    console.error('reimbursements.create error:', err);
    // Clean up uploaded files on failure
    try {
      const files = [
        ...((req.files && req.files.invoice) || []),
        ...((req.files && req.files.report) || []),
        ...((req.files && req.files.approvalEmail) || []),
      ];
      for (const f of files) fs.existsSync(f.path) && fs.unlinkSync(f.path);
    } catch (_) {}
    return res
      .status(500)
      .json({ message: 'Failed to submit reimbursement request' });
  }
};

/** GET /api/reimbursements/mine */
const listMine = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, hospital_name, reason, amount, currency,
              invoice_url, invoice_filename, report_url, report_filename,
              payout_method, payout_account_name, payout_phone,
              payout_bank_name, payout_account_number, payout_branch,
              status, paid_at, paid_amount, payment_reference, admin_notes,
              approval_path, authorization_id,
              approval_email_url, approval_email_filename, approval_reference,
              created_at, updated_at
         FROM reimbursement_claims
        WHERE member_id = $1
        ORDER BY created_at DESC`,
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('reimbursements.listMine error:', err);
    return res.status(500).json({ message: 'Failed to list reimbursements' });
  }
};

/**
 * PATCH /api/reimbursements/:id/status  (admin)
 * body: { status: 'paid'|'rejected'|'under_review', adminNotes, paidAmount, paymentReference }
 */
const updateStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const status = sanitize(req.body.status);
    const adminNotes = sanitize(req.body.adminNotes) || null;
    const paidAmountRaw = sanitize(req.body.paidAmount);
    const paidAmount = paidAmountRaw ? Number(paidAmountRaw) : null;
    const paymentReference = sanitize(req.body.paymentReference) || null;

    const allowed = ['pending', 'under_review', 'paid', 'rejected'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ message: `status must be one of: ${allowed.join(', ')}` });
    }

    const claimRes = await pool.query(
      `SELECT rc.*, m.first_name, m.last_name, m.email, m.phone, m.fcm_token, m.member_number
         FROM reimbursement_claims rc
         JOIN members m ON m.id = rc.member_id
        WHERE rc.id = $1`,
      [id]
    );
    if (!claimRes.rows.length) {
      return res.status(404).json({ message: 'Claim not found' });
    }
    const claim = claimRes.rows[0];

    const update = await pool.query(
      `UPDATE reimbursement_claims
          SET status = $1::text,
              admin_notes = COALESCE($2::text, admin_notes),
              paid_amount = COALESCE($3::numeric, paid_amount),
              payment_reference = COALESCE($4::text, payment_reference),
              paid_at = CASE WHEN $1::text = 'paid' THEN NOW() ELSE paid_at END,
              paid_by = CASE WHEN $1::text = 'paid' THEN $5::uuid ELSE paid_by END,
              updated_at = NOW()
        WHERE id = $6::uuid
        RETURNING *`,
      [status, adminNotes, paidAmount, paymentReference, req.user.id, id]
    );

    // Build a member-friendly message for every status change
    const refShort = id.slice(0, 8).toUpperCase();
    const amountTxt =
      paidAmount || claim.amount
        ? `UGX ${Number(paidAmount || claim.amount).toLocaleString()}`
        : '';
    let title, memberMsg, sms;
    if (status === 'paid') {
      title = 'Reimbursement Paid';
      memberMsg = `Your reimbursement for ${claim.hospital_name} has been PAID${amountTxt ? ` (${amountTxt})` : ''}. Ref ${refShort}.`;
      sms = `Sanlam: ${memberMsg}`;
    } else if (status === 'rejected') {
      title = 'Reimbursement Update';
      memberMsg = `Your reimbursement for ${claim.hospital_name} could not be approved. Please contact sancare@ug.sanlamallianz.com for details. Ref ${refShort}.`;
      sms = `Sanlam: ${memberMsg}`;
    } else if (status === 'under_review') {
      title = 'Reimbursement Under Review';
      memberMsg = `Your reimbursement for ${claim.hospital_name} is now under review. Ref ${refShort}.`;
      sms = null;
    } else {
      title = 'Reimbursement Update';
      memberMsg = `Status of your reimbursement for ${claim.hospital_name} is now: ${status}. Ref ${refShort}.`;
      sms = null;
    }

    const logNotif = async (channel, st) => {
      try {
        await pool.query(
          `INSERT INTO notifications (member_id, type, channel, title, message, status, sent_at)
           VALUES ($1,$2,$3,$4,$5,$6, NOW())`,
          [claim.member_id, 'reimbursement', channel, title, memberMsg, st]
        );
      } catch (e) {
        console.error('notification log insert failed:', e.message);
      }
    };

    // Respond IMMEDIATELY to avoid the portal freezing while SMTP/SMS run
    res.json(update.rows[0]);

    setImmediate(async () => {
      try {
        // Always: in-app inbox entry so member sees it inside the app
        await logNotif('in_app', 'sent');

        // Push to device on every status change (best-effort)
        if (claim.fcm_token) {
          try {
            await sendPush(claim.fcm_token, title, memberMsg);
            await logNotif('push', 'sent');
          } catch (e) {
            console.error('push notify failed:', e.message);
            await logNotif('push', 'failed');
          }
        }

        // SMS + email only for paid / rejected
        if (status === 'paid' || status === 'rejected') {
          if (claim.phone && sms) {
            try {
              await sendSMS(claim.phone, sms);
              await logNotif('sms', 'sent');
            } catch (e) {
              console.error('sms notify failed:', e.message);
              await logNotif('sms', 'failed');
            }
          }
          if (claim.email) {
            try {
              await sendEmail(
                claim.email,
                title,
                `<p>Hi ${claim.first_name || 'Member'},</p><p>${memberMsg}</p>${adminNotes ? `<p><em>${adminNotes}</em></p>` : ''}<p>Sanlam Allianz Health</p>`
              );
              await logNotif('email', 'sent');
            } catch (e) {
              console.error('email notify failed:', e.message);
              await logNotif('email', 'failed');
            }
          }
        }
      } catch (e) {
        console.error('reimbursement notify bg:', e.message);
      }
    });
    return;
  } catch (err) {
    console.error('reimbursements.updateStatus error:', err);
    return res.status(500).json({ message: 'Failed to update status' });
  }
};

/** GET /api/reimbursements (admin) — list all */
const listAll = async (req, res) => {
  try {
    const status = sanitize(req.query.status);
    const params = [];
    let where = '';
    if (status) {
      params.push(status);
      where = `WHERE rc.status = $1`;
    }
    const result = await pool.query(
      `SELECT rc.*, m.first_name, m.last_name, m.member_number, m.email, m.phone
         FROM reimbursement_claims rc
         JOIN members m ON m.id = rc.member_id
         ${where}
        ORDER BY rc.created_at DESC
        LIMIT 500`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('reimbursements.listAll error:', err);
    return res.status(500).json({ message: 'Failed to list reimbursements' });
  }
};

module.exports = { create, listMine, listAll, updateStatus };
