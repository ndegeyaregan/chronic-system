import 'package:flutter_test/flutter_test.dart';
import 'package:sanlam_chronic/models/medication.dart';
import 'package:sanlam_chronic/providers/medications_provider.dart';

Medication _med({
  String id = '1',
  String name = 'Metformin',
  bool isTakenToday = false,
  bool isSkippedToday = false,
}) =>
    Medication(
      id: id,
      name: name,
      dosage: '500mg',
      frequency: 'Twice daily',
      isTakenToday: isTakenToday,
      isSkippedToday: isSkippedToday,
    );

void main() {
  group('MedicationsState', () {
    test('initial state has empty medications and no error', () {
      const state = MedicationsState();
      expect(state.medications, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.isOffline, isFalse);
    });

    test('copyWith preserves existing values when nothing overridden', () {
      final med = _med();
      final state = MedicationsState(medications: [med], isLoading: false);
      final copied = state.copyWith();
      expect(copied.medications, [med]);
      expect(copied.isLoading, isFalse);
    });

    test('copyWith clears error when clearError=true', () {
      final state = MedicationsState(error: 'Network error');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('dueTodayMeds excludes taken and skipped medications', () {
      final due = _med(id: '1', isTakenToday: false, isSkippedToday: false);
      final taken = _med(id: '2', isTakenToday: true);
      final skipped = _med(id: '3', isSkippedToday: true);
      final state = MedicationsState(medications: [due, taken, skipped]);
      expect(state.dueTodayMeds, [due]);
    });

    test('dueTodayMeds returns empty when all meds are taken', () {
      final meds = [
        _med(id: '1', isTakenToday: true),
        _med(id: '2', isTakenToday: true),
      ];
      final state = MedicationsState(medications: meds);
      expect(state.dueTodayMeds, isEmpty);
    });

    test('isOffline flag is reflected in state', () {
      final state = MedicationsState(isOffline: true, error: 'Offline — showing cached data');
      expect(state.isOffline, isTrue);
      expect(state.error, contains('Offline'));
    });

    test('Medication.fromJson parses fields correctly', () {
      final json = {
        'id': 'abc-123',
        'name': 'Aspirin',
        'dosage': '100mg',
        'frequency': 'Once daily',
        'adherence_percent': '85.5',
        'is_taken_today': true,
        'is_skipped_today': false,
      };
      final med = Medication.fromJson(json);
      expect(med.id, 'abc-123');
      expect(med.name, 'Aspirin');
      expect(med.adherencePercent, 85.5);
      expect(med.isTakenToday, isTrue);
      expect(med.isSkippedToday, isFalse);
    });
  });
}
