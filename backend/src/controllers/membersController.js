const pool = require('../config/db');
const csvParser = require('csv-parser');
const { Readable } = require('stream');
const notificationService = require('../services/notificationService');

const resolveConditionIds = async (client, rawConditions = []) => {
  const names = [...new Set(
    rawConditions
      .flatMap((entry) => Array.isArray(entry) ? entry : `${entry}`.split(','))
      .map((entry) => entry.trim())
      .filter(Boolean)
  )];

  const conditionIds = [];
  for (const name of names) {
    let condition = await client.query(
      'SELECT id FROM conditions WHERE LOWER(name) = LOWER($1) LIMIT 1',
      [name]
    );

    if (!condition.rows.length) {
      condition = await client.query(
        'INSERT INTO conditions (name, is_active) VALUES ($1, TRUE) RETURNING id',
        [name]
      );
    }

    conditionIds.push(condition.rows[0].id);
  }

  return conditionIds;
};

const toNumber = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const average = (values) => {
  const normalized = values.map(toNumber).filter((value) => value !== null);
  if (!normalized.length) return null;
  return Number((normalized.reduce((sum, value) => sum + value, 0) / normalized.length).toFixed(1));
};

const normalizeConditions = (conditions) => (
  Array.isArray(conditions)
    ? conditions
      .map((condition) => (typeof condition === 'string' ? condition : condition?.name))
      .filter(Boolean)
    : []
);

