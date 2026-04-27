import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../providers/emergency_provider.dart';

class EmergencySosScreen extends ConsumerStatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  ConsumerState<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends ConsumerState<EmergencySosScreen>
    with SingleTickerProviderStateMixin {
  double _painLevel = 5;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _locatingGps = true;
  String? _gpsError;
  String _countryCode = 'UG'; // default to Uganda
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _red = Color(0xFFDC2626);
  static const _redDark = Color(0xFFB91C1C);
  static const _redLight = Color(0xFFFEE2E2);
  static const _text1 = Color(0xFF0D1117);
  static const _text2 = Color(0xFF6B7280);
  static const _card = Colors.white;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _detectLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _locatingGps = true;
      _gpsError = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _locatingGps = false;
          _gpsError = 'Location permission denied. Please enter address.';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locatingGps = false;
      });
      // Detect country from GPS coordinates
      _detectCountry(pos.latitude, pos.longitude);
    } catch (_) {
      setState(() {
        _locatingGps = false;
        _gpsError = 'Could not detect location. Please enter address.';
      });
    }
  }

  Future<void> _detectCountry(double lat, double lng) async {
    try {
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=3',
        options: Options(
          headers: {'User-Agent': 'SanlamChronicCare/1.0'},
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final cc = resp.data?['address']?['country_code']?.toString().toUpperCase();
      if (cc != null && cc.isNotEmpty && mounted) {
        setState(() => _countryCode = cc);
      }
    } catch (_) {
      // keep default
    }
  }

  List<Map<String, String>> _emergencyNumbers() {
    switch (_countryCode) {
      case 'UG':
        return [
          {'label': 'Uganda Ambulance', 'number': '911'},
          {'label': 'Uganda Police', 'number': '999'},
          {'label': 'Uganda Red Cross', 'number': '0800 100 250'},
          {'label': 'Fire Brigade', 'number': '0800 100 911'},
        ];
      case 'KE':
        return [
          {'label': 'Kenya Emergency', 'number': '999'},
          {'label': 'Kenya Ambulance', 'number': '0800 723 253'},
          {'label': 'Kenya Red Cross', 'number': '1199'},
          {'label': 'Police', 'number': '999'},
        ];
      case 'TZ':
        return [
          {'label': 'Tanzania Emergency', 'number': '114'},
          {'label': 'Tanzania Ambulance', 'number': '115'},
          {'label': 'Police', 'number': '112'},
          {'label': 'Fire Brigade', 'number': '114'},
        ];
      case 'RW':
        return [
          {'label': 'Rwanda Emergency', 'number': '112'},
          {'label': 'Rwanda Ambulance (SAMU)', 'number': '912'},
          {'label': 'Police', 'number': '112'},
          {'label': 'Fire Brigade', 'number': '111'},
        ];
      case 'ZA':
        return [
          {'label': 'South Africa Emergency', 'number': '10177'},
          {'label': 'ER24', 'number': '084 124'},
          {'label': 'Netcare 911', 'number': '082 911'},
          {'label': 'Police', 'number': '10111'},
        ];
      default:
        return [
          {'label': 'Emergency', 'number': '112'},
          {'label': 'Ambulance', 'number': '911'},
        ];
    }
  }

  String _countryLabel() {
    const names = {
      'UG': 'Uganda',
      'KE': 'Kenya',
      'TZ': 'Tanzania',
      'RW': 'Rwanda',
      'ZA': 'South Africa',
    };
    return names[_countryCode] ?? _countryCode;
  }

  String _painLabel(double value) {
    final v = value.round();
    if (v == 0) return 'No pain';
    if (v <= 2) return 'Mild';
    if (v <= 4) return 'Moderate';
    if (v <= 6) return 'Severe';
    if (v <= 8) return 'Very severe';
    return 'Worst possible';
  }

  Color _painColor(double value) {
    final v = value.round();
    if (v <= 2) return const Color(0xFF22C55E);
    if (v <= 4) return const Color(0xFFF59E0B);
    if (v <= 6) return const Color(0xFFF97316);
    if (v <= 8) return _red;
    return _redDark;
  }

  Future<void> _sendEmergency() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _redLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confirm Emergency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(
          'This will send an emergency ambulance request to our team.\n\n'
          'Pain level: ${_painLevel.round()}/10 (${_painLabel(_painLevel)})\n'
          '${_latitude != null ? 'GPS location detected.' : 'No GPS — address will be used.'}',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref.read(emergencyProvider.notifier).requestAmbulance(
          painLevel: _painLevel.round(),
          latitude: _latitude,
          longitude: _longitude,
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚑 Emergency request sent. Stay calm — help is coming.'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergency = ref.watch(emergencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        title: const Text('Emergency SOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Success state ───────────────────────────────
            if (emergency.submitted) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(kRadiusXl),
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E), size: 48),
                    ),
                    const SizedBox(height: 20),
                    const Text('Emergency Request Sent',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _text1)),
                    const SizedBox(height: 8),
                    const Text(
                      'Our emergency team has been notified.\nStay calm — help is on the way.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _text2, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(emergencyProvider.notifier).reset();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('New Request'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusMd)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── SOS Button ───────────────────────────────────
              ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: emergency.isSubmitting ? null : _sendEmergency,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _red.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: emergency.isSubmitting
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.emergency_rounded,
                                  color: Colors.white, size: 48),
                              SizedBox(height: 4),
                              Text('SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  )),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to request emergency help',
                style: TextStyle(
                    color: _text2, fontSize: 13, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 28),

              // ── Pain Level ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.thermostat_rounded,
                            color: _painColor(_painLevel), size: 22),
                        const SizedBox(width: 8),
                        const Text('Pain Level',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _text1)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _painColor(_painLevel)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(kRadiusFull),
                          ),
                          child: Text(
                            '${_painLevel.round()}/10 · ${_painLabel(_painLevel)}',
                            style: TextStyle(
                              color: _painColor(_painLevel),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: _painColor(_painLevel),
                        thumbColor: _painColor(_painLevel),
                        inactiveTrackColor:
                            _painColor(_painLevel).withValues(alpha: 0.2),
                        overlayColor:
                            _painColor(_painLevel).withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: _painLevel,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        onChanged: (v) => setState(() => _painLevel = v),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0 – No pain',
                            style: TextStyle(color: _text2, fontSize: 11)),
                        Text('10 – Worst',
                            style: TextStyle(color: _text2, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── GPS Location ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location_rounded,
                            color: _latitude != null
                                ? const Color(0xFF22C55E)
                                : _text2,
                            size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Your Location',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _text1)),
                        ),
                        if (_locatingGps)
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _red))
                        else
                          GestureDetector(
                            onTap: _detectLocation,
                            child: const Icon(Icons.refresh_rounded,
                                color: _text2, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_locatingGps)
                      const Text('Detecting GPS location…',
                          style: TextStyle(color: _text2, fontSize: 13))
                    else if (_gpsError != null)
                      Text(_gpsError!,
                          style: const TextStyle(
                              color: Color(0xFFF59E0B), fontSize: 13))
                    else
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF22C55E), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  color: _text1,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        hintText: 'Street address (optional but helpful)',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Notes ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.note_alt_outlined,
                            color: _text2, size: 22),
                        SizedBox(width: 8),
                        Text('Additional Notes',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _text1)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe your symptoms or situation…',
                      ),
                      maxLines: 3,
                      minLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Error banner ──────────────────────────────────
              if (emergency.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _redLight,
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: _red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(emergency.error!,
                            style:
                                const TextStyle(color: _red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // ── Full-width SOS button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: emergency.isSubmitting ? null : _sendEmergency,
                  icon: const Icon(Icons.emergency_rounded, size: 22),
                  label: Text(
                      emergency.isSubmitting ? 'Sending…' : 'Send Emergency SOS',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _red.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMd)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Emergency info ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(
                      color: const Color(0xFFFDE68A), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Text('Emergency Information — ${_countryLabel()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emergencyNumbers()
                          .map((e) => '• ${e['label']}: ${e['number']}')
                          .join('\n'),
                      style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          height: 1.6),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
