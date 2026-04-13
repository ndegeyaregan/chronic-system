const pool = require('../config/db');

// ─── Meals ────────────────────────────────────────────────────────────────────

const logMeal = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { meal_type, description, calories, carbs_g, protein_g, fat_g, foods } = req.body;

    // Combine description and foods list into a single description field
    let fullDescription = description || null;
    if (Array.isArray(foods) && foods.length > 0) {
      const foodList = foods.join(', ');
      fullDescription = fullDescription ? `${fullDescription} [${foodList}]` : foodList;
    }

    let photo_url = null;
    if (req.file) {
      photo_url = `/uploads/meals/${req.file.filename}`;
    }

    const result = await pool.query(
      `INSERT INTO meal_logs
         (member_id, meal_type, description, calories, carbs_g, protein_g, fat_g, log_date, photo_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7, CURRENT_DATE, $8) RETURNING *`,
      [memberId, meal_type || null, fullDescription, calories || null,
       carbs_g || null, protein_g || null, fat_g || null, photo_url]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('logMeal error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getMeals = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { from_date, to_date } = req.query;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const offset = (page - 1) * limit;

    const params = [memberId];
    const filters = ['member_id = $1'];
    let idx = 2;

    if (from_date) { filters.push(`log_date >= $${idx++}`); params.push(from_date); }
    if (to_date) { filters.push(`log_date <= $${idx++}`); params.push(to_date); }

    const whereClause = filters.join(' AND ');
    const [dataResult, countResult] = await Promise.all([
      pool.query(
        `SELECT * FROM meal_logs WHERE ${whereClause} ORDER BY log_date DESC, created_at DESC LIMIT $${idx++} OFFSET $${idx++}`,
        [...params, limit, offset]
      ),
      pool.query(`SELECT COUNT(*) FROM meal_logs WHERE ${whereClause}`, params),
    ]);

    const total = parseInt(countResult.rows[0].count, 10);
    return res.json({
      data: dataResult.rows,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error('getMeals error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// ─── Fitness ──────────────────────────────────────────────────────────────────

const logFitness = async (req, res) => {
  try {
    const memberId = req.user.id;
    const {
      activity_type, duration_minutes, calories_burned,
      intensity, steps, notes,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO fitness_logs
         (member_id, activity_type, duration_minutes, calories_burned,
          intensity, steps, notes, log_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7, CURRENT_DATE) RETURNING *`,
      [
        memberId,
        activity_type || null, duration_minutes || null,
        calories_burned || null, intensity || null, steps || null, notes || null,
      ]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('logFitness error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getFitness = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { from_date, to_date } = req.query;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const offset = (page - 1) * limit;

    const params = [memberId];
    const filters = ['member_id = $1'];
    let idx = 2;

    if (from_date) { filters.push(`log_date >= $${idx++}`); params.push(from_date); }
    if (to_date) { filters.push(`log_date <= $${idx++}`); params.push(to_date); }

    const whereClause = filters.join(' AND ');
    const [dataResult, countResult] = await Promise.all([
      pool.query(
        `SELECT * FROM fitness_logs WHERE ${whereClause} ORDER BY log_date DESC, created_at DESC LIMIT $${idx++} OFFSET $${idx++}`,
        [...params, limit, offset]
      ),
      pool.query(`SELECT COUNT(*) FROM fitness_logs WHERE ${whereClause}`, params),
    ]);

    const total = parseInt(countResult.rows[0].count, 10);
    return res.json({
      data: dataResult.rows,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error('getFitness error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// ─── Psychosocial ─────────────────────────────────────────────────────────────

const logPsychosocial = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { stress_level, anxiety_level, notes, mood } = req.body;

    const result = await pool.query(
      `INSERT INTO psychosocial_checkins
         (member_id, stress_level, anxiety_level, notes, mood, checkin_date)
       VALUES ($1,$2,$3,$4,$5, CURRENT_DATE) RETURNING *`,
      [
        memberId,
        stress_level || null, anxiety_level || null, notes || null, mood || null,
      ]
    );

    // Auto-create admin alert for high stress or anxiety
    const sl = parseInt(stress_level, 10) || 0;
    const al = parseInt(anxiety_level, 10) || 0;
    if (sl > 6 || al > 6) {
      const maxLevel = Math.max(sl, al);
      const severity = maxLevel >= 9 ? 'high' : 'medium';
      pool.query(
        `INSERT INTO admin_alerts (member_id, alert_type, severity, value_reported, notes)
         VALUES ($1, 'psychosocial', $2, $3, $4)`,
        [memberId, severity, maxLevel,
         `High stress/anxiety: stress=${stress_level}, anxiety=${anxiety_level}`]
      ).catch((err) => console.error('Psychosocial alert insert error:', err.message));
    }

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('logPsychosocial error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getPsychosocial = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      'SELECT * FROM psychosocial_checkins WHERE member_id = $1 ORDER BY checkin_date DESC, created_at DESC LIMIT 30',
      [memberId]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('getPsychosocial error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// ─── Partners ─────────────────────────────────────────────────────────────────

const listPartners = async (req, res) => {
  try {
    const { type, city, province } = req.query;
    const params = ['TRUE'];
    const filters = ['p.is_active = TRUE'];
    let idx = 1;

    if (type) { filters.push(`p.type = $${idx++}`); params.push(type); }
    if (city) { filters.push(`p.city ILIKE $${idx++}`); params.push(`%${city}%`); }
    if (province) { filters.push(`p.province ILIKE $${idx++}`); params.push(`%${province}%`); }

    // Rebuild without placeholder for TRUE
    const realParams = [];
    const realFilters = ['p.is_active = TRUE'];
    let realIdx = 1;
    if (type) { realFilters.push(`p.type = $${realIdx++}`); realParams.push(type); }
    if (city) { realFilters.push(`p.city ILIKE $${realIdx++}`); realParams.push(`%${city}%`); }
    if (province) { realFilters.push(`p.province ILIKE $${realIdx++}`); realParams.push(`%${province}%`); }

    const result = await pool.query(
      `SELECT * FROM lifestyle_partners p WHERE ${realFilters.join(' AND ')} ORDER BY p.name`,
      realParams
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listPartners error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createPartner = async (req, res) => {
  try {
    const {
      name, type, address, city, province, latitude, longitude,
      phone, email, website, conditions,
    } = req.body;

    if (!name || !type) return res.status(400).json({ message: 'name and type are required' });

    const result = await pool.query(
      `INSERT INTO lifestyle_partners
         (name, type, address, city, province, latitude, longitude, phone, email, website)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [
        name, type, address || null, city || null, province || null,
        latitude || null, longitude || null, phone || null, email || null, website || null,
      ]
    );
    const partner = result.rows[0];

    if (Array.isArray(conditions) && conditions.length) {
      for (const cid of conditions) {
        await pool.query(
          'INSERT INTO partner_conditions (partner_id, condition_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
          [partner.id, cid]
        );
      }
    }

    return res.status(201).json(partner);
  } catch (err) {
    console.error('createPartner error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updatePartner = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name, type, address, city, province, latitude, longitude,
      phone, email, website, conditions,
    } = req.body;

    const existing = await pool.query('SELECT id FROM lifestyle_partners WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Partner not found' });

    const result = await pool.query(
      `UPDATE lifestyle_partners SET
         name = COALESCE($1, name),
         type = COALESCE($2, type),
         address = COALESCE($3, address),
         city = COALESCE($4, city),
         province = COALESCE($5, province),
         latitude = COALESCE($6, latitude),
         longitude = COALESCE($7, longitude),
         phone = COALESCE($8, phone),
         email = COALESCE($9, email),
         website = COALESCE($10, website),
         updated_at = NOW()
       WHERE id = $11 RETURNING *`,
      [name, type, address, city, province, latitude, longitude, phone, email, website, id]
    );

    if (Array.isArray(conditions)) {
      await pool.query('DELETE FROM partner_conditions WHERE partner_id = $1', [id]);
      for (const cid of conditions) {
        await pool.query(
          'INSERT INTO partner_conditions (partner_id, condition_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
          [id, cid]
        );
      }
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updatePartner error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deletePartner = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE lifestyle_partners SET is_active = FALSE, updated_at = NOW() WHERE id = $1 RETURNING id',
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Partner not found' });
    return res.json({ message: 'Partner deactivated' });
  } catch (err) {
    console.error('deletePartner error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listPartnerVideos = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT id, partner_id, title, youtube_video_id, duration_label, difficulty, category, sort_order
       FROM partner_videos
       WHERE partner_id = $1 AND is_active = TRUE
       ORDER BY sort_order ASC, created_at ASC`,
      [id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listPartnerVideos error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  logMeal, getMeals,
  logFitness, getFitness,
  logPsychosocial, getPsychosocial,
  listPartners, createPartner, updatePartner, deletePartner,
  listPartnerVideos,
};
