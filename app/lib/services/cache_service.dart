import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

const _kMedicationsBox = 'medications_cache';
const _kVitalsBox = 'vitals_cache';
const _kAppointmentsBox = 'appointments_cache';
const _kCmsBox = 'cms_cache';
const _kMedicationsKey = 'medications';
const _kVitalsKey = 'vitals';
const _kAppointmentsKey = 'appointments';
const _kCmsKey = 'cms_content';

/// Simple Hive-backed cache for offline access.
/// Stores JSON strings keyed by named constants.
class CacheService {
  static late Box<String> _medicationsBox;
  static late Box<String> _vitalsBox;
  static late Box<String> _appointmentsBox;
  static late Box<String> _cmsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _medicationsBox = await Hive.openBox<String>(_kMedicationsBox);
    _vitalsBox = await Hive.openBox<String>(_kVitalsBox);
    _appointmentsBox = await Hive.openBox<String>(_kAppointmentsBox);
    _cmsBox = await Hive.openBox<String>(_kCmsBox);
  }

  // ── Medications ──────────────────────────────────────────────────────────

  static Future<void> saveMedications(List<Map<String, dynamic>> data) async {
    await _medicationsBox.put(_kMedicationsKey, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadMedications() {
    final raw = _medicationsBox.get(_kMedicationsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();
  }

  static bool get hasCachedMedications =>
      _medicationsBox.containsKey(_kMedicationsKey);

  // ── Vitals ───────────────────────────────────────────────────────────────

  static Future<void> saveVitals(List<Map<String, dynamic>> data) async {
    await _vitalsBox.put(_kVitalsKey, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadVitals() {
    final raw = _vitalsBox.get(_kVitalsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();
  }

  static bool get hasCachedVitals =>
      _vitalsBox.containsKey(_kVitalsKey);

  // ── Appointments ─────────────────────────────────────────────────────────

  static Future<void> saveAppointments(List<Map<String, dynamic>> data) async {
    await _appointmentsBox.put(_kAppointmentsKey, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadAppointments() {
    final raw = _appointmentsBox.get(_kAppointmentsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();
  }

  static bool get hasCachedAppointments =>
      _appointmentsBox.containsKey(_kAppointmentsKey);

  static Future<void> clearAll() async {
    await _medicationsBox.clear();
    await _vitalsBox.clear();
    await _appointmentsBox.clear();
    await _cmsBox.clear();
  }

  // ── CMS Content ───────────────────────────────────────────────────────

  static Future<void> saveCmsContent(List<Map<String, dynamic>> data) async {
    await _cmsBox.put(_kCmsKey, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadCmsContent() {
    final raw = _cmsBox.get(_kCmsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();
  }

  static bool get hasCachedCmsContent =>
      _cmsBox.containsKey(_kCmsKey);

  static Future<void> clearCmsCache() async {
    await _cmsBox.clear();
  }
}
