import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import {
  EyeIcon,
  CheckCircleIcon,
  XCircleIcon,
  ArrowPathIcon,
  CheckBadgeIcon,
  ExclamationTriangleIcon,
  MagnifyingGlassIcon,
  CalendarDaysIcon,
  BellAlertIcon,
} from '@heroicons/react/24/outline';
import { getAllAppointments, updateAppointmentStatus } from '../../api/appointments';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import StatCard from '../../components/UI/StatCard';
import { format } from 'date-fns';

const STATUSES = ['All', 'pending', 'confirmed', 'rescheduled', 'completed', 'cancelled', 'no_show'];

const sourceStyle = (source) => {
  if (source === 'Admin booked') return { background: '#dbeafe', color: '#1d4ed8' };
  if (source === 'Direct booked') return { background: '#dcfce7', color: '#166534' };
  return { background: '#f1f5f9', color: '#475569' };
};

const urgencyStyle = (urgency) => {
  if (urgency === 'high') return { background: '#fee2e2', color: '#b91c1c' };
  if (urgency === 'medium') return { background: '#fef3c7', color: '#92400e' };
  return { background: '#e2e8f0', color: '#475569' };
};

const formatDate = (value) => (value ? format(new Date(value), 'dd MMM yyyy') : '—');
const formatDateTime = (value) => (value ? format(new Date(value), 'dd MMM yyyy HH:mm') : '—');
const normalizeTimeline = (timeline) => {
  if (Array.isArray(timeline)) return timeline;
  if (typeof timeline === 'string' && timeline) {
    try {
      return JSON.parse(timeline);
    } catch {
      return [];
    }
  }
  return [];
};

