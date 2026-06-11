const axios = require('axios');
const pool = require('../config/db');
const { upsertSanlamInstitutions } = require('../controllers/institutionsController');

const SANLAM_API_BASE =
  process.env.SANLAM_API_URL || 'https://ehosccs.net/SanlamMemberApi/api/member/';
const SYNC_USERNAME = process.env.SANLAM_SYNC_USERNAME;
const SYNC_PASSWORD = process.env.SANLAM_SYNC_PASSWORD;

if (!SYNC_USERNAME || !SYNC_PASSWORD) {
  console.warn(
    '[sanlamInstitutionSyncService] SANLAM_SYNC_USERNAME / SANLAM_SYNC_PASSWORD ' +
      'are not set — institution sync will fail until they are configured.'
  );
}

const sanlamUrl = (path) =>
  SANLAM_API_BASE.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '');

/**
 * Logs into the Sanlam Member API with the configured service member
 * credentials and returns the bearer token.
 */
const loginToSanlam = async () => {
  const resp = await axios.post(
    sanlamUrl('login'),
    { username: SYNC_USERNAME, password: SYNC_PASSWORD },
    { timeout: 20000 }
  );
  const data = resp.data || {};
  if ((data.status || '').toString() !== 'OK') {
    throw new Error(
      `Sanlam login failed: ${data.description || JSON.stringify(data)}`
    );
  }
  // Token shape from /login → { status:'OK', data:{ ...member, token: '...' } }
  // or sometimes `data.data.Token`. Try the common variants.
  const payload = data.data || {};
  const token =
    payload.token || payload.Token || payload.accessToken || payload.access_token;
  if (!token) {
    throw new Error('Sanlam login: no token in response');
  }
  return token;
};

/**
 * Pulls the full institution list from the Sanlam Member API using the
 * configured service member credentials, then upserts everything into
 * the local DB via the shared controller helper.
 *
 * Records the outcome in `system_state` so the admin can see when the
 * last automated sync ran.
 */
const syncInstitutionsFromSanlam = async () => {
  const startedAt = new Date();
  let token;
  try {
    token = await loginToSanlam();
  } catch (err) {
    await recordOutcome('error', `login: ${err.message}`, startedAt);
    throw err;
  }

  let raw;
  try {
    const resp = await axios.post(
      sanlamUrl('searchInstitution'),
      {},
      {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 60000,
      }
    );
    const data = resp.data || {};
    if ((data.status || '').toString() !== 'OK') {
      const desc = (data.description || '').toString().toLowerCase();
      const looksEmpty =
        desc.includes('not found') ||
        desc.includes('no record') ||
        /\bno\b.*\b(found|exist|available)\b/.test(desc);
      if (!looksEmpty) {
        throw new Error(
          `searchInstitution failed: ${data.description || JSON.stringify(data)}`
        );
      }
      raw = [];
    } else {
      raw = Array.isArray(data.data) ? data.data : data.data ? [data.data] : [];
    }
  } catch (err) {
    await recordOutcome('error', `fetch: ${err.message}`, startedAt);
    throw err;
  }

  let result;
  try {
    result = await upsertSanlamInstitutions(raw);
  } catch (err) {
    await recordOutcome('error', `upsert: ${err.message}`, startedAt);
    throw err;
  }

  await recordOutcome(
    'ok',
    `received=${result.received} hospitals=${result.hospitals_upserted} pharmacies=${result.pharmacies_upserted} skipped=${result.skipped}`,
    startedAt
  );
  return result;
};

const recordOutcome = async (status, detail, startedAt) => {
  try {
    const value = JSON.stringify({
      status,
      detail,
      started_at: startedAt.toISOString(),
      finished_at: new Date().toISOString(),
    });
    await pool.query(
      `INSERT INTO system_state (key, value, applied_at)
       VALUES ('sanlam_institution_sync_last_run', $1, NOW())
       ON CONFLICT (key) DO UPDATE
         SET value = EXCLUDED.value,
             applied_at = EXCLUDED.applied_at`,
      [value]
    );
  } catch (err) {
    // Don't let bookkeeping failures mask the real outcome.
    console.error('Failed to record sync outcome:', err.message);
  }
};

module.exports = {
  syncInstitutionsFromSanlam,
  loginToSanlam,
};
