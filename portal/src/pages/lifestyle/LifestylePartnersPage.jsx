import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import { PlusIcon, PencilIcon, TrashIcon, VideoCameraIcon } from '@heroicons/react/24/outline';
import {
  getPartners, createPartner, updatePartner, deletePartner,
  getPartnerVideos, createPartnerVideo, updatePartnerVideo, deletePartnerVideo,
} from '../../api/lifestyle';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Select from '../../components/UI/Select';

const TABS = ['Gyms', 'Nutritionists', 'Counsellors'];
const TAB_TYPES = { Gyms: 'gym', Nutritionists: 'nutritionist', Counsellors: 'counsellor' };
const PROVINCES = ['Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape', 'Limpopo', 'Mpumalanga', 'North West', 'Free State', 'Northern Cape'];

// Extract video ID from YouTube URL or return as-is if already an ID
const extractVideoId = (input) => {
  if (!input) return '';
  
  // If it's already just an ID (11 chars, alphanumeric, dash, underscore)
  if (/^[a-zA-Z0-9_-]{11}$/.test(input)) {
    return input;
  }

  // Format: https://www.youtube.com/watch?v=dQw4w9WgXcQ
  if (input.includes('watch?v=')) {
    return input.split('watch?v=')[1].split('&')[0];
  }

  // Format: https://youtu.be/dQw4w9WgXcQ
  if (input.includes('youtu.be/')) {
    return input.split('youtu.be/')[1].split('?')[0];
  }

  // Return original if we can't extract
  return input;
};

