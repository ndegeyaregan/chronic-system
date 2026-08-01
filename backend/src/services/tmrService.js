/**
 * TMR Telehealth Integration Service
 *
 * TMR runs a telehealth platform where patients call in, get verified by
 * insurance, and have the consultation. This service lets Sanlam members
 * book directly from the Sanlam app without going to the TMR app.
 *
 * Before this booking reaches TMR, the Sanlam app already checks the
 * member's outpatient balance (via GetMemberPlanBenefit). The payload
 * we send to TMR includes `insuranceVerified: true` so the TMR team
 * skips their own benefits check and goes straight to consultation.
 *
 * ─── HOW TO WIRE UP ───────────────────────────────────────────────────────
 * 1. Add TMR credentials to .env:
 *      TMR_API_BASE_URL=https://api.tmr.example.com    ← replace with real URL
 *      TMR_API_KEY=<your-api-key>
 *
 * 2. Replace the TODO comments below with the actual endpoint paths and
 *    request/response field names that TMR provides.
 *
 * 3. Run the migration (057_hospitals_integration_type.sql) so the TMR
 *    hospital record has integration_type = 'tmr' in the DB.
 * ──────────────────────────────────────────────────────────────────────────
 */

const _axiosImport = require('axios');
const axios = _axiosImport.default ?? _axiosImport;

const TMR_BASE_URL = (process.env.TMR_API_BASE_URL || '').replace(/\/$/, '');
const TMR_API_KEY  = process.env.TMR_API_KEY || '';

/**
 * Book a telehealth appointment via TMR.
 *
 * Because the Sanlam app has already verified the member's outpatient
 * balance, we pass `insuranceVerified: true` so TMR skips re-verification.
 *
 * @param {Object} p
 * @param {string}  p.memberNumber       Sanlam member number
 * @param {string}  p.memberName         Full name
 * @param {string}  [p.memberPhone]      Contact phone
 * @param {string}  [p.memberEmail]      Contact email
 * @param {string}  p.appointmentDate    ISO 8601 date string
 * @param {string}  [p.preferredTime]    e.g. '09:00'
 * @param {string}  [p.condition]        Condition / reason for the call
 * @param {number}  p.outpatientBalance  Verified Sanlam outpatient balance (UGX)
 *
 * @returns {Promise<{ tmrBookingId: string|null, status: string, confirmedTime: string|null }>}
 */
async function bookTmrAppointment(p) {
  if (!TMR_BASE_URL) {
    throw new Error(
      'TMR_API_BASE_URL is not set. Add it to .env and restart the server.'
    );
  }

  // TODO: Confirm the exact endpoint path with the TMR team.
  const endpoint = `${TMR_BASE_URL}/appointments/book`;

  // TODO: Confirm field names, required vs optional, and date format with TMR.
  const payload = {
    memberNo:          p.memberNumber,
    memberName:        p.memberName,
    phone:             p.memberPhone  ?? null,
    email:             p.memberEmail  ?? null,
    appointmentDate:   p.appointmentDate,
    preferredTime:     p.preferredTime ?? null,
    complaint:         p.condition     ?? null,
    insuranceVerified: true,        // ← tells TMR to skip benefits re-check
    insurer:           'Sanlam',
    outpatientBalance: p.outpatientBalance ?? 0,
  };

  const response = await axios.post(endpoint, payload, {
    timeout: 10_000,
    headers: {
      // TODO: Confirm the auth scheme with TMR (Bearer, API-Key header, etc.)
      'Authorization': `Bearer ${TMR_API_KEY}`,
      'Content-Type':  'application/json',
    },
  });

  // TODO: Map the actual TMR response fields below.
  const data = response.data ?? {};
  return {
    tmrBookingId:  data.bookingId    ?? data.id            ?? data.appointmentId ?? null,
    status:        data.status       ?? data.bookingStatus ?? 'confirmed',
    confirmedTime: data.confirmedTime ?? data.time          ?? null,
  };
}

/**
 * Lightweight reachability check — call before booking if you want to
 * detect TMR outages early and show a helpful message to the member.
 *
 * TODO: Replace with TMR's actual health / ping endpoint.
 */
async function checkTmrHealth() {
  if (!TMR_BASE_URL) return false;
  try {
    // TODO: confirm the health endpoint path with TMR.
    await axios.get(`${TMR_BASE_URL}/health`, { timeout: 5_000 });
    return true;
  } catch {
    return false;
  }
}

module.exports = { bookTmrAppointment, checkTmrHealth };
