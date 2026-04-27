import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/vitals_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class _VitalWarning {
  final String message;
  final Color color;
  final IconData icon;
  const _VitalWarning({required this.message, required this.color, required this.icon});
}

class LogVitalsScreen extends ConsumerStatefulWidget {
  const LogVitalsScreen({super.key});

  @override
  ConsumerState<LogVitalsScreen> createState() => _LogVitalsScreenState();
}

class _LogVitalsScreenState extends ConsumerState<LogVitalsScreen> {
  final _bloodSugarCtrl = TextEditingController();
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _heartRateCtrl = TextEditingController();
  final _o2Ctrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _painDescCtrl = TextEditingController();

  double _painLevel = 0;
  String _mood = 'okay';

  final _moodOptions = ['great', 'good', 'okay', 'bad', 'terrible'];
  final _moodEmojis = {
    'great': '😄',
    'good': '🙂',
    'okay': '😐',
    'bad': '😕',
    'terrible': '😞',
  };
  final _moodColors = {
    'great':    Color(0xFF22C55E), // green
    'good':     Color(0xFF84CC16), // lime
    'okay':     Color(0xFFF59E0B), // amber
    'bad':      Color(0xFFF97316), // orange
    'terrible': Color(0xFFEF4444), // red
  };

  @override
  void dispose() {
    _bloodSugarCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _heartRateCtrl.dispose();
    _o2Ctrl.dispose();
    _notesCtrl.dispose();
    _painDescCtrl.dispose();
    super.dispose();
  }

  bool get _hasAnyValue =>
      _bloodSugarCtrl.text.isNotEmpty ||
      _systolicCtrl.text.isNotEmpty ||
      _weightCtrl.text.isNotEmpty ||
      _heartRateCtrl.text.isNotEmpty ||
      _o2Ctrl.text.isNotEmpty;

  /// Returns (category label, color) for a given BMI value.
  (String, Color) _bmiCategory(double bmi) {
    if (bmi < 18.5) return ('Underweight', const Color(0xFF3B82F6));
    if (bmi < 25.0) return ('Normal', const Color(0xFF22C55E));
    if (bmi < 30.0) return ('Overweight', const Color(0xFFF59E0B));
    return ('Obese', const Color(0xFFEF4444));
  }

  // Returns the most relevant condition name for use in warning messages.
  String _primaryConditionLabel(List<String> conds) {
    if (conds.any((c) => c.contains('hypertension'))) return 'hypertension';
    if (conds.any((c) => c.contains('high blood pressure'))) return 'high blood pressure';
    if (conds.any((c) => c.contains('heart'))) return 'heart condition';
    if (conds.any((c) => c.contains('stroke'))) return 'stroke history';
    if (conds.any((c) => c.contains('kidney') || c.contains('renal'))) return 'kidney condition';
    if (conds.any((c) => c.contains('copd'))) return 'COPD';
    if (conds.any((c) => c.contains('asthma'))) return 'asthma';
    return 'condition';
  }

