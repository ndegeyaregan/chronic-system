#!/usr/bin/env node
/*
 * Background worker for parsing claims Excel files.
 * Spawned as a detached child process by claimsAnalysisController so the
 * parse (which can allocate 2–3 GB for a 70 MB xlsx) runs in its own
 * V8 heap and cannot block or OOM the main API process.
 *
 * Usage: node --max-old-space-size=4096 claimsParserWorker.js <uploadId> <filepath>
 *
 * NOTE on dense mode: when xlsx is read with { dense: true }, cells live
 * directly on the worksheet as ws[rowIdx][colIdx] (numeric keys on ws
 * point at row arrays). This uses far less memory than the default
 * sparse form (which keys every cell as ws["A1"], ws["B1"] ...).
 */
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const fs = require('fs');
const XLSX = require('xlsx');
const pool = require('../config/db');

const [, , uploadId, filepath] = process.argv;
if (!uploadId || !filepath) {
  console.error('Usage: claimsParserWorker.js <uploadId> <filepath>');
  process.exit(2);
}

/* ── helpers ── */
const normKey = (s) => String(s ?? '').trim().toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');

const pickField = (row, candidates) => {
  for (const c of candidates) {
    const k = normKey(c);
    if (row[k] !== undefined && row[k] !== null && String(row[k]).trim() !== '') return row[k];
  }
  return null;
};

const toDate = (v) => {
  if (v === null || v === undefined || v === '') return null;
  if (v instanceof Date) return isNaN(v.getTime()) ? null : v;
  if (typeof v === 'number') {
    const d = XLSX.SSF && XLSX.SSF.parse_date_code(v);
    if (d) return new Date(Date.UTC(d.y, d.m - 1, d.d, d.H || 0, d.M || 0, Math.floor(d.S || 0)));
  }
  const s = String(v).trim();
  const t = Date.parse(s);
  if (!isNaN(t)) return new Date(t);
  // dd/mm/yyyy fallback
  const dmy = s.match(/^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})/);
  if (dmy) {
    let [, d, m, y] = dmy;
    if (y.length === 2) y = (Number(y) > 50 ? '19' : '20') + y;
    return new Date(`${y}-${m.padStart(2,'0')}-${d.padStart(2,'0')}`);
  }
  return null;
};

const toDateOnly = (v) => {
  const d = toDate(v);
  return d ? d.toISOString().slice(0, 10) : null;
};

// Combine a Create_Date (which may already be a full timestamp) with a
// Create_Time (which may be "HH:MM:SS" or another date). If we already have
// a timestamp in the date field, prefer it.
const toTimestamp = (dateVal, timeVal) => {
  const d = toDate(dateVal);
  if (!d) return null;
  // If timeVal looks like "HH:MM" or "HH:MM:SS", layer it onto the date
  if (typeof timeVal === 'string') {
    const m = timeVal.trim().match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?/);
    if (m) {
      d.setUTCHours(Number(m[1]), Number(m[2]), Number(m[3] || 0), 0);
    }
  } else if (timeVal instanceof Date && !isNaN(timeVal.getTime())) {
    // If timeVal is a Date with sensible hours, copy time-of-day from it
    d.setUTCHours(timeVal.getUTCHours(), timeVal.getUTCMinutes(), timeVal.getUTCSeconds(), 0);
  }
  return d.toISOString();
};

const toAmount = (v) => {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return v;
  const n = parseFloat(String(v).replace(/[^0-9.\-]/g, ''));
  return isNaN(n) ? null : n;
};

const toStr = (v, max = 500) => {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  if (!s) return null;
  return s.length > max ? s.slice(0, max) : s;
};

