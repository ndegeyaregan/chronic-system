import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import {
  PaperAirplaneIcon,
  MagnifyingGlassIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
  ChatBubbleLeftRightIcon,
  UserCircleIcon,
  ChevronDownIcon,
  BoltIcon,
} from '@heroicons/react/24/outline';
import {
  getAdminConversations,
  getConversationMessages,
  sendAdminReply,
  markMessagesRead,
  updateConversationStatus,
  getMemberChatInfo,
} from '../../api/chat';
import { useAuth } from '../../context/AuthContext';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

/* ── palette (no purple) ─────────────────────────────── */
const C = {
  blue:    '#003DA5',
  green:   '#7AB800',
  amber:   '#f59e0b',
  red:     '#ef4444',
  teal:    '#14b8a6',
  sky:     '#0ea5e9',
  slate:   '#64748b',
  border:  '#e2e8f0',
  bg:      '#f8fafc',
};

/* ── status config ───────────────────────────────────── */
const STATUS_OPTIONS = [
  { value: 'open',      label: 'Open',      color: C.sky   },
  { value: 'resolved',  label: 'Resolved',  color: C.green },
  { value: 'escalated', label: 'Escalated', color: C.red   },
];
const statusCfg = (s) => STATUS_OPTIONS.find(o => o.value === s) || STATUS_OPTIONS[0];

/* ── quick reply templates ───────────────────────────── */
const TEMPLATES = [
  { label: 'Prescription Renewed',   text: 'Your prescription has been reviewed and renewed. Please collect your medication from your nearest pharmacy.' },
  { label: 'Appointment Confirmed',  text: 'Your appointment has been confirmed. Please arrive 10 minutes early and bring your ID and medical card.' },
  { label: 'Lab Results Ready',      text: 'Your lab results are now available. Please log in to the portal or visit the clinic to discuss them with your doctor.' },
  { label: 'Authorisation Approved', text: 'Your authorisation request has been approved. The hospital/pharmacy has been notified.' },
  { label: 'Please Call Us',         text: 'We need to speak with you regarding your care plan. Please call SanCare Support at your earliest convenience.' },
  { label: 'Refill Reminder',        text: 'This is a reminder that your medication refill is due soon. Please contact your pharmacy or log a refill request in the portal.' },
];

/* ── panel helper ────────────────────────────────────── */
const panel = {
  background: '#fff',
  borderRadius: '12px',
  boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
  border: `1px solid ${C.border}`,
};

