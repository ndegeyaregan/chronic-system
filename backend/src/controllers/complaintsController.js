const pool = require('../config/db');
const { sendMail } = require('../utils/mailer');

const ALLOWED_CATEGORIES = [
  'system_error',
  'preauth_delay',
  'failing_to_register',
  'prolonged_turnaround_time',
];

const CATEGORY_LABELS = {
  system_error: 'System Error',
  preauth_delay: 'Pre-authorisation Delay',
  failing_to_register: 'Failing to Register',
  prolonged_turnaround_time: 'Prolonged Turnaround Time',
};

const RECIPIENTS = [
  'it@ug.sanlamallianz.com',
  'sancare@ug.sanlamallianz.com',
];

const escapeHtml = (s) =>
  String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const buildHtml = (rec) => {
  const label = CATEGORY_LABELS[rec.category] || rec.category;
  return `
    <div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;padding:24px;color:#222">
      <h2 style="color:#0d4f8a;margin:0 0 8px 0">New Complaint / Feedback</h2>
      <p style="color:#666;margin:0 0 16px 0">Submitted via the SanCare+ mobile app.</p>
      <table cellpadding="8" cellspacing="0" style="border-collapse:collapse;width:100%;border:1px solid #e2e8f0">
        <tr><td style="background:#f8fafc;width:160px"><b>Reference ID</b></td><td>#${rec.id}</td></tr>
        <tr><td style="background:#f8fafc"><b>Category</b></td><td>${escapeHtml(label)}</td></tr>
        <tr><td style="background:#f8fafc"><b>Submitted</b></td><td>${new Date(rec.created_at).toLocaleString()}</td></tr>
        <tr><td style="background:#f8fafc"><b>Member Number</b></td><td>${escapeHtml(rec.member_number) || '—'}</td></tr>
        <tr><td style="background:#f8fafc"><b>Email</b></td><td>${escapeHtml(rec.email) || '—'}</td></tr>
        <tr><td style="background:#f8fafc"><b>Phone</b></td><td>${escapeHtml(rec.phone) || '—'}</td></tr>
      </table>
      <h3 style="margin:20px 0 8px 0">Description</h3>
      <div style="background:#f8fafc;border:1px solid #e2e8f0;padding:12px;white-space:pre-wrap;line-height:1.5">
        ${escapeHtml(rec.description)}
      </div>
      <p style="color:#888;font-size:12px;margin-top:24px">
        This is an automated notification. Reply directly to the member if a contact address is provided above.
      </p>
    </div>
  `;
};

const create = async (req, res) => {
  const {
    category,
    description,
    email,
    phone,
    member_number: memberNumber,
  } = req.body || {};

  if (!category || !ALLOWED_CATEGORIES.includes(category)) {
    return res.status(400).json({
      message: 'Invalid category',
      allowed: ALLOWED_CATEGORIES,
    });
  }
  if (!description || !String(description).trim()) {
    return res.status(400).json({ message: 'Description is required' });
  }
  if (String(description).length > 5000) {
    return res.status(400).json({ message: 'Description is too long (max 5000 chars)' });
  }
  if (!email && !phone && !memberNumber) {
    return res.status(400).json({
      message: 'Provide at least one contact detail (email, phone, or member number)',
    });
  }

  let inserted;
  try {
    const r = await pool.query(
      `INSERT INTO complaints (category, description, email, phone, member_number)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, category, description, email, phone, member_number, created_at`,
      [
        category,
        String(description).trim(),
        email ? String(email).trim() : null,
        phone ? String(phone).trim() : null,
        memberNumber ? String(memberNumber).trim() : null,
      ]
    );
    inserted = r.rows[0];
  } catch (err) {
    console.error('complaints.create DB error:', err);
    return res.status(500).json({ message: 'Failed to save complaint' });
  }

  // Fire-and-update: send email but don't fail the request if SMTP is down.
  const subject = `[SanCare+] ${CATEGORY_LABELS[inserted.category]} — #${inserted.id}`;
  const html = buildHtml(inserted);
  try {
    await sendMail({
      to: RECIPIENTS.join(', '),
      subject,
      html,
      replyTo: inserted.email || undefined,
    });
    await pool.query(
      `UPDATE complaints SET email_sent = TRUE, updated_at = NOW() WHERE id = $1`,
      [inserted.id]
    );
  } catch (err) {
    console.error('complaints.create email error:', err);
    await pool.query(
      `UPDATE complaints SET email_sent = FALSE, email_error = $1, updated_at = NOW() WHERE id = $2`,
      [String(err.message || err).slice(0, 1000), inserted.id]
    );
  }

  return res.status(201).json({
    message: 'Complaint submitted. Our team will get back to you.',
    id: inserted.id,
  });
};

module.exports = { create, ALLOWED_CATEGORIES };
