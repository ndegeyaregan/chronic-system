require('dotenv').config();
const cron = require('node-cron');
const app = require('./app');
const pool = require('./config/db');
const alertService = require('./services/alertService');
const { sendRefillReminders } = require('./services/refillReminderService');
const notificationService = require('./services/notificationService');

const PORT = process.env.PORT || 3000;

// Track consecutive cron failures for admin alerting
const cronFailures = {};
const MAX_FAILURES_BEFORE_ALERT = 3;

const runCron = (name, fn) => async () => {
  try {
    await fn();
    cronFailures[name] = 0;
  } catch (err) {
    cronFailures[name] = (cronFailures[name] || 0) + 1;
    console.error(`${name} cron error (failure #${cronFailures[name]}):`, err.message);

    if (cronFailures[name] === MAX_FAILURES_BEFORE_ALERT) {
      try {
        const admins = await pool.query('SELECT email FROM admins WHERE email IS NOT NULL');
        for (const { email } of admins.rows) {
          await notificationService.sendEmail(email,
            `⚠️ Cron Job Failing: ${name}`,
            `<p>The cron job <strong>${name}</strong> has failed <strong>${MAX_FAILURES_BEFORE_ALERT}</strong> consecutive times.</p>
             <p>Last error: <code>${err.message}</code></p>
             <p>Please check the server logs.</p>`
          );
        }
      } catch (alertErr) {
        console.error('Failed to alert admins about cron failure:', alertErr.message);
      }
    }

    // Retry once after 30 seconds
    if (cronFailures[name] <= MAX_FAILURES_BEFORE_ALERT) {
      setTimeout(async () => {
        try {
          await fn();
          cronFailures[name] = 0;
          console.log(`${name} retry succeeded`);
        } catch (retryErr) {
          console.error(`${name} retry failed:`, retryErr.message);
        }
      }, 30000);
    }
  }
};

const server = app.listen(PORT, () => {
  console.log(`🚀 Sanlam Chronic Care API running on port ${PORT}`);
});

// Every minute — medication reminders
cron.schedule('* * * * *', runCron('medication-reminders', () =>
  alertService.sendMedicationReminders()
));

// Every day at 08:00 — appointment reminders
cron.schedule('0 8 * * *', runCron('appointment-reminders', () =>
  alertService.sendAppointmentReminders()
));

// Every day at 08:30 — treatment plan 24h-before reminder
cron.schedule('30 8 * * *', runCron('treatment-24h', () =>
  alertService.sendTreatmentPlanReminders()
));

// Every day at 08:00 — treatment plan morning reminder (same day)
cron.schedule('0 8 * * *', runCron('treatment-morning', () =>
  alertService.sendTreatmentDayReminder('morning')
));

// Every day at 12:00 — treatment plan midday reminder
cron.schedule('0 12 * * *', runCron('treatment-noon', () =>
  alertService.sendTreatmentDayReminder('noon')
));

// Every day at 17:00 — treatment plan afternoon reminder
cron.schedule('0 17 * * *', runCron('treatment-afternoon', () =>
  alertService.sendTreatmentDayReminder('afternoon')
));

// Every day at 09:00 — script expiry alerts
cron.schedule('0 9 * * *', runCron('script-expiry', () =>
  alertService.sendScriptExpiryAlerts()
));

// ── Lab test recurring reminders ──────────────────────────────────────────

// Every day at 09:00 — morning push for lab tests DUE WITHIN 2 DAYS
cron.schedule('0 9 * * *', runCron('labtest-morning', () =>
  alertService.sendLabTestDailyPush('morning')
));

// Every day at 18:00 — evening push reminder for lab tests DUE WITHIN 2 DAYS
cron.schedule('0 18 * * *', runCron('labtest-evening', () =>
  alertService.sendLabTestDailyPush('evening')
));

// Every Friday at 08:00 — weekly email reminder
cron.schedule('0 8 * * 5', runCron('labtest-weekly-email', () =>
  alertService.sendLabTestWeeklyEmail()
));

// Every day at 08:00 — end-of-month email reminder (sends on last day of month)
cron.schedule('0 8 * * *', runCron('labtest-end-of-month-email', () => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isLastDay = tomorrow.getMonth() !== now.getMonth();
  if (!isLastDay) return Promise.resolve();
  return alertService.sendLabTestEndOfMonthEmail();
}));

// Every day at 09:30 — SMS on the actual due date
cron.schedule('30 9 * * *', runCron('labtest-due-date-sms', () =>
  alertService.sendLabTestDueDateSms()
));

// Every day at 07:00 — medication refill reminders (7-day and 2-day before pickup)
cron.schedule('0 7 * * *', runCron('refill-reminders', () =>
  sendRefillReminders()
));

// ── Graceful shutdown ─────────────────────────────────────────────────────
const shutdown = async (signal) => {
  console.log(`\n${signal} received. Shutting down gracefully...`);
  server.close(async () => {
    try { await pool.end(); } catch (_) {}
    console.log('Server closed.');
    process.exit(0);
  });
  setTimeout(() => { console.error('Forced shutdown'); process.exit(1); }, 10000);
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
