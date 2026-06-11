const axios = require('axios');
const pool = require('../config/db');
const { loginToSanlam } = require('./sanlamInstitutionSyncService');
const { sendToMember } = require('./notificationService');

const SANLAM_API_BASE =
  process.env.SANLAM_API_URL || 'https://ehosccs.net/SanlamMemberApi/api/member/';

const sanlamUrl = (path) =>
  SANLAM_API_BASE.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '');

// Statuses we want to push for. We notify on the first appearance of each.
const NOTIFY_STATUSES = new Set(['open', 'approved', 'rejected']);

const normStatus = (s) => {
  const v = (s || '').toString().trim().toLowerCase();
  if (v === 'pending') return 'open';
  if (v === 'declined') return 'rejected';
  return v;
};

// Pull MemberNo / claimNo / status / etc from a Sanlam response row,
// tolerating both PascalCase and camelCase keys.
const pickField = (row, keys) => {
  for (const k of keys) {
    const v = row[k];
    if (v !== undefined && v !== null && v.toString().trim() !== '') {
      return v.toString().trim();
    }
  }
  return '';
};

const fetchPreauthsForMember = async (token, memberNo) => {
  try {
    const resp = await axios.post(
      sanlamUrl('GetPreAuthRequests'),
      { MemberNo: memberNo },
      { headers: { Authorization: `Bearer ${token}` }, timeout: 25000 }
    );
    const data = resp.data || {};
    const status = (data.status || '').toString();
    if (status !== 'OK') {
      const desc = (data.description || '').toString().toLowerCase();
      if (desc.includes('not found') || desc.includes('no record')) return [];
      console.warn(`preauth-instant: GetPreAuthRequests non-OK for ${memberNo}: ${data.description}`);
      return [];
    }
    const arr = data.data;
    if (!arr) return [];
    return Array.isArray(arr) ? arr : [arr];
  } catch (err) {
    console.warn(`preauth-instant: GetPreAuthRequests error for ${memberNo}: ${err.message}`);
    return [];
  }
};

const buildMessage = (statusLower, row) => {
  const condition = pickField(row, ['Description', 'description', 'Diagnosis', 'diagnosis']);
  const condLabel = condition ? ` for ${condition}` : '';

  if (statusLower === 'approved') {
    const amt = pickField(row, ['ApprovedAmount', 'approvedAmount']);
    let body = `Your pre-authorisation${condLabel} has been approved.`;
    if (amt && parseFloat(amt) > 0) {
      body += ` Approved up to UGX ${parseFloat(amt).toFixed(0)}.`;
    }
    return { title: '✅ Pre-authorisation approved', message: body };
  }
  if (statusLower === 'rejected') {
    const note = pickField(row, ['InsurerNote', 'insurerNote', 'Note', 'note']);
    let body = `Your pre-authorisation${condLabel} has been rejected.`;
    if (note) body += ` Note: ${note}`;
    return { title: '❌ Pre-authorisation rejected', message: body };
  }
  // Open
  return {
    title: '📨 Pre-authorisation received',
    message: `Your pre-authorisation request${condLabel} has been received and is being reviewed. We'll notify you as soon as a decision is made.`,
  };
};

/**
 * Polls Sanlam's GetPreAuthRequests endpoint for every active member,
 * inserts any pre-auth (member_no, request_no, status) tuples we haven't
 * seen before into preauth_events, and fires a push notification for each
 * newly seen Open / Approved / Rejected event.
 *
 * Idempotent: the unique constraint on preauth_events
 * (member_no, request_no, status) guarantees we only notify once per
 * (member, request, status).
 *
 * First-time seeding: if a member has zero rows in preauth_events,
 * existing pre-auths are recorded silently (no notifications) so the
 * first run after deployment doesn't blast people about old history.
 */
const checkPreauthsAndAlert = async () => {
  let token;
  try {
    token = await loginToSanlam();
  } catch (err) {
    console.error('preauth-instant: cannot log into Sanlam:', err.message);
    return { processed: 0, alerted: 0, errors: 1 };
  }

  const membersRes = await pool.query(
    `SELECT id, member_number, first_name, fcm_token, phone, email
     FROM members
     WHERE is_active = TRUE AND member_number IS NOT NULL`
  );

  let alerted = 0;
  let processed = 0;
  let errors = 0;

  for (const m of membersRes.rows) {
    processed += 1;
    const rows = await fetchPreauthsForMember(token, m.member_number);
    if (!rows.length) continue;

    // First-run seeding flag — if we've never recorded a preauth for this
    // member, treat all current items as historical.
    const hasHistory = await pool.query(
      'SELECT 1 FROM preauth_events WHERE member_no = $1 LIMIT 1',
      [m.member_number]
    );
    const isFirstSeed = hasHistory.rowCount === 0;

    for (const r of rows) {
      const statusLower = normStatus(pickField(r, ['Status', 'status']));
      if (!NOTIFY_STATUSES.has(statusLower)) continue;

      const requestNo = pickField(r, ['claimNo', 'ClaimNo', 'claim_no']);
      if (!requestNo) continue;

      const approvedAmtRaw = pickField(r, ['ApprovedAmount', 'approvedAmount']);
      const approvedAmt = approvedAmtRaw ? parseFloat(approvedAmtRaw) || null : null;
      const condition = pickField(r, ['Description', 'description', 'Diagnosis', 'diagnosis']);
      const provider = pickField(r, ['ProviderName', 'providerName', 'Institution', 'institution']);

      let inserted;
      try {
        inserted = await pool.query(
          `INSERT INTO preauth_events
             (member_no, request_no, status, approved_amount, decided_at, provider_name, condition)
           VALUES ($1, $2, $3, $4, NULL, $5, $6)
           ON CONFLICT (member_no, request_no, status) DO NOTHING
           RETURNING id`,
          [
            m.member_number,
            requestNo,
            statusLower,
            approvedAmt,
            provider || null,
            condition || null,
          ]
        );
      } catch (insertErr) {
        errors += 1;
        console.error(`preauth-instant: insert failed for ${m.member_number}/${requestNo}: ${insertErr.message}`);
        continue;
      }

      // Nothing inserted → we've already notified for this (member, request, status)
      if (!inserted.rowCount) continue;

      // First seeding — recorded but don't push.
      if (isFirstSeed) continue;

      const { title, message } = buildMessage(statusLower, r);
      try {
        await sendToMember(m.id, {
          type: 'preauth',
          title,
          message,
          channel: ['push'],
          fcmToken: m.fcm_token,
          phone: m.phone,
          email: m.email,
          firstName: m.first_name,
        });
        alerted += 1;
      } catch (pushErr) {
        errors += 1;
        console.warn(`preauth-instant: push failed for ${m.member_number}/${requestNo}: ${pushErr.message}`);
      }
    }
  }

  console.log(`preauth-instant: processed=${processed} alerted=${alerted} errors=${errors}`);
  return { processed, alerted, errors };
};

module.exports = { checkPreauthsAndAlert };
