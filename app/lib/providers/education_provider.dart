import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cms_service.dart';
import '../utils/content_mapper.dart';

class EducationContentState {
  final List<ConditionInfoData> conditions;
  final bool isLoading;
  final String? error;

  const EducationContentState({
    this.conditions = const [],
    this.isLoading = false,
    this.error,
  });

  EducationContentState copyWith({
    List<ConditionInfoData>? conditions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      EducationContentState(
        conditions: conditions ?? this.conditions,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error,
      );
}

class EducationContentNotifier extends StateNotifier<EducationContentState> {
  EducationContentNotifier() : super(const EducationContentState());

  Future<void> fetchEducationContent(List<String> conditionIds) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (conditionIds.isEmpty) {
        state = state.copyWith(isLoading: false, conditions: []);
        return;
      }

      final cmsContent =
          await CMSService.fetchContentForConditions(conditionIds);

      final mappedConditions = cmsContent
          .map((content) => ContentMapper.fromCMSContent(content))
          .toList();

      state = EducationContentState(conditions: mappedConditions);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load education content: ${e.toString()}',
      );
    }
  }

  void useLocalContent(List<ConditionInfoData> conditions) {
    state = EducationContentState(conditions: conditions);
  }
}

final educationContentProvider = StateNotifierProvider<EducationContentNotifier,
    EducationContentState>((ref) {
  return EducationContentNotifier();
});