/* ── column synonyms (matched on normalised header) ── */
const F = {
  date:        ['treatment_date', 'claim_date', 'date', 'service_date', 'visit_date', 'date_of_service'],
  claim_no:    ['claimno', 'claim_no', 'claim_number'],
  invoice_no:  ['invoiceno', 'invoice_no', 'invoice_number'],
  claim_type:  ['claimtype', 'claim_type'],
  illness_type:['illnesstype', 'illness_type'],
  pay_to:      ['payto', 'pay_to'],
  corp_id:     ['corpid', 'corp_id'],
  scheme:      ['corporate', 'scheme', 'scheme_name', 'company', 'employer'],
  provider:    ['institution', 'provider', 'hospital', 'facility', 'provider_name'],
  // ClaimType (OutPatient / InPatient / etc) is what the user filters
  // "provider type" by, so promote it into provider_type as well.
  provider_type:['claimtype', 'claim_type', 'provider_type', 'institution_type', 'facility_type', 'type'],
  member_no:   ['memberno', 'member_no', 'member_number', 'membership_no', 'member_id'],
  member_name: ['membername', 'member_name', 'patient_name', 'beneficiary'],
  benefit_plan:['benplanname', 'benefit_plan', 'plan', 'plan_name'],
  relation:    ['relation', 'relationship'],
  active:      ['active', 'status', 'member_status'],
  visit_reason:['visitreason', 'visit_reason', 'reason'],
  diagnosis:   ['diagnosis', 'diagnoses', 'condition', 'ailment'],
  diagnosis_code:['diagnosiscode', 'diagnosis_code', 'icd', 'icd_code', 'icd10'],
  amount:      ['procharges', 'pro_charges', 'amount', 'charge', 'charges', 'cost', 'claim_amount', 'gross_amount'],
  base_price:  ['baseprice', 'base_price'],
  overcharges: ['overcharges', 'overcharge'],
  payable_amount:['payableamount', 'payable_amount', 'paid_amount', 'net_amount'],
  copay:       ['copay', 'co_pay', 'copayment'],
  provider_note:['providernote', 'provider_note'],
  claim_status:['claimstatus', 'claim_status', 'status'],
  create_date: ['create_date', 'createddate', 'created_date'],
  create_time: ['create_time', 'createdtime', 'created_time'],
  created_by:  ['createdby', 'created_by'],
  checkout_date:['checkout_date', 'checkoutdate'],
  checkout_time:['checkout_time', 'checkouttime'],
  update_date: ['update_date', 'updateddate'],
  update_time: ['updated_time', 'update_time'],
  processed_by:['processedby', 'processed_by'],
  payment_date:['payment_date', 'paymentdate'],
  paid_by:     ['paidby', 'paid_by'],
  cancel_reason:['cancelreason', 'cancel_reason'],
  agent_note:  ['agentnote', 'agent_note'],
};

const log = (msg, extra) => console.log(`[claims-worker ${uploadId}] ${msg}`, extra ? JSON.stringify(extra) : '');

