const pool = require('../config/db');
const path = require('path');
const fs = require('fs');

const prescriptionsDir = path.join(__dirname, '../../uploads/prescriptions');
if (!fs.existsSync(prescriptionsDir)) fs.mkdirSync(prescriptionsDir, { recursive: true });

const parseTextArray = (value) => {
  if (!value) return null;
  if (Array.isArray(value)) {
    const cleaned = value.map((item) => `${item}`.trim()).filter(Boolean);
    return cleaned.length ? cleaned : null;
  }
  const cleaned = `${value}`.split(',').map((item) => item.trim()).filter(Boolean);
  return cleaned.length ? cleaned : null;
};

const buildMedicationSuggestions = ({ summary, riskFlags, topMedications, pharmacyBreakdown }) => {
  const suggestions = [];

  if ((summary.avg_adherence || 0) < 75) {
    suggestions.push('Average adherence is low. Prioritize reminder follow-up for members with missed doses in the last 30 days.');
  }
  if ((summary.refills_due_7d || 0) > 0) {
    suggestions.push(`There are ${summary.refills_due_7d} refills due within 7 days. Review pharmacy readiness and pending authorizations early.`);
  }
  if ((summary.unassigned_pharmacy_count || 0) > 0) {
    suggestions.push(`${summary.unassigned_pharmacy_count} active prescriptions do not have a linked pharmacy. Assign pharmacies to reduce refill delays.`);
  }
  if (riskFlags.some((flag) => flag.reason_code === 'low_adherence')) {
    suggestions.push('Members flagged for low adherence should receive a manual check-in and medication counselling.');
  }
  if (riskFlags.some((flag) => flag.reason_code === 'refill_overdue')) {
    suggestions.push('Some members are already overdue for refills. Escalate those scripts before treatment gaps widen.');
  }
  if ((topMedications[0]?.active_members || 0) >= 3) {
    suggestions.push(`"${topMedications[0].name}" is the most assigned medication right now. Monitor stock and refill readiness for this medicine closely.`);
  }
  if (pharmacyBreakdown.length > 0 && Number(pharmacyBreakdown[0].avg_adherence || 0) < 70) {
    suggestions.push(`Members linked to ${pharmacyBreakdown[0].pharmacy_name} are trending below target adherence. Review refill and counselling workflow there.`);
  }

  return suggestions.slice(0, 5);
};

