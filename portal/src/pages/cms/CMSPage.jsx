import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import {
  PlusIcon, PencilIcon, TrashIcon, GlobeAltIcon, EyeIcon,
  DocumentTextIcon, LightBulbIcon, VideoCameraIcon,
  ChartBarIcon, CheckCircleIcon, ClockIcon, ArrowDownTrayIcon,
  FunnelIcon, XMarkIcon,
} from '@heroicons/react/24/outline';
import { getContent, createContent, updateContent, deleteContent, publishContent } from '../../api/cms';
import { getConditions } from '../../api/conditions';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Select from '../../components/UI/Select';

/* ── helpers ── */
const fmtDate = (v) => v ? new Date(v).toLocaleDateString('en-ZA', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
const fmtNum  = (v) => Number(v ?? 0).toLocaleString();

const TYPE_META = {
  article: { label: 'Article', color: '#3b82f6', bg: '#eff6ff', Icon: DocumentTextIcon },
  tip:     { label: 'Tip',     color: '#10b981', bg: '#ecfdf5', Icon: LightBulbIcon },
  video:   { label: 'Video',   color: '#f59e0b', bg: '#fffbeb', Icon: VideoCameraIcon },
};

const TYPE_OPTIONS = [
  { value: 'article', label: 'Article' },
  { value: 'tip',     label: 'Tip' },
  { value: 'video',   label: 'Video' },
];

const card = {
  background: '#fff',
  borderRadius: '12px',
  padding: '18px 20px',
  boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
};

/* ── TypeChip ── */
function TypeChip({ type }) {
  const meta = TYPE_META[type] || { label: type, color: '#64748b', bg: '#f1f5f9', Icon: DocumentTextIcon };
  const { label, color, bg, Icon } = meta;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '12px', fontWeight: 600,
      color, background: bg, padding: '3px 8px', borderRadius: '20px', textTransform: 'capitalize' }}>
      <Icon style={{ width: 12, height: 12 }} />
      {label}
    </span>
  );
}

