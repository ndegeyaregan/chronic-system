const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host:   process.env.SMTP_HOST,
  port:   parseInt(process.env.SMTP_PORT || '587', 10),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: { rejectUnauthorized: false },
});

/**
 * Send an email via the corporate SMTP account.
 * @param {object} opts
 * @param {string}   opts.to      - Recipient email address
 * @param {string}   opts.subject - Email subject
 * @param {string}   opts.html    - HTML body
 * @param {string}  [opts.cc]     - Optional CC address
 * @param {string}  [opts.replyTo]- Optional reply-to address
 */
async function sendMail({ to, subject, html, cc, replyTo }) {
  const info = await transporter.sendMail({
    from:    `"Sanlam Chronic Care" <${process.env.SMTP_USER}>`,
    to,
    cc:      cc  || undefined,
    replyTo: replyTo || undefined,
    subject,
    html,
  });
  return info;
}

module.exports = { sendMail, transporter };
