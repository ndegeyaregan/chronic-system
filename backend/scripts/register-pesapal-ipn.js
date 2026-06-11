/**
 * One-off helper: registers our IPN URL with Pesapal and prints the IPN ID.
 * Add the printed value to .env as PESAPAL_IPN_ID, then restart the API.
 *
 *   node scripts/register-pesapal-ipn.js
 */
require('dotenv').config();
const pesapal = require('../src/services/pesapalService');

(async () => {
  try {
    const ipnUrl =
      process.argv[2] ||
      `${process.env.PUBLIC_API_BASE_URL || 'https://app.sanlamallianz4u.co.ug/api'}/pesapal/ipn`;
    console.log('Registering Pesapal IPN URL:', ipnUrl);
    const id = await pesapal.registerIpn(ipnUrl);
    console.log('\n✅ Success.\nAdd this to backend/.env:\n');
    console.log(`PESAPAL_IPN_ID=${id}\n`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Failed:', err.response?.data || err.message);
    process.exit(1);
  }
})();
