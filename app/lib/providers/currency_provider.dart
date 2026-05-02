import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCurrencyKey = 'selected_currency';

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('UGX') {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kCurrencyKey);
      if (saved != null) state = saved;
    } catch (_) {}
  }

  Future<void> select(String code) async {
    state = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCurrencyKey, code);
    } catch (_) {}
  }
}

final selectedCurrencyProvider =
    StateNotifierProvider<CurrencyNotifier, String>((_) => CurrencyNotifier());