export default function AppointmentsPage() {
  const qc = useQueryClient();
  const navigate = useNavigate();
  const [statusFilter, setStatusFilter] = useState('');
  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [page, setPage] = useState(1);
  const [actionModal, setActionModal] = useState(null);
  const [viewModal, setViewModal] = useState(null);

  const { register, handleSubmit, reset } = useForm();

  const { data, isLoading } = useQuery({
    queryKey: ['appointments', { statusFilter, search, dateFrom, dateTo, page }],
    queryFn: () =>
      getAllAppointments({
        status: statusFilter,
        search,
        date_from: dateFrom,
        date_to: dateTo,
        page,
        limit: 15,
      }).then((r) => r.data),
    retry: false,
    placeholderData: { appointments: [], data: [], total: 0, pages: 1, summary: {} },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data: payload }) => updateAppointmentStatus(id, payload),
    onSuccess: () => {
      qc.invalidateQueries(['appointments']);
      toast.success('Appointment updated');
      setActionModal(null);
      reset();
    },
    onError: () => toast.error('Failed to update appointment'),
  });

  const handleAction = (formData) => {
    const { id, type } = actionModal;
    if (type === 'confirm') {
      updateMutation.mutate({
        id,
        data: {
          status: 'confirmed',
          confirmed_date: formData.confirmed_date,
          confirmed_time: formData.confirmed_time,
        },
      });
      return;
    }

    if (type === 'cancel') {
      updateMutation.mutate({
        id,
        data: {
          status: 'cancelled',
          cancellation_reason: formData.reason,
        },
      });
      return;
    }

    if (type === 'reschedule') {
      updateMutation.mutate({
        id,
        data: {
          status: 'rescheduled',
          appointment_date: formData.appointment_date,
          preferred_time: formData.preferred_time,
          notes: formData.notes,
        },
      });
      return;
    }

    if (type === 'complete') {
      updateMutation.mutate({
        id,
        data: {
          status: 'completed',
          notes: formData.notes,
        },
      });
      return;
    }

    updateMutation.mutate({
      id,
      data: {
        status: 'no_show',
        no_show_reason: formData.no_show_reason,
      },
    });
  };

  const appointments = data?.appointments || data?.data || [];
  const totalPages = data?.pages || 1;
  const summary = data?.summary || {};

  const columns = [
    {
      key: 'member_name',
      header: 'Member',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <p style={{ margin: 0, fontWeight: '600' }}>{row.member_name || '—'}</p>
          <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>
            {row.member_number || '—'} {row.member_phone ? `• ${row.member_phone}` : ''}
          </p>
          <button
            type="button"
            onClick={() => navigate(`/members/${row.member_id}`)}
            style={{ background: 'none', border: 'none', padding: 0, color: 'var(--primary)', fontSize: '12px', textAlign: 'left', cursor: 'pointer' }}
          >
            Open member profile
          </button>
        </div>
      ),
    },
    {
      key: 'hospital_name',
      header: 'Provider',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <p style={{ margin: 0, fontWeight: '600' }}>{row.hospital_name || '—'}</p>
          <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>
            {row.contact_person || 'No contact'} {row.hospital_phone ? `• ${row.hospital_phone}` : ''}
          </p>
          <button
            type="button"
            onClick={() => navigate('/hospitals')}
            style={{ background: 'none', border: 'none', padding: 0, color: 'var(--primary)', fontSize: '12px', textAlign: 'left', cursor: 'pointer' }}
          >
            Open hospitals directory
          </button>
        </div>
      ),
    },
    { key: 'condition', header: 'Condition' },
    {
      key: 'preferred_date',
      header: 'Schedule',
      render: (value, row) => (
        <div>
          <p style={{ margin: 0 }}>{formatDate(value || row.appointment_date)}</p>
          <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>
            Preferred: {row.preferred_time || '—'}{row.confirmed_time ? ` • Confirmed: ${row.confirmed_time}` : ''}
          </p>
        </div>
      ),
    },
    {
      key: 'source_label',
      header: 'Source',
      render: (value) => (
        <span style={{ ...sourceStyle(value), padding: '3px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: '600', whiteSpace: 'nowrap' }}>
          {value}
        </span>
      ),
    },
    {
      key: 'urgency_level',
      header: 'Urgency',
      render: (value) => (
        <span style={{ ...urgencyStyle(value), padding: '3px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: '600', textTransform: 'capitalize', whiteSpace: 'nowrap' }}>
          {value}
        </span>
      ),
    },
    {
      key: 'reason',
      header: 'Reason',
      render: (value) => (
        <span style={{ display: 'inline-block', maxWidth: '180px', whiteSpace: 'normal', color: '#475569' }}>
          {value || '—'}
        </span>
      ),
    },
    {
      key: 'notifications',
      header: 'Notifications',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
          <Badge status={row.member_notified ? 'confirmed' : 'inactive'} label={`Member ${row.member_notified ? 'sent' : 'pending'}`} />
          <Badge status={row.provider_notified ? 'confirmed' : 'inactive'} label={`Provider ${row.provider_notified ? 'sent' : 'pending'}`} />
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (value) => <Badge status={value} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          <Button variant="ghost" onClick={() => setViewModal(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <EyeIcon style={{ width: 13, height: 13 }} /> View
          </Button>
          {['pending', 'rescheduled'].includes(row.status) && (
            <Button variant="success" onClick={() => { reset(); setActionModal({ type: 'confirm', id: row.id, appointment: row }); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <CheckCircleIcon style={{ width: 13, height: 13 }} /> Confirm
            </Button>
          )}
          {['pending', 'confirmed', 'rescheduled'].includes(row.status) && (
            <Button variant="secondary" onClick={() => { reset(); setActionModal({ type: 'reschedule', id: row.id, appointment: row }); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <ArrowPathIcon style={{ width: 13, height: 13 }} /> Reschedule
            </Button>
          )}
          {['confirmed', 'rescheduled'].includes(row.status) && (
            <Button variant="success" onClick={() => { reset(); setActionModal({ type: 'complete', id: row.id, appointment: row }); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <CheckBadgeIcon style={{ width: 13, height: 13 }} /> Attended
            </Button>
          )}
          {['confirmed', 'rescheduled'].includes(row.status) && (
            <Button variant="danger" onClick={() => { reset(); setActionModal({ type: 'no_show', id: row.id, appointment: row }); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <ExclamationTriangleIcon style={{ width: 13, height: 13 }} /> No-show
            </Button>
          )}
          {['pending', 'confirmed', 'rescheduled'].includes(row.status) && (
            <Button variant="danger" onClick={() => { reset(); setActionModal({ type: 'cancel', id: row.id, appointment: row }); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <XCircleIcon style={{ width: 13, height: 13 }} /> Cancel
            </Button>
          )}
        </div>
      ),
    },
  ];

  const actionTitle = {
    confirm: 'Confirm Appointment',
    cancel: 'Cancel Appointment',
    reschedule: 'Reschedule Appointment',
    complete: 'Mark Appointment Attended',
    no_show: 'Mark Appointment No-show',
  }[actionModal?.type];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px' }}>
        <StatCard title="Pending" value={summary.pending ?? 0} icon={BellAlertIcon} color="#f59e0b" variant="label" />
        <StatCard title="Confirmed" value={summary.confirmed ?? 0} icon={CheckCircleIcon} color="var(--accent)" variant="label" />
        <StatCard title="Completed" value={summary.completed ?? 0} icon={CheckBadgeIcon} color="#0f766e" variant="label" />
        <StatCard title="Cancelled" value={summary.cancelled ?? 0} icon={XCircleIcon} color="#ef4444" variant="label" />
        <StatCard title="No-show" value={summary.no_show ?? 0} icon={ExclamationTriangleIcon} color="#ea580c" variant="label" />
        <StatCard title="Today" value={summary.today ?? 0} icon={CalendarDaysIcon} color="#0ea5e9" variant="label" />
      </div>

      <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
        <div style={{ position: 'relative', minWidth: '260px', flex: 1 }}>
          <MagnifyingGlassIcon style={{ width: 16, height: 16, position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
          <input
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search member, member number, hospital, or condition…"
            style={{ width: '100%', padding: '8px 12px 8px 36px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
          style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
        >
          {STATUSES.map((status) => (
            <option key={status} value={status === 'All' ? '' : status}>
              {status === 'All' ? 'All Statuses' : status.replace('_', ' ').replace(/\b\w/g, (char) => char.toUpperCase())}
            </option>
          ))}
        </select>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <input type="date" value={dateFrom} onChange={(e) => { setDateFrom(e.target.value); setPage(1); }} style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }} />
          <span style={{ color: '#64748b', fontSize: '14px' }}>to</span>
          <input type="date" value={dateTo} onChange={(e) => { setDateTo(e.target.value); setPage(1); }} style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }} />
        </div>
      </div>

      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : <Table columns={columns} data={appointments} emptyMessage="No appointments found." />}
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: '13px', color: '#64748b' }}>Page {page} of {totalPages} — {data?.total || 0} total</span>
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="secondary" onClick={() => setPage((current) => Math.max(1, current - 1))} disabled={page <= 1}>‹ Prev</Button>
          <Button variant="secondary" onClick={() => setPage((current) => Math.min(totalPages, current + 1))} disabled={page >= totalPages}>Next ›</Button>
        </div>
      </div>

      {viewModal && (
        <Modal title="Appointment Details" onClose={() => setViewModal(null)} width="760px">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '14px' }}>
              {[
                ['Member', viewModal.member_name],
                ['Member #', viewModal.member_number],
                ['Member Phone', viewModal.member_phone],
                ['Member Email', viewModal.member_email],
                ['Hospital', viewModal.hospital_name],
                ['Hospital Contact', viewModal.contact_person],
                ['Hospital Phone', viewModal.hospital_phone],
                ['Hospital Email', viewModal.hospital_email],
                ['Condition', viewModal.condition || viewModal.condition_name],
                ['Preferred Date', formatDate(viewModal.preferred_date || viewModal.appointment_date)],
                ['Preferred Time', viewModal.preferred_time],
                ['Confirmed Date', formatDate(viewModal.confirmed_date)],
                ['Confirmed Time', viewModal.confirmed_time],
                ['Source', viewModal.source_label],
                ['Urgency', viewModal.urgency_level],
                ['Status', viewModal.status],
                ['Reason', viewModal.reason],
                ['Cancellation Reason', viewModal.cancellation_reason],
                ['No-show Reason', viewModal.no_show_reason],
                ['Notes', viewModal.notes],
                ['Member Notification', viewModal.member_notified ? 'Sent' : 'Pending'],
                ['Provider Notification', viewModal.provider_notified ? 'Sent' : 'Pending'],
              ].map(([label, value]) => (
                <div key={label} style={{ display: 'flex', gap: '8px', padding: '6px 0', borderBottom: '1px solid #f1f5f9' }}>
                  <span style={{ minWidth: '140px', color: '#64748b', fontWeight: '500' }}>{label}</span>
                  <span style={{ color: 'var(--text)' }}>{value || '—'}</span>
                </div>
              ))}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                <Button variant="ghost" onClick={() => navigate(`/members/${viewModal.member_id}`)}>Open Member</Button>
                <Button variant="secondary" onClick={() => navigate('/hospitals')}>Open Hospitals</Button>
              </div>

              <div style={{ border: '1px solid #e2e8f0', borderRadius: '12px', padding: '16px', background: '#f8fafc' }}>
                <h3 style={{ margin: '0 0 12px', fontSize: '15px', color: 'var(--text)' }}>Timeline</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {normalizeTimeline(viewModal.timeline).length > 0 ? (
                    normalizeTimeline(viewModal.timeline).map((item, index) => (
                      <div key={`${item.label}-${index}`} style={{ display: 'flex', gap: '10px' }}>
                        <div style={{ width: 10, height: 10, borderRadius: '50%', background: 'var(--primary)', marginTop: 6, flexShrink: 0 }} />
                        <div>
                          <p style={{ margin: 0, fontSize: '13px', fontWeight: '600', color: 'var(--text)' }}>{item.label}</p>
                          <p style={{ margin: '2px 0 0', fontSize: '12px', color: '#64748b' }}>
                            {item.actor || 'System'} • {formatDateTime(item.event_at)}
                          </p>
                        </div>
                      </div>
                    ))
                  ) : (
                    <p style={{ margin: 0, fontSize: '13px', color: '#64748b' }}>No timeline available.</p>
                  )}
                </div>
              </div>
            </div>
          </div>
        </Modal>
      )}

      {actionModal && (
        <Modal title={actionTitle} onClose={() => { setActionModal(null); reset(); }}>
          <form onSubmit={handleSubmit(handleAction)} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <p style={{ margin: '0 0 8px', fontSize: '14px', color: '#64748b' }}>
              {actionModal.type === 'confirm' && `Set the confirmed date and time for ${actionModal.appointment?.member_name}.`}
              {actionModal.type === 'cancel' && 'Provide a reason for cancelling this appointment.'}
              {actionModal.type === 'reschedule' && 'Choose the new appointment date and preferred time.'}
              {actionModal.type === 'complete' && 'Add any notes about the attended appointment.'}
              {actionModal.type === 'no_show' && 'Capture the no-show reason if one is known.'}
            </p>

            {actionModal.type === 'confirm' && (
              <>
                <Input label="Confirmed Date" name="confirmed_date" type="date" register={register} />
                <Input label="Confirmed Time" name="confirmed_time" type="time" register={register} />
              </>
            )}

            {actionModal.type === 'cancel' && (
              <Input label="Cancellation Reason" name="reason" register={register} placeholder="Reason for cancellation" />
            )}

            {actionModal.type === 'reschedule' && (
              <>
                <Input label="New Appointment Date" name="appointment_date" type="date" register={register} />
                <Input label="Preferred Time" name="preferred_time" type="time" register={register} />
                <Input label="Notes" name="notes" register={register} placeholder="Optional reschedule notes" />
              </>
            )}

            {actionModal.type === 'complete' && (
              <Input label="Completion Notes" name="notes" register={register} placeholder="Optional notes" />
            )}

            {actionModal.type === 'no_show' && (
              <Input label="No-show Reason" name="no_show_reason" register={register} placeholder="Reason member missed the appointment" />
            )}

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button variant="secondary" type="button" onClick={() => { setActionModal(null); reset(); }}>Back</Button>
              <Button
                variant={['cancel', 'no_show'].includes(actionModal.type) ? 'danger' : 'success'}
                type="submit"
                disabled={updateMutation.isPending}
              >
                {updateMutation.isPending ? 'Saving…' : actionTitle}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
