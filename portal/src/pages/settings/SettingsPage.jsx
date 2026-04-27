import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { useAuth } from '../../context/AuthContext';
import { changePassword } from '../../api/auth';
import Button from '../../components/UI/Button';
import Input from '../../components/UI/Input';

export default function SettingsPage() {
  const { user } = useAuth();
  const [pwSection, setPwSection] = useState(false);

  const { register, handleSubmit, reset, watch, formState: { errors } } = useForm();

  const pwMutation = useMutation({
    mutationFn: changePassword,
    onSuccess: () => { toast.success('Password changed successfully'); reset(); setPwSection(false); },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to change password'),
  });

  const onPwSubmit = (data) => {
    if (data.new_password !== data.confirm_password) {
      return toast.error('Passwords do not match');
    }
    pwMutation.mutate({ current_password: data.current_password, new_password: data.new_password });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '720px' }}>
      {/* Admin Profile */}
      <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' }}>
        <h3 style={{ margin: '0 0 20px', fontSize: '16px', fontWeight: '600', color: 'var(--text)' }}>Admin Profile</h3>
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px', marginBottom: '24px' }}>
          <div style={{
            width: 72, height: 72, borderRadius: '50%',
            background: 'var(--primary)', color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: '26px', fontWeight: '700',
          }}>
            {user?.name?.[0] || user?.email?.[0]?.toUpperCase() || 'A'}
          </div>
          <div>
            <h4 style={{ margin: '0 0 4px', fontSize: '18px', fontWeight: '700', color: 'var(--text)' }}>
              {user?.name || 'Admin User'}
            </h4>
            <p style={{ margin: 0, color: '#64748b', fontSize: '14px' }}>{user?.email}</p>
            <span style={{
              display: 'inline-block', marginTop: '6px',
              background: '#dbeafe', color: '#1e40af',
              padding: '2px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: '600',
              textTransform: 'capitalize',
            }}>
              {user?.role || 'Administrator'}
            </span>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
          {[
            ['Full Name', user?.name || '—'],
            ['Email Address', user?.email || '—'],
            ['Role', user?.role || 'Administrator'],
            ['Last Login', user?.last_login ? new Date(user.last_login).toLocaleString() : '—'],
          ].map(([label, val]) => (
            <div key={label} style={{ padding: '12px', background: '#f8fafc', borderRadius: '8px' }}>
              <p style={{ margin: '0 0 4px', fontSize: '12px', color: '#64748b', fontWeight: '500', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{label}</p>
              <p style={{ margin: 0, fontSize: '14px', fontWeight: '500', color: 'var(--text)' }}>{val}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Change Password */}
      <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: pwSection ? '20px' : 0 }}>
          <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '600', color: 'var(--text)' }}>Change Password</h3>
          <Button variant="ghost" onClick={() => setPwSection(!pwSection)}>
            {pwSection ? 'Cancel' : 'Change Password'}
          </Button>
        </div>
        {pwSection && (
          <form onSubmit={handleSubmit(onPwSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '14px', maxWidth: '400px' }}>
            <Input
              label="Current Password"
              name="current_password"
              type="password"
              register={register}
              error={errors.current_password}
              placeholder="Enter current password"
            />
            <Input
              label="New Password"
              name="new_password"
              type="password"
              register={register}
              error={errors.new_password}
              placeholder="At least 8 characters"
            />
            <Input
              label="Confirm New Password"
              name="confirm_password"
              type="password"
              register={register}
              error={errors.confirm_password}
              placeholder="Repeat new password"
            />
            <div>
              <Button variant="primary" type="submit" disabled={pwMutation.isPending}>
                {pwMutation.isPending ? 'Saving…' : 'Update Password'}
              </Button>
            </div>
          </form>
        )}
      </div>

      {/* App Info */}
      <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' }}>
        <h3 style={{ margin: '0 0 16px', fontSize: '16px', fontWeight: '600', color: 'var(--text)' }}>System Information</h3>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', fontSize: '14px' }}>
          {[
            ['Application', 'Sanlam Chronic Care Admin Portal'],
            ['Version', '1.0.0'],
            ['API Base URL', import.meta.env.VITE_API_URL || '/api'],
            ['Environment', import.meta.env.MODE],
          ].map(([k, v]) => (
            <div key={k} style={{ padding: '10px 14px', background: '#f8fafc', borderRadius: '8px' }}>
              <p style={{ margin: '0 0 2px', fontSize: '11px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em', fontWeight: '600' }}>{k}</p>
              <p style={{ margin: 0, color: 'var(--text)', wordBreak: 'break-all' }}>{v}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
