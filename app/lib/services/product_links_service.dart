import 'package:dio/dio.dart';

import '../core/app_config.dart';

/// One destination shown in the "Other Sanlam Allianz Products" popup on the
/// login screen. The `key` is stable and mirrors the backend seed so the UI
/// can map keys to labels / icons regardless of the response order.
class ProductLink {
  final String key;
  final String label;
  final String description;
  final String url;

  const ProductLink({
    required this.key,
    required this.label,
    required this.description,
    required this.url,
  });

  factory ProductLink.fromJson(Map<String, dynamic> j) => ProductLink(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
      );
}

/// Fetches the publishable product-link destinations from the backend.
/// The endpoint is public so the popup works before the member logs in.
class ProductLinksService {
  ProductLinksService._();
  static final ProductLinksService instance = ProductLinksService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Returns the three product links keyed by `key`. On any network error we
  /// fall back to the hard-coded defaults so the popup is never broken.
  Future<Map<String, ProductLink>> fetch() async {
    try {
      final resp = await _dio.get('/product-links');
      final raw = (resp.data as List?) ?? const [];
      final out = <String, ProductLink>{};
      for (final r in raw) {
        if (r is Map) {
          final link = ProductLink.fromJson(Map<String, dynamic>.from(r));
          if (link.key.isNotEmpty && link.url.isNotEmpty) {
            out[link.key] = link;
          }
        }
      }
      // Merge defaults for any keys the server omitted so the popup is
      // always complete.
      for (final entry in defaults.entries) {
        out.putIfAbsent(entry.key, () => entry.value);
      }
      return out;
    } catch (_) {
      return Map<String, ProductLink>.from(defaults);
    }
  }

  /// Hard-coded fallbacks used when the backend is unreachable. The URLs
  /// match the seed in `048_product_links.sql`.
  static const Map<String, ProductLink> defaults = {
    'microinsurance': ProductLink(
      key: 'microinsurance',
      label: 'Micro Insurance',
      description: 'Affordable cover for everyday risks',
      url: 'https://ug.sanlamallianz.com/',
    ),
    'existing_customer': ProductLink(
      key: 'existing_customer',
      label: 'Existing Customer',
      description: 'Log in to your existing Sanlam Allianz account',
      url: 'https://app.ug.sanlamallianz.com/login',
    ),
    'other_life_products': ProductLink(
      key: 'other_life_products',
      label: 'Other Life Products',
      description: 'Life cover, education plans & family protection',
      url: 'https://ug.sanlamallianz.com/life-insurance/individuals',
    ),
  };
}
