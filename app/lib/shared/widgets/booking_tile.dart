import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../animations/staggered_entrance.dart';
import '../models/models.dart';
import 'common.dart';

/// An appointment card: time column, artist colour bar, client, service, artist,
/// duration and status. Used on the dashboard, lists and client profiles.
class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking, required this.timezone, this.onTap, this.showDate = false});
  final Booking booking;
  final String timezone;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.lang;
    final artist = hexColor(booking.staff.color);
    final dimmed = !booking.isLive;
    return Semantics(
      button: onTap != null,
      label: '${fmt.time(booking.start, timezone)}, ${booking.customer.name}, ${booking.service.display(l)}, ${fmt.statusLabel(booking.status)}',
      child: ExcludeSemantics(
        child: GlowCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: AnimatedOpacity(
            opacity: dimmed ? 0.62 : 1,
            duration: const Duration(milliseconds: 250),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 96,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: Space.lg, top: Space.lg, bottom: Space.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate) Text(fmt.relativeDay(booking.start, timezone), style: context.text.labelSmall),
                          Text(fmt.time(booking.start, timezone), style: context.text.titleSmall, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                          const SizedBox(height: 2),
                          Text(fmt.duration(booking.durationMinutes), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: Space.md),
                    decoration: BoxDecoration(color: artist, borderRadius: Radii.pillAll),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  booking.customer.name,
                                  style: context.text.titleMedium?.copyWith(decoration: booking.status == 'CANCELLED' ? TextDecoration.lineThrough : null),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              StatusChip(booking.status, dense: true),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(booking.service.display(l), style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: artist, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Flexible(child: Text(booking.staff.display(l), style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (booking.depositBaisa > 0 && booking.paidBaisa >= booking.depositBaisa) ...[
                                const SizedBox(width: Space.sm),
                                Icon(Icons.verified_rounded, size: 14, color: context.colors.tertiary),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [BookingTile] with the staggered fade + slide entrance.
class AnimatedBookingCard extends StatelessWidget {
  const AnimatedBookingCard({super.key, required this.index, required this.booking, required this.timezone, this.onTap, this.showDate = false});
  final int index;
  final Booking booking;
  final String timezone;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) => StaggeredEntrance(
        index: index,
        child: BookingTile(booking: booking, timezone: timezone, onTap: onTap, showDate: showDate),
      );
}
