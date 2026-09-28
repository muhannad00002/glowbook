import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../bookings/presentation/booking_detail_sheet.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) => switch (type) {
        'BOOKING_CREATED' => Icons.event_available_rounded,
        'BOOKING_CONFIRMED' => Icons.check_circle_outline_rounded,
        'BOOKING_RESCHEDULED' => Icons.edit_calendar_outlined,
        'BOOKING_CANCELLED' => Icons.event_busy_outlined,
        'REMINDER_24H' || 'REMINDER_3H' => Icons.alarm_rounded,
        'REVIEW_REQUEST' => Icons.star_border_rounded,
        _ => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final inbox = ref.watch(inboxProvider);
    final membership = ref.watch(membershipProvider);
    final g = gutterOf(context);

    void open(AppNotification n) {
      ref.read(inboxProvider.notifier).markRead(n.id);
      if (n.bookingId == null) return;
      if (membership != null) {
        showBookingDetail(context, n.bookingId!);
      } else {
        context.push('/appointments/${n.bookingId}');
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(inboxProvider.future),
          child: AsyncView(
            value: inbox,
            onRetry: () => ref.invalidate(inboxProvider),
            data: (data) => ListView(
              padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
              children: [
                ContentWidth(
                  maxWidth: Breakpoints.maxReading,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: Text(l.notificationsTitle, style: context.text.headlineMedium)),
                        if (data.unread > 0) TextButton(onPressed: () => ref.read(inboxProvider.notifier).markAllRead(), child: Text(l.notificationsMarkAll)),
                      ]),
                      const SizedBox(height: Space.lg),
                      if (data.items.isEmpty) AnimatedEmptyState(art: GlowArt.bell, title: l.notificationsEmptyTitle, body: l.notificationsEmptyBody),
                      for (var i = 0; i < data.items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: StaggeredEntrance(
                            key: ValueKey(data.items[i].id),
                            index: i,
                            child: GlowCard(
                              onTap: () => open(data.items[i]),
                              elevated: !data.items[i].read,
                              padding: const EdgeInsets.all(Space.lg),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(color: context.colors.primaryContainer, shape: BoxShape.circle),
                                    child: Icon(_icon(data.items[i].type), size: 20, color: context.colors.onPrimaryContainer),
                                  ),
                                  const SizedBox(width: Space.md),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(data.items[i].title, style: context.text.titleSmall),
                                      const SizedBox(height: 2),
                                      Text(data.items[i].body, style: context.text.bodyMedium),
                                      const SizedBox(height: 4),
                                      Text(context.fmt.relativeDay(data.items[i].createdAt, ref.watch(salonTimezoneProvider)), style: context.text.bodySmall),
                                    ]),
                                  ),
                                  AnimatedOpacity(
                                    opacity: data.items[i].read ? 0 : 1,
                                    duration: Motion.of(context).medium,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
