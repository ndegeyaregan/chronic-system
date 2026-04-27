import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'cache_service.dart';

/// Represents content from the CMS API
class CMSContent {
  final String id;
  final String title;
  final String? body;
  final String type; // article, tip, video, guide
  final String? videoUrl;
  final String? conditionId;
  final String? conditionName;
  final String? category;
  final List<String>? tags;
  final bool published;
  final DateTime? publishedAt;
  final int views;

  const CMSContent({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.videoUrl,
    this.conditionId,
    this.conditionName,
    this.category,
    this.tags,
    required this.published,
    this.publishedAt,
    required this.views,
  });

  factory CMSContent.fromJson(Map<String, dynamic> json) => CMSContent(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        body: json['body'] as String?,
        type: (json['type'] ?? 'article').toString(),
        videoUrl: json['video_url'] as String?,
        conditionId: json['condition_id'] as String?,
        conditionName: json['condition_name'] as String?,
        category: json['category'] as String?,
        tags: (json['tags'] as List?)?.cast<String>(),
        published: (json['published'] ?? false) as bool,
        publishedAt: json['published_at'] != null
            ? DateTime.tryParse(json['published_at'].toString())
            : null,
        views: (json['views'] ?? 0) as int,
      );
}

/// Service to fetch and cache CMS content from the backend API
class CMSService {
  static Future<void> init() async {
    // CMS cache is initialized as part of CacheService
  }

  /// Fetch published articles for specific conditions
  static Future<List<CMSContent>> fetchContentForConditions(
    List<String> conditionIds, {
    bool useCache = true,
  }) async {
    try {
      // Check cache first
      if (useCache && CacheService.hasCachedCmsContent) {
        final cached = _loadCachedContent();
        if (cached.isNotEmpty) {
          return cached;
        }
      }

      // Fetch from API
      final List<CMSContent> allContent = [];

      for (final conditionId in conditionIds) {
        try {
          final response = await dio.get('/cms', queryParameters: {
            'condition_id': conditionId,
            'type': 'article',
            'published': 'true',
          });

          if (response.statusCode == 200 && response.data is List) {
            final items = (response.data as List)
                .map((item) => CMSContent.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .toList();
            allContent.addAll(items);
          }
        } catch (e) {
          // Log error but continue with other conditions
          print('Error fetching CMS content for condition $conditionId: $e');
        }
      }

      // Cache the results
      if (allContent.isNotEmpty) {
        await _cacheContent(allContent);
      }

      return allContent;
    } catch (e) {
      // Fall back to cache on network error
      print('Error fetching CMS content: $e');
      if (useCache) {
        return _loadCachedContent();
      }
      return [];
    }
  }

  /// Fetch a single article by ID
  static Future<CMSContent?> fetchContentById(String contentId) async {
    try {
      final response = await dio.get('/cms/$contentId');
      if (response.statusCode == 200) {
        return CMSContent.fromJson(
            Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      print('Error fetching CMS content $contentId: $e');
    }
    return null;
  }

  /// Get cached content
  static List<CMSContent> getCachedContent() => _loadCachedContent();

  /// Check if content is cached
  static bool hasCachedContent() => CacheService.hasCachedCmsContent;

  /// Clear cached content
  static Future<void> clearCache() async {
    await CacheService.clearCmsCache();
  }

  // Private helpers

  static Future<void> _cacheContent(List<CMSContent> content) async {
    try {
      final jsonList = content
          .map((c) => {
                'id': c.id,
                'title': c.title,
                'body': c.body,
                'type': c.type,
                'video_url': c.videoUrl,
                'condition_id': c.conditionId,
                'condition_name': c.conditionName,
                'category': c.category,
                'tags': c.tags,
                'published': c.published,
                'published_at': c.publishedAt?.toIso8601String(),
                'views': c.views,
              })
          .toList();
      await CacheService.saveCmsContent(jsonList);
    } catch (e) {
      print('Error caching CMS content: $e');
    }
  }

  static List<CMSContent> _loadCachedContent() {
    try {
      final cached = CacheService.loadCmsContent();
      if (cached == null) return [];
      final items = cached
          .map((item) =>
              CMSContent.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      return items;
    } catch (e) {
      print('Error loading cached CMS content: $e');
      return [];
    }
  }
}
