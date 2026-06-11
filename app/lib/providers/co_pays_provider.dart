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

/// Corporate (employer/group) name the member belongs to. Sourced from the
/// Sanlam `GetCoPay` response (`corpName`). Returns null if not available.
final corporateNameProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final auth = ref.watch(authProvider);
  final memberNo = auth.member?.memberNumber;
  if (memberNo == null || memberNo.isEmpty) return null;
  try {
    final raw = await sanlamApi.getCoPay(memberNo);
    final name = (raw['corpName'] ?? raw['CorpName'] ?? '').toString().trim();
    return name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
});

/// Loads institution-specific co-pays (`GetInstCoPay`) for the current member.
/// These are surcharges imposed by individual institutions (e.g. Nakasero
/// Hospital 25%) that apply *in addition to* any scheme-level co-pay returned
/// by [coPaysByInstIdProvider]. Indexed by Sanlam `InstId`.
final instCoPaysByInstIdProvider =
    FutureProvider.autoDispose<Map<String, CoPay>>((ref) async {
  final auth = ref.watch(authProvider);
  final memberNo = auth.member?.memberNumber;
  if (memberNo == null || memberNo.isEmpty) return <String, CoPay>{};

  final list = await sanlamApi.getInstCoPay(memberNo);
  final scheme = auth.member?.schemeName;
  final out = <String, CoPay>{};
  for (final raw in list) {
    final cp = CoPay.fromJson(raw);
    if (cp.instId.isEmpty) continue;
    if (!cp.hasAnyCharge) continue;
    // Defensive: if the API still echoes an institution that excludes this
    // member's scheme, drop it client-side as well.
    if (cp.isExcludedFor(scheme)) continue;
    out[cp.instId] = cp;
  }
  return out;
});
