const notificationService = require('./notificationService');
const pool = require('../config/db');

// Check vitals against thresholds and send alerts
const checkVitalAlerts = async (memberId, vitals) => {
  const checks = [
    { metric: 'blood_sugar', value: vitals.blood_sugar_mmol },
    { metric: 'systolic_bp', value: vitals.systolic_bp },
    { metric: 'diastolic_bp', value: vitals.diastolic_bp },
    { metric: 'heart_rate', value: vitals.heart_rate },
    { metric: 'o2_saturation', value: vitals.o2_saturation },
  ];

  // Get member conditions
  const conditionsRes = await pool.query(
    'SELECT condition_id FROM member_conditions WHERE member_id = $1',
    [memberId]
  );
  const conditionIds = conditionsRes.rows.map(r => r.condition_id);
  if (conditionIds.length === 0) return;

  for (const check of checks) {
    if (check.value === null || check.value === undefined) continue;
    const threshRes = await pool.query(
      `SELECT * FROM vital_thresholds
       WHERE metric = $1 AND (condition_id = ANY($2::uuid[]) OR condition_id IS NULL)
       LIMIT 1`,
      [check.metric, conditionIds]
    );
    if (threshRes.rows.length === 0) continue;
    const { min_value, max_value } = threshRes.rows[0];
    const outOfRange =
      (min_value !== null && check.value < min_value) ||
      (max_value !== null && check.value > max_value);

    if (outOfRange) {
      await notificationService.sendToMember(memberId, {
        type: 'vital_alert',
        title: '⚠️ Vital Alert',
        message: `Your ${check.metric.replace(/_/g, ' ')} reading of ${check.value} is outside the safe range. Please consult your doctor.`,
        channel: ['push', 'sms', 'email'],
      });
    }
  }
};

// Send medication reminders (called by scheduler)
const sendMedicationReminders = async () => {
  const now = new Date();
  const windowStart = new Date(now.getTime() - 5 * 60000);
  const windowEnd = new Date(now.getTime() + 5 * 60000);
  const timeStr = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;

  const res = await pool.query(
    `SELECT mm.*, m.first_name, m.fcm_token, m.phone, m.email
     FROM member_medications mm
     JOIN members m ON m.id = mm.member_id
     WHERE mm.reminder_enabled = TRUE
       AND (mm.end_date IS NULL OR mm.end_date >= CURRENT_DATE)
       AND $1 = ANY(mm.times)`,
    [timeStr]
  );

  for (const row of res.rows) {
    await notificationService.sendToMember(row.member_id, {
      type: 'medication_reminder',
      title: '💊 Medication Reminder',
      message: `Time to take your medication. Don't skip your dose!`,
      channel: ['push', 'sms', 'email'],
      fcmToken: row.fcm_token,
      phone: row.phone,
      email: row.email,
      firstName: row.first_name,
    });
  }
};

// Send appointment reminders
const sendAppointmentReminders = async () => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];

  const res = await pool.query(
    `SELECT a.*, m.first_name, m.fcm_token, m.phone, m.email, h.name as hospital_name
     FROM appointments a
     JOIN members m ON m.id = a.member_id
     JOIN hospitals h ON h.id = a.hospital_id
     WHERE a.appointment_date = $1
       AND a.status = 'confirmed'
       AND a.reminder_24h_sent = FALSE`,
    [tomorrowStr]
  );

  for (const row of res.rows) {
    await notificationService.sendToMember(row.member_id, {
      type: 'appointment_reminder',
      title: '📅 Appointment Reminder',
      message: `You have an appointment at ${row.hospital_name} tomorrow (${tomorrowStr}). Please be on time.`,
      channel: ['push', 'sms', 'email'],
    });
    await pool.query(
      'UPDATE appointments SET reminder_24h_sent = TRUE WHERE id = $1',
      [row.id]
    );
  }
};

// Check script expiry (7 days warning)
const sendScriptExpiryAlerts = async () => {
  const in7Days = new Date();
  in7Days.setDate(in7Days.getDate() + 7);
  const dateStr = in7Days.toISOString().split('T')[0];

  const res = await pool.query(
    `SELECT mm.*, m.first_name, m.fcm_token, m.phone, m.email, med.name as med_name
     FROM member_medications mm
     JOIN members m ON m.id = mm.member_id
     JOIN medications med ON med.id = mm.medication_id
     WHERE mm.end_date = $1`,
    [dateStr]
  );

  for (const row of res.rows) {
    await notificationService.sendToMember(row.member_id, {
      type: 'script_expiry',
      title: '📋 Script Expiry Alert',
      message: `Your prescription for ${row.med_name} expires in 7 days. Please visit your doctor to renew.`,
      channel: ['push', 'sms', 'email'],
    });
  }
};

