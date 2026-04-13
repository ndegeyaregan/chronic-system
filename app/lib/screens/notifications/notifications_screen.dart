import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';

final _notificationsProvider = StateNotifierProvider<_NotifNotifier,
    List<AppNotification>>((ref) => _NotifNotifier());

class _NotifNotifier extends StateNotifier<List<AppNotification>> {
  _NotifNotifier() : super([]) {
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await dio.get('/notifications');
      final list = (response.data as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    state = state.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    try {
      await dio.put('/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    try {
      await dio.put('/notifications/read-all');
    } catch (_) {}
  }

  Future<void> refresh() => _fetch();
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _typeIcon(NotificationType t) {
    switch (t) {
      case NotificationType.medication:
        return Icons.medication_outlined;
      case NotificationType.appointment:
        return Icons.calendar_today_outlined;
      case NotificationType.vital:
        return Icons.monitor_heart_outlined;
      case NotificationType.lifestyle:
        return Icons.spa_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(NotificationType t) {
    switch (t) {
      case NotificationType.medication:
        return kAccent;
      case NotificationType.appointment:
        return kPrimary;
      case NotificationType.vital:
        return kError;
      case NotificationType.lifestyle:
        return const Color(0xFF22C55E);
      default:
        return kSubtext;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(_notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(_notificationsProvider.notifier).markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      color: Color(0xFFCBD5E1), size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: kSubtext, fontSize: 15),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: () =>
                  ref.read(_notificationsProvider.notifier).refresh(),
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, i) {
                  final n = notifications[i];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: n.isRead
                        ? Colors.transparent
                        : kPrimary.withValues(alpha: 0.04),
                    child: InkWell(
                      onTap: () => ref
                          .read(_notificationsProvider.notifier)
                          .markRead(n.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _typeColor(n.type)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_typeIcon(n.type),
                                  color: _typeColor(n.type), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: TextStyle(
                                            fontWeight: n.isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            fontSize: 14,
                                            color: kText,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _timeAgo(n.createdAt),
                                        style: const TextStyle(
                                            fontSize: 11, color: kSubtext),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.message,
                                    style: const TextStyle(
                                        fontSize: 13, color: kSubtext),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!n.isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: kPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
