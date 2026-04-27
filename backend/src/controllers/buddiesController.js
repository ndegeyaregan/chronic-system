const pool = require('../config/db');

// GET /api/buddies — list buddies for the authenticated member
async function listBuddies(req, res) {
  try {
    const memberId = req.user.id;
    const { rows } = await pool.query(
      `SELECT id, name, phone, relationship, created_at, updated_at
         FROM care_buddies
        WHERE member_id = $1
        ORDER BY created_at`,
      [memberId]
    );
    res.json(rows);
  } catch (err) {
    console.error('listBuddies error:', err);
    res.status(500).json({ message: 'Failed to fetch care buddies.' });
  }
}

// POST /api/buddies — add a care buddy
async function addBuddy(req, res) {
  try {
    const memberId = req.user.id;
    const { name, phone, relationship } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ message: 'Name and phone are required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO care_buddies (member_id, name, phone, relationship)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, phone, relationship, created_at, updated_at`,
      [memberId, name.trim(), phone.trim(), (relationship || '').trim() || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('addBuddy error:', err);
    res.status(500).json({ message: 'Failed to add care buddy.' });
  }
}

// PUT /api/buddies/:id — update a care buddy
async function updateBuddy(req, res) {
  try {
    const memberId = req.user.id;
    const buddyId = req.params.id;
    const { name, phone, relationship } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ message: 'Name and phone are required.' });
    }

    const { rows, rowCount } = await pool.query(
      `UPDATE care_buddies
          SET name = $1, phone = $2, relationship = $3, updated_at = NOW()
        WHERE id = $4 AND member_id = $5
        RETURNING id, name, phone, relationship, created_at, updated_at`,
      [name.trim(), phone.trim(), (relationship || '').trim() || null, buddyId, memberId]
    );

    if (rowCount === 0) {
      return res.status(404).json({ message: 'Buddy not found.' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('updateBuddy error:', err);
    res.status(500).json({ message: 'Failed to update care buddy.' });
  }
}

// DELETE /api/buddies/:id — remove a care buddy
async function deleteBuddy(req, res) {
  try {
    const memberId = req.user.id;
    const buddyId = req.params.id;

    const { rowCount } = await pool.query(
      `DELETE FROM care_buddies WHERE id = $1 AND member_id = $2`,
      [buddyId, memberId]
    );

    if (rowCount === 0) {
      return res.status(404).json({ message: 'Buddy not found.' });
    }
    res.json({ message: 'Buddy removed.' });
  } catch (err) {
    console.error('deleteBuddy error:', err);
    res.status(500).json({ message: 'Failed to remove care buddy.' });
  }
}

module.exports = { listBuddies, addBuddy, updateBuddy, deleteBuddy };

// ── Admin endpoints (operate on any member) ────────────────────────────────

async function adminListBuddies(req, res) {
  try {
    const memberId = req.params.memberId;
    const { rows } = await pool.query(
      `SELECT id, name, phone, relationship, created_at, updated_at
         FROM care_buddies WHERE member_id = $1 ORDER BY created_at`,
      [memberId]
    );
    res.json(rows);
  } catch (err) {
    console.error('adminListBuddies error:', err);
    res.status(500).json({ message: 'Failed to fetch care buddies.' });
  }
}

async function adminAddBuddy(req, res) {
  try {
    const memberId = req.params.memberId;
    const { name, phone, relationship } = req.body;
    if (!name || !phone) return res.status(400).json({ message: 'Name and phone are required.' });

    const { rows } = await pool.query(
      `INSERT INTO care_buddies (member_id, name, phone, relationship)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, phone, relationship, created_at, updated_at`,
      [memberId, name.trim(), phone.trim(), (relationship || '').trim() || null]
    );

    // Audit log
    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'add_care_buddy', 'member', $2, $3, $4)`,
      [req.user.id, memberId, JSON.stringify({ buddy_name: name, admin_name: req.user.name || req.user.email }), req.ip]
    );

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('adminAddBuddy error:', err);
    res.status(500).json({ message: 'Failed to add care buddy.' });
  }
}

async function adminUpdateBuddy(req, res) {
  try {
    const { buddyId } = req.params;
    const { name, phone, relationship } = req.body;
    if (!name || !phone) return res.status(400).json({ message: 'Name and phone are required.' });

    const { rows, rowCount } = await pool.query(
      `UPDATE care_buddies SET name=$1, phone=$2, relationship=$3, updated_at=NOW()
       WHERE id=$4 RETURNING id, member_id, name, phone, relationship, created_at, updated_at`,
      [name.trim(), phone.trim(), (relationship || '').trim() || null, buddyId]
    );
    if (!rowCount) return res.status(404).json({ message: 'Buddy not found.' });

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'update_care_buddy', 'member', $2, $3, $4)`,
      [req.user.id, rows[0].member_id, JSON.stringify({ buddy_name: name, admin_name: req.user.name || req.user.email }), req.ip]
    );

    res.json(rows[0]);
  } catch (err) {
    console.error('adminUpdateBuddy error:', err);
    res.status(500).json({ message: 'Failed to update care buddy.' });
  }
}

async function adminDeleteBuddy(req, res) {
  try {
    const { buddyId } = req.params;
    const buddy = await pool.query('SELECT member_id, name FROM care_buddies WHERE id=$1', [buddyId]);
    if (!buddy.rows.length) return res.status(404).json({ message: 'Buddy not found.' });

    await pool.query('DELETE FROM care_buddies WHERE id=$1', [buddyId]);

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'delete_care_buddy', 'member', $2, $3, $4)`,
      [req.user.id, buddy.rows[0].member_id, JSON.stringify({ buddy_name: buddy.rows[0].name, admin_name: req.user.name || req.user.email }), req.ip]
    );

    res.json({ message: 'Buddy removed.' });
  } catch (err) {
    console.error('adminDeleteBuddy error:', err);
    res.status(500).json({ message: 'Failed to remove care buddy.' });
  }
}

module.exports.adminListBuddies = adminListBuddies;
module.exports.adminAddBuddy = adminAddBuddy;
module.exports.adminUpdateBuddy = adminUpdateBuddy;
module.exports.adminDeleteBuddy = adminDeleteBuddy;