/* ── StatCard ── */
function StatCard({ label, value, sub, color = '#3b82f6', Icon }) {
  return (
    <div style={{ ...card, display: 'flex', alignItems: 'center', gap: '16px', flex: 1, minWidth: 160 }}>
      <div style={{ width: 44, height: 44, borderRadius: '10px', background: color + '1a',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {Icon && <Icon style={{ width: 22, height: 22, color }} />}
      </div>
      <div>
        <div style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a', lineHeight: 1.2 }}>{value}</div>
        <div style={{ fontSize: '13px', color: '#64748b', marginTop: '2px' }}>{label}</div>
        {sub && <div style={{ fontSize: '12px', color, marginTop: '2px' }}>{sub}</div>}
      </div>
    </div>
  );
}

/* ── PreviewModal ── */
function PreviewModal({ item, onClose }) {
  const tags = Array.isArray(item.tags) ? item.tags : (item.tags ? JSON.parse(item.tags) : []);
  return (
    <Modal title={`Preview — ${item.title}`} onClose={onClose} width="720px">
      <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          <TypeChip type={item.type} />
          {item.condition_name && (
            <span style={{ fontSize: '12px', background: '#f1f5f9', color: '#475569', padding: '3px 8px', borderRadius: '20px' }}>
              {item.condition_name}
            </span>
          )}
          <Badge status={item.published ? 'published' : 'draft'} label={item.published ? 'Published' : 'Draft'} />
          <span style={{ marginLeft: 'auto', fontSize: '12px', color: '#94a3b8' }}>
            {fmtNum(item.views)} views · Created {fmtDate(item.created_at)}
          </span>
        </div>

        {item.video_url && (
          <div style={{ borderRadius: '8px', overflow: 'hidden', background: '#000', aspectRatio: '16/9' }}>
            <iframe src={item.video_url} title="Video" style={{ width: '100%', height: '100%', border: 'none' }} allowFullScreen />
          </div>
        )}

        <div style={{ padding: '16px', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0',
          fontSize: '14px', color: '#334155', lineHeight: 1.7, whiteSpace: 'pre-wrap', minHeight: '120px' }}>
          {item.body || <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>No body content.</span>}
        </div>

        {tags.length > 0 && (
          <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
            {tags.map((t) => (
              <span key={t} style={{ fontSize: '11px', background: '#e0f2fe', color: '#0369a1',
                padding: '2px 8px', borderRadius: '20px' }}>#{t}</span>
            ))}
          </div>
        )}

        {item.scheduled_at && !item.published && (
          <div style={{ fontSize: '13px', color: '#f59e0b', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <ClockIcon style={{ width: 14, height: 14 }} />
            Scheduled to publish on {fmtDate(item.scheduled_at)}
          </div>
        )}
      </div>
    </Modal>
  );
}

/* ══════════════════════════════════════════════════════════════ */
export default function CMSPage() {
  const qc = useQueryClient();

  /* UI state */
  const [showModal,   setShowModal]   = useState(false);
  const [editing,     setEditing]     = useState(null);
  const [previewing,  setPreviewing]  = useState(null);
  const [search,      setSearch]      = useState('');
  const [filterType,  setFilterType]  = useState('');
  const [filterCond,  setFilterCond]  = useState('');
  const [filterPub,   setFilterPub]   = useState('');
  const [page,        setPage]        = useState(1);
  const PAGE_SIZE = 15;

  /* ── Data fetching ── */
  const { data: allItems = [], isLoading } = useQuery({
    queryKey: ['cms-content'],
    queryFn: () => getContent().then((r) => (Array.isArray(r.data) ? r.data : [])),
    retry: false,
  });

  const { data: conditions = [] } = useQuery({
    queryKey: ['conditions'],
    queryFn: () => getConditions().then((r) => (Array.isArray(r.data) ? r.data : [])),
    retry: false,
  });

  /* ── Derived stats ── */
  const stats = useMemo(() => {
    const published = allItems.filter((i) => i.published).length;
    const draft     = allItems.length - published;
    const totalViews = allItems.reduce((sum, i) => sum + Number(i.views ?? 0), 0);
    const byType = TYPE_OPTIONS.map(({ value, label }) => ({
      type: value, label, count: allItems.filter((i) => i.type === value).length,
    }));
    return { total: allItems.length, published, draft, totalViews, byType };
  }, [allItems]);

  /* ── Client-side filter + search ── */
  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return allItems.filter((i) => {
      if (filterType && i.type !== filterType) return false;
      if (filterCond && i.condition_id !== filterCond) return false;
      if (filterPub === 'published' && !i.published) return false;
      if (filterPub === 'draft'     &&  i.published) return false;
      if (q && !i.title.toLowerCase().includes(q) && !(i.body || '').toLowerCase().includes(q)) return false;
      return true;
    });
  }, [allItems, search, filterType, filterCond, filterPub]);

  const pages      = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const paginated  = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const hasFilters = search || filterType || filterCond || filterPub;

  const clearFilters = () => { setSearch(''); setFilterType(''); setFilterCond(''); setFilterPub(''); setPage(1); };

  /* ── Form ── */
  const { register, handleSubmit, reset, watch, formState: { errors } } = useForm();
  const watchType = watch('type');

  const openCreate = () => { setEditing(null); reset({ type: 'article', published: false }); setShowModal(true); };
  const openEdit   = (c) => {
    setEditing(c);
    const tags = Array.isArray(c.tags) ? c.tags.join(', ') : (c.tags || '');
    reset({
      title: c.title, type: c.type, body: c.body || '',
      video_url: c.video_url || '', condition_id: c.condition_id || '',
      category: c.category || '',
      tags, published: c.published,
      scheduled_at: c.scheduled_at?.split('T')[0] || '',
    });
    setShowModal(true);
  };

  /* ── Mutations ── */
  const invalidate = () => qc.invalidateQueries({ queryKey: ['cms-content'] });

  const saveMutation = useMutation({
    mutationFn: (raw) => {
      if (!raw.title?.trim()) throw new Error('Title is required');
      if (!raw.type)          throw new Error('Content type is required');
      const tagArray = raw.tags ? raw.tags.split(',').map((t) => t.trim()).filter(Boolean) : [];
      const payload = {
        ...raw,
        title:        raw.title.trim(),
        tags:         tagArray,
        condition_id: raw.condition_id || null,
        video_url:    raw.video_url    || null,
        scheduled_at: raw.scheduled_at || null,
        published:    !!raw.published,
      };
      return editing ? updateContent(editing.id, payload) : createContent(payload);
    },
    onSuccess: () => {
      invalidate();
      toast.success(editing ? 'Content updated!' : 'Content created!');
      setShowModal(false); setEditing(null); reset();
    },
    onError: (err) => toast.error(err?.response?.data?.message || err?.message || 'Failed to save content'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteContent,
    onSuccess: () => { invalidate(); toast.success('Content deleted'); },
    onError:  () => toast.error('Delete failed'),
  });

  const publishMutation = useMutation({
    mutationFn: publishContent,
    onSuccess: () => { invalidate(); toast.success('Content published!'); },
    onError:  () => toast.error('Publish failed'),
  });

  /* ── CSV export ── */
  const exportCSV = () => {
    const header = ['Title', 'Type', 'Condition', 'Published', 'Views', 'Scheduled', 'Created'];
    const rows = filtered.map((i) => [
      `"${(i.title || '').replace(/"/g, '""')}"`,
      i.type, i.condition_name || '', i.published, i.views ?? 0,
      i.scheduled_at ? fmtDate(i.scheduled_at) : '',
      fmtDate(i.created_at),
    ]);
    const csv = [header, ...rows].map((r) => r.join(',')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv]));
    a.download = `cms-content-${Date.now()}.csv`; a.click();
  };

  /* ── Table columns ── */
  const columns = [
    {
      key: 'title', header: 'Title',
      render: (v, row) => (
        <div>
          <div style={{ fontWeight: 600, fontSize: '14px', color: '#0f172a', maxWidth: '240px',
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{v}</div>
          {row.category && <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '2px' }}>{row.category}</div>}
        </div>
      ),
    },
    { key: 'type', header: 'Type', render: (v) => <TypeChip type={v} /> },
    { key: 'condition_name', header: 'Condition', render: (v) => v || <span style={{ color: '#cbd5e1' }}>—</span> },
    {
      key: 'published', header: 'Status',
      render: (v, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
          <Badge status={v ? 'active' : 'inactive'} label={v ? 'Published' : 'Draft'} />
          {row.scheduled_at && !v && (
            <span style={{ fontSize: '10px', color: '#f59e0b', display: 'flex', alignItems: 'center', gap: '3px' }}>
              <ClockIcon style={{ width: 10, height: 10 }} />
              {fmtDate(row.scheduled_at)}
            </span>
          )}
        </div>
      ),
    },
    { key: 'views', header: 'Views', render: (v) => <span style={{ fontWeight: 600 }}>{fmtNum(v)}</span> },
    { key: 'created_at', header: 'Created', render: (v) => <span style={{ fontSize: '12px', color: '#64748b' }}>{fmtDate(v)}</span> },
    {
      key: 'actions', header: '',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
          <Button variant="ghost" onClick={() => setPreviewing(row)}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <EyeIcon style={{ width: 12, height: 12 }} /> Preview
          </Button>
          <Button variant="ghost" onClick={() => openEdit(row)}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <PencilIcon style={{ width: 12, height: 12 }} /> Edit
          </Button>
          {!row.published && (
            <Button variant="success" onClick={() => publishMutation.mutate(row.id)}
              style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
              <GlobeAltIcon style={{ width: 12, height: 12 }} /> Publish
            </Button>
          )}
          <Button variant="danger"
            onClick={() => { if (window.confirm(`Delete "${row.title}"?`)) deleteMutation.mutate(row.id); }}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <TrashIcon style={{ width: 12, height: 12 }} /> Delete
          </Button>
        </div>
      ),
    },
  ];

  /* ══ RENDER ══ */
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

      {/* ── Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '12px', flexWrap: 'wrap' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>Content Management</h2>
          <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
            Manage health articles, tips, and videos for app members
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant="secondary" onClick={exportCSV}
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}>
            <ArrowDownTrayIcon style={{ width: 15, height: 15 }} /> Export CSV
          </Button>
          <Button variant="primary" onClick={openCreate}
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <PlusIcon style={{ width: 15, height: 15 }} /> New Content
          </Button>
        </div>
      </div>

      {/* ── Stat cards ── */}
      <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
        <StatCard label="Total Content"    value={fmtNum(stats.total)}      color="#3b82f6" Icon={DocumentTextIcon} />
        <StatCard label="Published"        value={fmtNum(stats.published)}   color="#10b981" Icon={CheckCircleIcon}
          sub={stats.total ? `${Math.round((stats.published / stats.total) * 100)}% of total` : ''} />
        <StatCard label="Drafts"           value={fmtNum(stats.draft)}       color="#f59e0b" Icon={ClockIcon} />
        <StatCard label="Total Views"      value={fmtNum(stats.totalViews)}  color="#64748b" Icon={ChartBarIcon} />
      </div>

      {/* ── Type breakdown ── */}
      <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
        {stats.byType.map(({ type, label, count }) => {
          const meta = TYPE_META[type] || { color: '#64748b', bg: '#f1f5f9', Icon: DocumentTextIcon };
          return (
            <div key={type} onClick={() => { setFilterType(filterType === type ? '' : type); setPage(1); }}
              style={{ ...card, display: 'flex', alignItems: 'center', gap: '12px', flex: 1, minWidth: 140,
                cursor: 'pointer', border: filterType === type ? `2px solid ${meta.color}` : '2px solid transparent',
                transition: 'border-color 0.15s' }}>
              <div style={{ width: 36, height: 36, borderRadius: '8px', background: meta.bg,
                display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <meta.Icon style={{ width: 18, height: 18, color: meta.color }} />
              </div>
              <div>
                <div style={{ fontWeight: 700, fontSize: '18px', color: '#0f172a' }}>{count}</div>
                <div style={{ fontSize: '12px', color: '#64748b' }}>{label}s</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* ── Filters ── */}
      <div style={{ ...card, padding: '14px 16px' }}>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          <FunnelIcon style={{ width: 16, height: 16, color: '#94a3b8', flexShrink: 0 }} />

          <input
            placeholder="Search title or body…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            style={{ flex: 2, minWidth: 180, padding: '7px 12px', borderRadius: '6px',
              border: '1px solid #e2e8f0', fontSize: '13px', outline: 'none' }}
          />

          <select value={filterType} onChange={(e) => { setFilterType(e.target.value); setPage(1); }}
            style={{ padding: '7px 10px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '13px', background: '#fff' }}>
            <option value="">All types</option>
            {TYPE_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>

          <select value={filterCond} onChange={(e) => { setFilterCond(e.target.value); setPage(1); }}
            style={{ padding: '7px 10px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '13px', background: '#fff' }}>
            <option value="">All conditions</option>
            {conditions.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>

          <select value={filterPub} onChange={(e) => { setFilterPub(e.target.value); setPage(1); }}
            style={{ padding: '7px 10px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '13px', background: '#fff' }}>
            <option value="">All statuses</option>
            <option value="published">Published</option>
            <option value="draft">Draft</option>
          </select>

          {hasFilters && (
            <button onClick={clearFilters}
              style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '7px 10px', borderRadius: '6px',
                border: '1px solid #fca5a5', background: '#fff', color: '#ef4444', fontSize: '13px', cursor: 'pointer' }}>
              <XMarkIcon style={{ width: 13, height: 13 }} /> Clear
            </button>
          )}

          <span style={{ marginLeft: 'auto', fontSize: '13px', color: '#94a3b8' }}>
            {filtered.length} result{filtered.length !== 1 ? 's' : ''}
          </span>
        </div>
      </div>

      {/* ── Table ── */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading
          ? <div style={{ padding: '60px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>
          : <Table columns={columns} data={paginated} emptyMessage="No content found." />
        }

        {/* Pagination */}
        {pages > 1 && (
          <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px', padding: '14px',
            borderTop: '1px solid #f1f5f9' }}>
            <button onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page === 1}
              style={{ padding: '5px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
                background: '#fff', cursor: page === 1 ? 'not-allowed' : 'pointer', opacity: page === 1 ? 0.4 : 1 }}>
              ‹ Prev
            </button>
            <span style={{ fontSize: '13px', color: '#64748b' }}>
              Page {page} of {pages}
            </span>
            <button onClick={() => setPage((p) => Math.min(pages, p + 1))} disabled={page === pages}
              style={{ padding: '5px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
                background: '#fff', cursor: page === pages ? 'not-allowed' : 'pointer', opacity: page === pages ? 0.4 : 1 }}>
              Next ›
            </button>
          </div>
        )}
      </div>

      {/* ── Preview modal ── */}
      {previewing && <PreviewModal item={previewing} onClose={() => setPreviewing(null)} />}

      {/* ── Create / Edit modal ── */}
      {showModal && (
        <Modal
          title={editing ? `Edit — ${editing.title}` : 'New Content'}
          onClose={() => { setShowModal(false); setEditing(null); reset(); }}
          width="760px"
        >
          <form onSubmit={handleSubmit((d) => saveMutation.mutate(d))}
            style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>

            <Input label="Title *" name="title"
              register={register} error={errors.title} placeholder="Enter a descriptive title" />

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
              <Select label="Content Type *" name="type" register={register}
                options={TYPE_OPTIONS} placeholder="Select type" error={errors.type} />
              <Select label="Condition" name="condition_id" register={register}
                options={conditions.map((c) => ({ value: c.id, label: c.name }))}
                placeholder="All conditions (general)" />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
              <Input label="Category" name="category" register={register}
                placeholder="e.g. Nutrition, Exercise, Mental Health" />
              <Input label="Tags (comma-separated)" name="tags" register={register}
                placeholder="diabetes, diet, tips" />
            </div>

            {/* Body */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>
                Body / Article Content {watchType !== 'video' ? '*' : ''}
              </label>
              <textarea
                {...register('body')}
                rows={8}
                placeholder="Write the full article, tip, or description here…"
                style={{ padding: '10px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
                  fontSize: '14px', resize: 'vertical', fontFamily: 'inherit', lineHeight: 1.6 }}
              />
            </div>

            {/* Video URL — shown for all, required for video type */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>
                Video / Embed URL {watchType === 'video' && <span style={{ color: '#ef4444' }}>*</span>}
              </label>
              <input
                {...register('video_url', watchType === 'video' ? { required: 'Video URL required for video type' } : {})}
                placeholder="https://www.youtube.com/embed/... or video URL"
                style={{ padding: '8px 12px', borderRadius: '6px', border: `1px solid ${errors.video_url ? '#ef4444' : '#e2e8f0'}`,
                  fontSize: '14px', fontFamily: 'inherit' }}
              />
              {errors.video_url && <span style={{ fontSize: '12px', color: '#ef4444' }}>{errors.video_url.message}</span>}
              <span style={{ fontSize: '11px', color: '#94a3b8' }}>
                For YouTube, use the embed URL (youtube.com/embed/VIDEO_ID)
              </span>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>Schedule Publish Date</label>
                <input type="date" {...register('scheduled_at')}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }} />
                <span style={{ fontSize: '11px', color: '#94a3b8' }}>Leave blank to save as draft</span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', gap: '12px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                  <input type="checkbox" {...register('published')}
                    style={{ width: 17, height: 17, cursor: 'pointer', accentColor: '#3b82f6' }} />
                  <span style={{ fontSize: '14px', fontWeight: 500, color: '#334155' }}>Publish immediately</span>
                </label>
                <span style={{ fontSize: '12px', color: '#94a3b8' }}>
                  Overrides schedule date if checked
                </span>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', paddingTop: '4px', borderTop: '1px solid #f1f5f9' }}>
              <Button variant="secondary" type="button"
                onClick={() => { setShowModal(false); setEditing(null); reset(); }}>
                Cancel
              </Button>
              <Button variant="primary" type="submit" disabled={saveMutation.isPending}
                style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                {saveMutation.isPending ? 'Saving…' : editing ? 'Save Changes' : 'Create Content'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
