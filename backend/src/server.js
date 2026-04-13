require('dotenv').config();
const cron = require('node-cron');
const app = require('./app');
const alertService = require('./services/alertService');
const { sendRefillReminders } = require('./services/refillReminderService');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`🚀 Sanlam Chronic Care API running on port ${PORT}`);
});

// Every minute — medication reminders
cron.schedule('* * * * *', () => {
  alertService.sendMedicationReminders().catch((err) =>
    console.error('Medication reminders cron error:', err.message)
  );
});

// Every day at 08:00 — appointment reminders
cron.schedule('0 8 * * *', () => {
  alertService.sendAppointmentReminders().catch((err) =>
    console.error('Appointment reminders cron error:', err.message)
  );
});

// Every day at 08:30 — treatment plan 24h-before reminder
cron.schedule('30 8 * * *', () => {
  alertService.sendTreatmentPlanReminders().catch((err) =>
    console.error('Treatment plan 24h reminder cron error:', err.message)
  );
});

// Every day at 08:00 — treatment plan morning reminder (same day)
cron.schedule('0 8 * * *', () => {
  alertService.sendTreatmentDayReminder('morning').catch((err) =>
    console.error('Treatment plan morning reminder cron error:', err.message)
  );
});

// Every day at 12:00 — treatment plan midday reminder
cron.schedule('0 12 * * *', () => {
  alertService.sendTreatmentDayReminder('noon').catch((err) =>
    console.error('Treatment plan noon reminder cron error:', err.message)
  );
});

// Every day at 17:00 — treatment plan afternoon reminder
cron.schedule('0 17 * * *', () => {
  alertService.sendTreatmentDayReminder('afternoon').catch((err) =>
    console.error('Treatment plan afternoon reminder cron error:', err.message)
  );
});

// Every day at 09:00 — script expiry alerts
cron.schedule('0 9 * * *', () => {
  alertService.sendScriptExpiryAlerts().catch((err) =>
    console.error('Script expiry cron error:', err.message)
  );
});

// ── Lab test recurring reminders ──────────────────────────────────────────

// Every day at 09:00 — morning push for every pending lab test
cron.schedule('0 9 * * *', () => {
  alertService.sendLabTestDailyPush('morning').catch((err) =>
    console.error('Lab test morning push cron error:', err.message)
  );
});

// Every day at 18:00 — evening push reminder for every pending lab test
cron.schedule('0 18 * * *', () => {
  alertService.sendLabTestDailyPush('evening').catch((err) =>
    console.error('Lab test evening push cron error:', err.message)
  );
});

// Every Friday at 08:00 — weekly email reminder
cron.schedule('0 8 * * 5', () => {
  alertService.sendLabTestWeeklyEmail().catch((err) =>
    console.error('Lab test weekly email cron error:', err.message)
  );
});

// Every day at 08:00 — SMS on last day of month only
cron.schedule('0 8 * * *', () => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isLastDay = tomorrow.getMonth() !== now.getMonth();
  if (!isLastDay) return;
  alertService.sendLabTestMonthlySms().catch((err) =>
    console.error('Lab test monthly SMS cron error:', err.message)
  );
});

// Every day at 07:00 — medication refill reminders (7-day and 2-day before pickup)
cron.schedule('0 7 * * *', () => {
  sendRefillReminders().catch((err) =>
    console.error('Refill reminder cron error:', err.message)
  );
});
