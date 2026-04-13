import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/lab_test.dart';
import '../services/api_service.dart';

class LabTestsState {
  final List<LabTest> tests;
  final bool isLoading;
  final String? error;

  const LabTestsState({
    this.tests = const [],
    this.isLoading = false,
    this.error,
  });

  LabTestsState copyWith({
    List<LabTest>? tests,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      LabTestsState(
        tests: tests ?? this.tests,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class LabTestsNotifier extends StateNotifier<LabTestsState> {
  LabTestsNotifier() : super(const LabTestsState()) {
    fetchTests();
  }

  Future<void> fetchTests() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/lab-tests');
      final tests = (response.data as List)
          .map((e) => LabTest.fromJson(e as Map<String, dynamic>))
          .toList();
      state = LabTestsState(tests: tests);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
    }
  }

  Future<bool> completeTest(
    String testId, {
    String? resultNotes,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (resultNotes != null) 'result_notes': resultNotes,
        if (fileBytes != null && fileName != null)
          'result': MultipartFile.fromBytes(fileBytes, filename: fileName)
        else if (filePath != null)
          'result': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      await dio.patch(
        '/lab-tests/$testId/complete',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      await fetchTests();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
      return false;
    }
  }
}

final labTestsProvider =
    StateNotifierProvider<LabTestsNotifier, LabTestsState>((ref) {
  return LabTestsNotifier();
});
