require('dotenv').config();
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: { rejectUnauthorized: false },
});

async function testEmail() {
  console.log(`Testing SMTP connection to ${process.env.SMTP_HOST}:${process.env.SMTP_PORT}...`);
  
  await transporter.verify();
  console.log('✅ SMTP connection successful!');

  const info = await transporter.sendMail({
    from: `"Sanlam Chronic Care" <${process.env.SMTP_USER}>`,
    to: process.env.SMTP_USER,
    subject: '✅ Sanlam Chronic Care — Email Test',
    html: `
      <div style="font-family:sans-serif;max-width:500px;margin:auto;padding:32px">
        <div style="background:#003DA5;padding:20px;border-radius:8px 8px 0 0;text-align:center">
          <h2 style="color:#fff;margin:0">Sanlam Chronic Care</h2>
        </div>
        <div style="background:#f8fafc;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e2e8f0">
          <p>🎉 Your email configuration is working correctly!</p>
          <p>This email was sent from <strong>${process.env.SMTP_USER}</strong> via <strong>${process.env.SMTP_HOST}</strong>.</p>
          <hr style="border:none;border-top:1px solid #e2e8f0;margin:16px 0">
          <p style="color:#64748b;font-size:12px">Sanlam Chronic Care Management System</p>
        </div>
      </div>
    `,
  });

  console.log(`✅ Test email sent! Message ID: ${info.messageId}`);
  console.log(`   Sent to: ${process.env.SMTP_USER}`);
  process.exit(0);
}

testEmail().catch(err => {
  console.error('❌ Email test failed:', err.message);
  process.exit(1);
});
