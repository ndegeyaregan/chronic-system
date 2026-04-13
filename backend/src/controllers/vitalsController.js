const pool = require('../config/db');
const alertService = require('../services/alertService');

const logVitals = async (req, res) => {
  try {
    const memberId = req.user.id;
    const {
      blood_sugar_mmol, systolic_bp, diastolic_bp, heart_rate,
      weight_kg, height_cm, o2_saturation, pain_level, temperature_c, notes, mood,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO vitals
         (member_id, blood_sugar_mmol, systolic_bp, diastolic_bp, heart_rate,
          weight_kg, height_cm, o2_saturation, pain_level, temperature_c, notes, mood, recorded_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW()) RETURNING *`,
      [
        memberId,
        blood_sugar_mmol || null, systolic_bp || null, diastolic_bp || null,
        heart_rate || null, weight_kg || null, height_cm || null,
        o2_saturation || null, pain_level || null, temperature_c || null,
        notes || null, mood || null,
      ]
    );
    const vitals = result.rows[0];

    // Check alerts asynchronously
    alertService.checkVitalAlerts(memberId, vitals).catch((err) =>
      console.error('Vital alert check error:', err.message)
    );

    // Insert admin alert for high pain level
    const painLevel = parseInt(vitals.pain_level, 10);
    if (!isNaN(painLevel) && painLevel >= 7) {
      const severity = painLevel >= 9 ? 'critical' : 'high';
      pool.query(
        `INSERT INTO admin_alerts (member_id, alert_type, severity, value_reported, notes)
         VALUES ($1, 'pain', $2, $3, $4)`,
        [memberId, severity, painLevel, `Pain level ${painLevel} reported via vitals`]
      ).catch((err) => console.error('Pain alert insert error:', err.message));

      if (painLevel >= 9) {
        const notificationService = require('../services/notificationService');
        notificationService.sendToMember(memberId, {
          type: 'pain_alert',
          title: '🚨 Critical Pain Level',
          message: 'Your pain level is critical. If you need emergency help, please use the SOS feature.',
          channel: ['push'],
        }).catch((err) => console.error('Pain push notification error:', err.message));
      }
    }

    return res.status(201).json(vitals);
  } catch (err) {
    console.error('logVitals error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getVitalsHistory = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { from_date, to_date, metric } = req.query;
    const params = [memberId];
    const filters = ['v.member_id = $1'];
    let idx = 2;

    if (from_date) {
      filters.push(`v.recorded_at >= $${idx++}`);
      params.push(from_date);
    }
    if (to_date) {
      filters.push(`v.recorded_at <= $${idx++}`);
      params.push(to_date + ' 23:59:59');
    }

    // Build SELECT columns based on requested metric
    const allMetrics = [
      'blood_sugar_mmol', 'systolic_bp', 'diastolic_bp', 'heart_rate',
      'weight_kg', 'height_cm', 'o2_saturation', 'pain_level', 'temperature_c', 'notes',
    ];
    const selectCols = metric && allMetrics.includes(metric)
      ? `id, member_id, ${metric}, recorded_at`
      : '*';

    const result = await pool.query(
      `SELECT ${selectCols} FROM vitals v
       WHERE ${filters.join(' AND ')}
       ORDER BY v.recorded_at DESC`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getVitalsHistory error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getLatestVitals = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      'SELECT * FROM vitals WHERE member_id = $1 ORDER BY recorded_at DESC LIMIT 1',
      [memberId]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'No vitals recorded yet' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('getLatestVitals error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const logCheckin = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { mood, energy_level, symptoms, notes } = req.body;
    const today = new Date().toISOString().split('T')[0];

    const result = await pool.query(
      `INSERT INTO daily_checkins (member_id, checkin_date, mood, energy_level, symptoms, notes)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (member_id, checkin_date)
       DO UPDATE SET
         mood = EXCLUDED.mood,
         energy_level = EXCLUDED.energy_level,
         symptoms = EXCLUDED.symptoms,
         notes = EXCLUDED.notes,
         updated_at = NOW()
       RETURNING *`,
      [
        memberId,
        today,
        mood || null,
        energy_level || null,
        symptoms ? JSON.stringify(symptoms) : null,
        notes || null,
      ]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('logCheckin error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getCheckins = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { from_date, to_date } = req.query;
    const params = [memberId];
    const filters = ['member_id = $1'];
    let idx = 2;

    if (from_date) {
      filters.push(`checkin_date >= $${idx++}`);
      params.push(from_date);
    }
    if (to_date) {
      filters.push(`checkin_date <= $${idx++}`);
      params.push(to_date);
    }

    const result = await pool.query(
      `SELECT * FROM daily_checkins WHERE ${filters.join(' AND ')}
       ORDER BY checkin_date DESC`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getCheckins error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { logVitals, getVitalsHistory, getLatestVitals, logCheckin, getCheckins };