// Returns computed dose times based on frequency and a start time string (HH:MM)
const computeDoseTimes = (frequency, startTime) => {
  if (!startTime) return startTime ? [startTime] : [];
  const [h, m] = startTime.split(':').map(Number);
  const addHours = (hours) => {
    const total = (h + hours) % 24;
    return `${String(total).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  };
  switch (frequency) {
    case 'Once daily':        return [startTime];
    case 'Twice daily':       return [startTime, addHours(12)];
    case 'Three times daily': return [startTime, addHours(6), addHours(12)];
    case 'Four times daily':  return [startTime, addHours(4), addHours(8), addHours(12)];
    case 'Every 8 hours':     return [startTime, addHours(8), addHours(16)];
    case 'Every 12 hours':    return [startTime, addHours(12)];
    default:                  return [startTime];
  }
};

const listMedications = async (req, res) => {
  try {
    const { condition_id, search, limit } = req.query;
    const params = [];
    let where = 'WHERE m.is_active = TRUE';
    let idx = 1;

    if (condition_id) {
      params.push(condition_id);
      where += ` AND m.condition_id = $${idx++}`;
    }
    if (search) {
      params.push(`%${search}%`);
      where += ` AND (m.name ILIKE $${idx} OR m.generic_name ILIKE $${idx})`;
      idx += 1;
    }

    const parsedLimit = limit ? Math.min(100, Math.max(1, parseInt(limit, 10))) : null;
    if (parsedLimit) {
      params.push(parsedLimit);
    }

    const result = await pool.query(
      `SELECT m.*, c.name AS condition_name,
       (SELECT COUNT(*)::int FROM member_medications mm WHERE mm.medication_id = m.id AND mm.end_date IS NULL) AS active_members
       FROM medications m
       LEFT JOIN conditions c ON c.id = m.condition_id
       ${where}
       ORDER BY m.name
       ${parsedLimit ? `LIMIT $${idx}` : ''}`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listMedications error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createMedication = async (req, res) => {
  try {
    const { name, generic_name, dosage_options, frequency_options, condition_id, interactions, notes } = req.body;
    if (!name) return res.status(400).json({ message: 'name is required' });

    const result = await pool.query(
      `INSERT INTO medications (name, generic_name, dosage_options, frequency_options, condition_id, interactions, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [
        name,
        generic_name || null,
        parseTextArray(dosage_options),
        parseTextArray(frequency_options),
        condition_id || null,
        parseTextArray(interactions),
        notes || null,
      ]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createMedication error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateMedication = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, generic_name, dosage_options, frequency_options, condition_id, interactions, notes } = req.body;

    const existing = await pool.query('SELECT id FROM medications WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Medication not found' });

    const result = await pool.query(
      `UPDATE medications SET
         name = COALESCE($1, name),
         generic_name = COALESCE($2, generic_name),
         dosage_options = COALESCE($3, dosage_options),
         frequency_options = COALESCE($4, frequency_options),
         condition_id = COALESCE($5, condition_id),
         interactions = COALESCE($6, interactions),
         notes = COALESCE($7, notes),
         updated_at = NOW()
       WHERE id = $8 RETURNING *`,
      [
        name,
        generic_name,
        parseTextArray(dosage_options),
        parseTextArray(frequency_options),
        condition_id,
        parseTextArray(interactions),
        notes,
        id,
      ]
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateMedication error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const assignMedication = async (req, res) => {
  try {
    const memberId = req.user.type === 'member' ? req.user.id : req.body.member_id;
    const { dosage, frequency, times, end_date, reminder_enabled, start_time,
            pharmacy_id, refill_interval_days } = req.body;
    let { medication_id, start_date, name } = req.body;

    if (!dosage && !frequency) {
      // Allow submission without dosage/frequency when media is attached (admin will review)
    }

    // Resolve medication_id from name if not provided
    if (!medication_id) {
      if (!name) {
        const created = await pool.query(
          'INSERT INTO medications (name, is_active) VALUES ($1, TRUE) RETURNING id',
          ['Unidentified (see attached media)']
        );
        medication_id = created.rows[0].id;
      } else {
        const existing = await pool.query(
          'SELECT id FROM medications WHERE LOWER(name) = LOWER($1) AND is_active = TRUE',
          [name.trim()]
        );
        if (existing.rows.length > 0) {
          medication_id = existing.rows[0].id;
        } else {
          const created = await pool.query(
            'INSERT INTO medications (name, is_active) VALUES ($1, TRUE) RETURNING id',
            [name.trim()]
          );
          medication_id = created.rows[0].id;
        }
      }
    } else {
      const medCheck = await pool.query('SELECT id FROM medications WHERE id = $1', [medication_id]);
      if (!medCheck.rows.length) return res.status(404).json({ message: 'Medication not found' });
    }

    // Default start_date to today if not provided
    if (!start_date) {
      start_date = new Date().toISOString().split('T')[0];
    }

    // Calculate next refill date if refill_interval_days provided
    let next_refill_date = null;
    if (refill_interval_days && start_date) {
      const sd = new Date(start_date);
      sd.setDate(sd.getDate() + parseInt(refill_interval_days));
      next_refill_date = sd.toISOString().split('T')[0];
    }

    // Use provided times, or compute from frequency + start_time, or null
    let doseTimes = times || null;
    if (!doseTimes && start_time) {
      doseTimes = computeDoseTimes(frequency, start_time);
    }

    let prescription_file_url = null;
    let audio_url = null;
    let video_url = null;
    let photo_url = null;
    if (req.files) {
      if (req.files.prescription?.[0]) {
        prescription_file_url = `/uploads/prescriptions/${req.files.prescription[0].filename}`;
      }
      if (req.files.audio?.[0]) {
        audio_url = `/uploads/media/${req.files.audio[0].filename}`;
      }
      if (req.files.video?.[0]) {
        video_url = `/uploads/media/${req.files.video[0].filename}`;
      }
      if (req.files.photo?.[0]) {
        photo_url = `/uploads/media/${req.files.photo[0].filename}`;
      }
    } else if (req.file) {
      prescription_file_url = `/uploads/prescriptions/${req.file.filename}`;
    }

    const result = await pool.query(
      `INSERT INTO member_medications
         (member_id, medication_id, dosage, frequency, times, start_date, end_date, reminder_enabled, start_time,
          prescription_file_url, audio_url, video_url, photo_url,
          pharmacy_id, refill_interval_days, next_refill_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) RETURNING *`,
      [
        memberId,
        medication_id,
        dosage || null,
        frequency || 'Once daily',
        doseTimes || null,
        start_date,
        end_date || null,
        reminder_enabled !== undefined ? reminder_enabled : false,
        start_time || null,
        prescription_file_url,
        audio_url,
        video_url,
        photo_url,
        pharmacy_id || null,
        refill_interval_days ? parseInt(refill_interval_days) : null,
        next_refill_date,
      ]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('assignMedication error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const stopMedication = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { id } = req.params;
    const endDate = (req.body && req.body.end_date) || new Date().toISOString().split('T')[0];

    const result = await pool.query(
      `UPDATE member_medications
       SET end_date = $1, updated_at = NOW()
       WHERE id = $2 AND member_id = $3
       RETURNING *`,
      [endDate, id, memberId]
    );
    if (!result.rows.length) {
      return res.status(404).json({ message: 'Medication not found' });
    }
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('stopMedication error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listMyMedications = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT mm.*, med.name AS name, med.generic_name, med.interactions,
              med.notes AS medication_notes, c.name AS condition,
              p.name AS pharmacy_name, p.address AS pharmacy_address, p.phone AS pharmacy_phone,
              EXISTS(
                SELECT 1 FROM medication_logs ml
                WHERE ml.member_medication_id = mm.id
                  AND ml.status = 'taken'
                  AND ml.scheduled_time::date = CURRENT_DATE
              ) AS is_taken_today,
              EXISTS(
                SELECT 1 FROM medication_logs ml
                WHERE ml.member_medication_id = mm.id
                  AND ml.status = 'skipped'
                  AND ml.scheduled_time::date = CURRENT_DATE
              ) AS is_skipped_today,
              COALESCE((
                SELECT LEAST(COUNT(*) * 100.0 / 7, 100)
                FROM medication_logs ml
                WHERE ml.member_medication_id = mm.id
                  AND ml.status = 'taken'
                  AND ml.scheduled_time >= NOW() - INTERVAL '7 days'
              ), 0) AS adherence_percent
       FROM member_medications mm
       JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN conditions c ON c.id = med.condition_id
       LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
       WHERE mm.member_id = $1
       ORDER BY mm.created_at DESC`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listMyMedications error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const logDose = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { member_medication_id, status, notes } = req.body;

    if (!member_medication_id || !status) {
      return res.status(400).json({ message: 'member_medication_id and status are required' });
    }
    if (!['taken', 'skipped'].includes(status)) {
      return res.status(400).json({ message: 'status must be taken or skipped' });
    }

    const mmCheck = await pool.query(
      'SELECT id FROM member_medications WHERE id = $1 AND member_id = $2',
      [member_medication_id, memberId]
    );
    if (!mmCheck.rows.length) {
      return res.status(404).json({ message: 'Member medication not found' });
    }

    const takenAt = status === 'taken' ? new Date() : null;
    const result = await pool.query(
      `INSERT INTO medication_logs (member_medication_id, member_id, status, notes, scheduled_time, taken_at)
       VALUES ($1,$2,$3,$4,NOW(),$5) RETURNING *`,
      [member_medication_id, memberId, status, notes || null, takenAt]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('logDose error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getDoseLogs = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { from_date, to_date, member_medication_id } = req.query;
    const params = [memberId];
    const filters = ['ml.member_id = $1'];
    let idx = 2;

    if (from_date) {
      filters.push(`ml.scheduled_time >= $${idx++}`);
      params.push(from_date);
    }
    if (to_date) {
      filters.push(`ml.scheduled_time <= $${idx++}`);
      params.push(to_date + ' 23:59:59');
    }
    if (member_medication_id) {
      filters.push(`ml.member_medication_id = $${idx++}`);
      params.push(member_medication_id);
    }

    const result = await pool.query(
      `SELECT ml.*, med.name AS medication_name, mm.dosage, mm.frequency
       FROM medication_logs ml
       JOIN member_medications mm ON mm.id = ml.member_medication_id
       JOIN medications med ON med.id = mm.medication_id
       WHERE ${filters.join(' AND ')}
       ORDER BY ml.scheduled_time DESC`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getDoseLogs error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const searchMedications = async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (!q || q.length < 2) return res.json([]);

    const result = await pool.query(
      `SELECT name FROM medications
       WHERE is_active = TRUE AND name ILIKE $1
       ORDER BY
         CASE WHEN LOWER(name) = LOWER($2) THEN 0
              WHEN LOWER(name) LIKE LOWER($3) THEN 1
              ELSE 2 END,
         name
       LIMIT 20`,
      [`%${q}%`, q, `${q}%`]
    );
    return res.json(result.rows.map(r => r.name));
  } catch (err) {
    console.error('searchMedications error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMedicationAdminOverview = async (req, res) => {
  try {
    const summaryResult = await pool.query(
      `WITH assignment_metrics AS (
         SELECT
           mm.id,
           mm.member_id,
           mm.pharmacy_id,
           mm.end_date,
           mm.next_refill_date,
           mm.prescription_file_url,
           mm.photo_url,
           mm.audio_url,
           mm.video_url,
           COALESCE((
             SELECT ROUND(
               LEAST(
                 (
                   COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0
                 ) / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0),
                 100
               )::numeric,
               1
             )
             FROM medication_logs ml
             WHERE ml.member_medication_id = mm.id
               AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
           ), 0) AS adherence_percent
         FROM member_medications mm
       )
       SELECT
         (SELECT COUNT(*)::int FROM medications WHERE is_active = TRUE) AS catalogue_total,
         COUNT(*) FILTER (WHERE am.end_date IS NULL)::int AS active_assignments,
         COUNT(DISTINCT am.member_id) FILTER (WHERE am.end_date IS NULL)::int AS members_on_medication,
         COUNT(*) FILTER (
           WHERE am.end_date IS NULL
             AND am.next_refill_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
         )::int AS refills_due_7d,
         COUNT(*) FILTER (
           WHERE am.end_date IS NULL
             AND am.next_refill_date < CURRENT_DATE
         )::int AS refills_overdue,
         COUNT(*) FILTER (
           WHERE am.end_date IS NULL
             AND am.pharmacy_id IS NULL
         )::int AS unassigned_pharmacy_count,
         COUNT(*) FILTER (
           WHERE am.end_date IS NULL
             AND (am.prescription_file_url IS NOT NULL OR am.photo_url IS NOT NULL OR am.audio_url IS NOT NULL OR am.video_url IS NOT NULL)
         )::int AS media_attachments,
         COUNT(*) FILTER (
           WHERE am.end_date IS NULL
             AND am.adherence_percent < 70
         )::int AS low_adherence_count,
         COALESCE(ROUND((AVG(am.adherence_percent) FILTER (WHERE am.end_date IS NULL))::numeric, 1), 0) AS avg_adherence
       FROM assignment_metrics am`
    );

    const adherenceTrendResult = await pool.query(
      `SELECT
         TO_CHAR(DATE(ml.scheduled_time), 'DD Mon') AS day,
         COUNT(*) FILTER (WHERE ml.status = 'taken')::int AS taken,
         COUNT(*) FILTER (WHERE ml.status = 'skipped')::int AS skipped
       FROM medication_logs ml
       WHERE ml.scheduled_time >= CURRENT_DATE - INTERVAL '6 days'
       GROUP BY DATE(ml.scheduled_time)
       ORDER BY DATE(ml.scheduled_time)`
    );

    const topMedicationsResult = await pool.query(
      `SELECT
         med.name,
         COUNT(*) FILTER (WHERE mm.end_date IS NULL)::int AS active_members,
         COALESCE(ROUND(AVG((
           SELECT LEAST(COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0 / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0), 100)
           FROM medication_logs ml
           WHERE ml.member_medication_id = mm.id
             AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
         ))::numeric, 1), 0) AS adherence
       FROM member_medications mm
       JOIN medications med ON med.id = mm.medication_id
       GROUP BY med.id, med.name
       HAVING COUNT(*) FILTER (WHERE mm.end_date IS NULL) > 0
       ORDER BY active_members DESC, med.name
       LIMIT 6`
    );

    const pharmacyBreakdownResult = await pool.query(
      `SELECT
         COALESCE(p.name, 'No pharmacy assigned') AS pharmacy_name,
         COUNT(*) FILTER (WHERE mm.end_date IS NULL)::int AS active_scripts,
         COALESCE(ROUND(AVG((
           SELECT LEAST(COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0 / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0), 100)
           FROM medication_logs ml
           WHERE ml.member_medication_id = mm.id
             AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
         ))::numeric, 1), 0) AS avg_adherence
       FROM member_medications mm
       LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
       GROUP BY COALESCE(p.name, 'No pharmacy assigned')
       ORDER BY active_scripts DESC, pharmacy_name
       LIMIT 6`
    );

    const riskFlagsResult = await pool.query(
      `SELECT
         mm.id,
         m.id AS member_id,
         CONCAT_WS(' ', m.first_name, m.last_name) AS member_name,
         m.member_number,
         med.name AS medication_name,
         COALESCE(p.name, 'No pharmacy assigned') AS pharmacy_name,
         mm.next_refill_date,
         COALESCE((
           SELECT ROUND(
             LEAST(
               (
                 COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0
               ) / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0),
               100
             )::numeric,
             1
           )
           FROM medication_logs ml
           WHERE ml.member_medication_id = mm.id
             AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
         ), 0) AS adherence_percent,
         CASE
           WHEN mm.end_date IS NULL AND mm.next_refill_date < CURRENT_DATE THEN 'refill_overdue'
           WHEN mm.end_date IS NULL AND mm.next_refill_date <= CURRENT_DATE + INTERVAL '3 days' THEN 'refill_due_soon'
           WHEN mm.end_date IS NULL AND mm.pharmacy_id IS NULL THEN 'no_pharmacy'
           WHEN mm.end_date IS NULL AND COALESCE((
             SELECT LEAST(
               (COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0) / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0),
               100
             )
             FROM medication_logs ml
             WHERE ml.member_medication_id = mm.id
               AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
           ), 0) < 70 THEN 'low_adherence'
           ELSE 'normal'
         END AS reason_code
       FROM member_medications mm
       JOIN members m ON m.id = mm.member_id
       JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
       WHERE mm.end_date IS NULL
         AND (
           mm.next_refill_date < CURRENT_DATE
           OR mm.next_refill_date <= CURRENT_DATE + INTERVAL '3 days'
           OR mm.pharmacy_id IS NULL
           OR COALESCE((
             SELECT LEAST(
               (COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0) / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0),
               100
             )
             FROM medication_logs ml
             WHERE ml.member_medication_id = mm.id
               AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
           ), 0) < 70
         )
       ORDER BY
         CASE
           WHEN mm.next_refill_date < CURRENT_DATE THEN 0
           WHEN mm.next_refill_date <= CURRENT_DATE + INTERVAL '3 days' THEN 1
           ELSE 2
         END,
         adherence_percent ASC,
         mm.created_at DESC
       LIMIT 8`
    );

    const assignmentsResult = await pool.query(
      `SELECT
         mm.id,
         mm.member_id,
         CONCAT_WS(' ', m.first_name, m.last_name) AS member_name,
         m.member_number,
         med.name AS medication_name,
         med.generic_name,
         COALESCE(c.name, (
           SELECT cond.name FROM member_conditions mc2
           JOIN conditions cond ON cond.id = mc2.condition_id
           WHERE mc2.member_id = mm.member_id
           ORDER BY mc2.diagnosed_date ASC NULLS LAST
           LIMIT 1
         )) AS condition_name,
         mm.dosage,
         mm.frequency,
         mm.start_date,
         mm.end_date,
         mm.start_time,
         mm.next_refill_date,
         mm.refill_interval_days,
         mm.reminder_enabled,
         COALESCE(p.name, 'No pharmacy assigned') AS pharmacy_name,
         (mm.prescription_file_url IS NOT NULL OR mm.photo_url IS NOT NULL OR mm.audio_url IS NOT NULL OR mm.video_url IS NOT NULL) AS has_media,
         mm.prescription_file_url,
         mm.photo_url,
         mm.audio_url,
         mm.video_url,
         COALESCE((
           SELECT ROUND(
             LEAST(
               (
                 COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0
               ) / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken', 'skipped')), 0),
               100
             )::numeric,
             1
           )
           FROM medication_logs ml
           WHERE ml.member_medication_id = mm.id
             AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
         ), 0) AS adherence_percent
       FROM member_medications mm
       JOIN members m ON m.id = mm.member_id
       JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN conditions c ON c.id = med.condition_id
       LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
       ORDER BY mm.created_at DESC
       LIMIT 40`
    );

    const adherenceByConditionResult = await pool.query(
      `SELECT
         COALESCE(cond.name, 'Uncategorised') AS condition_name,
         COUNT(DISTINCT mm.member_id) FILTER (WHERE mm.end_date IS NULL)::int AS members,
         COALESCE(ROUND(
            (AVG(COALESCE((
              SELECT LEAST(
                (COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0)
                / NULLIF(COUNT(*) FILTER (WHERE ml.status IN ('taken','skipped')), 0),
                100
              )
              FROM medication_logs ml
              WHERE ml.member_medication_id = mm.id
                AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
            ), 0)) FILTER (WHERE mm.end_date IS NULL))::numeric,
          1), 0) AS avg_adherence
       FROM member_medications mm
       JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN conditions cond ON cond.id = med.condition_id
       GROUP BY cond.id, cond.name
       HAVING COUNT(*) FILTER (WHERE mm.end_date IS NULL) > 0
       ORDER BY members DESC
       LIMIT 8`
    );

    const upcomingRefillsResult = await pool.query(
      `SELECT
         CONCAT_WS(' ', m.first_name, m.last_name) AS member_name,
         m.member_number,
         med.name AS medication_name,
         mm.next_refill_date,
         COALESCE(p.name, 'No pharmacy assigned') AS pharmacy_name,
         mm.id AS assignment_id
       FROM member_medications mm
       JOIN members m ON m.id = mm.member_id
       JOIN medications med ON med.id = mm.medication_id
       LEFT JOIN pharmacies p ON p.id = mm.pharmacy_id
       WHERE mm.end_date IS NULL
         AND mm.next_refill_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
       ORDER BY mm.next_refill_date ASC
       LIMIT 30`
    );

    const summary = summaryResult.rows[0];
    return res.json({
      summary,
      adherence_trend: adherenceTrendResult.rows,
      top_medications: topMedicationsResult.rows,
      pharmacy_breakdown: pharmacyBreakdownResult.rows,
      risk_flags: riskFlagsResult.rows,
      assignments: assignmentsResult.rows,
      adherence_by_condition: adherenceByConditionResult.rows,
      upcoming_refills: upcomingRefillsResult.rows,
      suggestions:buildMedicationSuggestions({
        summary,
        riskFlags: riskFlagsResult.rows,
        topMedications: topMedicationsResult.rows,
        pharmacyBreakdown: pharmacyBreakdownResult.rows,
      }),
    });
  } catch (err) {
    console.error('getMedicationAdminOverview error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deleteMemberMedication = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { id } = req.params;
    const result = await pool.query(
      'DELETE FROM member_medications WHERE id = $1 AND member_id = $2 RETURNING id',
      [id, memberId]
    );
    if (!result.rows.length) {
      return res.status(404).json({ message: 'Medication not found' });
    }
    return res.json({ message: 'Medication removed' });
  } catch (err) {
    console.error('deleteMemberMedication error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getAssignmentDoseLogs = async (req, res) => {
  try {
    const { id } = req.params;
    const assignment = await pool.query('SELECT id FROM member_medications WHERE id = $1', [id]);
    if (!assignment.rows.length) return res.status(404).json({ message: 'Assignment not found' });

    const result = await pool.query(
      `SELECT ml.id, ml.scheduled_time, ml.taken_at, ml.status, ml.notes,
              COALESCE(ml.notes, '') AS notes
       FROM medication_logs ml
       WHERE ml.member_medication_id = $1
       ORDER BY ml.scheduled_time DESC
       LIMIT 60`,
      [id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getAssignmentDoseLogs error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const adminStopAssignment = async (req, res) => {
  try {
    const { id } = req.params;
    const endDate = req.body?.end_date || new Date().toISOString().split('T')[0];
    const result = await pool.query(
      `UPDATE member_medications SET end_date = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [endDate, id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Assignment not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('adminStopAssignment error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateAssignmentRefill = async (req, res) => {
  try {
    const { id } = req.params;
    const { next_refill_date, refill_interval_days } = req.body;
    if (!next_refill_date) return res.status(400).json({ message: 'next_refill_date is required' });
    const result = await pool.query(
      `UPDATE member_medications
       SET next_refill_date = $1,
           refill_interval_days = COALESCE($2, refill_interval_days),
           updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [next_refill_date, refill_interval_days ? parseInt(refill_interval_days) : null, id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Assignment not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateAssignmentRefill error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  listMedications,
  createMedication,
  updateMedication,
  getMedicationAdminOverview,
  assignMedication,
  listMyMedications,
  stopMedication,
  deleteMemberMedication,
  logDose,
  getDoseLogs,
  computeDoseTimes,
  searchMedications,
  adminStopAssignment,
  updateAssignmentRefill,
  getAssignmentDoseLogs,
};
