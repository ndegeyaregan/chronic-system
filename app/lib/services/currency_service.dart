class CurrencyService {
  static const Map<String, double> _ratesFromUgx = {
    'UGX': 1.0,
    'USD': 1 / 3700,
    'KES': 1 / 27,
    'ZAR': 1 / 200,
    'EUR': 1 / 4000,
    'GBP': 1 / 4700,
  }; // TODO: replace with live FX feed

  static double convertFromUgx(num amountUgx, String code) {
    final rate = _ratesFromUgx[code] ?? 1.0;
    return amountUgx * rate;
  }

  static String symbol(String code) {
    switch (code) {
      case 'UGX':
        return 'USh';
      case 'USD':
        return r'$';
      case 'KES':
        return 'KSh';
      case 'ZAR':
        return 'R';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  static const List<String> supportedCurrencies = [
    'UGX',
    'USD',
    'KES',
    'ZAR',
    'EUR',
    'GBP',
  ];
}
