const axios = require('axios');
const pool = require('../config/db');
const { loginToSanlam } = require('./sanlamInstitutionSyncService');
const { sendToMember } = require('./notificationService');

const SANLAM_API_BASE =
  process.env.SANLAM_API_URL || 'https://ehosccs.net/SanlamMemberApi/api/member/';

const sanlamUrl = (path) =>
  SANLAM_API_BASE.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '');

// Threshold: a claim is considered "stuck" once it's been pending for 24h.
const PENDING_HOURS = 24;

const PENDING_STATUSES = new Set(['pending', 'in progress', 'in-progress', 'submitted']);

const isPendingStatus = (s) =>
  PENDING_STATUSES.has((s || '').toString().trim().toLowerCase());

// Mirrors the Flutter classifiers in app/lib/utils/benefit_forecast.dart
const isOutPatient = (t) => /OUT/i.test(t || '');
const isDental     = (t) => /DENTAL/i.test(t || '');
const isOptical    = (t) => /OPTICAL/i.test(t || '');
// Inpatient intentionally excluded — no notifications requested for it.

const principalNumber = (memberNo) => {
  if (!memberNo) return memberNo;
  const dash = memberNo.lastIndexOf('-');
  if (dash === -1) return memberNo;
  return `${memberNo.substring(0, dash)}-00`;
};

