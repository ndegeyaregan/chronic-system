const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth');
const membersRoutes = require('./routes/members');
const hospitalsRoutes = require('./routes/hospitals');
const appointmentsRoutes = require('./routes/appointments');
const medicationsRoutes = require('./routes/medications');
const vitalsRoutes = require('./routes/vitals');
const lifestyleRoutes = require('./routes/lifestyle');
const cmsRoutes = require('./routes/cms');
const analyticsRoutes = require('./routes/analytics');
const dashboardRoutes = require('./routes/dashboard');
const conditionsRoutes = require('./routes/conditions');
const treatmentPlansRoutes = require('./routes/treatmentPlans');
const labTestsRoutes = require('./routes/labTests');
const alertsRoutes = require('./routes/alerts');
const emergencyRoutes = require('./routes/emergency');
const memberProviderRoutes = require('./routes/memberProvider');
const notificationsRoutes = require('./routes/notifications');
const chatRoutes = require('./routes/chat');
const pharmaciesRoutes = require('./routes/pharmacies');
const authorizationsRoutes = require('./routes/authorizations');
const devRoutes = require('./routes/dev');
const adminsRoutes = require('./routes/admins');
const reportsRoutes = require('./routes/reports');

const app = express();

app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests from portal, mobile apps, and same-origin (no origin = Postman/mobile)
    const allowed = [
      'http://localhost:5173',
      'http://127.0.0.1:5173',
      process.env.FRONTEND_URL,
    ].filter(Boolean);
    // Also allow any localhost/127.0.0.1 port (Flutter web dev server uses a random port)
    const isLocalhost = origin && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
    if (!origin || allowed.includes(origin) || isLocalhost) return callback(null, true);
    callback(new Error(`CORS: origin ${origin} not allowed`));
  },
  credentials: true,
}));
app.use(morgan('dev'));

// Global rate limiter — 100 requests per minute per IP across all endpoints
const globalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests. Please slow down.' },
  skip: (req) => req.path === '/health', // health check exempt
});
app.use(globalLimiter);

app.use(express.json());

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/members', membersRoutes);
app.use('/api/hospitals', hospitalsRoutes);
app.use('/api/appointments', appointmentsRoutes);
app.use('/api/medications', medicationsRoutes);
app.use('/api/vitals', vitalsRoutes);
app.use('/api/lifestyle', lifestyleRoutes);
app.use('/api/cms', cmsRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/conditions', conditionsRoutes);

// Static file serving for uploads — CORS headers required for Flutter web Image.network
app.use('/uploads', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(path.join(__dirname, '../uploads')));

// New feature routes
app.use('/api/treatment-plans', treatmentPlansRoutes);
app.use('/api/lab-tests', labTestsRoutes);
app.use('/api/alerts', alertsRoutes);
app.use('/api/emergency', emergencyRoutes);
app.use('/api/members', memberProviderRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/pharmacies', pharmaciesRoutes);
app.use('/api/authorizations', authorizationsRoutes);
app.use('/api/admins', adminsRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/dev', devRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.path} not found` });
});

// Global error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  const status = err.status || err.statusCode || 500;
  // Include unexpected field name in message for easier debugging
  const message = err.code === 'LIMIT_UNEXPECTED_FILE'
    ? `Unexpected field: "${err.field}"`
    : (err.message || 'Internal server error');
  res.status(status).json({ message });
});

module.exports = app;
