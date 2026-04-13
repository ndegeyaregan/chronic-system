import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

const _kMedicationsBox = 'medications_cache';
const _kVitalsBox = 'vitals_cache';
const _kMedicationsKey = 'medications';
const _kVitalsKey = 'vitals';

/// Simple Hive-backed cache for offline access.
/// Stores JSON strings keyed by named constants.
class CacheService {
  static late Box<String> _medicationsBox;
  static late Box<String> _vitalsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _medicationsBox = await Hive.openBox<String>(_kMedicationsBox);
    _vitalsBox = await Hive.openBox<String>(_kVitalsBox);
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

  static Future<void> clearAll() async {
    await _medicationsBox.clear();
    await _vitalsBox.clear();
  }
}