const buildMemberInsights = ({
  conditions,
  medications,
  vitals,
  checkins,
  meals,
  fitness,
  psychosocial,
  appointments,
  labTests,
  treatmentPlans,
  medicationAdherence,
}) => {
  const conditionNames = normalizeConditions(conditions).map((name) => name.toLowerCase());
  const avgBloodSugar = average(vitals.map((entry) => entry.blood_sugar_mmol));
  const avgSystolic = average(vitals.map((entry) => entry.systolic_bp));
  const avgDiastolic = average(vitals.map((entry) => entry.diastolic_bp));
  const avgPain = average(vitals.map((entry) => entry.pain_level));
  const avgEnergy = average(checkins.map((entry) => entry.energy_level));
  const avgStress = average(psychosocial.map((entry) => entry.stress_level));
  const avgAnxiety = average(psychosocial.map((entry) => entry.anxiety_level));
  const adherencePct = medicationAdherence?.adherence_pct ?? null;
  const upcomingAppointments = appointments.filter((entry) => ['pending', 'confirmed'].includes(entry.status)).length;
  const missedAppointments = appointments.filter((entry) => entry.status === 'missed').length;
  const overdueLabs = labTests.filter((entry) => entry.status === 'overdue').length;
  const activeTreatments = treatmentPlans.filter((entry) => entry.status === 'active').length;
  const stepsLast30Days = fitness.reduce((sum, entry) => sum + (toNumber(entry.steps) || 0), 0);

  const advice = [];
  const suggestions = [];
  const strengths = [];
  let severityScore = 0;

  if (conditionNames.some((name) => name.includes('diabetes')) && avgBloodSugar !== null) {
    if (avgBloodSugar > 9) {
      severityScore += 2;
      advice.push(`Average blood sugar is ${avgBloodSugar} mmol/L, which suggests glycaemic control needs attention.`);
      suggestions.push('Review diet logs, medication adherence, and consider a clinician follow-up for glucose management.');
    } else if (avgBloodSugar <= 7.8) {
      strengths.push(`Blood sugar trend is stable at an average of ${avgBloodSugar} mmol/L.`);
    }
  }

  if (avgSystolic !== null || avgDiastolic !== null) {
    if ((avgSystolic || 0) >= 140 || (avgDiastolic || 0) >= 90) {
      severityScore += 2;
      advice.push(`Average blood pressure is ${avgSystolic || '—'}/${avgDiastolic || '—'} mmHg, which is above target.`);
      suggestions.push('Escalate blood pressure review and reinforce medication plus lifestyle compliance.');
    } else if ((avgSystolic || 0) > 0 && (avgDiastolic || 0) > 0) {
      strengths.push(`Blood pressure trend is currently ${avgSystolic}/${avgDiastolic} mmHg on average.`);
    }
  }

  if (adherencePct !== null) {
    if (adherencePct < 70) {
      severityScore += 2;
      advice.push(`Medication adherence is low at ${adherencePct}% over the last 30 days.`);
      suggestions.push('Send a check-in message, verify refill access, and review the treatment routine with the member.');
    } else if (adherencePct < 85) {
      severityScore += 1;
      advice.push(`Medication adherence is moderate at ${adherencePct}% and could be improved.`);
      suggestions.push('Encourage the member to use reminders consistently and confirm dosing times still fit their routine.');
    } else {
      strengths.push(`Medication adherence is strong at ${adherencePct}%.`);
    }
  }

  if (avgPain !== null && avgPain >= 7) {
    severityScore += 1;
    advice.push(`Pain scores are elevated with an average of ${avgPain}/10.`);
    suggestions.push('Check whether pain symptoms are worsening and decide if clinician escalation or emergency review is needed.');
  }

  if ((avgStress !== null && avgStress > 6) || (avgAnxiety !== null && avgAnxiety > 6)) {
    severityScore += 1;
    advice.push(`Psychosocial check-ins show elevated stress/anxiety levels (${avgStress || '—'}/${avgAnxiety || '—'}).`);
    suggestions.push('Offer counselling support, lifestyle coaching, or direct follow-up through the admin messaging channel.');
  } else if (avgStress !== null || avgAnxiety !== null) {
    strengths.push(`Psychosocial check-ins are being captured consistently.`);
  }

  if (overdueLabs > 0) {
    severityScore += 1;
    advice.push(`${overdueLabs} lab test${overdueLabs === 1 ? ' is' : 's are'} overdue.`);
    suggestions.push('Follow up on pending lab work and book collection or review dates.');
  }

  if (missedAppointments > 0) {
    severityScore += 1;
    advice.push(`${missedAppointments} appointment${missedAppointments === 1 ? ' has' : 's have'} been missed recently.`);
    suggestions.push('Confirm transport/access barriers and consider rescheduling missed appointments.');
  }

  if (upcomingAppointments > 0) {
    strengths.push(`${upcomingAppointments} upcoming appointment${upcomingAppointments === 1 ? '' : 's'} already scheduled.`);
  }

  if (stepsLast30Days > 0) {
    strengths.push(`Fitness logs show ${stepsLast30Days.toLocaleString()} tracked steps recently.`);
  }

  const status = severityScore >= 5
    ? 'critical'
    : severityScore >= 2
      ? 'needs_attention'
      : 'on_track';

  const summary = status === 'critical'
    ? 'This member needs prompt clinical or care-team attention based on recent submissions.'
    : status === 'needs_attention'
      ? 'This member is showing mixed progress and would benefit from follow-up and coaching.'
      : 'This member appears to be progressing steadily based on the latest available data.';

  return {
    status,
    summary,
    strengths,
    advice,
    suggestions,
    metrics: {
      medication_adherence_pct: adherencePct,
      avg_blood_sugar: avgBloodSugar,
      avg_systolic_bp: avgSystolic,
      avg_diastolic_bp: avgDiastolic,
      avg_pain_level: avgPain,
      avg_energy_level: avgEnergy,
      avg_stress_level: avgStress,
      avg_anxiety_level: avgAnxiety,
      meals_logged_last_30_days: meals.length,
      workouts_last_30_days: fitness.length,
      steps_last_30_days: stepsLast30Days,
      upcoming_appointments: upcomingAppointments,
      missed_appointments: missedAppointments,
      overdue_lab_tests: overdueLabs,
      active_treatment_plans: activeTreatments,
      active_medications: medications.length,
    },
  };
};

