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

// ─── Water ────────────────────────────────────────────────────────────────────

const logWater = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { cups } = req.body;
    const cupCount = Math.max(0, Math.min(20, parseInt(cups, 10) || 0));

    const result = await pool.query(
      `INSERT INTO water_logs (member_id, log_date, cups)
       VALUES ($1, CURRENT_DATE, $2)
       ON CONFLICT (member_id, log_date)
       DO UPDATE SET cups = $2, updated_at = NOW()
       RETURNING *`,
      [memberId, cupCount]
    );
    return res.status(200).json(result.rows[0]);
  } catch (err) {
    console.error('logWater error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getWater = async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      `SELECT * FROM water_logs WHERE member_id = $1 AND log_date = CURRENT_DATE`,
      [memberId]
    );
    const row = result.rows[0];
    return res.json({ cups: row ? row.cups : 0 });
  } catch (err) {
    console.error('getWater error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// ─── Leaderboard ──────────────────────────────────────────────────────────────
// Holistic wellness score across fitness, meals, and hydration:
//   Steps: 1 pt per 100 steps  |  Active minutes: 2 pts/min
//   Calories burned: 1 pt per 50 cal  |  Each fitness activity: 10 pts
//   Each meal logged: 5 pts  |  Water cups: 3 pts/cup

const getLeaderboard = async (req, res) => {
  try {
    const memberId = req.user.id;
    const period = req.query.period || 'week'; // week | month

    const interval = period === 'month' ? '30 days' : '7 days';

    const result = await pool.query(
      `SELECT
         m.id AS member_id,
         COALESCE(m.first_name, 'Member') AS first_name,
         COALESCE(LEFT(m.last_name, 1), '') AS last_initial,
         COALESCE(fit.total_steps, 0)::int        AS total_steps,
         COALESCE(fit.total_minutes, 0)::int      AS total_minutes,
         COALESCE(fit.total_calories, 0)::int     AS total_calories,
         COALESCE(fit.activity_count, 0)::int     AS activity_count,
         COALESCE(ml.meal_count, 0)::int          AS meal_count,
         COALESCE(wl.water_cups, 0)::int          AS water_cups,
         COALESCE(fit.workout_count, 0)::int      AS workout_count,
         (
           FLOOR(COALESCE(fit.total_steps, 0)    / 100.0) +
           COALESCE(fit.total_minutes, 0)   * 2           +
           FLOOR(COALESCE(fit.total_calories, 0) / 50.0)  +
           COALESCE(fit.activity_count, 0)  * 10          +
           COALESCE(ml.meal_count, 0)       * 5           +
           COALESCE(wl.water_cups, 0)       * 3
         )::int AS total_points
       FROM members m
       LEFT JOIN (
         SELECT member_id,
                COALESCE(SUM(steps), 0)            AS total_steps,
                COALESCE(SUM(duration_minutes), 0) AS total_minutes,
                COALESCE(SUM(calories_burned), 0)  AS total_calories,
                COUNT(id)                          AS activity_count,
                COUNT(CASE WHEN steps IS NULL OR steps = 0 THEN id END) AS workout_count
         FROM fitness_logs
         WHERE log_date >= CURRENT_DATE - INTERVAL '${interval}'
         GROUP BY member_id
       ) fit ON fit.member_id = m.id
       LEFT JOIN (
         SELECT member_id, COUNT(id) AS meal_count
         FROM meal_logs
         WHERE log_date >= CURRENT_DATE - INTERVAL '${interval}'
         GROUP BY member_id
       ) ml ON ml.member_id = m.id
       LEFT JOIN (
         SELECT member_id, COALESCE(SUM(cups), 0) AS water_cups
         FROM water_logs
         WHERE log_date >= CURRENT_DATE - INTERVAL '${interval}'
         GROUP BY member_id
       ) wl ON wl.member_id = m.id
       WHERE (
         COALESCE(fit.activity_count, 0) > 0 OR
         COALESCE(ml.meal_count, 0) > 0 OR
         COALESCE(wl.water_cups, 0) > 0
       )
       ORDER BY total_points DESC, total_minutes DESC
       LIMIT 50`
    );

    const entries = result.rows.map((row, idx) => ({
      rank: idx + 1,
      member_id: row.member_id,
      name: `${row.first_name} ${row.last_initial}.`,
      total_steps: row.total_steps,
      total_minutes: row.total_minutes,
      total_calories: row.total_calories,
      activity_count: row.activity_count,
      meal_count: row.meal_count,
      water_cups: row.water_cups,
      workout_count: row.workout_count,
      total_points: row.total_points,
      is_current_user: row.member_id === memberId,
    }));

    // Find current user's rank (even if not in top 50)
    const currentUser = entries.find(e => e.is_current_user);
    let myRank = null;
    if (!currentUser) {
      const myResult = await pool.query(
        `SELECT COUNT(*) + 1 AS rank FROM (
           SELECT m.id,
             (
               FLOOR(COALESCE(SUM(f.steps), 0) / 100.0) +
               COALESCE(SUM(f.duration_minutes), 0) * 2 +
               FLOOR(COALESCE(SUM(f.calories_burned), 0) / 50.0) +
               COUNT(f.id) * 10 +
               COALESCE(ml.meal_count, 0) * 5 +
               COALESCE(wl.water_cups, 0) * 3
             ) AS total_points
           FROM members m
           LEFT JOIN fitness_logs f ON f.member_id = m.id AND f.log_date >= CURRENT_DATE - INTERVAL '${interval}'
           LEFT JOIN (SELECT member_id, COUNT(id) AS meal_count FROM meal_logs WHERE log_date >= CURRENT_DATE - INTERVAL '${interval}' GROUP BY member_id) ml ON ml.member_id = m.id
           LEFT JOIN (SELECT member_id, COALESCE(SUM(cups),0) AS water_cups FROM water_logs WHERE log_date >= CURRENT_DATE - INTERVAL '${interval}' GROUP BY member_id) wl ON wl.member_id = m.id
           GROUP BY m.id, ml.meal_count, wl.water_cups
           HAVING COUNT(f.id) > 0 OR COALESCE(ml.meal_count, 0) > 0 OR COALESCE(wl.water_cups, 0) > 0
         ) sub
         WHERE sub.total_points > (
           SELECT
             FLOOR(COALESCE(SUM(f.steps), 0) / 100.0) +
             COALESCE(SUM(f.duration_minutes), 0) * 2 +
             FLOOR(COALESCE(SUM(f.calories_burned), 0) / 50.0) +
             COUNT(f.id) * 10 +
             COALESCE((SELECT COUNT(id) FROM meal_logs WHERE member_id = $1 AND log_date >= CURRENT_DATE - INTERVAL '${interval}'), 0) * 5 +
             COALESCE((SELECT SUM(cups) FROM water_logs WHERE member_id = $1 AND log_date >= CURRENT_DATE - INTERVAL '${interval}'), 0) * 3
           FROM fitness_logs f
           WHERE f.member_id = $1 AND f.log_date >= CURRENT_DATE - INTERVAL '${interval}'
         )`,
        [memberId]
      );
      myRank = parseInt(myResult.rows[0]?.rank, 10) || null;
    }

    return res.json({
      period,
      leaderboard: entries,
      my_rank: currentUser?.rank || myRank,
      total_participants: entries.length,
    });
  } catch (err) {
    console.error('getLeaderboard error:', err);
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

const createPartnerVideo = async (req, res) => {
  try {
    const { id } = req.params;
    const fullBody = req.body;
    const { title, youtube_video_id, duration_label, difficulty, category, sort_order } = req.body;

    console.log('\n╔════════════════════════════════════════════════════╗');
    console.log('║        createPartnerVideo - Request Received       ║');
    console.log('╚════════════════════════════════════════════════════╝');
    console.log('Partner ID:', id);
    console.log('Full request body:', JSON.stringify(fullBody, null, 2));
    console.log('Extracted fields:', { title, youtube_video_id, duration_label, difficulty, category, sort_order });

    // Validate required fields
    if (!title || title.trim() === '') {
      return res.status(400).json({ 
        success: false,
        message: 'Title is required and cannot be empty',
        received: { title }
      });
    }

    if (!youtube_video_id || youtube_video_id.trim() === '') {
      return res.status(400).json({ 
        success: false,
        message: 'YouTube Video ID is required and cannot be empty',
        received: { youtube_video_id }
      });
    }

    // Check if partner exists
    const partnerCheck = await pool.query('SELECT id, name FROM lifestyle_partners WHERE id = $1', [id]);
    if (!partnerCheck.rows.length) {
      console.error('❌ Partner not found with ID:', id);
      return res.status(404).json({ 
        success: false,
        message: 'Partner not found',
        received: { partner_id: id }
      });
    }
    console.log('✅ Partner found:', partnerCheck.rows[0].name);

    const parsedSortOrder = sort_order !== null && sort_order !== undefined && sort_order !== '' ? parseInt(sort_order, 10) : 0;
    if (Number.isNaN(parsedSortOrder)) {
      return res.status(400).json({ 
        success: false,
        message: 'Sort order must be a valid integer',
        received: { sort_order }
      });
    }

    const insertData = {
      partner_id: id,
      title: title.trim(),
      youtube_video_id: youtube_video_id.trim(),
      duration_label: (duration_label || '30 min').trim(),
      difficulty: (difficulty || 'Beginner').trim(),
      category: (category || 'Strength').trim(),
      sort_order: parsedSortOrder,
    };

    console.log('Attempting INSERT with:', JSON.stringify(insertData, null, 2));

    const result = await pool.query(
      `INSERT INTO partner_videos
         (partner_id, title, youtube_video_id, duration_label, difficulty, category, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [
        insertData.partner_id,
        insertData.title,
        insertData.youtube_video_id,
        insertData.duration_label,
        insertData.difficulty,
        insertData.category,
        insertData.sort_order,
      ]
    );
    
    console.log('✅ Video created successfully:', result.rows[0].id);
    console.log('Full created video:', JSON.stringify(result.rows[0], null, 2));
    return res.status(201).json({ 
      success: true,
      message: 'Video created successfully',
      data: result.rows[0]
    });
  } catch (err) {
    console.error('\n╔════════════════════════════════════════════════════╗');
    console.error('║        ❌ ERROR IN createPartnerVideo              ║');
    console.error('╚════════════════════════════════════════════════════╝');
    console.error('Error Type:', err.constructor.name);
    console.error('Message:', err.message);
    console.error('Code:', err.code);
    console.error('Detail:', err.detail);
    console.error('Constraint:', err.constraint);
    console.error('Position:', err.position);
    console.error('Hint:', err.hint);
    console.error('Where:', err.where);
    console.error('Stack:', err.stack);
    
    // Provide detailed error response
    const errorResponse = {
      success: false,
      message: err.message || 'Failed to create video',
      error: {
        type: err.constructor.name,
        code: err.code,
        detail: err.detail,
        constraint: err.constraint,
        hint: err.hint,
      }
    };
    
    return res.status(500).json(errorResponse);
  }
};

const updatePartnerVideo = async (req, res) => {
  try {
    const { videoId } = req.params;
    const { title, youtube_video_id, duration_label, difficulty, category, sort_order } = req.body;

    console.log('\n╔════════════════════════════════════════════════════╗');
    console.log('║        updatePartnerVideo - Request Received       ║');
    console.log('╚════════════════════════════════════════════════════╝');
    console.log('Video ID:', videoId);
    console.log('Fields to update:', { title, youtube_video_id, duration_label, difficulty, category, sort_order });

    const existing = await pool.query('SELECT id, title FROM partner_videos WHERE id = $1', [videoId]);
    if (!existing.rows.length) {
      return res.status(404).json({ 
        success: false,
        message: 'Video not found',
        received: { video_id: videoId }
      });
    }
    console.log('✅ Video found:', existing.rows[0].title);

    const result = await pool.query(
      `UPDATE partner_videos SET
         title = COALESCE($1, title),
         youtube_video_id = COALESCE($2, youtube_video_id),
         duration_label = COALESCE($3, duration_label),
         difficulty = COALESCE($4, difficulty),
         category = COALESCE($5, category)
       WHERE id = $6 RETURNING *`,
      [title || null, youtube_video_id || null, duration_label || null, difficulty || null, category || null, videoId]
    );
    
    console.log('✅ Video updated successfully');
    return res.json({ 
      success: true,
      message: 'Video updated successfully',
      data: result.rows[0]
    });
  } catch (err) {
    console.error('\n╔════════════════════════════════════════════════════╗');
    console.error('║        ❌ ERROR IN updatePartnerVideo              ║');
    console.error('╚════════════════════════════════════════════════════╝');
    console.error('Error Type:', err.constructor.name);
    console.error('Message:', err.message);
    console.error('Code:', err.code);
    console.error('Detail:', err.detail);
    
    return res.status(500).json({ 
      success: false,
      message: err.message || 'Failed to update video',
      error: {
        type: err.constructor.name,
        code: err.code,
        detail: err.detail,
      }
    });
  }
};

const deletePartnerVideo = async (req, res) => {
  try {
    const { videoId } = req.params;
    
    console.log('deletePartnerVideo called for:', videoId);
    
    const result = await pool.query(
      'UPDATE partner_videos SET is_active = FALSE WHERE id = $1 RETURNING id, title',
      [videoId]
    );
    
    if (!result.rows.length) {
      return res.status(404).json({ 
        success: false,
        message: 'Video not found',
        received: { video_id: videoId }
      });
    }
    
    console.log('✅ Video deleted successfully:', result.rows[0].title);
    return res.json({ 
      success: true,
      message: 'Video removed successfully'
    });
  } catch (err) {
    console.error('❌ deletePartnerVideo error:', err.message);
    return res.status(500).json({ 
      success: false,
      message: err.message || 'Failed to delete video',
      error: {
        type: err.constructor.name,
        code: err.code,
        detail: err.detail,
      }
    });
  }
};

module.exports = {
  logMeal, getMeals,
  logWater, getWater,
  logFitness, getFitness,
  getLeaderboard,
  logPsychosocial, getPsychosocial,
  listPartners, createPartner, updatePartner, deletePartner,
  listPartnerVideos, createPartnerVideo, updatePartnerVideo, deletePartnerVideo,
};
