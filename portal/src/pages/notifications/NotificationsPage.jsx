import { useState } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import { PaperAirplaneIcon } from '@heroicons/react/24/outline';
import { sendCampaign, getNotificationLogs } from '../../api/notifications';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';
import { format } from 'date-fns';

const CONDITIONS = ['Diabetes', 'Hypertension', 'Asthma', 'HIV/AIDS', 'TB', 'Cancer'];

export default function NotificationsPage() {
  const [allMembers, setAllMembers] = useState(true);
  const { register, handleSubmit, reset, watch } = useForm({ defaultValues: { channels: [] } });

  const { data: logsData, isLoading: logsLoading } = useQuery({
    queryKey: ['notification-logs'],
    queryFn: () => getNotificationLogs({ limit: 20 }).then((r) => r.data),
    retry: false,
    placeholderData: { logs: [] },
  });

  const sendMutation = useMutation({
    mutationFn: sendCampaign,
    onSuccess: () => { toast.success('Campaign sent successfully!'); reset(); },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to send campaign'),
  });

  const onSubmit = (data) => {
    const channels = [];
    if (data.push) channels.push('push');
    if (data.sms) channels.push('sms');
    if (data.email) channels.push('email');
    if (channels.length === 0) return toast.error('Select at least one channel');
    const payload = {
      title: data.title,
      message: data.message,
      channel: channels,
      all_members: allMembers,
      condition_id: !allMembers ? data.condition : undefined,
    };
    sendMutation.mutate(payload);
  };

  const logs = logsData?.logs || [];

  const logColumns = [
    { key: 'member_name', header: 'Member', render: (_, r) => r.member_name || r.member?.name || '—' },
    { key: 'title', header: 'Title' },
    { key: 'channel', header: 'Channel', render: (v) => <span style={{ textTransform: 'capitalize', fontSize: '12px', background: '#f1f5f9', padding: '2px 8px', borderRadius: '4px' }}>{v}</span> },
    { key: 'status', header: 'Status', render: (v) => <Badge status={v === 'sent' || v === 'delivered' ? 'active' : v === 'failed' ? 'cancelled' : 'pending'} label={v} /> },
    { key: 'sent_at', header: 'Sent At', render: (v) => v ? format(new Date(v), 'dd MMM yyyy HH:mm') : '—' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Send Campaign Form */}
      <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' }}>
        <h3 style={{ margin: '0 0 20px', fontSize: '16px', fontWeight: '600', color: 'var(--text)' }}>
          📣 Send Campaign
        </h3>
        <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '16px', maxWidth: '600px' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Campaign Title *</label>
            <input
              {...register('title', { required: true })}
              placeholder="e.g. Medication Refill Reminder"
              style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
            />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Message *</label>
            <textarea
              {...register('message', { required: true })}
              rows={4}
              placeholder="Write your campaign message here…"
              style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', resize: 'vertical', fontFamily: 'inherit' }}
            />
          </div>

          {/* Channels */}
          <div>
            <p style={{ margin: '0 0 8px', fontSize: '13px', fontWeight: '500', color: '#475569' }}>Channels *</p>
            <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>
              {['push', 'sms', 'email'].map((ch) => (
                <label key={ch} style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                  <input type="checkbox" {...register(ch)} style={{ width: 16, height: 16 }} />
                  {ch.toUpperCase()}
                </label>
              ))}
            </div>
          </div>

          {/* Target */}
          <div>
            <p style={{ margin: '0 0 8px', fontSize: '13px', fontWeight: '500', color: '#475569' }}>Target Audience</p>
            <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', alignItems: 'center' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                <input type="radio" checked={allMembers} onChange={() => setAllMembers(true)} />
                All Members
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                <input type="radio" checked={!allMembers} onChange={() => setAllMembers(false)} />
                By Condition
              </label>
              {!allMembers && (
                <select
                  {...register('condition')}
                  style={{ padding: '7px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                >
                  <option value="">Select condition…</option>
                  {CONDITIONS.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
              )}
            </div>
          </div>

          <div>
            <Button variant="primary" type="submit" disabled={sendMutation.isPending} style={{ padding: '10px 20px' }}>
              <PaperAirplaneIcon style={{ width: 16, height: 16 }} />
              {sendMutation.isPending ? 'Sending…' : 'Send Campaign'}
            </Button>
          </div>
        </form>
      </div>

      {/* Recent Logs */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid #f1f5f9' }}>
          <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '600', color: 'var(--text)' }}>Recent Notifications Log</h3>
        </div>
        {logsLoading ? <Spinner /> : <Table columns={logColumns} data={logs} emptyMessage="No notifications sent yet." />}
      </div>
    </div>
  );
}
