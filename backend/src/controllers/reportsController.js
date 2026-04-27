const pool = require('../config/db');

const escapeCsv = (value) => {
  if (value === null || value === undefined) return '';
  const stringValue = `${value}`;
  return /[",\n]/.test(stringValue)
    ? `"${stringValue.replace(/"/g, '""')}"`
    : stringValue;
};

const formatDate = (value) => (
  value ? new Date(value).toISOString().split('T')[0] : ''
);

/* ─────────────────── DATA FETCHERS ─────────────────── */

const getMembersReportRows = async () => {
  const result = await pool.query(
    `SELECT m.id, m.member_number, m.first_name, m.last_name, m.email, m.phone,
            m.plan_type, m.date_of_birth, m.gender, m.is_active, m.created_at,
            COALESCE(array_remove(array_agg(DISTINCT c.name), NULL), ARRAY[]::VARCHAR[]) AS conditions
     FROM members m
     LEFT JOIN member_conditions mc ON mc.member_id = m.id
     LEFT JOIN conditions c ON c.id = mc.condition_id
     GROUP BY m.id ORDER BY m.created_at DESC`
  );
  return result.rows.map((row) => ({
    ...row,
    plan: row.plan_type,
    conditions: row.conditions || [],
  }));
};

const getAuthorizationsReportRows = async ({ start_date, end_date } = {}) => {
  const params = [];
  let where = '';
  if (start_date) { params.push(start_date); where += ` AND ar.created_at >= $${params.length}`; }
  if (end_date)   { params.push(end_date);   where += ` AND ar.created_at <= $${params.length}`; }
  const result = await pool.query(
    `SELECT ar.id, m.member_number,
            m.first_name || ' ' || m.last_name AS member_name,
            ar.request_type, ar.provider_type, ar.provider_name,
            ar.status, ar.notes, ar.admin_comments,
            ar.scheduled_date, ar.reviewed_at, ar.created_at,
            CONCAT(a.first_name, ' ', a.last_name) AS reviewed_by_name
     FROM authorization_requests ar
     JOIN members m ON m.id = ar.member_id
     LEFT JOIN admins a ON a.id = ar.reviewed_by
     WHERE 1=1 ${where}
     ORDER BY ar.created_at DESC`,
    params
  );
  return result.rows;
};

const getLabTestsReportRows = async ({ start_date, end_date, status } = {}) => {
  const params = [];
  const conds = [];
  if (status)     { params.push(status);     conds.push(`lt.status = $${params.length}`); }
  if (start_date) { params.push(start_date); conds.push(`lt.due_date >= $${params.length}`); }
  if (end_date)   { params.push(end_date);   conds.push(`lt.due_date <= $${params.length}`); }
  const where = conds.length ? 'WHERE ' + conds.join(' AND ') : '';
  const result = await pool.query(
    `SELECT m.member_number, m.first_name || ' ' || m.last_name AS member_name,
            lt.test_type, lt.due_date, lt.scheduled_date,
            lt.status, lt.completed_at, lt.result_notes, lt.result_file_url,
            lt.created_at
     FROM lab_tests lt
     JOIN members m ON m.id = lt.member_id
     ${where}
     ORDER BY lt.due_date ASC`,
    params
  );
  return result.rows;
};

const getPrescriptionsReportRows = async ({ start_date, end_date } = {}) => {
  const params = [];
  let where = '';
  if (start_date) { params.push(start_date); where += ` AND mm.created_at >= $${params.length}`; }
  if (end_date)   { params.push(end_date);   where += ` AND mm.created_at <= $${params.length}`; }
  const result = await pool.query(
    `SELECT m.member_number, m.first_name || ' ' || m.last_name AS member_name,
            med.name AS medication_name, med.generic_name,
            mm.dosage, mm.frequency, mm.start_date, mm.end_date,
            mm.next_refill_date, mm.refill_interval_days,
            CASE WHEN mm.end_date IS NULL OR mm.end_date >= CURRENT_DATE THEN 'Active' ELSE 'Inactive' END AS active_status,
            mm.notes, mm.created_at
     FROM member_medications mm
     JOIN members m ON m.id = mm.member_id
     JOIN medications med ON med.id = mm.medication_id
     WHERE 1=1 ${where}
     ORDER BY m.member_number, mm.created_at DESC`,
    params
  );
  return result.rows;
};

const getTreatmentPlansReportRows = async ({ start_date, end_date, status } = {}) => {
  const params = [];
  const conds = [];
  if (status)     { params.push(status);     conds.push(`tp.status = $${params.length}`); }
  if (start_date) { params.push(start_date); conds.push(`tp.plan_date >= $${params.length}`); }
  if (end_date)   { params.push(end_date);   conds.push(`tp.plan_date <= $${params.length}`); }
  const where = conds.length ? 'WHERE ' + conds.join(' AND ') : '';
  const result = await pool.query(
    `SELECT m.member_number, m.first_name || ' ' || m.last_name AS member_name,
            c.name AS condition_name, tp.title, tp.status, tp.provider_name,
            tp.plan_date, tp.cost, tp.currency, tp.description, tp.created_at
     FROM treatment_plans tp
     JOIN members m ON m.id = tp.member_id
     LEFT JOIN conditions c ON c.id = tp.condition_id
     ${where}
     ORDER BY tp.plan_date DESC`,
    params
  );
  return result.rows;
};

const getAppointmentsReportRows = async ({ start_date, end_date, status } = {}) => {
  const params = [];
  const conds = [];
  if (status)     { params.push(status);     conds.push(`a.status = $${params.length}`); }
  if (start_date) { params.push(start_date); conds.push(`a.appointment_date >= $${params.length}`); }
  if (end_date)   { params.push(end_date);   conds.push(`a.appointment_date <= $${params.length}`); }
  const where = conds.length ? 'WHERE ' + conds.join(' AND ') : '';
  const result = await pool.query(
    `SELECT m.member_number, m.first_name || ' ' || m.last_name AS member_name,
            h.name AS hospital_name, c.name AS condition_name,
            a.appointment_date, a.preferred_time, a.status, a.reason,
            a.confirmed_date, a.notes, a.created_at
     FROM appointments a
     JOIN members m ON m.id = a.member_id
     LEFT JOIN hospitals h ON h.id = a.hospital_id
     LEFT JOIN conditions c ON c.id = a.condition_id
     ${where}
     ORDER BY a.appointment_date DESC`,
    params
  );
  return result.rows;
};

const getVitalsReportRows = async ({ start_date, end_date } = {}) => {
  const params = [];
  let where = '';
  if (start_date) { params.push(start_date); where += ` AND v.recorded_at >= $${params.length}`; }
  if (end_date)   { params.push(end_date);   where += ` AND v.recorded_at <= $${params.length}`; }
  const result = await pool.query(
    `SELECT m.member_number, m.first_name || ' ' || m.last_name AS member_name,
            v.recorded_at, v.blood_sugar_mmol, v.systolic_bp, v.diastolic_bp,
            v.heart_rate, v.weight_kg, v.height_cm, v.o2_saturation,
            v.pain_level, v.temperature_c, v.mood, v.notes
     FROM vitals v
     JOIN members m ON m.id = v.member_id
     WHERE 1=1 ${where}
     ORDER BY v.recorded_at DESC`,
    params
  );
  return result.rows;
};

const getConditionsEnrollmentRows = async () => {
  const result = await pool.query(
    `SELECT c.name AS condition_name, c.description,
            COUNT(DISTINCT mc.member_id)::int AS total_enrolled,
            COUNT(DISTINCT CASE WHEN m.is_active THEN mc.member_id END)::int AS active_members,
            MIN(mc.diagnosed_date) AS earliest_diagnosis,
            MAX(mc.diagnosed_date) AS latest_diagnosis
     FROM conditions c
     LEFT JOIN member_conditions mc ON mc.condition_id = c.id
     LEFT JOIN members m ON m.id = mc.member_id
     GROUP BY c.id, c.name, c.description
     ORDER BY total_enrolled DESC`
  );
  return result.rows;
};

/* ─────────────────── API HANDLERS ─────────────────── */

const makeDataHandler = (fn) => async (req, res) => {
  try { return res.json(await fn(req.query)); }
  catch (err) { console.error(err); return res.status(500).json({ message: 'Server error' }); }
};

const makeCsvHandler = (fn, filename, headersFn, rowFn) => async (req, res) => {
  try {
    const rows = await fn(req.query);
    const headers = headersFn();
    const csvRows = [headers.join(','), ...rows.map(rowFn)];
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(csvRows.join('\n'));
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
};

/* Members */
const getMembersReportData     = makeDataHandler(() => getMembersReportRows());
const exportMembersReport      = makeCsvHandler(
  () => getMembersReportRows(), 'members_report.csv',
  () => ['Member Number','First Name','Last Name','Email','Phone','Gender','Plan','Date of Birth','Active','Conditions','Registered'],
  (r) => [r.member_number,r.first_name,r.last_name,r.email,r.phone,r.gender,r.plan,formatDate(r.date_of_birth),r.is_active?'Yes':'No',r.conditions.join('; '),formatDate(r.created_at)].map(escapeCsv).join(',')
);

/* Authorizations */
const getAuthorizationsReportData = makeDataHandler(getAuthorizationsReportRows);
const exportAuthorizationsReport  = makeCsvHandler(
  getAuthorizationsReportRows, 'authorizations_report.csv',
  () => ['Member #','Member Name','Request Type','Provider Type','Provider Name','Status','Notes','Admin Comments','Scheduled Date','Reviewed By','Reviewed At','Created At'],
  (r) => [r.member_number,r.member_name,r.request_type,r.provider_type,r.provider_name,r.status,r.notes,r.admin_comments,formatDate(r.scheduled_date),r.reviewed_by_name,formatDate(r.reviewed_at),formatDate(r.created_at)].map(escapeCsv).join(',')
);

/* Lab Tests */
const getLabTestsReportData    = makeDataHandler(getLabTestsReportRows);
const exportLabTestsReport     = makeCsvHandler(
  getLabTestsReportRows, 'lab_tests_report.csv',
  () => ['Member #','Member Name','Test Type','Due Date','Scheduled Date','Status','Completed At','Result Notes'],
  (r) => [r.member_number,r.member_name,r.test_type,formatDate(r.due_date),formatDate(r.scheduled_date),r.status,formatDate(r.completed_at),r.result_notes].map(escapeCsv).join(',')
);

/* Prescriptions */
const getPrescriptionsReportData  = makeDataHandler(getPrescriptionsReportRows);
const exportPrescriptionsReport   = makeCsvHandler(
  getPrescriptionsReportRows, 'prescriptions_report.csv',
  () => ['Member #','Member Name','Medication','Generic Name','Dosage','Frequency','Start Date','End Date','Next Refill','Status','Notes'],
  (r) => [r.member_number,r.member_name,r.medication_name,r.generic_name,r.dosage,r.frequency,formatDate(r.start_date),formatDate(r.end_date),formatDate(r.next_refill_date),r.active_status,r.notes].map(escapeCsv).join(',')
);

/* Treatment Plans */
const getTreatmentPlansReportData = makeDataHandler(getTreatmentPlansReportRows);
const exportTreatmentPlansReport  = makeCsvHandler(
  getTreatmentPlansReportRows, 'treatment_plans_report.csv',
  () => ['Member #','Member Name','Condition','Plan Title','Status','Provider','Plan Date','Cost','Currency'],
  (r) => [r.member_number,r.member_name,r.condition_name,r.title,r.status,r.provider_name,formatDate(r.plan_date),r.cost,r.currency].map(escapeCsv).join(',')
);

/* Appointments */
const getAppointmentsReportData   = makeDataHandler(getAppointmentsReportRows);
const exportAppointmentsReport    = makeCsvHandler(
  getAppointmentsReportRows, 'appointments_report.csv',
  () => ['Member #','Member Name','Hospital','Condition','Appointment Date','Time','Status','Reason','Notes'],
  (r) => [r.member_number,r.member_name,r.hospital_name,r.condition_name,formatDate(r.appointment_date),r.preferred_time,r.status,r.reason,r.notes].map(escapeCsv).join(',')
);

/* Vitals */
const getVitalsReportData         = makeDataHandler(getVitalsReportRows);
const exportVitalsReport          = makeCsvHandler(
  getVitalsReportRows, 'vitals_report.csv',
  () => ['Member #','Member Name','Recorded At','Blood Sugar (mmol)','Systolic BP','Diastolic BP','Heart Rate','Weight (kg)','Height (cm)','O2 Sat (%)','Pain Level','Temp (°C)','Mood','Notes'],
  (r) => [r.member_number,r.member_name,formatDate(r.recorded_at),r.blood_sugar_mmol,r.systolic_bp,r.diastolic_bp,r.heart_rate,r.weight_kg,r.height_cm,r.o2_saturation,r.pain_level,r.temperature_c,r.mood,r.notes].map(escapeCsv).join(',')
);

/* Conditions Enrollment */
const getConditionsEnrollmentData = makeDataHandler(() => getConditionsEnrollmentRows());
const exportConditionsReport      = makeCsvHandler(
  () => getConditionsEnrollmentRows(), 'conditions_enrollment_report.csv',
  () => ['Condition','Description','Total Enrolled','Active Members','Earliest Diagnosis','Latest Diagnosis'],
  (r) => [r.condition_name,r.description,r.total_enrolled,r.active_members,formatDate(r.earliest_diagnosis),formatDate(r.latest_diagnosis)].map(escapeCsv).join(',')
);

module.exports = {
  getMembersReportData, exportMembersReport,
  getAuthorizationsReportData, exportAuthorizationsReport,
  getLabTestsReportData, exportLabTestsReport,
  getPrescriptionsReportData, exportPrescriptionsReport,
  getTreatmentPlansReportData, exportTreatmentPlansReport,
  getAppointmentsReportData, exportAppointmentsReport,
  getVitalsReportData, exportVitalsReport,
  getConditionsEnrollmentData, exportConditionsReport,
};