const getProfile = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT m.*, 
              json_agg(DISTINCT jsonb_build_object(
                'id', c.id, 'name', c.name, 'diagnosed_date', mc.diagnosed_date
              )) FILTER (WHERE c.id IS NOT NULL) AS conditions
       FROM members m
       LEFT JOIN member_conditions mc ON mc.member_id = m.id
       LEFT JOIN conditions c ON c.id = mc.condition_id
       WHERE m.id = $1
       GROUP BY m.id`,
      [memberId]
    );
    const member = result.rows[0];
    if (!member) return res.status(404).json({ message: 'Member not found' });

    delete member.password_hash;
    return res.json(member);
  } catch (err) {
    console.error('getProfile error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateProfile = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { phone, email, fcm_token, gender } = req.body;

    await pool.query(
      `UPDATE members
       SET phone = COALESCE($1, phone),
           email = COALESCE($2, email),
           fcm_token = COALESCE($3, fcm_token),
           gender = COALESCE($4, gender),
           updated_at = NOW()
       WHERE id = $5`,
      [phone, email, fcm_token, gender, memberId]
    );

    const result = await pool.query(
      `SELECT m.*, 
              json_agg(DISTINCT jsonb_build_object(
                'id', c.id, 'name', c.name, 'diagnosed_date', mc.diagnosed_date
              )) FILTER (WHERE c.id IS NOT NULL) AS conditions
       FROM members m
       LEFT JOIN member_conditions mc ON mc.member_id = m.id
       LEFT JOIN conditions c ON c.id = mc.condition_id
       WHERE m.id = $1
       GROUP BY m.id`,
      [memberId]
    );
    const member = result.rows[0];
    delete member.password_hash;
    return res.json(member);
  } catch (err) {
    console.error('updateProfile error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listMembers = async (req, res) => {
  try {
    const {
      search,
      condition_id,
      condition,
      is_active,
      status,
      page = 1,
      limit = 20,
    } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const params = [];
    const conditions = [];
    let idx = 1;

    if (search) {
      conditions.push(`(m.first_name ILIKE $${idx} OR m.last_name ILIKE $${idx} OR m.member_number ILIKE $${idx} OR m.email ILIKE $${idx})`);
      params.push(`%${search}%`);
      idx++;
    }
    if (condition_id) {
      conditions.push(`mc.condition_id = $${idx}`);
      params.push(condition_id);
      idx++;
    }
    if (condition) {
      conditions.push(`LOWER(c.name) = LOWER($${idx})`);
      params.push(condition);
      idx++;
    }

    const activeFilter = is_active !== undefined
      ? is_active
      : (status === 'active' ? 'true' : status === 'inactive' ? 'false' : undefined);

    if (activeFilter !== undefined) {
      conditions.push(`m.is_active = $${idx}`);
      params.push(activeFilter === 'true');
      idx++;
    }

    const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const joinClause = 'LEFT JOIN member_conditions mc ON mc.member_id = m.id LEFT JOIN conditions c ON c.id = mc.condition_id';

    const countResult = await pool.query(
      `SELECT COUNT(DISTINCT m.id) FROM members m ${joinClause} ${whereClause}`,
      params
    );
    const total = parseInt(countResult.rows[0].count);

    params.push(parseInt(limit), offset);
    const result = await pool.query(
      `SELECT
              m.id,
              m.member_number,
              m.first_name,
              m.last_name,
              m.email,
              m.phone,
              m.gender,
              m.plan_type,
              m.plan_type AS plan,
              m.scheme_id,
              s.name AS scheme_name,
              m.is_active,
              m.is_password_set,
              m.created_at,
              COALESCE(array_remove(array_agg(DISTINCT c.name), NULL), ARRAY[]::VARCHAR[]) AS conditions
       FROM members m
       LEFT JOIN schemes s ON s.id = m.scheme_id
       ${joinClause} ${whereClause}
       GROUP BY m.id, s.name
       ORDER BY m.created_at DESC
        LIMIT $${idx} OFFSET $${idx + 1}`,
      params
    );

    return res.json({
      members: result.rows,
      data: result.rows,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
    });
  } catch (err) {
    console.error('listMembers error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMemberById = async (req, res) => {
  try {
    const { id } = req.params;

    const memberResult = await pool.query(
      `SELECT m.*,
              s.name AS scheme_name,
              json_agg(DISTINCT jsonb_build_object('id', c.id, 'name', c.name, 'diagnosed_date', mc.diagnosed_date))
                FILTER (WHERE c.id IS NOT NULL) AS conditions
       FROM members m
       LEFT JOIN schemes s ON s.id = m.scheme_id
       LEFT JOIN member_conditions mc ON mc.member_id = m.id
       LEFT JOIN conditions c ON c.id = mc.condition_id
       WHERE m.id = $1
       GROUP BY m.id, s.name`,
      [id]
    );
    if (!memberResult.rows.length) return res.status(404).json({ message: 'Member not found' });

    const member = memberResult.rows[0];
    delete member.password_hash;

    const [
      medsResult,
      vitalsResult,
      appointmentsResult,
      checkinsResult,
      mealsResult,
      fitnessResult,
      psychosocialResult,
      labTestsResult,
      treatmentPlansResult,
      medicationAdherenceResult,
    ] = await Promise.all([
      pool.query(
        `SELECT mm.*, med.name AS medication_name, med.generic_name, med.notes AS medication_notes,
                c.name AS condition_name,
                COALESCE((
                  SELECT ROUND(LEAST(COUNT(*) FILTER (WHERE ml.status = 'taken') * 100.0 / NULLIF(COUNT(*), 0), 100), 1)
                  FROM medication_logs ml
                  WHERE ml.member_medication_id = mm.id
                    AND ml.scheduled_time >= NOW() - INTERVAL '30 days'
                ), 0) AS adherence_percent
         FROM member_medications mm
         JOIN medications med ON med.id = mm.medication_id
         LEFT JOIN conditions c ON c.id = med.condition_id
         WHERE mm.member_id = $1
         ORDER BY mm.created_at DESC`,
        [id]
      ),
      pool.query(
        `SELECT * FROM vitals WHERE member_id = $1 ORDER BY recorded_at DESC LIMIT 30`,
        [id]
      ),
      pool.query(
        `SELECT a.*, h.name AS hospital_name, c.name AS condition_name
         FROM appointments a
         JOIN hospitals h ON h.id = a.hospital_id
         LEFT JOIN conditions c ON c.id = a.condition_id
         WHERE a.member_id = $1
         ORDER BY a.appointment_date DESC, a.created_at DESC
         LIMIT 20`,
        [id]
      ),
      pool.query(
        `SELECT * FROM daily_checkins WHERE member_id = $1 ORDER BY checkin_date DESC LIMIT 30`,
        [id]
      ),
      pool.query(
        `SELECT * FROM meal_logs WHERE member_id = $1 ORDER BY log_date DESC, created_at DESC LIMIT 20`,
        [id]
      ),
      pool.query(
        `SELECT * FROM fitness_logs WHERE member_id = $1 ORDER BY log_date DESC, created_at DESC LIMIT 20`,
        [id]
      ),
      pool.query(
        `SELECT * FROM psychosocial_checkins WHERE member_id = $1 ORDER BY checkin_date DESC, created_at DESC LIMIT 20`,
        [id]
      ),
      pool.query(
        `SELECT * FROM lab_tests WHERE member_id = $1 ORDER BY due_date DESC, created_at DESC LIMIT 20`,
        [id]
      ),
      pool.query(
        `SELECT tp.*, c.name AS condition_name
         FROM treatment_plans tp
         LEFT JOIN conditions c ON c.id = tp.condition_id
         WHERE tp.member_id = $1
         ORDER BY tp.plan_date DESC NULLS LAST, tp.created_at DESC
         LIMIT 20`,
        [id]
      ),
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE status = 'taken') AS taken,
           COUNT(*) FILTER (WHERE status IN ('taken', 'skipped')) AS total
         FROM medication_logs
         WHERE member_id = $1
           AND scheduled_time >= NOW() - INTERVAL '30 days'`,
        [id]
      ),
    ]);

    const medicationAdherence = (() => {
      const row = medicationAdherenceResult.rows[0] || {};
      const taken = parseInt(row.taken || 0, 10);
      const total = parseInt(row.total || 0, 10);
      return {
        taken,
        total,
        adherence_pct: total > 0 ? Math.round((taken / total) * 100) : null,
      };
    })();

    const checkins = checkinsResult.rows.map((entry) => ({
      ...entry,
      symptoms: Array.isArray(entry.symptoms) ? entry.symptoms : (() => {
        if (!entry.symptoms) return [];
        try {
          const parsed = JSON.parse(entry.symptoms);
          return Array.isArray(parsed) ? parsed : [];
        } catch {
          return [];
        }
      })(),
    }));

    const insights = buildMemberInsights({
      conditions: member.conditions,
      medications: medsResult.rows,
      vitals: vitalsResult.rows,
      checkins,
      meals: mealsResult.rows,
      fitness: fitnessResult.rows,
      psychosocial: psychosocialResult.rows,
      appointments: appointmentsResult.rows,
      labTests: labTestsResult.rows,
      treatmentPlans: treatmentPlansResult.rows,
      medicationAdherence,
    });

    return res.json({
      ...member,
      plan: member.plan_type,
      medications: medsResult.rows,
      vitals_history: vitalsResult.rows,
      recent_vitals: vitalsResult.rows,
      appointments_history: appointmentsResult.rows,
      recent_appointments: appointmentsResult.rows,
      daily_checkins: checkins,
      meals: mealsResult.rows,
      fitness_logs: fitnessResult.rows,
      psychosocial_checkins: psychosocialResult.rows,
      lab_tests: labTestsResult.rows,
      treatment_plans: treatmentPlansResult.rows,
      medication_adherence: medicationAdherence,
      lifestyle_summary: {
        meals_logged_last_30_days: mealsResult.rows.length,
        workouts_last_30_days: fitnessResult.rows.length,
        psychosocial_entries_last_30_days: psychosocialResult.rows.length,
        checkins_last_30_days: checkins.length,
      },
      insights,
    });
  } catch (err) {
    console.error('getMemberById error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const uploadMembers = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'CSV file is required' });

    const rows = [];
    const stream = Readable.from(req.file.buffer.toString());

    await new Promise((resolve, reject) => {
      stream
        .pipe(csvParser())
        .on('data', (row) => rows.push(row))
        .on('end', resolve)
        .on('error', reject);
    });

    if (!rows.length) return res.status(400).json({ message: 'CSV file is empty' });

    let inserted = 0;
    let skipped = 0;
    const newMemberIds = [];

    for (const row of rows) {
      const {
        member_number,
        first_name,
        last_name,
        date_of_birth,
        email,
        phone,
        plan_type,
        plan,
      } = row;
      if (!member_number || !first_name || !last_name || !date_of_birth) {
        skipped++;
        continue;
      }

      const result = await pool.query(
        `INSERT INTO members (member_number, first_name, last_name, date_of_birth, email, phone, plan_type)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (member_number) DO NOTHING
         RETURNING id`,
        [member_number, first_name, last_name, date_of_birth, email || null, phone || null, plan_type || plan || null]
      );

      if (result.rows.length) {
        inserted++;
        newMemberIds.push(result.rows[0].id);
      } else {
        skipped++;
      }
    }

    // Fire-and-forget welcome notifications
    for (const memberId of newMemberIds) {
      notificationService.sendWelcome(memberId).catch((err) =>
        console.error(`Welcome notification failed for ${memberId}:`, err.message)
      );
    }

    return res.json({ message: 'Upload complete', inserted, skipped });
  } catch (err) {
    console.error('uploadMembers error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const toggleMemberStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `UPDATE members SET is_active = NOT is_active, updated_at = NOW()
       WHERE id = $1 RETURNING id, is_active, first_name, last_name, member_number`,
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Member not found' });

    const m = result.rows[0];
    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', $2, 'member', $3, $4, $5)`,
      [
        req.user.id,
        m.is_active ? 'activate_member' : 'deactivate_member',
        id,
        JSON.stringify({ member_number: m.member_number, name: `${m.first_name} ${m.last_name}`, admin_name: req.user.name || req.user.email }),
        req.ip,
      ]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('toggleMemberStatus error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const exportMembers = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT m.id, m.member_number, m.first_name, m.last_name, m.email, m.phone,
              m.gender, m.plan_type, m.date_of_birth, m.is_active, m.is_password_set,
              m.created_at,
              COALESCE(json_agg(DISTINCT c.name) FILTER (WHERE c.id IS NOT NULL), '[]') AS conditions
       FROM members m
       LEFT JOIN member_conditions mc ON mc.member_id = m.id
       LEFT JOIN conditions c ON c.id = mc.condition_id
       GROUP BY m.id
       ORDER BY m.last_name, m.first_name`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('exportMembers error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateConditions = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { conditions } = req.body;

    if (!Array.isArray(conditions)) {
      return res.status(400).json({ message: 'conditions must be an array of strings' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Remove all existing conditions for this member
      await client.query('DELETE FROM member_conditions WHERE member_id = $1', [memberId]);

      for (const rawName of conditions) {
        const name = (rawName || '').toString().trim();
        if (!name) continue;

        // Find existing condition (case-insensitive) or create a new one
        let condResult = await client.query(
          'SELECT id FROM conditions WHERE LOWER(name) = LOWER($1) LIMIT 1',
          [name]
        );

        let conditionId;
        if (condResult.rows.length) {
          conditionId = condResult.rows[0].id;
        } else {
          const newCond = await client.query(
            'INSERT INTO conditions (name, is_active) VALUES ($1, true) RETURNING id',
            [name]
          );
          conditionId = newCond.rows[0].id;
        }

        await client.query(
          `INSERT INTO member_conditions (member_id, condition_id, diagnosed_date)
           VALUES ($1, $2, CURRENT_DATE)
           ON CONFLICT DO NOTHING`,
          [memberId, conditionId]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    // Return full updated profile (same shape as getProfile)
    const result = await pool.query(
      `SELECT m.*,
              json_agg(DISTINCT jsonb_build_object(
                'id', c.id, 'name', c.name, 'diagnosed_date', mc.diagnosed_date
              )) FILTER (WHERE c.id IS NOT NULL) AS conditions
       FROM members m
       LEFT JOIN member_conditions mc ON mc.member_id = m.id
       LEFT JOIN conditions c ON c.id = mc.condition_id
       WHERE m.id = $1
       GROUP BY m.id`,
      [memberId]
    );
    const member = result.rows[0];
    delete member.password_hash;
    return res.json(member);
  } catch (err) {
    console.error('updateConditions error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const registerMember = async (req, res) => {
  try {
    const {
      member_number, first_name, last_name, email, phone,
      plan, plan_type, scheme_id, conditions, date_of_birth, id_number,
    } = req.body;
    if (!member_number || !first_name || !last_name || !date_of_birth) {
      return res.status(400).json({ message: 'member_number, first_name, last_name, date_of_birth are required' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const existing = await client.query(
        'SELECT id FROM members WHERE member_number = $1',
        [member_number]
      );
      if (existing.rows.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({ message: 'Member number already exists' });
      }

      const result = await client.query(
        `INSERT INTO members
          (member_number, first_name, last_name, email, phone, plan_type, scheme_id, date_of_birth, id_number, is_active)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,TRUE)
         RETURNING id, member_number, first_name, last_name, email, phone, plan_type, scheme_id, date_of_birth, id_number, is_active, created_at`,
        [
          member_number,
          first_name,
          last_name,
          email || null,
          phone || null,
          plan_type || plan || null,
          scheme_id || null,
          date_of_birth,
          id_number || null,
        ]
      );

      const member = result.rows[0];
      const conditionIds = await resolveConditionIds(client, Array.isArray(conditions) ? conditions : [conditions]);
      for (const conditionId of conditionIds) {
        await client.query(
          `INSERT INTO member_conditions (member_id, condition_id, diagnosed_date)
           VALUES ($1, $2, CURRENT_DATE)
           ON CONFLICT (member_id, condition_id) DO NOTHING`,
          [member.id, conditionId]
        );
      }

      // Audit log
      await client.query(
        `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
         VALUES ($1, 'admin', 'create_member', 'member', $2, $3, $4)`,
        [req.user.id, member.id, JSON.stringify({ member_number, first_name, last_name, admin_name: req.user.name || req.user.email }), req.ip]
      );

      await client.query('COMMIT');

      notificationService.sendWelcome(member.id).catch((err) =>
        console.error(`Welcome notification failed for ${member.id}:`, err.message)
      );

      return res.status(201).json({
        ...member,
        plan: member.plan_type,
        conditions: Array.isArray(conditions) ? conditions.filter(Boolean) : (conditions ? [`${conditions}`] : []),
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('registerMember error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Admin: update a member's details
const adminUpdateMember = async (req, res) => {
  try {
    const memberId = req.params.id;
    const {
      member_number, first_name, last_name, email, phone,
      scheme_id, date_of_birth, id_number, gender, conditions,
    } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Check member exists
      const existing = await client.query('SELECT id, member_number FROM members WHERE id = $1', [memberId]);
      if (!existing.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Member not found' });
      }

      // If changing member_number, check uniqueness
      if (member_number && member_number !== existing.rows[0].member_number) {
        const dup = await client.query('SELECT id FROM members WHERE member_number = $1 AND id != $2', [member_number, memberId]);
        if (dup.rows.length) {
          await client.query('ROLLBACK');
          return res.status(409).json({ message: 'Member number already in use' });
        }
      }

      await client.query(
        `UPDATE members SET
           member_number = COALESCE($1, member_number),
           first_name = COALESCE($2, first_name),
           last_name = COALESCE($3, last_name),
           email = COALESCE($4, email),
           phone = COALESCE($5, phone),
           scheme_id = $6,
           date_of_birth = COALESCE($7, date_of_birth),
           id_number = COALESCE($8, id_number),
           gender = COALESCE($9, gender),
           updated_at = NOW()
         WHERE id = $10`,
        [
          member_number || null, first_name || null, last_name || null,
          email || null, phone || null, scheme_id || null,
          date_of_birth || null, id_number || null, gender || null,
          memberId,
        ]
      );

      // Update conditions if provided
      if (conditions !== undefined) {
        await client.query('DELETE FROM member_conditions WHERE member_id = $1', [memberId]);
        const conditionIds = await resolveConditionIds(client, Array.isArray(conditions) ? conditions : [conditions]);
        for (const conditionId of conditionIds) {
          await client.query(
            `INSERT INTO member_conditions (member_id, condition_id, diagnosed_date)
             VALUES ($1, $2, CURRENT_DATE) ON CONFLICT (member_id, condition_id) DO NOTHING`,
            [memberId, conditionId]
          );
        }
      }

      // Audit log
      await client.query(
        `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
         VALUES ($1, 'admin', 'update_member', 'member', $2, $3, $4)`,
        [req.user.id, memberId, JSON.stringify({
          admin_name: req.user.name || req.user.email,
          fields_updated: Object.keys(req.body).filter(k => req.body[k] !== undefined),
        }), req.ip]
      );

      await client.query('COMMIT');

      // Re-fetch updated member
      const result = await pool.query(
        `SELECT m.*, s.name AS scheme_name,
                json_agg(DISTINCT jsonb_build_object('id', c.id, 'name', c.name, 'diagnosed_date', mc.diagnosed_date))
                  FILTER (WHERE c.id IS NOT NULL) AS conditions
         FROM members m
         LEFT JOIN schemes s ON s.id = m.scheme_id
         LEFT JOIN member_conditions mc ON mc.member_id = m.id
         LEFT JOIN conditions c ON c.id = mc.condition_id
         WHERE m.id = $1
         GROUP BY m.id, s.name`,
        [memberId]
      );
      const member = result.rows[0];
      delete member.password_hash;
      return res.json(member);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('adminUpdateMember error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  getProfile,
  updateProfile,
  updateConditions,
  listMembers,
  getMemberById,
  uploadMembers,
  toggleMemberStatus,
  exportMembers,
  registerMember,
  adminUpdateMember,
};
