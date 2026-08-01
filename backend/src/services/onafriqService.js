// Onafriq (MFS Africa) Collection Requests API
//
// A "collection request" is a pay-in request: we ask a customer's mobile
// money wallet for funds, and on supported networks the customer simply
// enters their PIN on a USSD prompt to approve it -- no manual USSD dialing
// or screenshot proof required.
//
// Docs: https://developers.onafriq.com (Collection Requests API)
//
// Sandbox vs live --------------------------------------------------------
// ONAFRIQ_API_KEY defaults to Onafriq's public test token and
// ONAFRIQ_CURRENCY defaults to BXC (their test currency). In sandbox mode,
// only numbers in the +800XXXXXXXX test format receive a (simulated) PIN
// prompt -- real Ugandan numbers will not work until this is switched to a
// live API key with ONAFRIQ_CURRENCY=UGX.

const _axiosImport = require('axios');
const axios = _axiosImport.default ?? _axiosImport;

const API_URL = (process.env.ONAFRIQ_API_URL || 'https://api.onafriq.com/api').replace(/\/$/, '');
const API_KEY = process.env.ONAFRIQ_API_KEY || 'ab594c14986612f6167a975e1c369e71edab6900';
const CURRENCY = process.env.ONAFRIQ_CURRENCY || 'BXC';
const SANDBOX_AMOUNT = Number(process.env.ONAFRIQ_SANDBOX_AMOUNT || 500);

const client = axios.create({
  baseURL: API_URL,
  timeout: 15_000,
  headers: {
    Authorization: `Token ${API_KEY}`,
    'Content-Type': 'application/json',
  },
});

// True while running against Onafriq's BXC sandbox rather than live currency.
const isSandbox = () => CURRENCY === 'BXC';

// The amount to actually charge Onafriq with, given the current currency.
// BXC sandbox only accepts 10-1000; live UGX uses the real fee amount.
const resolveAmount = (liveAmount) => (isSandbox() ? SANDBOX_AMOUNT : liveAmount);

// Creates a pay-in ("collection") request, triggering a USSD PIN prompt
// on the customer's phone on supported networks.
//   phonenumber          International format, e.g. +2567...
//   liveAmount           The real amount to charge in production currency
//   reason               Short reason shown to the customer (keep under 20 chars)
//   partnerTransactionId Our own reference (card_reprint_requests.id)
// Returns the Onafriq collection request object.
const createCollectionRequest = async ({ phonenumber, liveAmount, reason, partnerTransactionId }) => {
  const { data } = await client.post('/collectionrequests', {
    phonenumber,
    amount: resolveAmount(liveAmount),
    currency: CURRENCY,
    reason,
    send_instructions: true,
    partner_transaction_id: partnerTransactionId,
  });
  return data;
};

// Fetches the current status of a previously created collection request.
const getCollectionRequest = async (onafriqRequestId) => {
  const { data } = await client.get(`/collectionrequests/${onafriqRequestId}`);
  return data;
};

module.exports = {
  createCollectionRequest,
  getCollectionRequest,
  isSandbox,
  CURRENCY,
};
