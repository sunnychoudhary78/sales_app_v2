import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_repository.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(notificationsProvider));
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(authProvider.select((a) => a.profile?.userId)) ?? '';

    return Scaffold(
      drawer: const AppSideDrawer(),
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load notifications.\n$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(notificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final row = rows[i];
                final title = (row['title'] ?? 'Notification').toString();
                final body = (row['body'] ?? row['message'] ?? '').toString();
                final atRaw = (row['receivedAt'] ?? row['created_at'] ?? '').toString();
                final at = DateTime.tryParse(atRaw)?.toLocal();
                final isRead = row['is_read'] == true;
                final id = row['id'];
                return Card(
                  color: isRead
                      ? null
                      : scheme.primaryContainer.withValues(alpha: 0.35),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primary.withValues(alpha: 0.2),
                      child: Icon(Icons.notifications, color: scheme.primary),
                    ),
                    title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(body),
                        if (at != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(at),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () async {
                      if (id is int && uid.isNotEmpty) {
                        await ref.read(notificationsRepositoryProvider).markAsRead(id, userId: uid);
                        ref.invalidate(notificationsProvider);
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
