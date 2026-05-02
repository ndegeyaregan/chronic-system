import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/benefit.dart';
import '../providers/auth_provider.dart';
import '../services/sanlam_api_service.dart';

/// Benefits for a specific member number (principal or dependant).
///
/// The Sanlam back-end exposes per-member balances only through
/// `GetPlanBenefitList`, which is keyed on the principal's member number
/// and returns one row per family member (principal first, then
/// dependants). We fetch that list once and pick the row matching the
/// requested [memberNo].
final benefitProvider =
    FutureProvider.family<Benefit, String>((ref, memberNo) async {
  final auth = ref.watch(authProvider);
  final member = auth.member;
  if (member == null) throw Exception('Not authenticated');

  final list = await sanlamApi.getPlanBenefitList(member.memberNumber);
  final benefits = list.map(Benefit.fromJson).toList();

  Benefit? match;
  for (final b in benefits) {
    if (b.memberNo == memberNo) {
      match = b;
      break;
    }
  }

  // Fallback: if the principal's own benefit was requested but not found
  // in the list response (shouldn't normally happen), use the dedicated
  // single-member endpoint so the principal still sees their balances.
  if (match == null && memberNo == member.memberNumber) {
    final data = await sanlamApi.getMemberPlanBenefit(memberNo);
    return Benefit.fromMyJson(data, member);
  }

  if (match == null) {
    throw Exception('No benefits found for member $memberNo');
  }
  return match;
});

/// Full benefit list for the principal (includes dependants).
final benefitsListProvider = FutureProvider<List<Benefit>>((ref) async {
  final auth = ref.watch(authProvider);
  final member = auth.member;
  if (member == null) throw Exception('Not authenticated');
  final list = await sanlamApi.getPlanBenefitList(member.memberNumber);
  return list.map(Benefit.fromJson).toList();
});
