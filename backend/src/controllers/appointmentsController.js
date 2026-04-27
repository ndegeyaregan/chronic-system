const pool = require('../config/db');
const notificationService = require('../services/notificationService');

const logAppointmentNotification = async ({
  memberId,
  type,
  channel,
  title,
  message,
  status = 'sent',
  appointmentId,
}) => pool.query(
  `INSERT INTO notifications
     (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
   VALUES ($1, $2, $3, $4, $5, $6, $7, 'appointment', NOW())`,
  [memberId || null, type, channel, title, message, status, appointmentId]
);

const createAppointment = async (req, res) => {
  try {
    const memberId = req.user.id;
    const { hospital_id, condition_id, condition, appointment_date, preferred_time, reason } = req.body;

    if (!hospital_id || !appointment_date) {
      return res.status(400).json({ message: 'hospital_id and appointment_date are required' });
    }

    const hospitalResult = await pool.query(
      'SELECT * FROM hospitals WHERE id = $1 AND is_active = TRUE',
      [hospital_id]
    );
    if (!hospitalResult.rows.length) {
      return res.status(404).json({ message: 'Hospital not found' });
    }
    const hospital = hospitalResult.rows[0];

    // Resolve condition_id — accept either a UUID or a condition name
    let resolvedConditionId = condition_id || null;
    if (!resolvedConditionId && condition) {
      const condResult = await pool.query(
        'SELECT id FROM conditions WHERE LOWER(name) = LOWER($1)',
        [condition]
      );
      if (condResult.rows.length) resolvedConditionId = condResult.rows[0].id;
    }

    const result = await pool.query(
      `INSERT INTO appointments
         (member_id, hospital_id, condition_id, appointment_date, preferred_time, reason, status, created_by_admin)
       VALUES ($1,$2,$3,$4,$5,$6,'pending', FALSE)
       RETURNING *`,
      [memberId, hospital_id, resolvedConditionId, appointment_date, preferred_time || null, reason || null]
    );
    const appointment = result.rows[0];

    // Notify member
    notificationService.sendToMember(memberId, {
      type: 'appointment_created',
      title: '📅 Appointment Request Received',
      message: `Your appointment request at ${hospital.name} on ${appointment_date} is pending confirmation.`,
      channel: ['push', 'sms', 'email'],
    }).catch((err) => console.error('Appointment member notification error:', err.message));
    logAppointmentNotification({
      memberId,
      type: 'appointment_request_member',
      channel: 'system',
      title: 'Appointment Request Received',
      message: `Member notified about appointment request at ${hospital.name}.`,
      appointmentId: appointment.id,
    }).catch((err) => console.error('Appointment member tracking log error:', err.message));

    // Notify hospital contact
    if (hospital.contact_person && hospital.email) {
      const memberResult = await pool.query(
        'SELECT first_name, last_name, member_number FROM members WHERE id = $1',
        [memberId]
      );
      const member = memberResult.rows[0];
      notificationService.sendEmail(
        hospital.email,
        'New Appointment Request — Sanlam Chronic Care',
        `<p>Dear ${hospital.contact_person},</p>
         <p>A new appointment has been requested:</p>
         <ul>
           <li><strong>Member:</strong> ${member ? `${member.first_name} ${member.last_name} (${member.member_number})` : memberId}</li>
           <li><strong>Date:</strong> ${appointment_date}</li>
           <li><strong>Preferred Time:</strong> ${preferred_time || 'Not specified'}</li>
           <li><strong>Reason:</strong> ${reason || 'Not provided'}</li>
         </ul>
         <p>Please confirm or update the appointment in the portal.</p>`
      ).catch((err) => console.error('Appointment hospital email error:', err.message));
      logAppointmentNotification({
        memberId,
        type: 'appointment_request_provider',
        channel: 'email',
        title: 'Appointment Request Sent to Provider',
        message: `Provider email sent to ${hospital.email}.`,
        appointmentId: appointment.id,
      }).catch((err) => console.error('Appointment provider tracking log error:', err.message));
    }

    // Create admin notification record for the portal
    pool.query(
      `INSERT INTO notifications (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
       VALUES ($1, 'admin_appointment_request', 'portal', $2, $3, 'sent', $4, 'appointment', NOW())`,
      [
        memberId,
        '📅 New Appointment Request',
        `A member has requested an appointment at ${hospital.name} on ${appointment_date}${condition ? ' for ' + condition : ''}.`,
        appointment.id,
      ]
    ).catch((err) => console.error('Admin notification insert error:', err.message));

    return res.status(201).json(appointment);
  } catch (err) {
    console.error('createAppointment error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listMyAppointments = async (req, res) => {
  try {
    const memberId = req.user.id;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const offset = (page - 1) * limit;

    const [dataResult, countResult] = await Promise.all([
      pool.query(
        `SELECT a.*, h.name AS hospital_name, h.address AS hospital_address,
                c.name AS condition_name
         FROM appointments a
         JOIN hospitals h ON h.id = a.hospital_id
         LEFT JOIN conditions c ON c.id = a.condition_id
         WHERE a.member_id = $1
         ORDER BY a.appointment_date DESC, a.created_at DESC
         LIMIT $2 OFFSET $3`,
        [memberId, limit, offset]
      ),
      pool.query('SELECT COUNT(*) FROM appointments WHERE member_id = $1', [memberId]),
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
    console.error('listMyAppointments error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const updateAppointmentStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      status,
      confirmed_date,
      confirmed_time,
      cancellation_reason,
      appointment_date,
      preferred_time,
      notes,
      no_show_reason,
    } = req.body;

    const validStatuses = ['pending', 'confirmed', 'cancelled', 'completed', 'no_show', 'rescheduled'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({ message: `status must be one of: ${validStatuses.join(', ')}` });
    }

    const existing = await pool.query(
      `SELECT a.*, h.name AS hospital_name, h.email AS hospital_email, h.contact_person,
              m.first_name, m.last_name, m.member_number
       FROM appointments a
       JOIN hospitals h ON h.id = a.hospital_id
       JOIN members m ON m.id = a.member_id
       WHERE a.id = $1`,
      [id]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Appointment not found' });
    const appointment = existing.rows[0];

    const result = await pool.query(
      `UPDATE appointments SET
         status = $1,
         confirmed_date = COALESCE($2, confirmed_date),
         confirmed_time = COALESCE($3, confirmed_time),
         cancellation_reason = COALESCE($4, cancellation_reason),
         appointment_date = COALESCE($5, appointment_date),
         preferred_time = COALESCE($6, preferred_time),
         notes = COALESCE($7, notes),
         no_show_reason = COALESCE($8, no_show_reason),
         updated_at = NOW()
       WHERE id = $9 RETURNING *`,
      [
        status,
        confirmed_date || null,
        confirmed_time || null,
        cancellation_reason || null,
        appointment_date || null,
        preferred_time || null,
        notes || null,
        no_show_reason || null,
        id,
      ]
    );
    const updatedAppointment = result.rows[0];

    // Notify member based on new status
    if (status === 'confirmed') {
      const dateStr = confirmed_date || appointment.appointment_date;
      const timeStr = confirmed_time || appointment.preferred_time || '';
      notificationService.sendToMember(appointment.member_id, {
        type: 'appointment_confirmed',
        title: '✅ Appointment Confirmed',
        message: `Your appointment at ${appointment.hospital_name} is confirmed for ${dateStr}${timeStr ? ' at ' + timeStr : ''}.`,
        channel: ['push', 'sms', 'email'],
      }).catch((err) => console.error('Confirm notification error:', err.message));
      logAppointmentNotification({
        memberId: appointment.member_id,
        type: 'appointment_confirmed_member',
        channel: 'system',
        title: 'Appointment Confirmed',
        message: `Member notified that appointment at ${appointment.hospital_name} is confirmed.`,
        appointmentId: appointment.id,
      }).catch((err) => console.error('Appointment confirmation tracking log error:', err.message));

      if (appointment.hospital_email) {
        notificationService.sendEmail(
          appointment.hospital_email,
          'Appointment Confirmed — Sanlam Chronic Care',
          `<p>Dear ${appointment.contact_person || appointment.hospital_name},</p>
           <p>A Sanlam admin has confirmed the following appointment:</p>
           <ul>
             <li><strong>Member:</strong> ${appointment.first_name} ${appointment.last_name} (${appointment.member_number})</li>
             <li><strong>Hospital:</strong> ${appointment.hospital_name}</li>
             <li><strong>Date:</strong> ${dateStr}</li>
             <li><strong>Time:</strong> ${timeStr || 'Not specified'}</li>
             <li><strong>Status:</strong> Confirmed</li>
           </ul>
            <p>Please prepare to receive the member as scheduled.</p>`
        ).catch((err) => console.error('Hospital confirmation email error:', err.message));
        logAppointmentNotification({
          memberId: appointment.member_id,
          type: 'appointment_confirmed_provider',
          channel: 'email',
          title: 'Appointment Confirmation Sent to Provider',
          message: `Provider confirmation email sent to ${appointment.hospital_email}.`,
          appointmentId: appointment.id,
        }).catch((err) => console.error('Appointment provider confirm tracking error:', err.message));
      }
    } else if (status === 'rescheduled') {
      const dateStr = appointment_date || appointment.appointment_date;
      const timeStr = preferred_time || appointment.preferred_time || '';
      notificationService.sendToMember(appointment.member_id, {
        type: 'appointment_rescheduled',
        title: '🔄 Appointment Rescheduled',
        message: `Your appointment at ${appointment.hospital_name} has been rescheduled to ${dateStr}${timeStr ? ' at ' + timeStr : ''}.`,
        channel: ['push', 'sms', 'email'],
      }).catch((err) => console.error('Reschedule notification error:', err.message));
      logAppointmentNotification({
        memberId: appointment.member_id,
        type: 'appointment_rescheduled_member',
        channel: 'system',
        title: 'Appointment Rescheduled',
        message: `Member notified that appointment at ${appointment.hospital_name} was rescheduled.`,
        appointmentId: appointment.id,
      }).catch((err) => console.error('Appointment reschedule tracking error:', err.message));
    } else if (status === 'cancelled') {
      notificationService.sendToMember(appointment.member_id, {
        type: 'appointment_cancelled',
        title: '❌ Appointment Cancelled',
        message: `Your appointment at ${appointment.hospital_name} has been cancelled.${cancellation_reason ? ' Reason: ' + cancellation_reason : ''}`,
        channel: ['push', 'sms', 'email'],
      }).catch((err) => console.error('Cancel notification error:', err.message));
      logAppointmentNotification({
        memberId: appointment.member_id,
        type: 'appointment_cancelled_member',
        channel: 'system',
        title: 'Appointment Cancelled',
        message: `Member notified that appointment at ${appointment.hospital_name} was cancelled.`,
        appointmentId: appointment.id,
      }).catch((err) => console.error('Appointment cancel tracking error:', err.message));
    } else if (status === 'completed') {
      logAppointmentNotification({
        memberId: appointment.member_id,
        type: 'appointment_completed_admin',
        channel: 'portal',
        title: 'Appointment Marked Attended',
        message: 'Sanlam admin marked appointment as attended.',
        appointmentId: appointment.id,
      }).catch((err) => console.error('Appointment completed tracking error:', err.message));
    } else if (status === 'no_show') {
      logAppointmentNotification({
        memberId: appointment.member_id,
        type: 'appointment_no_show_admin',
        channel: 'portal',
        title: 'Appointment Marked No-show',
        message: `Sanlam admin marked appointment as no-show.${no_show_reason ? ` Reason: ${no_show_reason}` : ''}`,
        appointmentId: appointment.id,
      }).catch((err) => console.error('Appointment no-show tracking error:', err.message));
    }

    return res.json(updatedAppointment);
  } catch (err) {
    console.error('updateAppointmentStatus error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const listAllAppointments = async (req, res) => {
  try {
    const {
      status,
      hospital_id,
      condition_id,
      search,
      date_from,
      date_to,
      page = 1,
      limit = 20,
    } = req.query;
    const params = [];
    const filters = [];
    let idx = 1;

    if (status) {
      filters.push(`a.status = $${idx++}`);
      params.push(status);
    }
    if (hospital_id) {
      filters.push(`a.hospital_id = $${idx++}`);
      params.push(hospital_id);
    }
    if (condition_id) {
      filters.push(`a.condition_id = $${idx++}`);
      params.push(condition_id);
    }
    if (date_from) {
      filters.push(`a.appointment_date >= $${idx++}`);
      params.push(date_from);
    }
    if (date_to) {
      filters.push(`a.appointment_date <= $${idx++}`);
      params.push(date_to);
    }
    if (search) {
      filters.push(`(
        CONCAT_WS(' ', m.first_name, m.last_name) ILIKE $${idx}
        OR m.member_number ILIKE $${idx}
        OR h.name ILIKE $${idx}
        OR COALESCE(c.name, '') ILIKE $${idx}
      )`);
      params.push(`%${search}%`);
      idx += 1;
    }

    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const countResult = await pool.query(
      `SELECT COUNT(*)
       FROM appointments a
       JOIN hospitals h ON h.id = a.hospital_id
       JOIN members m ON m.id = a.member_id
       LEFT JOIN conditions c ON c.id = a.condition_id
       ${where}`,
      params
    );
    const total = parseInt(countResult.rows[0].count);

    const summaryResult = await pool.query(
      `SELECT
         COUNT(*)::int AS total,
         COUNT(*) FILTER (WHERE a.status = 'pending')::int AS pending,
         COUNT(*) FILTER (WHERE a.status = 'confirmed')::int AS confirmed,
         COUNT(*) FILTER (WHERE a.status = 'completed')::int AS completed,
         COUNT(*) FILTER (WHERE a.status = 'cancelled')::int AS cancelled,
         COUNT(*) FILTER (WHERE a.status = 'no_show')::int AS no_show,
         COUNT(*) FILTER (WHERE a.appointment_date = CURRENT_DATE)::int AS today
       FROM appointments a
       JOIN hospitals h ON h.id = a.hospital_id
       JOIN members m ON m.id = a.member_id
       LEFT JOIN conditions c ON c.id = a.condition_id
       ${where}`,
      params
    );

    params.push(parseInt(limit), offset);
    const result = await pool.query(
      `SELECT a.*, h.name AS hospital_name, h.phone AS hospital_phone, h.email AS hospital_email,
               h.contact_person, m.first_name, m.last_name, m.member_number, m.phone AS member_phone,
               m.email AS member_email, m.id AS member_id,
               CONCAT_WS(' ', m.first_name, m.last_name) AS member_name,
               c.name AS condition_name,
               c.name AS condition,
               a.appointment_date AS preferred_date,
               COALESCE(CONCAT_WS(' ', ad.first_name, ad.last_name), ad.email) AS admin_name,
               CASE
                 WHEN a.status = 'pending' AND a.appointment_date <= CURRENT_DATE THEN 'high'
                 WHEN a.status = 'pending' AND a.appointment_date <= CURRENT_DATE + INTERVAL '2 days' THEN 'medium'
                 ELSE 'normal'
               END AS urgency_level,
               CASE
                 WHEN a.is_direct_booked THEN 'Direct booked'
                 WHEN a.created_by_admin THEN 'Admin booked'
                 ELSE 'Member request'
               END AS source_label,
               EXISTS(
                 SELECT 1 FROM notifications n
                 WHERE n.reference_type = 'appointment'
                   AND n.reference_id = a.id
                   AND n.type IN (
                     'appointment_request_member',
                     'appointment_confirmed_member',
                     'appointment_rescheduled_member',
                     'appointment_cancelled_member'
                   )
               ) AS member_notified,
               EXISTS(
                 SELECT 1 FROM notifications n
                 WHERE n.reference_type = 'appointment'
                   AND n.reference_id = a.id
                   AND n.type IN (
                     'appointment_request_provider',
                     'appointment_confirmed_provider'
                   )
               ) AS provider_notified,
               COALESCE((
                 SELECT json_agg(item ORDER BY item.event_at)
                 FROM (
                   SELECT a.created_at AS event_at,
                          CASE WHEN a.created_by_admin THEN 'Admin booking created' ELSE 'Member request created' END AS label,
                          CASE WHEN a.created_by_admin THEN 'Sanlam admin' ELSE 'Member' END AS actor
                   UNION ALL
                   SELECT COALESCE(a.confirmed_date::timestamp, a.updated_at) AS event_at,
                          'Appointment confirmed' AS label,
                          'Sanlam admin' AS actor
                   WHERE a.status = 'confirmed'
                   UNION ALL
                   SELECT a.updated_at AS event_at,
                          'Appointment rescheduled' AS label,
                          'Sanlam admin' AS actor
                   WHERE a.status = 'rescheduled'
                   UNION ALL
                   SELECT a.updated_at AS event_at,
                          'Appointment cancelled' AS label,
                          'Sanlam admin' AS actor
                   WHERE a.status = 'cancelled'
                   UNION ALL
                   SELECT a.updated_at AS event_at,
                          'Appointment marked attended' AS label,
                          'Sanlam admin' AS actor
                   WHERE a.status = 'completed'
                   UNION ALL
                   SELECT a.updated_at AS event_at,
                          'Appointment marked no-show' AS label,
                          'Sanlam admin' AS actor
                   WHERE a.status = 'no_show'
                 ) item
               ), '[]') AS timeline
        FROM appointments a
        JOIN hospitals h ON h.id = a.hospital_id
        JOIN members m ON m.id = a.member_id
       LEFT JOIN conditions c ON c.id = a.condition_id
       LEFT JOIN admins ad ON ad.id = a.admin_id
       ${where}
       ORDER BY a.appointment_date DESC, a.created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      params
    );

    return res.json({
      appointments: result.rows,
      data: result.rows,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
      summary: summaryResult.rows[0],
    });
  } catch (err) {
    console.error('listAllAppointments error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const createAppointmentForMember = async (req, res) => {
  try {
    const { member_id, hospital_id, condition_id, appointment_date, preferred_time, reason } = req.body;

    if (!member_id || !hospital_id || !appointment_date) {
      return res.status(400).json({ message: 'member_id, hospital_id and appointment_date are required' });
    }

    const memberCheck = await pool.query('SELECT id FROM members WHERE id = $1', [member_id]);
    if (!memberCheck.rows.length) return res.status(404).json({ message: 'Member not found' });

    const hospitalCheck = await pool.query('SELECT id, name FROM hospitals WHERE id = $1 AND is_active = TRUE', [hospital_id]);
    if (!hospitalCheck.rows.length) return res.status(404).json({ message: 'Hospital not found' });

    const result = await pool.query(
      `INSERT INTO appointments
         (member_id, hospital_id, condition_id, appointment_date, preferred_time, reason, status, created_by_admin, admin_id)
       VALUES ($1,$2,$3,$4,$5,$6,'confirmed', TRUE, $7)
       RETURNING *`,
      [member_id, hospital_id, condition_id || null, appointment_date, preferred_time || null, reason || null, req.user.id]
    );

    notificationService.sendToMember(member_id, {
      type: 'appointment_created',
      title: '📅 Appointment Booked',
      message: `An appointment has been booked for you at ${hospitalCheck.rows[0].name} on ${appointment_date}.`,
      channel: ['push', 'sms', 'email'],
    }).catch((err) => console.error('Admin appointment notification error:', err.message));
    logAppointmentNotification({
      memberId: member_id,
      type: 'appointment_booked_member',
      channel: 'system',
      title: 'Appointment Booked',
      message: `Member notified that appointment at ${hospitalCheck.rows[0].name} was booked.`,
      appointmentId: result.rows[0].id,
    }).catch((err) => console.error('Admin appointment tracking log error:', err.message));

    // Audit log
    pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'create_appointment', 'appointment', $2, $3, $4)`,
      [req.user.id, result.rows[0].id, JSON.stringify({ member_id, hospital: hospitalCheck.rows[0].name, appointment_date, admin_name: req.user.name || req.user.email }), req.ip]
    ).catch((err) => console.error('Audit log error:', err.message));

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('createAppointmentForMember error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const cancelAppointment = async (req, res) => {
  try {
    const { id } = req.params;
    const memberId = req.user.id;

    const existing = await pool.query(
      'SELECT * FROM appointments WHERE id = $1 AND member_id = $2',
      [id, memberId]
    );
    if (!existing.rows.length) {
      return res.status(404).json({ message: 'Appointment not found' });
    }
    if (['cancelled', 'completed', 'missed'].includes(existing.rows[0].status)) {
      return res.status(409).json({ message: `Appointment is already ${existing.rows[0].status}` });
    }

    const result = await pool.query(
      `UPDATE appointments SET status = 'cancelled', updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('cancelAppointment error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const confirmAttended = async (req, res) => {
  try {
    const { id } = req.params;
    const memberId = req.user.id;

    const existing = await pool.query(
      'SELECT * FROM appointments WHERE id = $1 AND member_id = $2',
      [id, memberId]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Appointment not found' });
    if (!['pending', 'confirmed'].includes(existing.rows[0].status)) {
      return res.status(409).json({ message: 'Only pending or confirmed appointments can be confirmed' });
    }

    const result = await pool.query(
      `UPDATE appointments SET status = 'completed', updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id]
    );

    // Notify admin
    pool.query(
      `INSERT INTO notifications (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
       VALUES ($1, 'appointment_attended', 'portal', $2, $3, 'sent', $4, 'appointment', NOW())`,
      [memberId, '✅ Appointment Attended', `Member confirmed they attended their appointment.`, id]
    ).catch(() => {});

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('confirmAttended error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const markMissed = async (req, res) => {
  try {
    const { id } = req.params;
    const memberId = req.user.id;
    const { reason } = req.body;

    const existing = await pool.query(
      'SELECT * FROM appointments WHERE id = $1 AND member_id = $2',
      [id, memberId]
    );
    if (!existing.rows.length) return res.status(404).json({ message: 'Appointment not found' });
    if (!['pending', 'confirmed'].includes(existing.rows[0].status)) {
      return res.status(409).json({ message: 'Only pending or confirmed appointments can be marked missed' });
    }

    const result = await pool.query(
      `UPDATE appointments SET status = 'missed', missed_reason = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [reason || null, id]
    );

    // Notify admin
    pool.query(
      `INSERT INTO notifications (member_id, type, channel, title, message, status, reference_id, reference_type, sent_at)
       VALUES ($1, 'appointment_missed', 'portal', $2, $3, 'sent', $4, 'appointment', NOW())`,
      [memberId, '⚠️ Appointment Missed', `Member missed their appointment.${reason ? ' Reason: ' + reason : ''}`, id]
    ).catch(() => {});

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('markMissed error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  createAppointment,
  listMyAppointments,
  updateAppointmentStatus,
  listAllAppointments,
  createAppointmentForMember,
  cancelAppointment,
  confirmAttended,
  markMissed,
};
