const pool = require('../config/db');
const path = require('path');
const fs = require('fs');

const uploadsDir = path.join(__dirname, '../../uploads/lab-results');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const getMyLabTests = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT * FROM lab_tests WHERE member_id = $1 ORDER BY due_date DESC`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getMyLabTests error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const scheduleLabTest = async (req, res) => {
  // Admin or system schedules a test for a member
  try {
    const { member_id, test_type, due_date, scheduled_date } = req.body;
    if (!member_id || !test_type || !due_date) {
      return res.status(400).json({ message: 'member_id, test_type, due_date are required' });
    }
    const result = await pool.query(
      `INSERT INTO lab_tests (member_id, test_type, due_date, scheduled_date)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [member_id, test_type, due_date, scheduled_date || null]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('scheduleLabTest error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const completeLabTest = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { id } = req.params;
    const { result_notes } = req.body;
    const existing = await pool.query(
      'SELECT * FROM lab_tests WHERE id = $1 AND member_id = $2',
      [id, memberId]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Lab test not found' });
    let result_file_url = null;
    if (req.file) {
      result_file_url = `/uploads/lab-results/${req.file.filename}`;
    }
    const result = await pool.query(
      `UPDATE lab_tests SET
         status = 'completed', completed_at = NOW(),
         result_file_url = COALESCE($1, result_file_url),
         result_notes = COALESCE($2, result_notes),
         updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [result_file_url, result_notes || null, id]
    );

    // Auto-schedule the next test 6 months from today
    const completed = existing.rows[0];
    const next = new Date();
    next.setMonth(next.getMonth() + 6);
    const nextDue = next.toISOString().split('T')[0];
    await pool.query(
      `INSERT INTO lab_tests (member_id, test_type, due_date)
       VALUES ($1, $2, $3)`,
      [memberId, completed.test_type, nextDue]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('completeLabTest error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMemberLabTests = async (req, res) => {
  try {
    const { memberId } = req.params;
    const result = await pool.query(
      `SELECT lt.*, m.first_name, m.last_name, m.member_number
       FROM lab_tests lt
       JOIN members m ON m.id = lt.member_id
       WHERE lt.member_id = $1
       ORDER BY lt.due_date DESC`,
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getMemberLabTests error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getAllLabTests = async (req, res) => {
  try {
    const { status, page = 1, limit = 20, search } = req.query;
    const offset = (page - 1) * limit;
    const params = [];
    const conditions = [];

    if (status) {
      params.push(status);
      conditions.push(`lt.status = $${params.length}`);
    } else {
      conditions.push(`lt.status IN ('pending', 'overdue')`);
    }
    if (search) {
      params.push(`%${search}%`);
      const idx = params.length;
      conditions.push(`(m.first_name ILIKE $${idx} OR m.last_name ILIKE $${idx} OR m.member_number ILIKE $${idx} OR lt.test_type ILIKE $${idx})`);
    }
    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    params.push(parseInt(limit), parseInt(offset));
    const result = await pool.query(
      `SELECT lt.*, m.first_name, m.last_name, m.member_number
       FROM lab_tests lt
       JOIN members m ON m.id = lt.member_id
       ${where}
       ORDER BY lt.due_date ASC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );
    const countParams = params.slice(0, params.length - 2);
    const countResult = await pool.query(
      `SELECT COUNT(*) FROM lab_tests lt JOIN members m ON m.id = lt.member_id ${where}`,
      countParams
    );
    return res.json({
      tests: result.rows,
      total: parseInt(countResult.rows[0].count),
      pages: Math.ceil(parseInt(countResult.rows[0].count) / parseInt(limit)),
    });
  } catch (err) {
    console.error('getAllLabTests error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getLabTestStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE status = 'pending')::int AS pending,
        COUNT(*) FILTER (WHERE status = 'completed')::int AS completed,
        COUNT(*) FILTER (WHERE status IN ('pending','overdue') AND due_date < CURRENT_DATE)::int AS overdue
      FROM lab_tests
    `);
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('getLabTestStats error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const adminCompleteLabTest = async (req, res) => {
  try {
    const { id } = req.params;
    const { result_notes } = req.body;
    const existing = await pool.query('SELECT * FROM lab_tests WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Lab test not found' });

    let result_file_url = null;
    if (req.file) {
      result_file_url = `/uploads/lab-results/${req.file.filename}`;
    }
    const result = await pool.query(
      `UPDATE lab_tests SET
         status = 'completed', completed_at = NOW(),
         result_file_url = COALESCE($1, result_file_url),
         result_notes = COALESCE($2, result_notes),
         updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [result_file_url, result_notes || null, id]
    );

    // Auto-schedule the next test 6 months from today
    const completed = existing.rows[0];
    const next = new Date();
    next.setMonth(next.getMonth() + 6);
    const nextDue = next.toISOString().split('T')[0];
    await pool.query(
      `INSERT INTO lab_tests (member_id, test_type, due_date) VALUES ($1, $2, $3)`,
      [completed.member_id, completed.test_type, nextDue]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('adminCompleteLabTest error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Auto-schedule LFT + KFT every 6 months for a member
const autoScheduleForMember = async (memberId) => {
  const in6Months = new Date();
  in6Months.setMonth(in6Months.getMonth() + 6);
  const dueStr = in6Months.toISOString().split('T')[0];
  for (const testType of ['liver_function', 'kidney_function']) {
    await pool.query(
      `INSERT INTO lab_tests (member_id, test_type, due_date)
       VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
      [memberId, testType, dueStr]
    );
  }
};

module.exports = {
  getMyLabTests,
  scheduleLabTest,
  completeLabTest,
  getMemberLabTests,
  getAllLabTests,
  getLabTestStats,
  adminCompleteLabTest,
  autoScheduleForMember,
};
