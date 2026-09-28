import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

/// The signed-in user's in-app inbox (customers and salon team alike).
class InboxController extends AutoDisposeAsyncNotifier<({List<AppNotification> items, int unread})> {
  @override
  Future<({List<AppNotification> items, int unread})> build() async {
    ref.watch(authControllerProvider.select((s) => s.valueOrNull?.me.user.id));
    final data = asJson(await ref.read(apiClientProvider).get<Object?>('/api/notifications', query: {'limit': '50'}));
    return (items: asJsonList(data['items']).map(AppNotification.fromJson).toList(), unread: asInt(data['unread']));
  }

  Future<void> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    // Optimistic: the dot fades immediately.
    state = AsyncData((
      items: [
        for (final n in current.items)
          n.id == id ? AppNotification(id: n.id, type: n.type, title: n.title, body: n.body, bookingId: n.bookingId, read: true, createdAt: n.createdAt) : n,
      ],
      unread: current.items.any((n) => n.id == id && !n.read) ? current.unread - 1 : current.unread,
    ));
    await ref.read(apiClientProvider).post<Object?>('/api/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await ref.read(apiClientProvider).post<Object?>('/api/notifications/read-all');
    ref.invalidateSelf();
  }
}

final inboxProvider = AsyncNotifierProvider.autoDispose<InboxController, ({List<AppNotification> items, int unread})>(InboxController.new);