  List<_VitalWarning> _getWarnings(List<String> conditions) {
    final warnings = <_VitalWarning>[];
    final conds = conditions.map((c) => c.toLowerCase()).toList();

    // Condition flags
    final hasHypertension = conds.any((c) =>
        c.contains('hypertension') || c.contains('high blood pressure') || c.contains('hbp'));
    final hasDiabetes = conds.any((c) =>
        c.contains('diabetes') || c.contains('diabetic'));
    final hasHeartDisease = conds.any((c) =>
        c.contains('heart') || c.contains('cardiac') || c.contains('coronary'));
    final hasCOPD = conds.any((c) =>
        c.contains('copd') || c.contains('asthma') || c.contains('lung') || c.contains('respiratory'));
    final hasKidney = conds.any((c) =>
        c.contains('kidney') || c.contains('renal'));
    final hasStroke = conds.any((c) =>
        c.contains('stroke') || c.contains('cerebro'));
    final isHighRiskBP = hasHypertension || hasHeartDisease || hasStroke || hasKidney;
    final condLabel = _primaryConditionLabel(conds);

    // ── Blood Sugar ────────────────────────────────────────────────
    final bs = double.tryParse(_bloodSugarCtrl.text);
    if (bs != null) {
      if (hasDiabetes) {
        if (bs < 4.0) {
          warnings.add(const _VitalWarning(
            message: '🔴 Hypoglycaemia: Blood sugar critically low (<4.0 mmol/L). As a diabetic, take fast-acting sugar (glucose tablets/juice) immediately and re-check in 15 minutes.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (bs > 11.1) {
          warnings.add(const _VitalWarning(
            message: '🔴 Severe Hyperglycaemia (>11.1 mmol/L): Blood sugar dangerously high. Check for ketones and contact your healthcare provider immediately.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (bs > 7.8) {
          warnings.add(const _VitalWarning(
            message: '🟡 Elevated Blood Sugar (7.8–11.1 mmol/L): Above your diabetes target range. Review recent meals and medication. Contact your doctor if this persists.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        }
      } else {
        if (bs < 3.9) {
          warnings.add(const _VitalWarning(
            message: '🔴 Hypoglycaemia: Blood sugar critically low (<3.9 mmol/L). Consume fast-acting sugar immediately.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (bs > 10.0) {
          warnings.add(const _VitalWarning(
            message: '🔴 Hyperglycaemia: Blood sugar very high (>10.0 mmol/L). Contact your healthcare provider.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (bs >= 7.8) {
          warnings.add(const _VitalWarning(
            message: '🟡 Elevated blood sugar (7.8–10.0 mmol/L). Monitor closely and consider dietary adjustments.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        }
      }
    }

    // ── Systolic BP ────────────────────────────────────────────────
    final sys = int.tryParse(_systolicCtrl.text);
    if (sys != null) {
      if (isHighRiskBP) {
        if (sys >= 160) {
          warnings.add(_VitalWarning(
            message: '🔴 Hypertensive Crisis: Systolic ${sys} mmHg. Given your $condLabel, this is a medical emergency — seek immediate care or call emergency services.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (sys >= 130) {
          warnings.add(_VitalWarning(
            message: '🟠 BP above target: Systolic ${sys} mmHg. With your $condLabel, the target is <130 mmHg. Take prescribed medication, rest, and contact your doctor if it stays elevated.',
            color: const Color(0xFFF97316),
            icon: Icons.info_outline_rounded,
          ));
        } else if (sys < 90) {
          warnings.add(const _VitalWarning(
            message: '🔴 Low BP: Systolic <90 mmHg. Sit or lie down, avoid sudden movements and stay hydrated. Contact your doctor.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        }
      } else {
        if (sys > 140) {
          warnings.add(const _VitalWarning(
            message: '🔴 High Blood Pressure: Systolic >140 mmHg. Rest and contact your doctor.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (sys > 120) {
          warnings.add(const _VitalWarning(
            message: '🟡 Elevated Systolic BP (120–140 mmHg). Monitor frequently and reduce salt intake.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        } else if (sys < 90) {
          warnings.add(const _VitalWarning(
            message: '🔴 Low Blood Pressure: Systolic <90 mmHg. Avoid sudden standing and stay hydrated.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        }
      }
    }

    // ── Diastolic BP ───────────────────────────────────────────────
    final dia = int.tryParse(_diastolicCtrl.text);
    if (dia != null) {
      if (isHighRiskBP) {
        if (dia > 90) {
          warnings.add(_VitalWarning(
            message: '🔴 High Diastolic BP (>90 mmHg): With your $condLabel this increases risk of complications. Contact your healthcare provider.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (dia > 80) {
          warnings.add(_VitalWarning(
            message: '🟡 Diastolic BP above target (>80 mmHg): For your $condLabel the target is ≤80 mmHg. Monitor and review your medication.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        } else if (dia < 60) {
          warnings.add(const _VitalWarning(
            message: '🔴 Low Diastolic BP (<60 mmHg). Monitor and consult your doctor if symptomatic.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        }
      } else {
        if (dia > 90) {
          warnings.add(const _VitalWarning(
            message: '🔴 High Diastolic BP (>90 mmHg). Contact your healthcare provider.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (dia < 60) {
          warnings.add(const _VitalWarning(
            message: '🔴 Low Diastolic BP (<60 mmHg). Monitor and consult your doctor if symptomatic.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        }
      }
    }

    // ── Heart Rate ─────────────────────────────────────────────────
    final hr = int.tryParse(_heartRateCtrl.text);
    if (hr != null) {
      if (hasHeartDisease) {
        if (hr > 100) {
          warnings.add(const _VitalWarning(
            message: '🔴 Tachycardia (>100 bpm): With your heart condition, this requires immediate attention. Rest and contact your cardiologist.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (hr > 90) {
          warnings.add(const _VitalWarning(
            message: '🟡 Elevated heart rate (>90 bpm): Slightly high for your heart condition. Avoid exertion and monitor closely.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        } else if (hr < 50) {
          warnings.add(const _VitalWarning(
            message: '🔴 Bradycardia (<50 bpm): Critically low heart rate given your heart condition. Seek medical attention immediately.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (hr < 60) {
          warnings.add(const _VitalWarning(
            message: '🟡 Low heart rate (<60 bpm): Monitor closely given your heart condition. Contact your doctor if you feel dizzy or faint.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        }
      } else {
        if (hr > 120) {
          warnings.add(const _VitalWarning(
            message: '🔴 Severe Tachycardia: Heart rate >120 bpm. Seek medical attention.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (hr > 100) {
          warnings.add(const _VitalWarning(
            message: '🟡 Tachycardia: Heart rate >100 bpm. Rest and monitor.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        } else if (hr < 60) {
          warnings.add(const _VitalWarning(
            message: '🟡 Bradycardia: Heart rate <60 bpm. Normal for athletes, otherwise consult your doctor.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        }
      }
    }

    // ── O₂ Saturation ─────────────────────────────────────────────
    final o2 = double.tryParse(_o2Ctrl.text);
    if (o2 != null) {
      if (hasCOPD) {
        if (o2 < 88) {
          warnings.add(const _VitalWarning(
            message: '🔴 Critical O₂ (<88%): Emergency for your respiratory condition. Use your rescue inhaler and call emergency services immediately.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (o2 < 92) {
          warnings.add(const _VitalWarning(
            message: '🟠 Low O₂ (88–92%): Below safe range for COPD/Asthma. Use your inhaler if prescribed, avoid exertion, and contact your doctor.',
            color: const Color(0xFFF97316),
            icon: Icons.warning_rounded,
          ));
        } else if (o2 < 95) {
          warnings.add(const _VitalWarning(
            message: '🟡 Slightly low O₂ (92–95%): Monitor closely given your respiratory condition. Ensure good ventilation and take prescribed medication.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        }
      } else {
        if (o2 < 94) {
          warnings.add(const _VitalWarning(
            message: '🔴 Low O₂ Saturation (<94%). Seek medical attention immediately.',
            color: kError,
            icon: Icons.warning_rounded,
          ));
        } else if (o2 < 97) {
          warnings.add(const _VitalWarning(
            message: '🟡 Slightly low O₂ Saturation (94–97%). Monitor and ensure adequate ventilation.',
            color: kWarning,
            icon: Icons.info_outline_rounded,
          ));
        }
      }
    }

    return warnings;
  }

  Future<void> _submit() async {
    if (!_hasAnyValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one vital reading.'),
          backgroundColor: kWarning,
        ),
      );
      return;
    }

    final data = <String, dynamic>{
      'pain_level': _painLevel.toInt(),
      'mood': _mood,
    };

    if (_bloodSugarCtrl.text.isNotEmpty) {
      data['blood_sugar_mmol'] = double.tryParse(_bloodSugarCtrl.text);
    }
    if (_systolicCtrl.text.isNotEmpty && _diastolicCtrl.text.isNotEmpty) {
      data['systolic_bp'] = int.tryParse(_systolicCtrl.text);
      data['diastolic_bp'] = int.tryParse(_diastolicCtrl.text);
    }
    if (_weightCtrl.text.isNotEmpty) {
      data['weight_kg'] = double.tryParse(_weightCtrl.text);
    }
    if (_heightCtrl.text.isNotEmpty) {
      data['height_cm'] = double.tryParse(_heightCtrl.text);
    }
    if (_heartRateCtrl.text.isNotEmpty) {
      data['heart_rate'] = int.tryParse(_heartRateCtrl.text);
    }
    if (_o2Ctrl.text.isNotEmpty) {
      data['o2_saturation'] = double.tryParse(_o2Ctrl.text);
    }
    if (_notesCtrl.text.isNotEmpty) {
      data['notes'] = _notesCtrl.text.trim();
    }

    final success = await ref.read(vitalsProvider.notifier).logVitals(data);
    if (!mounted) return;

    if (success) {
      // Fire a local notification if any vital is out of range
      final conditions = ref.read(memberProvider).member?.conditions ?? [];
      final warnings = _getWarnings(conditions);
      if (warnings.isNotEmpty) {
        final severe = warnings.any((w) => w.color == kError);
        NotificationService.show(
          id: 100,
          title: severe ? '🔴 Vitals Alert' : '⚠️ Vitals Warning',
          body: warnings.first.message.replaceAll(RegExp(r'^[🔴🟡🟠]\s*'), ''),
        );
      }

      final painLevel = _painLevel.toInt();

      if (painLevel >= 5) {
        // Report pain alert to backend (emails admin at sancare@ug.sanlamallianz.com)
        try {
          await dio.post('/alerts/pain', data: {
            'pain_level': painLevel,
            'description': _painDescCtrl.text.trim().isNotEmpty
                ? _painDescCtrl.text.trim()
                : null,
            'notes': 'Auto-reported from vitals log',
          });
        } catch (_) {}
      }

      if (painLevel >= 9) {
        // Critical — show emergency dialog
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('🚨 Critical Pain Level'),
            content: Text(
              'Your pain level is critical ($painLevel/10). Do you need emergency medical assistance?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('No, I\'m okay'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _requestAmbulance(painLevel);
                },
                style: ElevatedButton.styleFrom(backgroundColor: kError),
                child: const Text('Send Ambulance',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else if (painLevel >= 7) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ Our care team has been notified about your pain level.'),
            backgroundColor: kWarning,
          ),
        );
      }

      if (mounted && painLevel < 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vitals logged successfully!'),
            backgroundColor: kSuccess,
          ),
        );
        context.pop();
      }
    }
  }

  Future<void> _requestAmbulance(int painLevel) async {
    if (!mounted) return;
    try {
      Position? position;
      try {
        bool serviceEnabled =
            await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission =
              await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
          }
        }
      } catch (_) {}

      await dio.post('/emergency/ambulance', data: {
        'pain_level': painLevel,
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚑 Emergency request sent. Help is on the way!'),
            backgroundColor: kSuccess,
          ),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send emergency request. Please call emergency services directly.'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vitalsProvider);
    final conditions = ref.watch(memberProvider).member?.conditions ?? [];
    final warnings = _getWarnings(conditions);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(routeDashboard),
        ),
        title: const Text('Log Vitals'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard('Blood Glucose', [
              AppInput(
                label: 'Blood Sugar (mmol/L)',
                hint: 'e.g. 6.5',
                controller: _bloodSugarCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
            ], icon: Icons.water_drop_outlined, iconColor: const Color(0xFF3B82F6)),
            const SizedBox(height: 16),
            _sectionCard('Blood Pressure', [
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: 'Systolic (mmHg)',
                      hint: '120',
                      controller: _systolicCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      label: 'Diastolic (mmHg)',
                      hint: '80',
                      controller: _diastolicCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ], icon: Icons.monitor_heart_outlined, iconColor: kError),
            const SizedBox(height: 16),
            _sectionCard('Body Metrics', [
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: 'Weight (kg)',
                      hint: 'e.g. 72.5',
                      controller: _weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      label: 'Height (cm)',
                      hint: 'e.g. 170',
                      controller: _heightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              // Live BMI preview
              Builder(builder: (_) {
                final w = double.tryParse(_weightCtrl.text);
                final h = double.tryParse(_heightCtrl.text);
                if (w == null || h == null || h <= 0) return const SizedBox.shrink();
                final hm = h / 100.0;
                final bmi = w / (hm * hm);
                final (label, color) = _bmiCategory(bmi);
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate_rounded, color: color, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'BMI: ${bmi.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ], icon: Icons.monitor_weight_outlined, iconColor: kAccent),
            const SizedBox(height: 16),
            _sectionCard('Cardiovascular', [
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: 'Heart Rate (bpm)',
                      hint: '72',
                      controller: _heartRateCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      label: 'O₂ Saturation (%)',
                      hint: '98',
                      controller: _o2Ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ], icon: Icons.favorite_outline, iconColor: const Color(0xFFF97316)),
            const SizedBox(height: 16),
            _sectionCard('Pain Level', [
              StatefulBuilder(
                builder: (context, setLocal) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('No Pain', style: TextStyle(fontSize: 12, color: kSubtext)),
                        Text(
                          '${_painLevel.toInt()}/10',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _painLevel <= 3
                                ? kSuccess
                                : _painLevel <= 6
                                    ? kWarning
                                    : kError,
                          ),
                        ),
                        const Text('Severe', style: TextStyle(fontSize: 12, color: kSubtext)),
                      ],
                    ),
                    Slider(
                      value: _painLevel,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: _painLevel <= 3
                          ? kSuccess
                          : _painLevel <= 6
                              ? kWarning
                              : kError,
                      onChanged: (v) {
                        setLocal(() {});
                        setState(() => _painLevel = v);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                          11,
                          (i) => Text(
                                '$i',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: i == _painLevel.toInt()
                                      ? kPrimary
                                      : kSubtext,
                                  fontWeight: i == _painLevel.toInt()
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              )),
                    ),
                    // Pain description + emergency — shown when pain > 4
                    if (_painLevel > 4) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kError.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kError.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: kError, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Pain level above normal — our care team will be notified.',
                                  style: TextStyle(color: kError, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _painDescCtrl,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Please describe how you are feeling…',
                                hintStyle: TextStyle(color: kSubtext, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: kBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: kBorder),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '🚨 Emergency Contacts',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kText),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _emergencyCallButton('+256 753 115723', 'SOS 1'),
                                _emergencyCallButton('+256 783 970079', 'SOS 2'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ], icon: Icons.whatshot_outlined, iconColor: kError),
            const SizedBox(height: 16),
            _sectionCard('Mood Check-in', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moodOptions
                    .map((m) {
                      final mc = _moodColors[m] ?? kPrimary;
                      return GestureDetector(
                        onTap: () => setState(() => _mood = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _mood == m
                                ? mc
                                : mc.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _mood == m ? mc : mc.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _moodEmojis[m] ?? '😐',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                m[0].toUpperCase() + m.substring(1),
                                style: TextStyle(
                                  color: _mood == m ? Colors.white : mc,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ], icon: Icons.mood_outlined, iconColor: const Color(0xFFF97316)),
            // Mood activity recommendations for bad/terrible
            if (_mood == 'bad' || _mood == 'terrible') ...[
              const SizedBox(height: 12),
              _moodRecommendationsCard(_mood),
            ],
            const SizedBox(height: 16),
            AppInput(
              label: 'Notes (optional)',
              hint: 'Any additional observations...',
              controller: _notesCtrl,
              maxLines: 3,
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.health_and_safety_outlined, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conditions.isEmpty
                            ? 'Health alerts based on your readings:'
                            : 'Health alerts personalised to your saved conditions:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: w.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: w.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(w.icon, color: w.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.message,
                            style: TextStyle(
                              color: w.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(color: kError, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Save Vitals',
              onPressed: _submit,
              isLoading: state.isLoading,
              leadingIcon: Icons.save_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyCallButton(String number, String label) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kError,
              boxShadow: [
                BoxShadow(
                  color: kError.withOpacity(0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, color: Colors.white, size: 26),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              color: kError,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodRecommendationsCard(String mood) {
    final isTerrible = mood == 'terrible';
    final activities = isTerrible
        ? [
            ('🧘', 'Deep breathing', 'Inhale for 4s, hold 4s, exhale 4s — repeat 5 times'),
            ('🚶', 'Gentle walk', '5–10 minute slow walk in fresh air'),
            ('💧', 'Stay hydrated', 'Drink a glass of water right now'),
            ('📞', 'Reach out', 'Call a trusted friend or family member'),
            ('🎵', 'Calming music', 'Listen to soothing or favourite music'),
            ('🛏️', 'Rest', 'Lie down in a quiet room for 15 minutes'),
          ]
        : [
            ('🧘', 'Breathing exercise', 'Take 5 slow, deep breaths to reset your mind'),
            ('🚶', 'Light walk', '10–15 min walk can lift your mood significantly'),
            ('📖', 'Read or journal', 'Write down 3 things you are grateful for today'),
            ('☀️', 'Sunlight', 'Step outside for 10 minutes of natural light'),
            ('🤝', 'Connect', 'Send a message to someone who makes you smile'),
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFFF97316), size: 18),
              const SizedBox(width: 6),
              Text(
                isTerrible
                    ? "We're here for you - try these activities"
                    : 'Feeling down? These may help',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFFC05500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...activities.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: kText)),
                          Text(a.$3,
                              style: const TextStyle(
                                  fontSize: 12, color: kSubtext)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children,
      {IconData? icon, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (iconColor ?? kPrimary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon,
                      color: iconColor ?? kPrimary, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
