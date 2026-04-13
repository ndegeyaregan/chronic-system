const admin = require('firebase-admin');
const axios = require('axios');
const nodemailer = require('nodemailer');
const pool = require('../config/db');
const path = require('path');

// Firebase initializes lazily using the service account JSON file
let firebaseReady = false;
const initFirebase = () => {
  if (firebaseReady || admin.apps.length) { firebaseReady = true; return; }
  try {
    const serviceAccount = require(path.join(__dirname, '../config/firebase-service-account.json'));
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    firebaseReady = true;
    console.log('✅ Firebase initialized');
  } catch (err) {
    console.warn('Firebase init skipped:', err.message);
  }
};

// SMTP transporter using corporate mail server
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

// Send push notification
const sendPush = async (fcmToken, title, message) => {
  if (!fcmToken) return;
  initFirebase();
  if (!firebaseReady) return;
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body: message },
    });
  } catch (err) {
    console.error('Push error:', err.message);
  }
};

// Send SMS via TrueAfrican API
const sendSMS = async (phone, message) => {
  if (!phone) return;
  try {
    await axios.post(
      process.env.SMS_API_URL,
      {
        username: process.env.SMS_API_USERNAME,
        password: process.env.SMS_API_PASSWORD,
        to: phone,
        message,
      },
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    console.error('SMS error:', err.message);
  }
};

// Send Email via corporate SMTP
const sendEmail = async (to, subject, html) => {
  if (!to) return;
  try {
    await transporter.sendMail({
      from: `"Sanlam Chronic Care" <${process.env.SMTP_USER}>`,
      to,
      subject,
      html,
    });
  } catch (err) {
    console.error('Email error:', err.message);
  }
};

// Main: send to member across requested channels and log
const sendToMember = async (memberId, { type, title, message, channel = ['push'], fcmToken, phone, email, firstName }) => {
  // Fetch member details if not passed
  if (!fcmToken || !phone || !email) {
    const res = await pool.query(
      'SELECT fcm_token, phone, email, first_name FROM members WHERE id = $1',
      [memberId]
    );
    if (res.rows.length) {
      fcmToken = fcmToken || res.rows[0].fcm_token;
      phone = phone || res.rows[0].phone;
      email = email || res.rows[0].email;
      firstName = firstName || res.rows[0].first_name;
    }
  }

  const channels = Array.isArray(channel) ? channel : [channel];
  const greeting = firstName ? `Hi ${firstName}, ` : '';

  for (const ch of channels) {
    let status = 'failed';
    try {
      if (ch === 'push') {
        await sendPush(fcmToken, title, message);
        status = 'sent';
      } else if (ch === 'sms') {
        await sendSMS(phone, `${greeting}${message}`);
        status = 'sent';
      } else if (ch === 'email') {
        await sendEmail(email, title, `<p>${greeting}${message}</p>`);
        status = 'sent';
      }
    } catch {
      status = 'failed';
    }

    // Log to notifications table
    await pool.query(
      `INSERT INTO notifications (member_id, type, channel, title, message, status, sent_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
      [memberId, type, ch, title, message, status]
    );
  }
};

// Send welcome message to new member
const sendWelcome = async (memberId) => {
  const res = await pool.query('SELECT * FROM members WHERE id = $1', [memberId]);
  if (!res.rows.length) return;
  const member = res.rows[0];

  const message = `Welcome to Sanlam Chronic Care! Your member number is ${member.member_number}. Please download the app and set your password to get started.`;
  await sendToMember(memberId, {
    type: 'welcome',
    title: 'Welcome to Sanlam Chronic Care 🎉',
    message,
    channel: ['sms', 'email'],
  });
};

// Send bulk campaign to list of member IDs
const sendCampaign = async (memberIds, { type, title, message, channel }) => {
  const results = { sent: 0, failed: 0 };
  for (const memberId of memberIds) {
    try {
      await sendToMember(memberId, { type, title, message, channel });
      results.sent++;
    } catch {
      results.failed++;
    }
  }
  return results;
};

module.exports = { sendToMember, sendWelcome, sendCampaign, sendPush, sendSMS, sendEmail };
