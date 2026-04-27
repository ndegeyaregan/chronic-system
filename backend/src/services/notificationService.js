const admin = require('firebase-admin');
const axios = require('axios');
const nodemailer = require('nodemailer');
const pool = require('../config/db');

// Firebase initializes lazily using environment variables
let firebaseReady = false;
const initFirebase = () => {
  if (firebaseReady || admin.apps.length) { firebaseReady = true; return; }
  try {
    let serviceAccount;

    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } else if (process.env.FIREBASE_PROJECT_ID) {
      serviceAccount = {
        type: 'service_account',
        project_id: process.env.FIREBASE_PROJECT_ID,
        private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
        private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        client_email: process.env.FIREBASE_CLIENT_EMAIL,
        client_id: process.env.FIREBASE_CLIENT_ID,
        auth_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_uri: 'https://oauth2.googleapis.com/token',
        auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
        client_x509_cert_url: process.env.FIREBASE_CERT_URL,
      };
    } else {
      console.warn('Firebase credentials not configured - push notifications disabled');
      return;
    }

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

// Send push notification with optional sound
const sendPush = async (fcmToken, title, message, options = {}) => {
  if (!fcmToken) return;
  initFirebase();
  if (!firebaseReady) return;
  try {
    const payload = {
      token: fcmToken,
      notification: { title, body: message },
    };

    if (options.sound) {
      payload.webpush = {
        fcmOptions: { link: '/' },
        notification: {
          sound: options.sound,
        }
      };
      payload.apns = {
        payload: {
          aps: {
            sound: options.sound,
            alert: { title, body: message }
          }
        }
      };
      payload.android = {
        notification: {
          sound: options.sound,
          channelId: options.channelId || 'default'
        }
      };
    }

    await admin.messaging().send(payload);
  } catch (err) {
    console.error('Push error:', err.message);
  }
};

// Send SMS via TrueAfrican API
const sendSMS = async (phone, message) => {
  if (!phone) {
    console.warn('⚠️ SMS: No phone number provided');
    return;
  }
  try {
    console.log(`📱 SMS: Sending to ${phone}...`);
    const resp = await axios.post(
      process.env.SMS_API_URL,
      {
        username: process.env.SMS_API_USERNAME,
        password: process.env.SMS_API_PASSWORD,
        msisdn: phone,
        from: 'Sanlam',
        message,
      },
      { headers: { 'Content-Type': 'application/json' }, timeout: 15000 }
    );
    if (resp.data?.status === 'FAILED') {
      console.error(`❌ SMS FAILED to ${phone}:`, resp.data);
    } else {
      console.log(`✅ SMS sent to ${phone} - response:`, resp.data?.status || resp.status);
    }
  } catch (err) {
    console.error(`❌ SMS error for ${phone}:`, err.response?.data || err.message);
  }
};

// Send Email via corporate SMTP
const sendEmail = async (to, subject, html) => {
  if (!to) {
    console.warn('⚠️ Email: No recipient provided');
    return;
  }
  try {
    console.log(`📧 Email: Sending to ${to}...`);
    await transporter.sendMail({
      from: `"Sanlam Chronic Care" <${process.env.SMTP_USER}>`,
      to,
      subject,
      html,
    });
    console.log(`✅ Email sent to ${to}`);
  } catch (err) {
    console.error(`❌ Email error for ${to}:`, err.message);
  }
};

// Main: send to member across requested channels and log
const sendToMember = async (memberId, { type, title, message, channel = ['push'], fcmToken, phone, email, firstName, sound, channelId }) => {
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
        const pushOptions = {};
        if (sound) {
          pushOptions.sound = sound;
          if (channelId) pushOptions.channelId = channelId;
        }
        await sendPush(fcmToken, title, message, pushOptions);
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