(async () => {
  let totalAmount = 0;
  let rowCount = 0;
  let headers = [];
  try {
    const stat = fs.statSync(filepath);
    log('starting parse', { sizeBytes: stat.size });

    const wb = XLSX.readFile(filepath, {
      cellDates: true,
      cellHTML: false,
      cellFormula: false,
      cellNF: false,
      cellStyles: false,
      sheetStubs: false,
      dense: true,
    });
    log('workbook loaded', { sheets: wb.SheetNames });

    const ws = wb.Sheets[wb.SheetNames[0]];
    const range = XLSX.utils.decode_range(ws['!ref'] || 'A1');
    log('sheet range', { ref: ws['!ref'] });

    // Dense form: ws[rowIdx] is an array of cells indexed by col.
    const rowArr = (r) => ws[r];  // may be undefined for empty rows
    const cellVal = (r, c) => {
      const row = rowArr(r);
      if (!row) return null;
      const cell = row[c];
      if (!cell) return null;
      return cell.v !== undefined ? cell.v : null;
    };

    // Detect header row from the first 15 rows
    let headerRowIdx = range.s.r;
    let bestScore = 0;
    const sampleRows = [];
    for (let r = range.s.r; r <= Math.min(range.s.r + 14, range.e.r); r++) {
      const row = [];
      for (let c = range.s.c; c <= range.e.c; c++) row.push(cellVal(r, c));
      sampleRows.push(row);
      const score = row.filter((x) => typeof x === 'string' && x.trim()).length;
      if (score > bestScore) { bestScore = score; headerRowIdx = r; }
    }
    const headerCells = [];
    for (let c = range.s.c; c <= range.e.c; c++) headerCells.push(cellVal(headerRowIdx, c));
    headers = headerCells.map((h, i) => String(h ?? '').trim() || `Column ${i + 1}`);
    const normHeaders = headers.map(normKey);
    log('headers detected', { headerRowIdx, count: headers.length });

    // Persist columns immediately so the frontend sees them while inserts run
    await pool.query(
      `UPDATE claim_uploads SET columns = $1::jsonb, updated_at = NOW() WHERE id = $2`,
      [JSON.stringify(headers), uploadId]
    );

    const COL_COUNT = 36; // matches INSERT below
    const dataStart = headerRowIdx + 1;
    const BATCH = 800;
    let batchRows = [];

    const flushBatch = async () => {
      if (!batchRows.length) return;
      const values = [];
      const params = [];
      let p = 1;
      for (const obj of batchRows) {
        const claimDate    = toDateOnly(pickField(obj, F.date));
        const provider     = toStr(pickField(obj, F.provider), 300);
        const providerType = toStr(pickField(obj, F.provider_type), 100);
        const scheme       = toStr(pickField(obj, F.scheme), 300);
        const memberName   = toStr(pickField(obj, F.member_name), 300);
        const memberNo     = toStr(pickField(obj, F.member_no), 100);
        const diagnosis    = toStr(pickField(obj, F.diagnosis), 500);
        const amount       = toAmount(pickField(obj, F.amount)) ?? 0;
        const claimNo      = toStr(pickField(obj, F.claim_no), 100);
        const invoiceNo    = toStr(pickField(obj, F.invoice_no), 100);
        const claimType    = toStr(pickField(obj, F.claim_type), 50);
        const illnessType  = toStr(pickField(obj, F.illness_type), 50);
        const payTo        = toStr(pickField(obj, F.pay_to), 100);
        const corpId       = toStr(pickField(obj, F.corp_id), 100);
        const relation     = toStr(pickField(obj, F.relation), 50);
        const benefitPlan  = toStr(pickField(obj, F.benefit_plan), 200);
        const active       = toStr(pickField(obj, F.active), 50);
        const visitReason  = toStr(pickField(obj, F.visit_reason), 500);
        const diagnosisCode= toStr(pickField(obj, F.diagnosis_code), 100);
        const basePrice    = toAmount(pickField(obj, F.base_price));
        const overcharges  = toAmount(pickField(obj, F.overcharges));
        const payable      = toAmount(pickField(obj, F.payable_amount));
        const copay        = toAmount(pickField(obj, F.copay));
        const claimStatus  = toStr(pickField(obj, F.claim_status), 50);
        const createAt     = toTimestamp(pickField(obj, F.create_date), pickField(obj, F.create_time));
        const checkoutAt   = toTimestamp(pickField(obj, F.checkout_date), pickField(obj, F.checkout_time));
        const updateAt     = toTimestamp(pickField(obj, F.update_date), pickField(obj, F.update_time));
        const paymentDate  = toDateOnly(pickField(obj, F.payment_date));
        const createdBy    = toStr(pickField(obj, F.created_by), 200);
        const processedBy  = toStr(pickField(obj, F.processed_by), 200);
        const paidBy       = toStr(pickField(obj, F.paid_by), 200);
        const cancelReason = toStr(pickField(obj, F.cancel_reason), 500);
        const agentNote    = toStr(pickField(obj, F.agent_note), 1000);
        const providerNote = toStr(pickField(obj, F.provider_note), 1000);

        totalAmount += amount;

        const placeholders = [];
        for (let i = 0; i < COL_COUNT; i++) placeholders.push(`$${p++}`);
        values.push(`(${placeholders.join(',')})`);

        params.push(
          uploadId, claimDate, provider, providerType, scheme, memberName, memberNo,
          diagnosis, amount, JSON.stringify(obj),
          claimNo, invoiceNo, claimType, illnessType, payTo, corpId, relation,
          benefitPlan, active, visitReason, diagnosisCode,
          basePrice, overcharges, payable, copay,
          claimStatus, createAt, checkoutAt, updateAt, paymentDate,
          createdBy, processedBy, paidBy, cancelReason, agentNote, providerNote
        );
      }
      await pool.query(
        `INSERT INTO claims (
           upload_id, claim_date, provider, provider_type, scheme, member_name, member_no,
           diagnosis, amount, raw,
           claim_no, invoice_no, claim_type, illness_type, pay_to, corp_id, relation,
           benefit_plan, active, visit_reason, diagnosis_code,
           base_price, overcharges, payable_amount, copay,
           claim_status, create_at, checkout_at, update_at, payment_date,
           created_by, processed_by, paid_by, cancel_reason, agent_note, provider_note
         ) VALUES ${values.join(',')}`,
        params
      );
      batchRows = [];
    };

    for (let r = dataStart; r <= range.e.r; r++) {
      const row = rowArr(r);
      if (!row) continue;
      const obj = {};
      let hasAny = false;
      for (let c = range.s.c; c <= range.e.c; c++) {
        const cell = row[c];
        const v = cell ? (cell.v !== undefined ? cell.v : null) : null;
        if (v !== null && v !== '' && v !== undefined) hasAny = true;
        const key = normHeaders[c - range.s.c];
        if (key) obj[key] = v;
      }
      if (!hasAny) continue;
      batchRows.push(obj);
      rowCount++;
      if (batchRows.length >= BATCH) {
        await flushBatch();
        if (rowCount % 10000 === 0) {
          log('progress', { rowCount });
          await pool.query(
            `UPDATE claim_uploads SET row_count = $1, total_amount = $2, updated_at = NOW() WHERE id = $3`,
            [rowCount, totalAmount, uploadId]
          );
        }
      }
    }
    await flushBatch();

    await pool.query(
      `UPDATE claim_uploads
         SET row_count = $1, total_amount = $2, status = 'ready', updated_at = NOW()
         WHERE id = $3`,
      [rowCount, totalAmount, uploadId]
    );
    log('done', { rowCount, totalAmount });
    fs.unlink(filepath, () => {});
    process.exit(0);
  } catch (err) {
    log('FAILED', { error: err.message, stack: err.stack?.split('\n').slice(0, 3) });
    try {
      await pool.query(
        `UPDATE claim_uploads SET status = 'failed', error = $1, row_count = $2, updated_at = NOW() WHERE id = $3`,
        [String(err.message || err).slice(0, 1000), rowCount, uploadId]
      );
    } catch (_) { /* ignore */ }
    fs.unlink(filepath, () => {});
    process.exit(1);
  }
})();
