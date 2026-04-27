const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const pool = require('../config/db');

// List conditions — admins see all with counts; public sees only active
router.get('/', async (req, res) => {
  try {
    const isAdmin = req.headers.authorization ? (() => {
      try {
        const jwt = require('jsonwebtoken');
        const token = req.headers.authorization.split(' ')[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        return decoded.type === 'admin';
      } catch { return false; }
    })() : false;

    const whereClause = isAdmin ? '' : 'WHERE c.is_active = TRUE';

    const result = await pool.query(`
      SELECT
        c.*,
        COUNT(DISTINCT mc.member_id)::int  AS member_count,
        COUNT(DISTINCT m.id)::int          AS medication_count
      FROM conditions c
      LEFT JOIN member_conditions mc ON mc.condition_id = c.id
      LEFT JOIN medications m        ON m.condition_id  = c.id
      ${whereClause}
      GROUP BY c.id
      ORDER BY c.name
    `);
    return res.json(result.rows);
  } catch (err) {
    console.error('listConditions error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Admin: sync comprehensive condition list
router.post('/sync', authenticate, requireAdmin, async (req, res) => {
  const standardConditions = [
    { name: 'Type 1 Diabetes', description: 'Autoimmune condition where the pancreas produces little or no insulin' },
    { name: 'Type 2 Diabetes', description: 'Metabolic disorder causing high blood sugar due to insulin resistance' },
    { name: 'Hypertension', description: 'Chronic high blood pressure requiring ongoing management' },
    { name: 'Asthma', description: 'Chronic inflammatory lung disease causing breathing difficulties' },
    { name: 'COPD', description: 'Chronic obstructive pulmonary disease causing breathing obstruction' },
    { name: 'Coronary Artery Disease', description: 'Narrowing of coronary arteries reducing blood flow to the heart' },
    { name: 'Heart Failure', description: 'Heart unable to pump sufficient blood to meet body needs' },
    { name: 'Atrial Fibrillation', description: 'Irregular and often rapid heart rate' },
    { name: 'Chronic Kidney Disease', description: 'Gradual loss of kidney function over time' },
    { name: 'Rheumatoid Arthritis', description: 'Autoimmune disease causing joint inflammation' },
    { name: 'Osteoarthritis', description: 'Degenerative joint disease causing cartilage breakdown' },
    { name: 'Osteoporosis', description: 'Condition causing bones to become weak and brittle' },
    { name: 'HIV/AIDS', description: 'Chronic viral infection requiring antiretroviral therapy' },
    { name: 'Tuberculosis', description: 'Infectious bacterial disease primarily affecting the lungs' },
    { name: 'Epilepsy', description: 'Neurological disorder causing recurrent seizures' },
    { name: 'Multiple Sclerosis', description: 'Disease where the immune system attacks the protective myelin sheath' },
    { name: "Parkinson's Disease", description: 'Progressive nervous system disorder affecting movement' },
    { name: "Alzheimer's Disease", description: 'Progressive neurological disorder causing memory loss' },
    { name: 'Stroke', description: 'Brain injury caused by interrupted or reduced blood supply' },
    { name: 'Depression', description: 'Major depressive disorder affecting mood and daily functioning' },
    { name: 'Anxiety Disorder', description: 'Chronic anxiety conditions requiring ongoing management' },
    { name: 'Bipolar Disorder', description: 'Mental health condition causing extreme mood swings' },
    { name: 'Schizophrenia', description: 'Serious mental disorder affecting thinking, feeling and behaviour' },
    { name: 'Hypothyroidism', description: 'Underactive thyroid gland producing insufficient thyroid hormone' },
    { name: 'Hyperthyroidism', description: 'Overactive thyroid gland producing excessive thyroid hormone' },
    { name: 'Lupus', description: 'Autoimmune disease where the immune system attacks healthy tissue' },
    { name: "Crohn's Disease", description: 'Inflammatory bowel disease causing digestive tract inflammation' },
    { name: 'Ulcerative Colitis', description: 'Inflammatory bowel disease affecting the colon and rectum' },
    { name: 'Irritable Bowel Syndrome', description: 'Common disorder affecting the large intestine' },
    { name: 'Chronic Pain', description: 'Long-term pain condition requiring continuous management' },
    { name: 'Fibromyalgia', description: 'Widespread musculoskeletal pain and fatigue disorder' },
    { name: 'Migraine', description: 'Recurring headache disorder with moderate to severe pain' },
    { name: 'Sleep Apnoea', description: 'Serious sleep disorder causing repeated breathing interruptions' },
    { name: 'Obesity', description: 'Chronic condition of excess body fat impacting health' },
    { name: 'Anaemia', description: 'Deficiency of red blood cells or haemoglobin' },
    { name: 'Sickle Cell Disease', description: 'Inherited blood disorder affecting haemoglobin' },
    { name: 'Psoriasis', description: 'Autoimmune condition causing rapid skin cell build-up' },
    { name: 'Eczema', description: 'Chronic inflammatory skin condition causing itching and rash' },
    { name: 'Glaucoma', description: 'Eye condition damaging the optic nerve' },
    { name: 'Macular Degeneration', description: 'Eye disease causing central vision loss' },
    { name: 'Peripheral Artery Disease', description: 'Narrowed arteries reducing blood flow to the limbs' },
    { name: 'Deep Vein Thrombosis', description: 'Blood clot forming in a deep vein' },
    { name: 'Liver Cirrhosis', description: 'Scarring of liver tissue from long-term damage' },
    { name: 'Non-Alcoholic Fatty Liver Disease', description: 'Build-up of fat in liver cells not caused by alcohol' },
    { name: 'Gout', description: 'Form of inflammatory arthritis caused by uric acid buildup' },
    { name: 'Endometriosis', description: 'Tissue similar to uterine lining grows outside the uterus' },
    { name: 'Polycystic Ovary Syndrome', description: 'Hormonal disorder causing enlarged ovaries with cysts' },
    { name: 'Prostate Hyperplasia', description: 'Non-cancerous enlargement of the prostate gland' },
    { name: 'Chronic Hepatitis B', description: 'Long-term liver infection caused by hepatitis B virus' },
    { name: 'Chronic Hepatitis C', description: 'Long-term liver infection caused by hepatitis C virus' },
  ];

  try {
    let synced = 0;
    for (const c of standardConditions) {
      await pool.query(
        'INSERT INTO conditions (name, description) VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description, is_active = TRUE',
        [c.name, c.description]
      );
      synced++;
    }
    return res.json({ message: `Synced ${synced} conditions`, synced });
  } catch (err) {
    console.error('conditions sync error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Admin: create a new condition
router.post('/', authenticate, requireAdmin, async (req, res) => {
  try {
    const { name, description, icd_code } = req.body;
    if (!name) return res.status(400).json({ message: 'Name is required' });
    const result = await pool.query(
      'INSERT INTO conditions (name, description) VALUES ($1, $2) RETURNING *',
      [name, description ? `${icd_code ? '[' + icd_code + '] ' : ''}${description}` : (icd_code || null)]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ message: 'Condition already exists' });
    return res.status(500).json({ message: 'Server error' });
  }
});

// Admin: update condition name/description
router.put('/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description } = req.body;
    if (!name) return res.status(400).json({ message: 'Name is required' });
    const result = await pool.query(
      'UPDATE conditions SET name = $1, description = $2 WHERE id = $3 RETURNING *',
      [name, description || null, id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Condition not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ message: 'Condition name already exists' });
    console.error('updateCondition error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Admin: delete condition (only if no members or medications linked)
router.delete('/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const deps = await pool.query(
      'SELECT (SELECT COUNT(*) FROM member_conditions WHERE condition_id=$1)::int AS members, (SELECT COUNT(*) FROM medications WHERE condition_id=$1)::int AS medications',
      [id]
    );
    const { members, medications } = deps.rows[0];
    if (members > 0 || medications > 0) {
      return res.status(409).json({
        message: `Cannot delete — ${members} member(s) and ${medications} medication(s) are linked. Deactivate instead.`,
      });
    }
    const result = await pool.query('DELETE FROM conditions WHERE id = $1 RETURNING id', [id]);
    if (!result.rows.length) return res.status(404).json({ message: 'Condition not found' });
    return res.json({ message: 'Condition deleted' });
  } catch (err) {
    console.error('deleteCondition error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Admin: condition detail — medications, treatment plans, enrolled members
router.get('/:id/detail', authenticate, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    // Condition with aggregated counts
    const condResult = await pool.query(`
      SELECT c.*,
        COUNT(DISTINCT mc.member_id)::int  AS member_count,
        COUNT(DISTINCT m.id)::int          AS medication_count,
        COUNT(DISTINCT tp.id)::int         AS treatment_plan_count
      FROM conditions c
      LEFT JOIN member_conditions mc ON mc.condition_id = c.id
      LEFT JOIN medications m        ON m.condition_id  = c.id
      LEFT JOIN treatment_plans tp   ON tp.condition_id = c.id
      WHERE c.id = $1
      GROUP BY c.id
    `, [id]);
    if (!condResult.rows.length) return res.status(404).json({ message: 'Condition not found' });

    // Medications with active assignment count
    const medsResult = await pool.query(`
      SELECT m.id, m.name, m.generic_name, m.dosage_options, m.frequency_options, m.notes, m.is_active,
        COUNT(mm.id)::int AS active_assignments
      FROM medications m
      LEFT JOIN member_medications mm ON mm.medication_id = m.id
        AND (mm.end_date IS NULL OR mm.end_date >= CURRENT_DATE)
      WHERE m.condition_id = $1
      GROUP BY m.id
      ORDER BY m.name
    `, [id]);

    // Treatment plan counts by status
    const tpStatus = await pool.query(`
      SELECT status, COUNT(*)::int AS count
      FROM treatment_plans
      WHERE condition_id = $1
      GROUP BY status
    `, [id]);

    // Recent 5 treatment plans
    const tpRecent = await pool.query(`
      SELECT tp.id, tp.title, tp.status, tp.cost, tp.currency, tp.plan_date, tp.provider_name,
        mem.first_name, mem.last_name, mem.member_number
      FROM treatment_plans tp
      JOIN members mem ON mem.id = tp.member_id
      WHERE tp.condition_id = $1
      ORDER BY tp.created_at DESC
      LIMIT 5
    `, [id]);

    // Enrolled members (most recently diagnosed first, up to 10)
    const membersResult = await pool.query(`
      SELECT mem.id, mem.first_name, mem.last_name, mem.member_number, mem.gender,
        mc.diagnosed_date, mc.notes AS condition_notes
      FROM member_conditions mc
      JOIN members mem ON mem.id = mc.member_id
      WHERE mc.condition_id = $1
      ORDER BY mc.diagnosed_date DESC NULLS LAST
      LIMIT 10
    `, [id]);

    return res.json({
      condition: condResult.rows[0],
      medications: medsResult.rows,
      treatment_plans: { by_status: tpStatus.rows, recent: tpRecent.rows },
      members: membersResult.rows,
    });
  } catch (err) {
    console.error('conditionDetail error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Admin: toggle active status
router.patch('/:id/toggle', authenticate, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE conditions SET is_active = NOT is_active WHERE id = $1 RETURNING *',
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Condition not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