// Sanlam dates can come as "28 Apr 2026 | 00:00", "2026-04-28", "28/04/2026", etc.
const MONTHS = {
  jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
  jul: 6, aug: 7, sep: 8, sept: 8, oct: 9, nov: 10, dec: 11,
};
const parseFlexibleDate = (raw) => {
  if (!raw) return null;
  let s = raw.toString().trim();
  if (!s) return null;
  if (s.includes('|')) s = s.split('|')[0].trim();
  const iso = new Date(s);
  if (!isNaN(iso.getTime())) return iso;

  const tokens = s
    .replace(/[,\-/]+/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
  if (tokens.length >= 3) {
    let day, month, year;
    for (const t of tokens) {
      const lower = t.toLowerCase();
      if (lower in MONTHS) {
        if (month === undefined) month = MONTHS[lower];
      } else {
        const n = parseInt(t, 10);
        if (Number.isFinite(n)) {
          if (n >= 1900 && year === undefined) year = n;
          else if (day === undefined && n >= 1 && n <= 31) day = n;
          else if (month === undefined && n >= 1 && n <= 12) month = n - 1;
        }
      }
    }
    if (day !== undefined && month !== undefined && year !== undefined) {
      return new Date(year, month, day);
    }
  }
  return null;
};

const fetchVisitsForMember = async (token, memberNo) => {
  const principal = principalNumber(memberNo);
  const isPrincipal = memberNo === principal;
  const body = { MemberNo: principal };
  if (!isPrincipal) body.DependantNo = memberNo;
  try {
    const resp = await axios.post(
      sanlamUrl('GetVisitList'),
      body,
      { headers: { Authorization: `Bearer ${token}` }, timeout: 25000 }
    );
    const data = resp.data || {};
    if ((data.status || '').toString() !== 'OK') {
      const desc = (data.description || '').toString().toLowerCase();
      // Treat "no records" as empty rather than an error.
      if (desc.includes('not found') || desc.includes('no record')) return [];
      console.warn(`pending-claims: GetVisitList non-OK for ${memberNo}: ${data.description}`);
      return [];
    }
    return Array.isArray(data.data) ? data.data : (data.data ? [data.data] : []);
  } catch (err) {
    console.warn(`pending-claims: GetVisitList error for ${memberNo}: ${err.message}`);
    return [];
  }
};

const classifyClaim = (treatmentType) => {
  if (isOutPatient(treatmentType)) return 'outpatient';
  if (isDental(treatmentType))     return 'dental';
  if (isOptical(treatmentType))    return 'optical';
  return null; // inpatient / unknown — skip
};

const channelsFor = (cat) => {
  if (cat === 'outpatient' || cat === 'dental') return ['push', 'sms'];
  if (cat === 'optical') return ['push'];
  return [];
};

const buildMessage = (visit, cat) => {
  const claimNo = (visit.claimNo || visit.ClaimNo || '').toString().trim();
  const facility = (visit.institution || visit.Institution || '').toString().trim();
  const ref = claimNo ? ` (Claim ${claimNo})` : '';
  const where = facility ? ` at ${facility}` : '';
  const label = cat.charAt(0).toUpperCase() + cat.slice(1);
  return {
    title: 'Your claim is still pending',
    message: `Your ${label} claim${where}${ref} has been pending for over 24 hours. Sancare is following up; please contact sancare@ug.sanlamallianz.com for urgent queries.`,
  };
};

/**
 * Main entry point: scans all active members, finds pending claims older than
 * 24 hours, and sends one notification per (member, visit) pair using the
 * channel matrix (outpatient/dental → push+sms, optical → push only).
 *
 * Idempotent — uses the `claim_pending_alerts` table to dedupe.
 */
const checkPendingClaimsAndAlert = async () => {
  let token;
  try {
    token = await loginToSanlam();
  } catch (err) {
    console.error('pending-claims: cannot log into Sanlam:', err.message);
    return { processed: 0, alerted: 0, errors: 1 };
  }

  const membersRes = await pool.query(
    `SELECT id, member_number, first_name, fcm_token, phone, email
     FROM members
     WHERE is_active = TRUE AND member_number IS NOT NULL`
  );

  const cutoff = new Date(Date.now() - PENDING_HOURS * 60 * 60 * 1000);
  let alerted = 0;
  let processed = 0;
  let errors = 0;

  for (const m of membersRes.rows) {
    processed += 1;
    let visits;
    try {
      visits = await fetchVisitsForMember(token, m.member_number);
    } catch (err) {
      errors += 1;
      continue;
    }

    for (const v of visits) {
      const status = (v.claimStatus || v.ClaimStatus || '').toString();
      if (!isPendingStatus(status)) continue;

      const treatmentType = (v.treatmentType || v.TreatmentType || '').toString();
      const cat = classifyClaim(treatmentType);
      if (!cat) continue;

      const treatmentDate = parseFlexibleDate(v.treatmentDate || v.TreatmentDate);
      if (!treatmentDate || treatmentDate > cutoff) continue;

      const visitId = (v.visitId || v.VisitId || '').toString();
      if (!visitId) continue;

      // Dedupe: have we already alerted this member for this visit?
      const dup = await pool.query(
        'SELECT 1 FROM claim_pending_alerts WHERE member_id = $1 AND visit_id = $2',
        [m.id, visitId]
      );
      if (dup.rowCount) continue;

      const channels = channelsFor(cat);
      const { title, message } = buildMessage(v, cat);

      try {
        await sendToMember(m.id, {
          type: 'claim',
          title,
          message,
          channel: channels,
          fcmToken: m.fcm_token,
          phone: m.phone,
          email: m.email,
          firstName: m.first_name,
        });
        await pool.query(
          `INSERT INTO claim_pending_alerts
             (member_id, visit_id, claim_no, claim_type, alerted_channels)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (member_id, visit_id) DO NOTHING`,
          [
            m.id,
            visitId,
            (v.claimNo || v.ClaimNo || '').toString() || null,
            cat,
            channels,
          ]
        );
        alerted += 1;
      } catch (err) {
        errors += 1;
        console.error(`pending-claims: send failed for ${m.member_number}/${visitId}: ${err.message}`);
      }
    }
  }

  console.log(`pending-claims: processed=${processed} alerted=${alerted} errors=${errors}`);
  return { processed, alerted, errors };
};

module.exports = { checkPendingClaimsAndAlert };
