import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router/routes.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_widgets.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.inspectionId,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String? inspectionId;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final data = j['data'];
    return AppNotification(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'SYSTEM_ALERT',
      title: j['title'] as String? ?? _titleFor(j['type'] as String?),
      body: j['body'] as String? ?? j['message'] as String? ?? '',
      read: j['read'] as bool? ?? j['isRead'] as bool? ?? false,
      inspectionId: j['inspectionId'] as String? ??
          (data is Map<String, dynamic>
              ? data['inspectionId'] as String?
              : null),
      createdAt: j['createdAt'] is String
          ? DateTime.tryParse(j['createdAt'] as String)
          : null,
    );
  }

  static String _titleFor(String? type) => switch (type) {
        'ASSIGNMENT_CREATED' => 'New assignment',
        'ASSIGNMENT_CHANGED' => 'Assignment changed',
        'INSPECTION_SUBMITTED' => 'Inspection submitted',
        'INSPECTION_APPROVED' => 'Inspection approved',
        'INSPECTION_REJECTED' => 'Inspection rejected',
        'CORRECTION_REQUESTED' => 'Correction requested',
        'REPORT_READY' => 'Report ready',
        _ => 'Notification',
      };

  IconData get icon => switch (type) {
        'ASSIGNMENT_CREATED' || 'ASSIGNMENT_CHANGED' => Icons.inbox_rounded,
        'INSPECTION_APPROVED' => Icons.verified_rounded,
        'INSPECTION_REJECTED' => Icons.cancel_rounded,
        'CORRECTION_REQUESTED' => Icons.report_problem_rounded,
        'REPORT_READY' => Icons.description_outlined,
        _ => Icons.notifications_rounded,
      };

  Color get color => switch (type) {
        'INSPECTION_APPROVED' => AppColors.success,
        'INSPECTION_REJECTED' => AppColors.danger,
        'CORRECTION_REQUESTED' => AppColors.warning,
        _ => AppColors.primary,
      };
}

class NotificationsRepository {
  const NotificationsRepository(this._api);
  final ApiClient _api;

  Future<List<AppNotification>> list() async {
    final d = await _api.get<dynamic>('/notifications');
    final raw = d is Map<String, dynamic> ? (d['items'] ?? d['data']) : d;
    return raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList()
        : <AppNotification>[];
  }

  Future<int> unreadCount() async {
    final d = await _api.get<dynamic>('/notifications/unread-count');
    if (d is Map<String, dynamic>) {
      return (d['count'] as num?)?.toInt() ??
          (d['unread'] as num?)?.toInt() ??
          0;
    }
    return d is num ? d.toInt() : 0;
  }

  Future<void> markRead(String id) => _api.post<dynamic>(
      '/notifications/read', body: <String, dynamic>{'id': id});

  Future<void> markAllRead() => _api.post<dynamic>('/notifications/read-all');
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(apiClientProvider)));

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>(
        (ref) => ref.watch(notificationsRepositoryProvider).list());

final unreadCountProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.watch(notificationsRepositoryProvider).unreadCount());

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationsRepositoryProvider)
                  .markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: items.when(
        loading: () => const ListSkeleton(itemCount: 6, height: 76),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          },
          child: list.isEmpty
              ? ListView(
                  children: <Widget>[
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications',
                        message: 'Assignment and review updates appear here.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.xs, AppSpacing.md, 120),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return AlertTile(
                      title: n.title,
                      subtitle: <String>[
                        if (n.body.isNotEmpty) n.body,
                        if (n.createdAt != null)
                          DateFormat('d MMM HH:mm')
                              .format(n.createdAt!.toLocal()),
                      ].join(' · '),
                      icon: n.icon,
                      color: n.color,
                      trailing: n.read
                          ? null
                          : Container(
                              height: 9,
                              width: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                      onTap: () async {
                        if (!n.read) {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markRead(n.id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadCountProvider);
                        }
                        // Deep-link to the related inspection.
                        if (n.inspectionId != null && context.mounted) {
                          context.push(
                              Routes.inspectionDetail(n.inspectionId!));
                        }
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
