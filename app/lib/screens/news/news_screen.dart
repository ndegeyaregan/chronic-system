import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../core/app_colors.dart';

class NewsItem {
  final String id;
  final String title;
  final String? body;
  final String? category;
  final String? imageUrl;
  final DateTime publishedAt;

  const NewsItem({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.imageUrl,
    required this.publishedAt,
  });

  String? get resolvedImageUrl {
    final raw = imageUrl;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$kServerBase$raw';
    return '$kServerBase/$raw';
  }

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final raw = (json['updated_at'] ?? json['created_at'] ?? json['scheduled_at'] ?? '').toString();
    return NewsItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: json['body'] as String?,
      category: json['category'] as String?,
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      publishedAt: DateTime.tryParse(raw)?.toLocal() ?? DateTime.now(),
    );
  }
}

final newsListProvider =
    FutureProvider.autoDispose<List<NewsItem>>((ref) async {
  final response = await dio.get('/cms', queryParameters: {
    'type': 'news',
    'published': 'true',
  });
  if (response.data is! List) return [];
  final list = (response.data as List)
      .map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return list;
});

// ── Unread tracking ────────────────────────────────────────────────────────
// Persists the set of news IDs the member has already seen so the dashboard
// can show an unread badge on the News tile.
class _ReadNewsNotifier extends StateNotifier<Set<String>> {
  _ReadNewsNotifier() : super(const <String>{}) {
    _load();
  }
  static const _kKey = 'read_news_ids_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_kKey)?.toSet() ?? <String>{};
  }

  Future<void> markRead(Iterable<String> ids) async {
    final filtered = ids.where((id) => id.isNotEmpty);
    if (filtered.isEmpty) return;
    final next = {...state, ...filtered};
    if (next.length == state.length) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, state.toList());
  }
}

final readNewsIdsProvider =
    StateNotifierProvider<_ReadNewsNotifier, Set<String>>(
  (ref) => _ReadNewsNotifier(),
);

/// Number of published news items the member hasn't opened yet.
/// Watches [newsListProvider] (so it triggers a refresh) and
/// [readNewsIdsProvider] for persisted reads.
final unreadNewsCountProvider = Provider.autoDispose<int>((ref) {
  final readIds = ref.watch(readNewsIdsProvider);
  final asyncNews = ref.watch(newsListProvider);
  return asyncNews.maybeWhen(
    data: (items) => items.where((i) => !readIds.contains(i.id)).length,
    orElse: () => 0,
  );
});

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNews = ref.watch(newsListProvider);
    // Mark every loaded item as read once the list is in. This clears the
    // unread badge on the dashboard the moment the user opens this screen.
    ref.listen<AsyncValue<List<NewsItem>>>(newsListProvider, (_, next) {
      next.whenData((items) {
        if (items.isEmpty) return;
        ref.read(readNewsIdsProvider.notifier).markRead(items.map((e) => e.id));
      });
    });
    asyncNews.whenData((items) {
      if (items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(readNewsIdsProvider.notifier)
              .markRead(items.map((e) => e.id));
        });
      }
    });
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('News'),
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: () async => ref.refresh(newsListProvider.future),
        child: asyncNews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load news.\n$e',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.c.subtext)),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 140),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.newspaper_outlined,
                            color: Color(0xFFCBD5E1), size: 64),
                        SizedBox(height: 12),
                        Text('No news yet',
                            style:
                                TextStyle(color: context.c.subtext, fontSize: 15)),
                        SizedBox(height: 4),
                        Text(
                          'Updates from Sanlam will appear here.',
                          style: TextStyle(color: context.c.subtext, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _NewsCard(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('dd MMM yyyy • HH:mm').format(item.publishedAt);
    final preview = (item.body ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusMd),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _NewsDetailSheet(item: item, dateLabel: dateLabel),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.resolvedImageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.resolvedImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF1F5F9),
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined,
                        color: context.c.subtext, size: 32),
                  ),
                  loadingBuilder: (ctx, child, p) => p == null
                      ? child
                      : Container(
                          color: const Color(0xFFF8FAFC),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.newspaper_rounded,
                            color: Color(0xFFDC2626), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.c.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: context.c.subtext),
                      const SizedBox(width: 4),
                      Text(dateLabel,
                          style: TextStyle(
                              fontSize: 12, color: context.c.subtext)),
                      if (item.category != null && item.category!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(item.category!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.c.subtext,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: context.c.subtext, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsDetailSheet extends StatelessWidget {
  final NewsItem item;
  final String dateLabel;
  const _NewsDetailSheet({required this.item, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final fullText = (item.body ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(item.title,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: context.c.text)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: context.c.subtext),
                const SizedBox(width: 4),
                Text(dateLabel,
                    style: TextStyle(fontSize: 12, color: context.c.subtext)),
              ],
            ),
            const SizedBox(height: 16),
            if (item.resolvedImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    item.resolvedImageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined,
                          color: context.c.subtext, size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              fullText.isEmpty ? 'No further details provided.' : fullText,
              style: TextStyle(fontSize: 14, color: context.c.text, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
