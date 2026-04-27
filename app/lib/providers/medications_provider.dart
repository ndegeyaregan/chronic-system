import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/medication.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../widgets/common/media_attachment_widget.dart';

class MedicationsState {
  final List<Medication> medications;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  const MedicationsState({
    this.medications = const [],
    this.isLoading = false,
    this.error,
    this.isOffline = false,
  });

  MedicationsState copyWith({
    List<Medication>? medications,
    bool? isLoading,
    String? error,
    bool? isOffline,
    bool clearError = false,
  }) =>
      MedicationsState(
        medications: medications ?? this.medications,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error,
        isOffline: isOffline ?? this.isOffline,
      );

  List<Medication> get dueTodayMeds =>
      medications.where((m) => !m.isTakenToday && !m.isSkippedToday && !m.isCompleted).toList();

  List<Medication> get currentMeds =>
      medications.where((m) => !m.isCompleted).toList();

  List<Medication> get historyMeds =>
      medications.where((m) => m.isCompleted).toList();
}

class MedicationsNotifier extends StateNotifier<MedicationsState> {
  MedicationsNotifier() : super(const MedicationsState()) {
    fetchMedications();
  }

  Future<void> fetchMedications() async {
    state = state.copyWith(isLoading: true, clearError: true, isOffline: false);
    try {
      final response = await dio.get('/medications/member/mine');
      final meds = (response.data as List)
          .map((e) => Medication.fromJson(e as Map<String, dynamic>))
          .toList();
      // Save to cache for offline use
      await CacheService.saveMedications(
        meds.map((m) => m.toJson()).toList(),
      );
      state = MedicationsState(medications: meds);
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      if (isNetworkError && CacheService.hasCachedMedications) {
        final cached = CacheService.loadMedications()!
            .map((j) => Medication.fromJson(j))
            .toList();
        state = MedicationsState(
          medications: cached,
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

  Future<bool> logDose(String medicationId, String status) async {
    try {
      await dio.post('/medications/member/log',
          data: {'member_medication_id': medicationId, 'status': status});
      state = state.copyWith(
        medications: state.medications.map((m) {
          if (m.id == medicationId) {
            return m.copyWith(
              isTakenToday: status == 'taken',
              isSkippedToday: status == 'skipped',
            );
          }
          return m;
        }).toList(),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> addMedication(
    Map<String, dynamic> data, {
    String? startTime,
    String? prescriptionPath,
    MediaAttachmentController? media,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (startTime != null) data['start_time'] = startTime;

      // Build multipart form if any files are present
      final hasFiles = prescriptionPath != null ||
          (media?.hasPhoto ?? false) ||
          (media?.hasAudio ?? false) ||
          (media?.hasVideo ?? false);

      final Response response;
      if (hasFiles) {
        final fields = Map<String, dynamic>.from(data);

        if (prescriptionPath != null) {
          if (kIsWeb) {
            // On web, prescriptionPath is unused — file is in photo field
          } else {
            fields['prescription'] =
                await MultipartFile.fromFile(prescriptionPath);
          }
        }

        if (media != null) {
          if (media.hasPhoto) {
            final bytes = await media.photo!.readAsBytes();
            final name = media.photo!.name;
            fields['photo'] = MultipartFile.fromBytes(bytes, filename: name);
          }
          if (media.hasAudio && media.audioPath != null) {
            if (!kIsWeb) {
              fields['audio'] = await MultipartFile.fromFile(media.audioPath!,
                  filename: 'audio_note.m4a');
            }
            // On web, blob URLs can't be re-read as bytes; skip upload
          }
          if (media.hasVideo) {
            if (kIsWeb && media.videoPlatformFile?.bytes != null) {
              // On web, PlatformFile.path is unavailable — use .bytes directly.
              fields['video'] = MultipartFile.fromBytes(
                  media.videoPlatformFile!.bytes!,
                  filename: media.videoName ?? 'video.mp4');
            } else if (!kIsWeb && media.videoFile != null) {
              fields['video'] =
                  await MultipartFile.fromFile(media.videoFile!.path,
                      filename: media.videoName ?? 'video.mp4');
            }
          }
        }

        response = await dio.post(
          '/medications/member',
          data: FormData.fromMap(fields),
          options: Options(contentType: 'multipart/form-data'),
        );
      } else {
        response = await dio.post('/medications/member', data: data);
      }

      final med = Medication.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response.data)) as Map));
      state = MedicationsState(medications: [...state.medications, med]);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> stopMedication(String id) async {
    try {
      final response = await dio.put('/medications/member/$id/stop');
      final updated = Medication.fromJson(
          Map<String, dynamic>.from(response.data as Map));
      state = state.copyWith(
        medications: state.medications
            .map((m) => m.id == id ? updated : m)
            .toList(),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
      return false;
    }
  }

  Future<void> deleteMedication(String id) async {
    try {
      await dio.delete('/medications/member/$id');
      state = state.copyWith(
        medications: state.medications.where((m) => m.id != id).toList(),
      );
    } on DioException catch (e) {
      state = state.copyWith(error: extractErrorMessage(e));
    }
  }
}

final medicationsProvider =
    StateNotifierProvider<MedicationsNotifier, MedicationsState>((ref) {
  return MedicationsNotifier();
});
