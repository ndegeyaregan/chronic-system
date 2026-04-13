import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medications_provider.dart';
import '../../providers/vitals_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../models/appointment.dart';
import '../../widgets/common/loading_shimmer.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _wellnessTip  = '';
  String _weatherLabel = '';   // e.g. "Sunny · 28°C"
  IconData _weatherIcon = Icons.wb_sunny_rounded;
  Color _weatherColor   = const Color(0xFFFF9500);
  bool _weatherLoaded   = false;

  static const _bg       = Color(0xFFF2F4F8);
  static const _card     = Colors.white;
  static const _text1    = Color(0xFF0D1117);
  static const _text2    = Color(0xFF6B7280);
  static const _blue     = Color(0xFF007AFF);
  static const _green    = Color(0xFF34C759);
  static const _orange   = Color(0xFFFF9500);
  static const _red      = Color(0xFFFF3B30);
  static const _teal     = Color(0xFF32ADE6);
  static const _divider  = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _wellnessTip = _tipForTimeOfDay();  // instant fallback
    _loadWeatherTip();                  // async — updates when ready
  }

  // ── Weather-aware tip loader ───────────────────────────────────────────────
  Future<void> _loadWeatherTip() async {
    try {
      // Request location permission (web uses browser geolocation)
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _applyTimeBasedTip(); return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 6));

      final resp = await Dio().get(
        'https://wttr.in/${pos.latitude},${pos.longitude}?format=%C+%t',
        options: Options(responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 6)),
      );

      final raw = resp.data.toString().trim();
      _applyWeatherTip(raw);
    } catch (_) {
      _applyTimeBasedTip();
    }
  }

  void _applyWeatherTip(String raw) {
    final hour = DateTime.now().hour;
    // Night/early morning: always use time-based tip, ignore weather
    if (hour >= 22 || hour < 5) {
      _applyTimeBasedTip(); return;
    }

    final lower = raw.toLowerCase();
    final tempMatch = RegExp(r'([+-]?\d+)').firstMatch(raw);
    final tempC = tempMatch != null ? int.tryParse(tempMatch.group(1)!) : null;

    String tip;
    IconData icon;
    Color color;

    if (lower.contains('rain') || lower.contains('shower') || lower.contains('drizzle')) {
      tip   = "Rainy day — stay indoors and do light stretching or yoga. Keep warm and dry!";
      icon  = Icons.water_rounded;
      color = _blue;
    } else if (lower.contains('thunder') || lower.contains('storm')) {
      tip   = "Storm outside — stay safe indoors. Try deep breathing to stay calm and relaxed.";
      icon  = Icons.thunderstorm_rounded;
      color = _red;
    } else if (lower.contains('fog') || lower.contains('mist')) {
      tip   = "Foggy conditions today — be careful if going out. Great time for indoor meditation.";
      icon  = Icons.cloud_rounded;
      color = _text2;
    } else if (lower.contains('cloud') || lower.contains('overcast')) {
      tip   = "Cloudy day — perfect for a light outdoor walk without overheating. Stay hydrated!";
      icon  = Icons.wb_cloudy_rounded;
      color = _teal;
    } else if (lower.contains('sun') || lower.contains('clear')) {
      if (tempC != null && tempC >= 30) {
        tip   = "It's hot outside (${tempC}°C)! Drink water every 30 min and avoid midday sun.";
        icon  = Icons.wb_sunny_rounded;
        color = _red;
      } else {
        tip   = "Beautiful sunny day! A 20-min walk in fresh air lowers blood sugar and lifts mood.";
        icon  = Icons.wb_sunny_rounded;
        color = _orange;
      }
    } else {
      tip   = _tipForTimeOfDay();
      icon  = Icons.cloud_outlined;
      color = _orange;
    }

    // Build display label
    final condPart = raw.replaceAll(RegExp(r'[+-]?\d+°?C'), '').trim();
    final label = tempC != null ? '$condPart · ${tempC > 0 ? '+' : ''}${tempC}°C' : condPart;

    if (mounted) {
      setState(() {
        _wellnessTip   = tip;
        _weatherLabel  = label;
        _weatherIcon   = icon;
        _weatherColor  = color;
        _weatherLoaded = true;
      });
    }
  }

  void _applyTimeBasedTip() {
    if (mounted) setState(() { _wellnessTip = _tipForTimeOfDay(); });
  }

  String _tipForTimeOfDay() {
    final h = DateTime.now().hour;
    if (h >= 5  && h < 9)  return 'Start your morning right — take medications, eat breakfast, and hydrate!';
    if (h >= 9  && h < 12) return 'Mid-morning tip: 5 minutes of deep breathing reduces stress and blood pressure.';
    if (h >= 12 && h < 14) return 'Lunchtime! Choose balanced meals with vegetables and lean protein for steady energy.';
    if (h >= 14 && h < 17) return 'Afternoon hydration check — have you had 6+ glasses of water today?';
    if (h >= 17 && h < 20) return 'Evening walk tip: 20 minutes after dinner can lower blood sugar significantly.';
    if (h >= 20 && h < 23) return 'Wind down for bed — limit screens 1 hour before sleep for better rest quality.';
    return 'Good sleep is vital — aim for 7–8 hours to support your immune system and heart.';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String? firstName, String? fullName) {
    if (fullName != null && fullName.trim().isNotEmpty) {
      final p = fullName.trim().split(' ');
      if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
      return fullName[0].toUpperCase();
    }
    return firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : 'M';
  }

  @override
  Widget build(BuildContext context) {
    final member    = ref.watch(authProvider).member;
    final medsState = ref.watch(medicationsProvider);
    final vitState  = ref.watch(vitalsProvider);
    final apptState = ref.watch(appointmentsProvider);
    final memberState = ref.watch(memberProvider);
    final conditions = memberState.member?.conditions ?? member?.conditions ?? [];

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: () async {
          await Future.wait([
            ref.read(medicationsProvider.notifier).fetchMedications(),
            ref.read(vitalsProvider.notifier).fetchVitals(),
            ref.read(appointmentsProvider.notifier).fetchAppointments(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // ─────────────────────────────────────────
            //  HEADER
            // ─────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: kPrimaryDark,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF001A5C), Color(0xFF003DA5)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                ),
                                child: Center(
                                  child: Text(_initials(member?.firstName, member?.fullName),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_greeting(), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                                    Text(member?.firstName ?? 'Member',
                                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go(routeNotifications),
                                child: Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.1),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 19),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Health ring row
                          Row(
                            children: [
                              // Ring
                              SizedBox(
                                width: 80, height: 80,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(size: const Size(80, 80),
                                      painter: _RingPainter(0.78,
                                        Colors.white.withValues(alpha: 0.15),
                                        Colors.white, strokeWidth: 6)),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('78', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
                                        Text('/100', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 8)),
                                        const SizedBox(height: 1),
                                        Text('Score', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 8, letterSpacing: 0.3)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              // Stats beside ring
                              Expanded(
                                child: Column(
                                  children: [
                                    _headerRow(Icons.calendar_today_outlined,
                                      DateFormat('EEE, d MMM y').format(DateTime.now())),
                                    const SizedBox(height: 8),
                                    _headerRow(Icons.shield_outlined,
                                      member?.planType ?? 'Standard Plan'),
                                    const SizedBox(height: 8),
                                    _headerRow(Icons.medication_outlined,
                                      medsState.dueTodayMeds.isEmpty
                                        ? 'All medications taken ✓'
                                        : '${medsState.dueTodayMeds.length} medication(s) due'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─────────────────────────────────────────
            //  BODY
            // ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HealthAnimationCard(),
                    const SizedBox(height: 20),
                    _HealthScoreCard(vitals: vitState, meds: medsState, conditions: conditions),
                    const SizedBox(height: 20),
                    _buildQuickActions(medsState),
                    const SizedBox(height: 24),
                    _buildVitals(vitState),
                    const SizedBox(height: 24),
                    _buildMedications(medsState),
                    const SizedBox(height: 24),
                    _buildAppointments(apptState),
                    const SizedBox(height: 24),
                    _buildWellnessTip(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 12),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(medsState) {
    final medsDue = medsState.dueTodayMeds.length;
    final actions = [
      _Action('Log Vitals',    Icons.monitor_heart_rounded,    _blue,                    routeLogVitals,      null),
      _Action('Medications',   Icons.medication_rounded,        _orange,                  routeMedications,    medsDue > 0 ? '$medsDue' : null),
      _Action('Appointments',  Icons.calendar_month_rounded,   _teal,                    routeAppointments,   null),
      _Action('Lifestyle',     Icons.self_improvement_rounded,  _green,                   routeLifestyle,      null),
      _Action('Treatment',     Icons.medical_services_rounded,  const Color(0xFF0284C7),  routeTreatment,      null),
      _Action('Lab Results',   Icons.science_rounded,           _red,                     routeLabResults,     null),
      _Action('Find Facility', Icons.local_hospital_rounded,    const Color(0xFF059669),  routeFacilityFinder, null),
      _Action('Learn',         Icons.menu_book_rounded,         const Color(0xFFD97706),  routeEducation,      null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Quick Actions'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 7,
          mainAxisSpacing: 7,
          childAspectRatio: 1.25,
          children: actions.map((a) => _actionTile(a)).toList(),
        ),
      ],
    );
  }

  Widget _actionTile(_Action a) {
    return GestureDetector(
      onTap: () => context.go(a.route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: a.color.withValues(alpha: 0.16), blurRadius: 8, offset: const Offset(0, 2)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: a.color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(a.icon, color: Colors.white, size: 15),
                ),
                if (a.badge != null)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _red, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(a.badge!, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                a.label,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _text1),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── VITALS ────────────────────────────────────────────────────────────────
  Widget _buildVitals(vitState) {
    final latest = vitState.latest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Recent Vitals'),
              _textBtn('Log now', _blue, () => context.go(routeLogVitals)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (vitState.isLoading)
          const LoadingStatCardRow()
        else if (latest == null)
          _emptyCard(icon: Icons.monitor_heart_outlined, color: _blue,
            title: 'No vitals recorded',
            sub: 'Tap to log your first reading',
            btnLabel: 'Log vitals',
            onTap: () => context.go(routeLogVitals))
        else
          SizedBox(
            height: 106,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (latest.bloodSugar != null)
                  _vitalTile('Blood Sugar', latest.bloodSugar!.toStringAsFixed(1), 'mmol/L',
                    Icons.water_drop_rounded, _blue,
                    latest.bloodSugar! > 10 || latest.bloodSugar! < 3.9),
                if (latest.systolicBP != null)
                  _vitalTile('Blood Pressure', '${latest.systolicBP}/${latest.diastolicBP}', 'mmHg',
                    Icons.monitor_heart_rounded, _red, latest.systolicBP! > 140),
                if (latest.heartRate != null)
                  _vitalTile('Heart Rate', '${latest.heartRate}', 'bpm',
                    Icons.favorite_rounded, _red,
                    latest.heartRate! > 100 || latest.heartRate! < 60),
                if (latest.weight != null)
                  _vitalTile('Weight', latest.weight!.toStringAsFixed(1), 'kg',
                    Icons.monitor_weight_rounded, _green, false),
              ],
            ),
          ),
      ],
    );
  }

  Widget _vitalTile(String label, String value, String unit, IconData icon, Color color, bool alert) {
    final c = alert ? _red : color;
    return Container(
      width: 136,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(alert ? Icons.warning_rounded : icon, color: c, size: 18),
              if (alert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('High', style: TextStyle(color: _red, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c, height: 1)),
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(unit, style: const TextStyle(fontSize: 10, color: _text2)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: _text2, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── MEDICATIONS ───────────────────────────────────────────────────────────
  Widget _buildMedications(medsState) {
    final due = medsState.dueTodayMeds;
    return _card_(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel("Today's Medications"),
              _textBtn('View all', _orange, () => context.go(routeMedications)),
            ],
          ),
          const SizedBox(height: 12),
          if (medsState.isLoading)
            const LoadingMedicationCard()
          else if (due.isEmpty)
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _green.withValues(alpha: 0.1)),
                  child: const Icon(Icons.check_circle_rounded, color: _green, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All done for today!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _text1)),
                      Text("Great job staying on track 🎉", style: TextStyle(fontSize: 12, color: _text2)),
                    ],
                  ),
                ),
              ],
            )
          else
            ...due.take(3).map((med) => _medRow(med, due.indexOf(med) < due.take(3).length - 1)),
        ],
      ),
    );
  }

  Widget _medRow(med, bool divider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _orange.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.medication_rounded, color: _orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _text1)),
                    Text('${med.dosage} · ${med.frequency}', style: const TextStyle(fontSize: 12, color: _text2)),
                  ],
                ),
              ),
              Row(
                children: [
                  _pillBtn('Take', _green, () => ref.read(medicationsProvider.notifier).logDose(med.id, 'taken')),
                  const SizedBox(width: 6),
                  _pillBtn('Skip', _text2, () => ref.read(medicationsProvider.notifier).logDose(med.id, 'skipped')),
                ],
              ),
            ],
          ),
        ),
        if (divider) Divider(height: 1, color: _divider),
      ],
    );
  }

  Widget _pillBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── APPOINTMENTS ──────────────────────────────────────────────────────────
  Widget _buildAppointments(apptState) {
    final upcoming = apptState.upcoming.take(2).toList();
    return _card_(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Upcoming Appointments'),
              _textBtn('Book', _teal, () => context.go(routeBookAppointment)),
            ],
          ),
          const SizedBox(height: 12),
          if (apptState.isLoading)
            const LoadingListCard(count: 2)
          else if (upcoming.isEmpty)
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _teal.withValues(alpha: 0.1)),
                  child: Icon(Icons.calendar_month_rounded, color: _teal.withValues(alpha: 0.7), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No upcoming appointments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _text1)),
                      GestureDetector(
                        onTap: () => context.go(routeBookAppointment),
                        child: Text('Tap to book one →', style: TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            ...List.generate(upcoming.length, (i) => _apptRow(upcoming[i], i < upcoming.length - 1)),
        ],
      ),
    );
  }

  Widget _apptRow(appt, bool divider) {
    final confirmed = appt.status == AppointmentStatus.confirmed;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _teal.withValues(alpha: 0.1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('dd').format(appt.appointmentDate),
                      style: const TextStyle(color: _teal, fontSize: 16, fontWeight: FontWeight.w800, height: 1)),
                    Text(DateFormat('MMM').format(appt.appointmentDate),
                      style: const TextStyle(color: _teal, fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appt.hospitalName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _text1)),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 11, color: _text2),
                        const SizedBox(width: 3),
                        Text(appt.preferredTime, style: const TextStyle(fontSize: 12, color: _text2)),
                        const Text('  ·  ', style: TextStyle(fontSize: 12, color: _text2)),
                        Expanded(child: Text(appt.condition, style: const TextStyle(fontSize: 12, color: _text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (confirmed ? _green : _orange).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  confirmed ? 'Confirmed' : 'Pending',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: confirmed ? _green : _orange),
                ),
              ),
            ],
          ),
        ),
        if (divider) Divider(height: 1, color: _divider),
      ],
    );
  }

  // ── WELLNESS TIP ──────────────────────────────────────────────────────────
  Widget _buildWellnessTip() {
    return _card_(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _weatherColor.withValues(alpha: 0.1)),
                child: Icon(_weatherIcon, color: _weatherColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wellness Tip of the Day',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text1)),
                    if (_weatherLoaded && _weatherLabel.isNotEmpty)
                      Text(_weatherLabel,
                        style: TextStyle(fontSize: 11, color: _weatherColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (!_weatherLoaded)
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _orange.withValues(alpha: 0.5)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_wellnessTip, style: const TextStyle(fontSize: 13, color: _text2, height: 1.5)),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _card_({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text1, letterSpacing: -0.2));
  }

  Widget _textBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _emptyCard({required IconData icon, required Color color, required String title, required String sub, required String btnLabel, required VoidCallback onTap}) {
    return _card_(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
            child: Icon(icon, color: color.withValues(alpha: 0.6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _text1)),
                Text(sub, style: const TextStyle(fontSize: 12, color: _text2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(btnLabel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────
class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;
  const _Action(this.label, this.icon, this.color, this.route, this.badge);
}

// ── Health Score Computation ──────────────────────────────────────────────────
double _computeHealthScore(VitalsState vitals, MedicationsState meds, List<String> conditions) {
  double score = 50.0;

  final latest = vitals.latest;
  if (latest != null) {
    final hasHypertension = conditions.any((c) =>
        c.toLowerCase().contains('hypertension') ||
        c.toLowerCase().contains('high blood pressure'));
    final hasDiabetes = conditions.any((c) => c.toLowerCase().contains('diabetes'));

    if (latest.systolicBP != null) {
      final sys = latest.systolicBP!;
      final target = hasHypertension ? 130 : 140;
      if (sys <= target) { score += 8; }
      else if (sys <= target + 20) { score += 4; }
    }

    if (latest.bloodSugar != null) {
      final bs = latest.bloodSugar!;
      if (hasDiabetes) {
        if (bs >= 4 && bs <= 7.8) { score += 8; }
        else if (bs < 10) { score += 4; }
      } else {
        if (bs >= 3.9 && bs <= 7.8) { score += 8; }
        else if (bs < 10) { score += 4; }
      }
    }

    if (latest.heartRate != null) {
      final hr = latest.heartRate!;
      if (hr >= 60 && hr <= 100) { score += 5; }
      else if (hr >= 50 && hr <= 110) { score += 2; }
    }

    if (latest.oxygenSaturation != null) {
      if (latest.oxygenSaturation! >= 97) { score += 4; }
      else if (latest.oxygenSaturation! >= 94) { score += 2; }
    }
  }

  if (meds.medications.isNotEmpty) {
    final avgAdherence = meds.medications
        .map((m) => m.adherencePercent)
        .reduce((a, b) => a + b) / meds.medications.length;
    score += (avgAdherence / 100) * 25;
  }

  return score.clamp(0, 100);
}

// ── Health Score Card ─────────────────────────────────────────────────────────
class _HealthScoreCard extends StatefulWidget {
  final VitalsState vitals;
  final MedicationsState meds;
  final List<String> conditions;

  const _HealthScoreCard({
    required this.vitals,
    required this.meds,
    required this.conditions,
  });

  @override
  State<_HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<_HealthScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    final score = _computeHealthScore(
        widget.vitals, widget.meds, widget.conditions);
    _anim = Tween<double>(begin: 0, end: score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _computeHealthScore(
        widget.vitals, widget.meds, widget.conditions);

    final Color scoreColor = score >= 75
        ? const Color(0xFF10B981)
        : score >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final String message = score >= 75
        ? 'Great progress! Keep logging your vitals daily.'
        : score >= 50
            ? 'Good effort — improve your medication adherence and log vitals more often.'
            : 'Your health score needs attention. Log vitals and take medications consistently.';

    // Breakdown components
    final vitalsScore = widget.vitals.latest != null ? 25.0 : 0.0;
    final medScore = widget.meds.medications.isNotEmpty
        ? (widget.meds.medications
                    .map((m) => m.adherencePercent)
                    .reduce((a, b) => a + b) /
                widget.meds.medications.length)
            .clamp(0.0, 100.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001A5C), Color(0xFF003DA5)],
        ),
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated ring gauge
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(90, 90),
                        painter: _RingPainter(
                          _anim.value,
                          Colors.white.withValues(alpha: 0.15),
                          scoreColor,
                          strokeWidth: 7,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(_anim.value * 100).toInt()}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1)),
                          Text('/100',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9)),
                          const SizedBox(height: 1),
                          Text('Score',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 9,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Health Score',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    _barRow('Vitals', vitalsScore / 25, Colors.white),
                    const SizedBox(height: 6),
                    _barRow('Medication', medScore / 100, scoreColor),
                    const SizedBox(height: 6),
                    _barRow('Logging', widget.vitals.vitals.isNotEmpty ? 1.0 : 0.2,
                        const Color(0xFF32ADE6)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  score >= 75
                      ? Icons.emoji_events_rounded
                      : score >= 50
                          ? Icons.trending_up_rounded
                          : Icons.warning_amber_rounded,
                  color: scoreColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${(value * 100).toInt()}%',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;
  const _RingPainter(this.progress, this.trackColor, this.fillColor, {this.strokeWidth = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - strokeWidth / 2;
    final base = Paint()..color = trackColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fill = Paint()..color = fillColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi, false, base);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}

// ── Health Animation Card ─────────────────────────────────────────────────────
class _HealthAnimationCard extends StatefulWidget {
  const _HealthAnimationCard();
  @override
  State<_HealthAnimationCard> createState() => _HealthAnimationCardState();
}

class _HealthAnimationCardState extends State<_HealthAnimationCard> with TickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late AnimationController _ecgCtrl;
  late AnimationController _bubbleCtrl;
  late Animation<double> _heartScale;
  late Animation<double> _ecgProgress;
  late Animation<double> _bubbleY;
  late Animation<double> _bubbleOpacity;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _ecgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _bubbleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _heartScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.easeInOut));
    _ecgProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ecgCtrl, curve: Curves.linear));
    _bubbleY = Tween<double>(begin: 0.0, end: -30.0).animate(
      CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeInOut));
    _bubbleOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _ecgCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E9), Color(0xFFE3F2FD)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Left: animated heart + rings
          SizedBox(
            width: 80, height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _heartCtrl,
                  builder: (_, __) => Container(
                    width: 60 + (_heartScale.value - 1) * 40,
                    height: 60 + (_heartScale.value - 1) * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF3B30).withValues(alpha: (1 - (_heartScale.value - 1) * 4).clamp(0.0, 0.12)),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _heartCtrl,
                  builder: (_, __) => Container(
                    width: 48 + (_heartScale.value - 1) * 20,
                    height: 48 + (_heartScale.value - 1) * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _heartScale,
                  builder: (_, __) => Transform.scale(
                    scale: _heartScale.value,
                    child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF3B30), size: 34),
                  ),
                ),
                AnimatedBuilder(
                  animation: _bubbleCtrl,
                  builder: (_, __) => Positioned(
                    top: 10 + _bubbleY.value,
                    right: 8,
                    child: Opacity(
                      opacity: _bubbleOpacity.value,
                      child: const Icon(Icons.add, color: Color(0xFF34C759), size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Middle: text + ECG line
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stay Healthy Today!',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0D1117), letterSpacing: -0.3)),
                const SizedBox(height: 4),
                const Text('Track vitals & keep moving.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 30,
                  child: AnimatedBuilder(
                    animation: _ecgProgress,
                    builder: (_, __) => CustomPaint(
                      size: const Size(double.infinity, 30),
                      painter: _EcgPainter(_ecgProgress.value),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Color(0xFFFF3B30), size: 11),
                    const SizedBox(width: 4),
                    const Text('Live pulse', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: activity bubbles
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bubble(Icons.directions_run_rounded, const Color(0xFF34C759)),
              const SizedBox(height: 10),
              _bubble(Icons.water_drop_rounded, const Color(0xFF007AFF)),
              const SizedBox(height: 10),
              _bubble(Icons.nightlight_round, const Color(0xFF32ADE6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(IconData icon, Color color) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
    child: Icon(icon, color: color, size: 16),
  );
}

// ── ECG painter ───────────────────────────────────────────────────────────────
class _EcgPainter extends CustomPainter {
  final double progress;
  const _EcgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final mid = size.height / 2;
    final drawTo = w * progress;

    final pts = [
      Offset(0, mid),
      Offset(w * 0.10, mid),
      Offset(w * 0.15, mid - 3),
      Offset(w * 0.20, mid),
      Offset(w * 0.25, mid),
      Offset(w * 0.28, mid + 4),
      Offset(w * 0.32, mid - size.height * 0.85),
      Offset(w * 0.36, mid + 5),
      Offset(w * 0.40, mid),
      Offset(w * 0.45, mid - 6),
      Offset(w * 0.52, mid),
      Offset(w * 0.60, mid),
      Offset(w * 0.65, mid - 3),
      Offset(w * 0.70, mid),
      Offset(w * 0.75, mid),
      Offset(w * 0.78, mid + 4),
      Offset(w * 0.82, mid - size.height * 0.85),
      Offset(w * 0.86, mid + 5),
      Offset(w * 0.90, mid),
      Offset(w * 0.95, mid - 6),
      Offset(w, mid),
    ];

    final path = Path();
    bool started = false;
    for (int i = 0; i < pts.length; i++) {
      if (pts[i].dx > drawTo) break;
      if (!started) { path.moveTo(pts[i].dx, pts[i].dy); started = true; }
      else { path.lineTo(pts[i].dx, pts[i].dy); }
    }
    if (started) {
      for (int i = 1; i < pts.length; i++) {
        if (pts[i].dx > drawTo && pts[i-1].dx <= drawTo) {
          final t = (drawTo - pts[i-1].dx) / (pts[i].dx - pts[i-1].dx);
          path.lineTo(drawTo, pts[i-1].dy + (pts[i].dy - pts[i-1].dy) * t);
          break;
        }
      }
    }
    canvas.drawPath(path, paint);

    if (drawTo > 0 && drawTo < w) {
      canvas.drawCircle(Offset(drawTo, mid), 5,
        Paint()..color = const Color(0xFFFF3B30).withValues(alpha: 0.3));
      canvas.drawCircle(Offset(drawTo, mid), 2.5,
        Paint()..color = const Color(0xFFFF3B30));
    }
  }

  @override
  bool shouldRepaint(_EcgPainter o) => o.progress != progress;
}
