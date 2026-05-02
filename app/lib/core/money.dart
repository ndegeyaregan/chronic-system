import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/currency_provider.dart';
import '../services/currency_service.dart';

String formatMoney(num amountUgx, String code) {
  final converted = CurrencyService.convertFromUgx(amountUgx, code);
  final symbol = CurrencyService.symbol(code);
  final decimals = code == 'UGX' ? 0 : 2;
  final formatter = NumberFormat.currency(
    symbol: symbol,
    decimalDigits: decimals,
  );
  return formatter.format(converted);
}

class Money extends ConsumerWidget {
  final num amount;
  final TextStyle? style;

  const Money({super.key, required this.amount, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(selectedCurrencyProvider);
    return Text(formatMoney(amount, code), style: style);
  }
}