export default function LifestylePartnersPage() {
  const qc = useQueryClient();
  const [activeTab, setActiveTab] = useState('Gyms');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const type = TAB_TYPES[activeTab];

  // Video management state
  const [videoPartner, setVideoPartner] = useState(null);
  const [showVideoModal, setShowVideoModal] = useState(false);
  const [showVideoForm, setShowVideoForm] = useState(false);
  const [editingVideo, setEditingVideo] = useState(null);
  const videoForm = useForm({
    mode: 'onBlur',
    defaultValues: {
      title: '',
      youtube_video_id: '',
      duration_label: '30 min',
      difficulty: 'Beginner',
      category: 'Strength',
    },
  });

  const { data, isLoading } = useQuery({
    queryKey: ['lifestyle-partners', type],
    queryFn: () => getPartners({ type }).then((r) => r.data),
    retry: false,
    placeholderData: [],
  });

  const { register, handleSubmit, reset, formState: { errors } } = useForm();

  const saveMutation = useMutation({
    mutationFn: (d) => editing ? updatePartner(editing.id, d) : createPartner({ ...d, type }),
    onSuccess: () => {
      qc.invalidateQueries(['lifestyle-partners']);
      toast.success(editing ? 'Partner updated' : 'Partner added');
      setShowModal(false); setEditing(null); reset();
    },
    onError: () => toast.error('Failed to save partner'),
  });

  const deleteMutation = useMutation({
    mutationFn: deletePartner,
    onSuccess: () => { qc.invalidateQueries(['lifestyle-partners']); toast.success('Partner removed'); },
    onError: () => toast.error('Delete failed'),
  });

  // Video queries/mutations
  const { data: videosData, isLoading: videosLoading, error: videosError } = useQuery({
    queryKey: ['partner-videos', videoPartner?.id],
    queryFn: async () => {
      console.log('📥 Fetching videos for partner:', videoPartner?.id);
      const response = await getPartnerVideos(videoPartner.id);
      console.log('✅ Videos fetched successfully:', response);
      return response;
    },
    enabled: showVideoModal && !!videoPartner?.id,
    retry: 1,
    placeholderData: [],
  });
  const videos = Array.isArray(videosData) ? videosData : [];

  if (videosError) {
    console.error('❌ Error loading videos:', videosError);
  }

  const saveVideoMutation = useMutation({
    mutationFn: (d) => {
      // Remove sort_order - backend will auto-assign it
      const { sort_order, ...cleanData } = d;
      console.log('📤 Sending video data to backend:', cleanData);
      console.log('   videoPartner.id:', videoPartner?.id);
      console.log('   editingVideo:', editingVideo);
      return editingVideo
        ? updatePartnerVideo(editingVideo.id, cleanData)
        : createPartnerVideo(videoPartner.id, cleanData);
    },
    onSuccess: () => {
      console.log('✅ Video saved successfully');
      qc.invalidateQueries(['partner-videos', videoPartner?.id]);
      toast.success(editingVideo ? 'Video updated' : 'Video added');
      setShowVideoForm(false);
      setEditingVideo(null);
      videoForm.reset();
    },
    onError: (error) => {
      console.error('❌ Save video error');
      console.error('   Full error:', error);
      console.error('   Response status:', error?.response?.status);
      console.error('   Response data:', error?.response?.data);
      console.error('   Message:', error?.message);
      
      const errorMsg = error?.response?.data?.message || error?.response?.data?.error?.detail || error?.message || 'Failed to save video';
      console.error('   Final error message:', errorMsg);
      
      toast.error(errorMsg);
    },
  });

  const deleteVideoMutation = useMutation({
    mutationFn: deletePartnerVideo,
    onSuccess: () => {
      qc.invalidateQueries(['partner-videos', videoPartner?.id]);
      toast.success('Video removed');
    },
    onError: () => toast.error('Failed to delete video'),
  });

  const openVideos = (partner) => {
    setVideoPartner(partner);
    setShowVideoModal(true);
    setShowVideoForm(false);
    setEditingVideo(null);
    videoForm.reset();
  };

  const openEditVideo = (video) => {
    setEditingVideo(video);
    videoForm.reset({
      title: video.title,
      youtube_video_id: video.youtube_video_id,
      duration_label: video.duration_label || '30 min',
      difficulty: video.difficulty || 'Beginner',
      category: video.category || 'Strength',
    });
    setShowVideoForm(true);
  };

  const openEdit = (p) => {
    setEditing(p);
    reset({ name: p.name, city: p.city, province: p.province, phone: p.phone, email: p.email, address: p.address, website: p.website });
    setShowModal(true);
  };

  const partners = Array.isArray(data) ? data : data?.partners || [];

  const columns = [
    { key: 'name', header: 'Name' },
    { key: 'city', header: 'City' },
    { key: 'province', header: 'Province' },
    { key: 'phone', header: 'Phone' },
    { key: 'email', header: 'Email' },
    {
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px' }}>
          {row.type === 'gym' && (
            <Button variant="ghost" onClick={() => openVideos(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <VideoCameraIcon style={{ width: 13, height: 13 }} /> Videos
            </Button>
          )}
          <Button variant="ghost" onClick={() => openEdit(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <PencilIcon style={{ width: 13, height: 13 }} /> Edit
          </Button>
          <Button variant="danger" onClick={() => { if (window.confirm('Remove this partner?')) deleteMutation.mutate(row.id); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <TrashIcon style={{ width: 13, height: 13 }} /> Delete
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Tabs */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        <div style={{ display: 'flex', borderBottom: '2px solid #f1f5f9', alignItems: 'center', justifyContent: 'space-between', paddingRight: '16px' }}>
          <div style={{ display: 'flex' }}>
            {TABS.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                style={{
                  padding: '13px 20px', background: 'none', border: 'none',
                  borderBottom: activeTab === tab ? '2px solid var(--primary)' : '2px solid transparent',
                  marginBottom: '-2px', cursor: 'pointer',
                  fontSize: '14px', fontWeight: activeTab === tab ? '600' : '400',
                  color: activeTab === tab ? 'var(--primary)' : '#64748b',
                }}
              >
                {tab}
              </button>
            ))}
          </div>
          <Button variant="primary" onClick={() => { setEditing(null); reset(); setShowModal(true); }} style={{ padding: '6px 12px', fontSize: '13px' }}>
            <PlusIcon style={{ width: 14, height: 14 }} /> Add {activeTab.slice(0, -1)}
          </Button>
        </div>
        <div style={{ padding: '0' }}>
          {isLoading ? <Spinner /> : <Table columns={columns} data={partners} emptyMessage={`No ${activeTab.toLowerCase()} found.`} />}
        </div>
      </div>

      {showModal && (
        <Modal title={`${editing ? 'Edit' : 'Add'} ${activeTab.slice(0, -1)}`} onClose={() => { setShowModal(false); setEditing(null); reset(); }}>
          <form onSubmit={handleSubmit((d) => saveMutation.mutate(d))} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Name *" name="name" register={register} error={errors.name} placeholder="Partner name" />
            </div>
            <Input label="City *" name="city" register={register} placeholder="e.g. Cape Town" />
            <Select label="Province" name="province" register={register} options={PROVINCES.map((p) => ({ value: p, label: p }))} placeholder="Select province" />
            <Input label="Phone" name="phone" register={register} placeholder="021 123 4567" />
            <Input label="Email" name="email" type="email" register={register} placeholder="info@partner.co.za" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Address" name="address" register={register} placeholder="Street address" />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Website" name="website" register={register} placeholder="https://partner.co.za" />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowModal(false); setEditing(null); reset(); }}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? 'Saving…' : editing ? 'Save Changes' : 'Add Partner'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Video Management Modal */}
      {showVideoModal && videoPartner && (
        <Modal
          title={`Manage Videos — ${videoPartner.name}`}
          onClose={() => { setShowVideoModal(false); setVideoPartner(null); setShowVideoForm(false); setEditingVideo(null); videoForm.reset(); }}
          width="780px"
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {/* Add / Edit Video Form */}
            {showVideoForm ? (
              <form
                onSubmit={videoForm.handleSubmit((d) => saveVideoMutation.mutate(d))}
                style={{
                  display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px',
                  background: '#f8fafc', borderRadius: '10px', padding: '16px',
                  border: '1px solid #e2e8f0',
                }}
              >
                <div style={{ gridColumn: '1 / -1', fontSize: '14px', fontWeight: 600, color: '#0f172a' }}>
                  {editingVideo ? 'Edit Video' : 'Add New Video'}
                </div>
                <div style={{ gridColumn: '1 / -1' }}>
                  <Input label="Title *" name="title" register={videoForm.register} error={videoForm.formState.errors.title} placeholder="e.g. 30-Min Full Body HIIT" />
                </div>
                <Input label="YouTube Video ID *" name="youtube_video_id" register={videoForm.register} error={videoForm.formState.errors.youtube_video_id} placeholder="e.g. dQw4w9WgXcQ" />
                <Input label="Duration" name="duration_label" register={videoForm.register} placeholder="e.g. 30 min" />
                <Select label="Difficulty" name="difficulty" register={videoForm.register} options={[
                  { value: 'Beginner', label: 'Beginner' },
                  { value: 'Intermediate', label: 'Intermediate' },
                  { value: 'Advanced', label: 'Advanced' },
                ]} />
                <Select label="Category" name="category" register={videoForm.register} options={[
                  { value: 'Cardio', label: 'Cardio' },
                  { value: 'Strength', label: 'Strength' },
                  { value: 'HIIT', label: 'HIIT' },
                  { value: 'Yoga', label: 'Yoga' },
                  { value: 'Stretching', label: 'Stretching' },
                  { value: 'Pilates', label: 'Pilates' },
                  { value: 'CrossFit', label: 'CrossFit' },
                  { value: 'Dance', label: 'Dance' },
                ]} />
                <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                  <Button variant="secondary" type="button" onClick={() => { setShowVideoForm(false); setEditingVideo(null); videoForm.reset(); }}>Cancel</Button>
                  <Button variant="primary" type="submit" disabled={saveVideoMutation.isPending}>
                    {saveVideoMutation.isPending ? 'Saving…' : editingVideo ? 'Save Changes' : 'Add Video'}
                  </Button>
                </div>
              </form>
            ) : (
              <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                <Button variant="primary" onClick={() => { setEditingVideo(null); videoForm.reset(); setShowVideoForm(true); }} style={{ padding: '6px 12px', fontSize: '13px' }}>
                  <PlusIcon style={{ width: 14, height: 14 }} /> Add Video
                </Button>
              </div>
            )}

            {/* Videos List */}
            {videosError && (
              <div style={{ background: '#fee2e2', border: '1px solid #fca5a5', borderRadius: '6px', padding: '12px', marginBottom: '12px', color: '#991b1b' }}>
                <strong>Error loading videos:</strong> {videosError?.message || 'Failed to load videos'}
              </div>
            )}
            {videosLoading ? (
              <Spinner />
            ) : videos.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '32px 16px', color: '#94a3b8', fontSize: '14px' }}>
                No videos yet. Add a YouTube video to get started.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {videos.map((v) => {
                  const videoId = extractVideoId(v.youtube_video_id);
                  return (
                    <div key={v.id} style={{
                      display: 'flex', alignItems: 'center', gap: '14px',
                      background: '#fff', borderRadius: '10px', padding: '12px 16px',
                      border: '1px solid #e2e8f0',
                    }}>
                      <a href={`https://www.youtube.com/watch?v=${videoId}`} target="_blank" rel="noreferrer"
                        style={{ flexShrink: 0 }}>
                        <img
                          src={`https://img.youtube.com/vi/${videoId}/mqdefault.jpg`}
                          alt={v.title}
                          style={{ width: 120, height: 68, objectFit: 'cover', borderRadius: '6px' }}
                        />
                      </a>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: 600, fontSize: '14px', color: '#0f172a', marginBottom: '4px' }}>{v.title}</div>
                        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', fontSize: '12px', color: '#64748b' }}>
                          <span style={{ background: '#f1f5f9', padding: '2px 8px', borderRadius: '4px' }}>{v.difficulty}</span>
                          <span style={{ background: '#f1f5f9', padding: '2px 8px', borderRadius: '4px' }}>{v.category}</span>
                          <span style={{ background: '#f1f5f9', padding: '2px 8px', borderRadius: '4px' }}>{v.duration_label}</span>
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: '6px', flexShrink: 0 }}>
                      <Button variant="ghost" onClick={() => openEditVideo(v)} style={{ padding: '4px 8px', fontSize: '12px' }}>
                        <PencilIcon style={{ width: 13, height: 13 }} /> Edit
                      </Button>
                      <Button variant="danger" onClick={() => { if (window.confirm('Remove this video?')) deleteVideoMutation.mutate(v.id); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
                        <TrashIcon style={{ width: 13, height: 13 }} /> Delete
                      </Button>
                    </div>
                  </div>
                    );
                })}
              </div>
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