// Check for overdue lab tests and notify members
// ── DAILY push: morning (09:00) and evening (18:00) per pending lab test ──
// slot = 'morning' | 'evening' — tracked in separate columns so both fire daily
const sendLabTestDailyPush = async (slot = 'morning') => {
  const col = slot === 'evening' ? 'last_push_evening_at' : 'last_push_reminder_at';
  const greeting = slot === 'evening' ? "End-of-day reminder:" : "Reminder:";

  const res = await pool.query(
    `SELECT lt.*, m.first_name, m.fcm_token
     FROM lab_tests lt
     JOIN members m ON m.id = lt.member_id
     WHERE lt.status = 'pending'
       AND (lt.${col} IS NULL
            OR DATE(lt.${col} AT TIME ZONE 'Africa/Johannesburg') < CURRENT_DATE)`
  );

  for (const row of res.rows) {
    const testLabel = row.test_type.replace(/_/g, ' ');
    const dueStr = new Date(row.due_date).toLocaleDateString('en-ZA', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
    const isOverdue = new Date(row.due_date) < new Date();
    await notificationService.sendToMember(row.member_id, {
      type: 'lab_test_push',
      title: isOverdue ? '⚠️ Lab Test Overdue' : '🔬 Lab Test Reminder',
      message: isOverdue
        ? `${greeting} your ${testLabel} test is overdue (was due ${dueStr}). Please visit your nearest lab.`
        : `${greeting} your ${testLabel} test is due on ${dueStr}. Please book your lab appointment.`,
      channel: ['push'],
      fcmToken: row.fcm_token,
    });
    await pool.query(
      `UPDATE lab_tests SET ${col} = NOW(), updated_at = NOW() WHERE id = $1`,
      [row.id]
    );
  }
};

// ── WEEKLY email: every Friday for all pending lab tests ──
const sendLabTestWeeklyEmail = async () => {
  const res = await pool.query(
    `SELECT lt.*, m.first_name, m.email
     FROM lab_tests lt
     JOIN members m ON m.id = lt.member_id
     WHERE lt.status = 'pending'
       AND (lt.last_email_reminder_at IS NULL
            OR lt.last_email_reminder_at < NOW() - INTERVAL '6 days')
       AND m.email IS NOT NULL`
  );

  for (const row of res.rows) {
    const testLabel = row.test_type.replace(/_/g, ' ');
    const dueStr = new Date(row.due_date).toLocaleDateString('en-ZA', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
    const isOverdue = new Date(row.due_date) < new Date();
    await notificationService.sendToMember(row.member_id, {
      type: 'lab_test_email',
      title: isOverdue ? '⚠️ Lab Test Overdue' : '🔬 Weekly Lab Test Reminder',
      message: isOverdue
        ? `Hi ${row.first_name}, your ${testLabel} test was due on ${dueStr} and has not been completed. Please visit your nearest lab as soon as possible.`
        : `Hi ${row.first_name}, this is your weekly reminder that your ${testLabel} test is due on ${dueStr}. Please ensure you book your lab appointment.`,
      channel: ['email'],
      email: row.email,
      firstName: row.first_name,
    });
    await pool.query(
      'UPDATE lab_tests SET last_email_reminder_at = NOW(), updated_at = NOW() WHERE id = $1',
      [row.id]
    );
  }
};

// ── MONTHLY SMS: last day of every month for all pending lab tests ──
const sendLabTestMonthlySms = async () => {
  const res = await pool.query(
    `SELECT lt.*, m.first_name, m.phone
     FROM lab_tests lt
     JOIN members m ON m.id = lt.member_id
     WHERE lt.status = 'pending'
       AND (lt.last_sms_reminder_at IS NULL
            OR lt.last_sms_reminder_at < NOW() - INTERVAL '27 days')
       AND m.phone IS NOT NULL`
  );

  for (const row of res.rows) {
    const testLabel = row.test_type.replace(/_/g, ' ');
    const dueStr = new Date(row.due_date).toLocaleDateString('en-ZA', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
    const isOverdue = new Date(row.due_date) < new Date();
    await notificationService.sendToMember(row.member_id, {
      type: 'lab_test_sms',
      title: 'Lab Test Reminder',
      message: isOverdue
        ? `Sanlam Health: Your ${testLabel} test (due ${dueStr}) is overdue. Please visit your nearest lab ASAP.`
        : `Sanlam Health: Reminder - your ${testLabel} test is due on ${dueStr}. Please book your lab appointment.`,
      channel: ['sms'],
      phone: row.phone,
      firstName: row.first_name,
    });
    await pool.query(
      'UPDATE lab_tests SET last_sms_reminder_at = NOW(), updated_at = NOW() WHERE id = $1',
      [row.id]
    );
  }
};

// Kept for backward compat — no longer used by cron (replaced by sendLabTestDailyPush)
const sendLabTestReminders = sendLabTestDailyPush;
const sendLabTestDayReminder = sendLabTestDailyPush;
const checkLabTestsDue = sendLabTestDailyPush;

// Send treatment plan reminders — 24h before and 3 times on the day
const sendTreatmentPlanReminders = async () => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];

  // 24-hour advance reminder
  const upcoming = await pool.query(
    `SELECT tp.*, m.first_name, m.fcm_token, m.phone, m.email
     FROM treatment_plans tp
     JOIN members m ON m.id = tp.member_id
     WHERE tp.plan_date = $1
       AND tp.status = 'active'
       AND tp.reminder_24h_sent = FALSE`,
    [tomorrowStr]
  );

  for (const row of upcoming.rows) {
    const label = row.title ? `"${row.title}"` : 'your treatment plan';
    await notificationService.sendToMember(row.member_id, {
      type: 'treatment_reminder',
      title: '🏥 Treatment Plan Tomorrow',
      message: `You have ${label} scheduled for tomorrow (${tomorrowStr}). Please prepare and confirm with your provider.`,
      channel: ['push', 'sms', 'email'],
      fcmToken: row.fcm_token,
      phone: row.phone,
      email: row.email,
      firstName: row.first_name,
    });
    await pool.query(
      'UPDATE treatment_plans SET reminder_24h_sent = TRUE, updated_at = NOW() WHERE id = $1',
      [row.id]
    );
  }
};

/**
 * Send one of the three same-day treatment reminders.
 * @param {'morning'|'noon'|'afternoon'} slot
 */
const sendTreatmentDayReminder = async (slot) => {
  const todayStr = new Date().toISOString().split('T')[0];

  const slotConfig = {
    morning:   { col: 'reminder_day_morning_sent',   emoji: '🌅', label: 'Good morning! Your treatment plan' },
    noon:      { col: 'reminder_day_noon_sent',       emoji: '☀️',  label: 'Midday reminder: your treatment plan' },
    afternoon: { col: 'reminder_day_afternoon_sent',  emoji: '🌆', label: "Don't forget — your treatment plan" },
  };

  const { col, emoji, label } = slotConfig[slot];

  const res = await pool.query(
    `SELECT tp.*, m.first_name, m.fcm_token, m.phone, m.email
     FROM treatment_plans tp
     JOIN members m ON m.id = tp.member_id
     WHERE tp.plan_date = $1
       AND tp.status = 'active'
       AND tp.${col} = FALSE`,
    [todayStr]
  );

  for (const row of res.rows) {
    const planLabel = row.title ? `"${row.title}"` : 'a treatment plan';
    await notificationService.sendToMember(row.member_id, {
      type: 'treatment_reminder',
      title: `${emoji} Treatment Plan Today`,
      message: `${label} ${planLabel} is scheduled for today (${todayStr}). Please check in with your care provider.`,
      channel: ['push', 'sms', 'email'],
      fcmToken: row.fcm_token,
      phone: row.phone,
      email: row.email,
      firstName: row.first_name,
    });
    await pool.query(
      `UPDATE treatment_plans SET ${col} = TRUE, updated_at = NOW() WHERE id = $1`,
      [row.id]
    );
  }
};

module.exports = {
  checkVitalAlerts,
  sendMedicationReminders,
  sendAppointmentReminders,
  sendScriptExpiryAlerts,
  checkLabTestsDue,
  sendLabTestReminders,
  sendLabTestDayReminder,
  sendLabTestDailyPush,
  sendLabTestWeeklyEmail,
  sendLabTestMonthlySms,
  sendTreatmentPlanReminders,
  sendTreatmentDayReminder,
};
