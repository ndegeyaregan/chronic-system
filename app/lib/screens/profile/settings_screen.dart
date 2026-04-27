import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../providers/theme_provider.dart';

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
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Appearance', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                      color: kPrimary, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dark Mode',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium?.color)),
                        Text(
                            themeMode == ThemeMode.system
                                ? 'Follow system setting'
                                : themeMode == ThemeMode.dark
                                    ? 'Always dark'
                                    : 'Always light',
                            style: const TextStyle(fontSize: 11, color: kSubtext)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: themeMode == ThemeMode.dark,
                    activeColor: kPrimary,
                    onChanged: (v) => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _section('Channels', [
            _toggle(
              ref,
              icon: Icons.notifications_outlined,
              label: 'Push Notifications',
              subtitle: 'Receive alerts on your device',
              value: settings.pushEnabled,
              key: 'push_enabled',
            ),
            _toggle(
              ref,
              icon: Icons.email_outlined,
              label: 'Email Notifications',
              subtitle: 'Receive alerts via email',
              value: settings.emailEnabled,
              key: 'email_enabled',
            ),
            _toggle(
              ref,
              icon: Icons.sms_outlined,
              label: 'SMS Notifications',
              subtitle: 'Receive alerts via SMS',
              value: settings.smsEnabled,
              key: 'sms_enabled',
            ),
          ]),
          const SizedBox(height: 16),
          _section('Reminder Types', [
            _toggle(
              ref,
              icon: Icons.medication_outlined,
              label: 'Medication Reminders',
              subtitle: 'Daily dose reminders',
              value: settings.medicationReminders,
              key: 'medication_reminders',
            ),
            _toggle(
              ref,
              icon: Icons.calendar_today_outlined,
              label: 'Appointment Reminders',
              subtitle: '24h before appointments',
              value: settings.appointmentReminders,
              key: 'appointment_reminders',
            ),
            _toggle(
              ref,
              icon: Icons.monitor_heart_outlined,
              label: 'Vitals Check-in Reminders',
              subtitle: 'Daily reminder to log vitals',
              value: settings.vitalsReminders,
              key: 'vitals_reminders',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Builder(builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kSubtext,
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14, color: kText)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: kSubtext)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: kPrimary,
            onChanged: (v) =>
                ref.read(_settingsProvider.notifier).toggle(key, v),
          ),
        ],
      ),
    );
  }
}