/* ── component ───────────────────────────────────────── */
export default function ChatPage() {
  const qc = useQueryClient();
  const { user } = useAuth();
  const [selectedMemberId, setSelectedMemberId] = useState('');
  const [message, setMessage] = useState('');
  const [search, setSearch] = useState('');
  const [showTemplates, setShowTemplates] = useState(false);
  const [showInfo, setShowInfo] = useState(false);
  const [statusDropdown, setStatusDropdown] = useState(false);
  const messagesEndRef = useRef(null);
  const textareaRef = useRef(null);

  /* conversations — auto-refresh every 30s */
  const { data: conversations = [], isLoading: conversationsLoading } = useQuery({
    queryKey: ['admin-chat-conversations'],
    queryFn: getAdminConversations,
    refetchInterval: 30_000,
    retry: false,
  });

  const activeMemberId = selectedMemberId || conversations[0]?.member_id || '';

  const selectedConversation = useMemo(
    () => conversations.find(c => c.member_id === activeMemberId),
    [activeMemberId, conversations]
  );

  /* messages — auto-refresh every 15s when a conversation is open */
  const { data: messages = [], isLoading: messagesLoading } = useQuery({
    queryKey: ['admin-chat-messages', activeMemberId],
    queryFn: () => getConversationMessages(activeMemberId),
    enabled: !!activeMemberId,
    refetchInterval: 15_000,
    retry: false,
  });

  /* member info */
  const { data: memberInfo } = useQuery({
    queryKey: ['admin-chat-member-info', activeMemberId],
    queryFn: () => getMemberChatInfo(activeMemberId),
    enabled: !!activeMemberId && showInfo,
    retry: false,
  });

  /* mark read when opening a conversation */
  const markReadMutation = useMutation({ mutationFn: markMessagesRead });
  useEffect(() => {
    if (!activeMemberId) return;
    markReadMutation.mutate(activeMemberId, {
      onSuccess: () => qc.invalidateQueries(['admin-chat-conversations']),
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeMemberId]);

  /* scroll to bottom when messages change */
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  /* status update */
  const statusMutation = useMutation({
    mutationFn: ({ memberId, status }) => updateConversationStatus(memberId, status),
    onSuccess: (_, { status }) => {
      qc.invalidateQueries(['admin-chat-conversations']);
      toast.success(`Status set to ${status}`);
      setStatusDropdown(false);
    },
    onError: () => toast.error('Failed to update status'),
  });

  /* reply */
  const adminName = user?.name || [user?.first_name, user?.last_name].filter(Boolean).join(' ') || 'SanCare Support';

  const replyMutation = useMutation({
    mutationFn: sendAdminReply,
    onSuccess: () => {
      qc.invalidateQueries(['admin-chat-conversations']);
      qc.invalidateQueries(['admin-chat-messages', activeMemberId]);
      toast.success('Reply sent');
      setMessage('');
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to send reply'),
  });

  const handleSend = useCallback(() => {
    if (!activeMemberId || !message.trim() || replyMutation.isPending) return;
    replyMutation.mutate({ member_id: activeMemberId, message, admin_name: adminName });
  }, [activeMemberId, message, replyMutation, adminName]);

  /* Ctrl+Enter to send */
  const handleKeyDown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault();
      handleSend();
    }
  };

  /* filtered conversations */
  const filteredConversations = useMemo(
    () => conversations.filter(c =>
      !search || c.member_name?.toLowerCase().includes(search.toLowerCase())
    ),
    [conversations, search]
  );

  const totalUnread = conversations.reduce((s, c) => s + (c.unread_count || 0), 0);

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '300px minmax(0,1fr)', gap: '20px', height: 'calc(100vh - 140px)', minHeight: '500px' }}>

      {/* ── LEFT: conversation list ── */}
      <div style={{ ...panel, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        {/* header */}
        <div style={{ padding: '14px 16px', borderBottom: `1px solid ${C.border}`, flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <h3 style={{ margin: 0, fontSize: '14px', fontWeight: '700', color: 'var(--text)', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <ChatBubbleLeftRightIcon style={{ width: 16, height: 16, color: C.blue }} />
              Conversations
            </h3>
            {totalUnread > 0 && (
              <span style={{ background: C.red, color: '#fff', fontSize: '11px', fontWeight: '700', borderRadius: '10px', padding: '2px 7px' }}>
                {totalUnread}
              </span>
            )}
          </div>
          {/* search */}
          <div style={{ position: 'relative' }}>
            <MagnifyingGlassIcon style={{ position: 'absolute', left: '9px', top: '50%', transform: 'translateY(-50%)', width: 14, height: 14, color: '#94a3b8', pointerEvents: 'none' }} />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search members…"
              style={{ width: '100%', padding: '7px 10px 7px 28px', borderRadius: '8px', border: `1px solid ${C.border}`, fontSize: '13px', boxSizing: 'border-box', outline: 'none' }}
            />
          </div>
        </div>

        {/* list */}
        <div style={{ overflowY: 'auto', flex: 1 }}>
          {conversationsLoading ? (
            <div style={{ padding: 20 }}><Spinner /></div>
          ) : filteredConversations.length === 0 ? (
            <div style={{ padding: '28px 20px', textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
              {search ? 'No matching conversations.' : 'No member messages yet.'}
            </div>
          ) : filteredConversations.map((conv) => {
            const isActive = conv.member_id === activeMemberId;
            const sc = statusCfg(conv.status);
            return (
              <button
                key={conv.member_id}
                type="button"
                onClick={() => setSelectedMemberId(conv.member_id)}
                style={{
                  width: '100%', textAlign: 'left', padding: '12px 14px',
                  border: 'none', borderBottom: `1px solid ${C.bg}`,
                  background: isActive ? '#eff6ff' : '#fff',
                  cursor: 'pointer',
                  borderLeft: isActive ? `3px solid ${C.blue}` : '3px solid transparent',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 6, marginBottom: '4px' }}>
                  <span style={{ fontSize: '13px', fontWeight: conv.unread_count > 0 ? '700' : '600', color: 'var(--text)', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {conv.member_name}
                  </span>
                  <div style={{ display: 'flex', gap: 4, alignItems: 'center', flexShrink: 0 }}>
                    {conv.unread_count > 0 && (
                      <span style={{ background: C.red, color: '#fff', fontSize: '10px', fontWeight: '700', borderRadius: '8px', padding: '1px 6px' }}>
                        {conv.unread_count}
                      </span>
                    )}
                    <span style={{ fontSize: '10px', color: '#94a3b8' }}>
                      {conv.created_at ? format(new Date(conv.created_at), 'dd MMM') : ''}
                    </span>
                  </div>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 4 }}>
                  <p style={{ margin: 0, fontSize: '12px', color: '#64748b', lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>
                    {conv.message}
                  </p>
                  <span style={{ fontSize: '10px', fontWeight: '600', color: sc.color, background: sc.color + '18', borderRadius: '6px', padding: '1px 6px', flexShrink: 0 }}>
                    {sc.label}
                  </span>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* ── RIGHT: conversation thread ── */}
      <div style={{ ...panel, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* header bar */}
        <div style={{ padding: '12px 16px', borderBottom: `1px solid ${C.border}`, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: C.blue + '18', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <UserCircleIcon style={{ width: 20, height: 20, color: C.blue }} />
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>
                {selectedConversation ? selectedConversation.member_name : 'Select a conversation'}
              </h3>
              {selectedConversation && (
                <span style={{ fontSize: '11px', color: C.slate }}>
                  {messages.length} message{messages.length !== 1 ? 's' : ''}
                </span>
              )}
            </div>
          </div>

          {selectedConversation && (
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              {/* status dropdown */}
              <div style={{ position: 'relative' }}>
                <button
                  onClick={() => setStatusDropdown(p => !p)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 5, padding: '5px 10px',
                    border: `1px solid ${C.border}`, borderRadius: '8px', background: '#fff',
                    fontSize: '12px', fontWeight: '600', cursor: 'pointer',
                    color: statusCfg(selectedConversation.status).color,
                  }}
                >
                  {statusCfg(selectedConversation.status).label}
                  <ChevronDownIcon style={{ width: 12, height: 12 }} />
                </button>
                {statusDropdown && (
                  <div style={{ position: 'absolute', top: '100%', right: 0, marginTop: 4, background: '#fff', border: `1px solid ${C.border}`, borderRadius: '10px', boxShadow: '0 4px 16px rgba(0,0,0,0.1)', zIndex: 50, minWidth: 130 }}>
                    {STATUS_OPTIONS.map(opt => (
                      <button
                        key={opt.value}
                        onClick={() => statusMutation.mutate({ memberId: activeMemberId, status: opt.value })}
                        style={{ width: '100%', display: 'block', padding: '9px 14px', textAlign: 'left', border: 'none', background: 'none', cursor: 'pointer', fontSize: '13px', fontWeight: '600', color: opt.color }}
                      >
                        {opt.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
              {/* member info toggle */}
              <button
                onClick={() => setShowInfo(p => !p)}
                title="Member info"
                style={{ padding: '5px 10px', border: `1px solid ${C.border}`, borderRadius: '8px', background: showInfo ? C.blue : '#fff', color: showInfo ? '#fff' : C.slate, fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
              >
                Info
              </button>
            </div>
          )}
        </div>

        {/* body row: messages + optional info panel */}
        <div style={{ flex: 1, overflow: 'hidden', display: 'flex', minHeight: 0 }}>
          {/* messages */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: '10px', background: C.bg }}>
            {!activeMemberId ? (
              <div style={{ margin: 'auto', color: '#94a3b8', fontSize: '13px', textAlign: 'center' }}>
                <ChatBubbleLeftRightIcon style={{ width: 40, height: 40, marginBottom: 8, opacity: 0.3 }} />
                <p>Choose a conversation to respond.</p>
              </div>
            ) : messagesLoading ? (
              <Spinner />
            ) : messages.length === 0 ? (
              <div style={{ margin: 'auto', color: '#94a3b8', fontSize: '13px' }}>No messages yet.</div>
            ) : messages.map((entry) => (
              <div
                key={entry.id}
                style={{
                  alignSelf: entry.is_from_admin ? 'flex-end' : 'flex-start',
                  maxWidth: '72%',
                }}
              >
                <div
                  style={{
                    background: entry.is_from_admin ? C.blue : '#fff',
                    color: entry.is_from_admin ? '#fff' : 'var(--text)',
                    borderRadius: entry.is_from_admin ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                    padding: '10px 14px',
                    boxShadow: '0 1px 3px rgba(15,23,42,0.08)',
                  }}
                >
                  <p style={{ margin: 0, fontSize: '13px', lineHeight: 1.5 }}>{entry.message}</p>
                </div>
                <p style={{ margin: '3px 6px 0', fontSize: '10px', color: '#94a3b8', textAlign: entry.is_from_admin ? 'right' : 'left' }}>
                  {entry.is_from_admin ? (entry.admin_name || adminName) : entry.member_name}
                  {' · '}{entry.created_at ? format(new Date(entry.created_at), 'dd MMM HH:mm') : ''}
                  {entry.is_from_admin && (
                    <CheckCircleIcon style={{ width: 10, height: 10, display: 'inline', marginLeft: 4, color: C.green }} />
                  )}
                </p>
              </div>
            ))}
            <div ref={messagesEndRef} />
          </div>

          {/* member info sidebar */}
          {showInfo && activeMemberId && (
            <div style={{ width: 220, borderLeft: `1px solid ${C.border}`, padding: '16px', overflowY: 'auto', background: '#fff', flexShrink: 0 }}>
              <h4 style={{ margin: '0 0 12px', fontSize: '13px', fontWeight: '700', color: 'var(--text)' }}>Member Info</h4>
              {!memberInfo ? (
                <Spinner />
              ) : (
                <>
                  <InfoRow label="Name" value={`${memberInfo.first_name || ''} ${memberInfo.last_name || ''}`.trim()} />
                  <InfoRow label="Email" value={memberInfo.email} />
                  <InfoRow label="Phone" value={memberInfo.phone || '—'} />
                  <InfoRow label="Gender" value={memberInfo.gender || '—'} />
                  <InfoRow label="DOB" value={memberInfo.date_of_birth ? format(new Date(memberInfo.date_of_birth), 'dd MMM yyyy') : '—'} />
                  <div style={{ marginTop: '12px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '11px', fontWeight: '700', color: C.slate, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Conditions</p>
                    {memberInfo.conditions?.length > 0
                      ? memberInfo.conditions.map(c => (
                          <span key={c} style={{ display: 'inline-block', fontSize: '11px', background: C.blue + '15', color: C.blue, borderRadius: '6px', padding: '2px 7px', marginRight: 4, marginBottom: 4, fontWeight: '600' }}>{c}</span>
                        ))
                      : <span style={{ fontSize: '12px', color: '#94a3b8' }}>None recorded</span>
                    }
                  </div>
                  {memberInfo.last_appointment && (
                    <div style={{ marginTop: '12px', background: C.bg, borderRadius: '8px', padding: '10px' }}>
                      <p style={{ margin: '0 0 4px', fontSize: '11px', fontWeight: '700', color: C.slate, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Last Appointment</p>
                      <p style={{ margin: 0, fontSize: '12px', color: 'var(--text)' }}>
                        {format(new Date(memberInfo.last_appointment.appointment_date), 'dd MMM yyyy')}
                      </p>
                      <p style={{ margin: '2px 0 0', fontSize: '11px', color: C.slate }}>{memberInfo.last_appointment.reason || 'Appointment'} · {memberInfo.last_appointment.status}</p>
                    </div>
                  )}
                </>
              )}
            </div>
          )}
        </div>

        {/* ── reply footer ── */}
        <div style={{ padding: '12px 16px', borderTop: `1px solid ${C.border}`, background: '#fff', flexShrink: 0 }}>
          {/* quick reply templates */}
          <div style={{ position: 'relative', marginBottom: 8 }}>
            <button
              onClick={() => setShowTemplates(p => !p)}
              disabled={!activeMemberId}
              style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '12px', color: activeMemberId ? C.blue : '#94a3b8', background: 'none', border: 'none', cursor: activeMemberId ? 'pointer' : 'default', fontWeight: '600', padding: 0 }}
            >
              <BoltIcon style={{ width: 13, height: 13 }} />
              Quick replies
              <ChevronDownIcon style={{ width: 11, height: 11 }} />
            </button>
            {showTemplates && (
              <div style={{ position: 'absolute', bottom: '100%', left: 0, marginBottom: 4, background: '#fff', border: `1px solid ${C.border}`, borderRadius: '10px', boxShadow: '0 4px 16px rgba(0,0,0,0.12)', zIndex: 50, width: 340 }}>
                {TEMPLATES.map((t) => (
                  <button
                    key={t.label}
                    onClick={() => { setMessage(t.text); setShowTemplates(false); textareaRef.current?.focus(); }}
                    style={{ width: '100%', textAlign: 'left', padding: '9px 14px', border: 'none', borderBottom: `1px solid ${C.bg}`, background: 'none', cursor: 'pointer', fontSize: '13px' }}
                  >
                    <span style={{ fontWeight: '600', color: C.blue, display: 'block' }}>{t.label}</span>
                    <span style={{ color: C.slate, fontSize: '12px', lineHeight: 1.4 }}>{t.text.slice(0, 70)}…</span>
                  </button>
                ))}
              </div>
            )}
          </div>

          <div style={{ display: 'flex', gap: '10px', alignItems: 'flex-end' }}>
            <textarea
              ref={textareaRef}
              rows={3}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              onKeyDown={handleKeyDown}
              disabled={!activeMemberId}
              placeholder={activeMemberId ? 'Type your reply… (Ctrl+Enter to send)' : 'Select a conversation first'}
              style={{ flex: 1, padding: '10px 12px', borderRadius: '10px', border: `1px solid ${C.border}`, fontSize: '13px', resize: 'vertical', fontFamily: 'inherit', outline: 'none' }}
            />
            <Button
              variant="primary"
              disabled={!activeMemberId || !message.trim() || replyMutation.isPending}
              onClick={handleSend}
            >
              <PaperAirplaneIcon style={{ width: 15, height: 15 }} />
              {replyMutation.isPending ? 'Sending…' : 'Send'}
            </Button>
          </div>
          <p style={{ margin: '4px 0 0', fontSize: '11px', color: '#94a3b8' }}>Ctrl+Enter to send quickly</p>
        </div>
      </div>
    </div>
  );
}

/* ── helper component ── */
function InfoRow({ label, value }) {
  return (
    <div style={{ marginBottom: '8px' }}>
      <p style={{ margin: 0, fontSize: '10px', fontWeight: '700', color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</p>
      <p style={{ margin: 0, fontSize: '12px', color: 'var(--text)', wordBreak: 'break-all' }}>{value || '—'}</p>
    </div>
  );
}
