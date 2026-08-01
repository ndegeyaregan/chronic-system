import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

final _settingsProvider =
    StateNotifierProvider<_SettingsNotifier, _SettingsState>(
        (ref) => _SettingsNotifier());

class _SettingsState {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool medicationReminders;
  final bool appointmentReminders;
  final bool vitalsReminders;

  const _SettingsState({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.medicationReminders = true,
    this.appointmentReminders = true,
    this.vitalsReminders = true,
  });

  _SettingsState copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? medicationReminders,
    bool? appointmentReminders,
    bool? vitalsReminders,
  }) =>
      _SettingsState(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        smsEnabled: smsEnabled ?? this.smsEnabled,
        medicationReminders: medicationReminders ?? this.medicationReminders,
        appointmentReminders:
            appointmentReminders ?? this.appointmentReminders,
        vitalsReminders: vitalsReminders ?? this.vitalsReminders,
      );
}

class _SettingsNotifier extends StateNotifier<_SettingsState> {
  _SettingsNotifier() : super(const _SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _SettingsState(
      pushEnabled: prefs.getBool('push_enabled') ?? true,
      emailEnabled: prefs.getBool('email_enabled') ?? true,
      smsEnabled: prefs.getBool('sms_enabled') ?? false,
      medicationReminders: prefs.getBool('medication_reminders') ?? true,
      appointmentReminders: prefs.getBool('appointment_reminders') ?? true,
      vitalsReminders: prefs.getBool('vitals_reminders') ?? true,
    );
  }

  Future<void> toggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    switch (key) {
      case 'push_enabled':
        state = state.copyWith(pushEnabled: value);
        break;
      case 'email_enabled':
        state = state.copyWith(emailEnabled: value);
        break;
      case 'sms_enabled':
        state = state.copyWith(smsEnabled: value);
        break;
      case 'medication_reminders':
        state = state.copyWith(medicationReminders: value);
        break;
      case 'appointment_reminders':
        state = state.copyWith(appointmentReminders: value);
        break;
      case 'vitals_reminders':
        state = state.copyWith(vitalsReminders: value);
        break;
    }
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, 'Appearance', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.light_mode_outlined, color: kPrimary, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display Mode',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: context.c.text)),
                        Text('Light mode',
                            style: TextStyle(fontSize: 11, color: context.c.subtext)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Channels', [
            _toggle(context, 
              ref,
              icon: Icons.notifications_outlined,
              label: 'Push Notifications',
              subtitle: 'Receive alerts on your device',
              value: settings.pushEnabled,
              key: 'push_enabled',
            ),
            _toggle(context, 
              ref,
              icon: Icons.email_outlined,
              label: 'Email Notifications',
              subtitle: 'Receive alerts via email',
              value: settings.emailEnabled,
              key: 'email_enabled',
            ),
            _toggle(context, 
              ref,
              icon: Icons.sms_outlined,
              label: 'SMS Notifications',
              subtitle: 'Receive alerts via SMS',
              value: settings.smsEnabled,
              key: 'sms_enabled',
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Reminder Types', [
            _toggle(context, 
              ref,
              icon: Icons.medication_outlined,
              label: 'Medication Reminders',
              subtitle: 'Daily dose reminders',
              value: settings.medicationReminders,
              key: 'medication_reminders',
            ),
            _toggle(context, 
              ref,
              icon: Icons.calendar_today_outlined,
              label: 'Appointment Reminders',
              subtitle: '24h before appointments',
              value: settings.appointmentReminders,
              key: 'appointment_reminders',
            ),
            _toggle(context, 
              ref,
              icon: Icons.monitor_heart_outlined,
              label: 'Vitals Check-in Reminders',
              subtitle: 'Daily reminder to log vitals',
              value: settings.vitalsReminders,
              key: 'vitals_reminders',
            ),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Diagnostics', [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.notifications_active_outlined,
                  color: kPrimary),
              title: const Text('Send test notification',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Verifies your phone can show SanCare+ system notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                try {
                  await NotificationService.show(
                    id: 999001,
                    title: '🔔 SanCare+ test notification',
                    body:
                        'If you can see this, push notifications are working on this device.',
                    payload: 'test',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Test notification sent — check your notification shade.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to show notification: $e'),
                        backgroundColor: kError,
                      ),
                    );
                  }
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Legal', [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.info_outline, color: kPrimary),
              title: const Text('Medical Disclaimer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('SanCare+ is not a medical device'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Medical Disclaimer'),
                  content: const Text(
                    kMedicalDisclaimerFull,
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.person_remove_outlined, color: kError),
              title: const Text('Delete My Account',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Permanently delete your account and data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete My Account'),
                    content: const Text(
                      'This permanently deletes your account and all '
                      'associated data. This cannot be undone.\n\n'
                      'Are you sure you want to continue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style:
                            ElevatedButton.styleFrom(backgroundColor: kError),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await ref.read(authProvider.notifier).deleteAccount();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete account. Please try again.'),
                      backgroundColor: kError,
                    ),
                  );
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Builder(builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.c.subtext,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: children
                  .asMap()
                  .entries
                  .map((e) => Column(
                        children: [
                          e.value,
                          if (e.key < children.length - 1)
                            const Divider(height: 1, indent: 56),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      );
    });
  }

  Widget _toggle(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required String key,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: kPrimary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14, color: context.c.text)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: context.c.subtext)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: kPrimary, activeTrackColor: kPrimary.withValues(alpha: 0.5),
            onChanged: (v) =>
                ref.read(_settingsProvider.notifier).toggle(key, v),
          ),
        ],
      ),
    );
  }
}
