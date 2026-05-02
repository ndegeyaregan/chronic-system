import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/co_pay.dart';
import '../providers/auth_provider.dart';
import '../services/sanlam_api_service.dart';

/// Loads the member's co-pays once and indexes them by Sanlam `InstId`
/// for O(1) lookup from the facility detail screen.
final coPaysByInstIdProvider =
    FutureProvider.autoDispose<Map<String, CoPay>>((ref) async {
  final auth = ref.watch(authProvider);
  final memberNo = auth.member?.memberNumber;
  if (memberNo == null || memberNo.isEmpty) return <String, CoPay>{};

  final raw = await sanlamApi.getCoPay(memberNo);
  final list = (raw['coPays'] as List? ?? const [])
      .map((e) => CoPay.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  return {for (final c in list) c.instId: c};
});
