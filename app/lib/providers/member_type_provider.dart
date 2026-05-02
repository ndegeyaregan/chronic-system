import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final isChronicMemberProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).member?.isChronic ?? false,
);
