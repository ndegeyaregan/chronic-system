import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/appointment.dart';
import '../models/hospital.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class AppointmentsState {
  final List<Appointment> appointments;
  final List<Hospital> hospitals;
  final bool isLoading;
  final bool isSubmitting;
  final bool isOffline;
  final String? error;

  const AppointmentsState({
    this.appointments = const [],
    this.hospitals = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.isOffline = false,
    this.error,
  });

  AppointmentsState copyWith({
    List<Appointment>? appointments,
    List<Hospital>? hospitals,
    bool? isLoading,
    bool? isSubmitting,
    bool? isOffline,
    String? error,
    bool clearError = false,
  }) =>
      AppointmentsState(
        appointments: appointments ?? this.appointments,
        hospitals: hospitals ?? this.hospitals,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isOffline: isOffline ?? this.isOffline,
        error: clearError ? null : error,
      );

  List<Appointment> get upcoming => appointments
      .where((a) => a.isUpcoming)
      .toList()
    ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

  List<Appointment> get past => appointments
      .where((a) => a.isPast)
      .toList()
    ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
}

class AppointmentsNotifier extends StateNotifier<AppointmentsState> {
  AppointmentsNotifier() : super(const AppointmentsState()) {
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    state = state.copyWith(isLoading: true, clearError: true, isOffline: false);
    try {
      final response = await dio.get('/appointments/mine');
      final raw = response.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw as List);
      final list = items
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache for offline use
      await CacheService.saveAppointments(
        items.cast<Map<String, dynamic>>(),
      );

      state = AppointmentsState(appointments: list);
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      if (isNetworkError && CacheService.hasCachedAppointments) {
        final cached = CacheService.loadAppointments()!
            .map((e) => Appointment.fromJson(e))
            .toList();
        state = state.copyWith(
          appointments: cached,
          isLoading: false,
          isOffline: true,
          error: 'Offline — showing cached data.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: extractErrorMessage(e),
        );
      }
    }
  }

  Future<void> fetchHospitals({String? search}) async {
    try {
      final response = await dio.get('/hospitals',
          queryParameters: {if (search != null) 'name': search});
      final list = (response.data as List)
          .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(hospitals: list);
    } on DioException catch (_) {}
  }

  Future<bool> bookAppointment(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await dio.post('/appointments', data: data);
      final appt = Appointment.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = state.copyWith(
        appointments: [appt, ...state.appointments],
        isSubmitting: false,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: extractErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> cancelAppointment(String id) async {
    try {
      await dio.patch('/appointments/$id/cancel');
      _updateLocalStatus(id, AppointmentStatus.cancelled);
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
    }
  }

  Future<bool> confirmAttended(String id) async {
    try {
      await dio.patch('/appointments/$id/attended');
      _updateLocalStatus(id, AppointmentStatus.completed);
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  Future<bool> markMissed(String id, {String? reason}) async {
    try {
      await dio.patch('/appointments/$id/missed', data: {'reason': reason});
      _updateLocalStatus(id, AppointmentStatus.missed);
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  void _updateLocalStatus(String id, AppointmentStatus newStatus) {
    state = state.copyWith(
      appointments: state.appointments.map((a) {
        if (a.id == id) {
          return Appointment(
            id: a.id,
            hospitalId: a.hospitalId,
            hospitalName: a.hospitalName,
            hospitalCity: a.hospitalCity,
            condition: a.condition,
            appointmentDate: a.appointmentDate,
            preferredTime: a.preferredTime,
            reason: a.reason,
            status: newStatus,
            notes: a.notes,
          );
        }
        return a;
      }).toList(),
    );
  }
}

final appointmentsProvider =
    StateNotifierProvider<AppointmentsNotifier, AppointmentsState>((ref) {
  return AppointmentsNotifier();
});
