const pool = require('../config/db');

const listHospitals = async (req, res) => {
  try {
    const { city, province, condition_id, direct_booking_capable, name } = req.query;
    const params = [];
    const conditions = ['h.is_active = TRUE'];
    let idx = 1;

    if (name) {
      conditions.push(`(h.name ILIKE $${idx} OR h.city ILIKE $${idx} OR h.address ILIKE $${idx})`);
      params.push(`%${name}%`);
      idx++;
    }
    if (city) {
      conditions.push(`h.city ILIKE $${idx++}`);
      params.push(`%${city}%`);
    }
    if (province) {
      conditions.push(`h.province ILIKE $${idx++}`);
      params.push(`%${province}%`);
    }
    if (condition_id) {
      conditions.push(`hc.condition_id = $${idx++}`);
      params.push(condition_id);
    }
    if (direct_booking_capable !== undefined) {
      conditions.push(`h.direct_booking_capable = $${idx++}`);
      params.push(direct_booking_capable === 'true');
    }

    const joinClause = condition_id
      ? 'JOIN hospital_conditions hc ON hc.hospital_id = h.id'
      : 'LEFT JOIN hospital_conditions hc ON hc.hospital_id = h.id';

    const where = `WHERE ${conditions.join(' AND ')}`;

    const result = await pool.query(
      `SELECT h.id, h.name, h.type, h.address, h.city, h.province,
              h.latitude, h.longitude, h.phone, h.email, h.working_hours,
              h.direct_booking_capable, h.specialties,
              COALESCE(json_agg(jsonb_build_object('id', c.id, 'name', c.name))
                FILTER (WHERE c.id IS NOT NULL), '[]') AS conditions
       FROM hospitals h
       ${joinClause}
       LEFT JOIN conditions c ON c.id = hc.condition_id
       ${where}
       GROUP BY h.id
       ORDER BY h.name`,
      params
    );

    return res.json(result.rows);
  } catch (err) {
    console.error('listHospitals error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getHospital = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT h.*,
              COALESCE(json_agg(DISTINCT jsonb_build_object('id', c.id, 'name', c.name, 'code', c.code))
                FILTER (WHERE c.id IS NOT NULL), '[]') AS conditions
       FROM hospitals h
       LEFT JOIN hospital_conditions hc ON hc.hospital_id = h.id
       LEFT JOIN conditions c ON c.id = hc.condition_id
       WHERE h.id = $1
       GROUP BY h.id`,
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Hospital not found' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('getHospital error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createHospital = async (req, res) => {
  try {
    const {
      name, type, address, city, province, latitude, longitude,
      phone, email, contact_person, working_hours, specialties,
      direct_booking_capable, booking_api_url, condition_ids,
    } = req.body;

    if (!name || !address || !city) {
      return res.status(400).json({ message: 'name, address and city are required' });
    }

    const result = await pool.query(
      `INSERT INTO hospitals
         (name, type, address, city, province, latitude, longitude, phone, email,
          contact_person, working_hours, specialties, direct_booking_capable, booking_api_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       RETURNING *`,
      [
        name, type, address, city, province, latitude || null, longitude || null,
        phone, email, contact_person, working_hours, specialties || null,
        direct_booking_capable || false, booking_api_url || null,
      ]
    );
    const hospital = result.rows[0];

    if (Array.isArray(condition_ids) && condition_ids.length) {
      for (const cid of condition_ids) {
        await pool.query(
          'INSERT INTO hospital_conditions (hospital_id, condition_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [hospital.id, cid]
        );
      }
    }

    return res.status(201).json(hospital);
  } catch (err) {
    console.error('createHospital error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateHospital = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name, type, address, city, province, latitude, longitude,
      phone, email, contact_person, working_hours, specialties,
      direct_booking_capable, booking_api_url, condition_ids,
    } = req.body;

    const existing = await pool.query('SELECT id FROM hospitals WHERE id = $1', [id]);
    if (!existing.rows.length) return res.status(404).json({ message: 'Hospital not found' });

    const result = await pool.query(
      `UPDATE hospitals SET
         name = COALESCE($1, name),
         type = COALESCE($2, type),
         address = COALESCE($3, address),
         city = COALESCE($4, city),
         province = COALESCE($5, province),
         latitude = COALESCE($6, latitude),
         longitude = COALESCE($7, longitude),
         phone = COALESCE($8, phone),
         email = COALESCE($9, email),
         contact_person = COALESCE($10, contact_person),
         working_hours = COALESCE($11, working_hours),
         specialties = COALESCE($12, specialties),
         direct_booking_capable = COALESCE($13, direct_booking_capable),
         booking_api_url = COALESCE($14, booking_api_url),
         updated_at = NOW()
       WHERE id = $15 RETURNING *`,
      [
        name, type, address, city, province, latitude, longitude,
        phone, email, contact_person, working_hours, specialties,
        direct_booking_capable, booking_api_url, id,
      ]
    );

    if (Array.isArray(condition_ids)) {
      await pool.query('DELETE FROM hospital_conditions WHERE hospital_id = $1', [id]);
      for (const cid of condition_ids) {
        await pool.query(
          'INSERT INTO hospital_conditions (hospital_id, condition_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [id, cid]
        );
      }
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateHospital error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deleteHospital = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE hospitals SET is_active = FALSE, updated_at = NOW() WHERE id = $1 RETURNING id',
      [id]
    );
    if (!result.rows.length) return res.status(404).json({ message: 'Hospital not found' });
    return res.json({ message: 'Hospital deactivated' });
  } catch (err) {
    console.error('deleteHospital error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listHospitals, getHospital, createHospital, updateHospital, deleteHospital };
