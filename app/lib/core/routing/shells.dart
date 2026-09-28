import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/data/notifications_repository.dart';
import '../../shared/widgets/responsive_shell.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

/// Brand + salon name block for the sidebar / "More" sheet.
class _ShellHeader extends ConsumerWidget {
  const _ShellHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(membershipProvider);
    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(gradient: context.glow.cardGradient, borderRadius: Radii.mdAll),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: Space.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.l10n.appName, style: context.text.titleMedium),
          if (m != null)
            Text(context.lang == 'ar' && m.salonNameAr != null ? m.salonNameAr! : m.salonName, style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final m = ref.watch(membershipProvider);
    final unread = ref.watch(inboxProvider).valueOrNull?.unread ?? 0;
    final admin = m?.isAdmin ?? false;
    final destinations = [
      ShellDestination(path: '/admin', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: l.navHome),
      ShellDestination(path: '/admin/calendar', icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, label: l.navCalendar),
      ShellDestination(path: '/admin/clients', icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: l.navCustomers),
      ShellDestination(path: '/admin/inbox', icon: Icons.notifications_none_rounded, selectedIcon: Icons.notifications_rounded, label: l.navInbox, badge: unread),
      ShellDestination(path: '/admin/services', icon: Icons.spa_outlined, selectedIcon: Icons.spa_rounded, label: l.navServices, primary: false),
      ShellDestination(path: '/admin/team', icon: Icons.badge_outlined, selectedIcon: Icons.badge_rounded, label: l.navStaff, primary: false),
      ShellDestination(path: '/admin/payments', icon: Icons.payments_outlined, selectedIcon: Icons.payments_rounded, label: l.navPayments, primary: false),
      if (admin) ShellDestination(path: '/admin/reports', icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded, label: l.navReports, primary: false),
      ShellDestination(path: '/admin/reviews', icon: Icons.star_outline_rounded, selectedIcon: Icons.star_rounded, label: l.navReviews, primary: false),
      ShellDestination(path: '/admin/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: l.navSettings, primary: false),
    ];
    return ResponsiveShell(
      destinations: destinations,
      currentPath: location,
      onNavigate: context.go,
      moreLabel: l.navMore,
      header: const _ShellHeader(),
      child: child,
    );
  }
}

class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unread = ref.watch(inboxProvider).valueOrNull?.unread ?? 0;
    return ResponsiveShell(
      destinations: [
        ShellDestination(path: '/staff', icon: Icons.wb_sunny_outlined, selectedIcon: Icons.wb_sunny_rounded, label: l.navMyDay),
        ShellDestination(path: '/staff/calendar', icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, label: l.navCalendar),
        ShellDestination(path: '/staff/clients', icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: l.navCustomers),
        ShellDestination(path: '/staff/inbox', icon: Icons.notifications_none_rounded, selectedIcon: Icons.notifications_rounded, label: l.navInbox, badge: unread),
        ShellDestination(path: '/staff/profile', icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: l.navProfile),
      ],
      currentPath: location,
      onNavigate: context.go,
      moreLabel: l.navMore,
      header: const _ShellHeader(),
      child: child,
    );
  }
}

class CustomerShell extends ConsumerWidget {
  const CustomerShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unread = ref.watch(inboxProvider).valueOrNull?.unread ?? 0;
    return ResponsiveShell(
      destinations: [
        ShellDestination(path: '/discover', icon: Icons.explore_outlined, selectedIcon: Icons.explore_rounded, label: l.navDiscover),
        ShellDestination(path: '/appointments', icon: Icons.event_note_outlined, selectedIcon: Icons.event_note_rounded, label: l.navAppointments),
        ShellDestination(path: '/inbox', icon: Icons.notifications_none_rounded, selectedIcon: Icons.notifications_rounded, label: l.navInbox, badge: unread),
        ShellDestination(path: '/profile', icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: l.navProfile),
      ],
      currentPath: location,
      onNavigate: context.go,
      moreLabel: l.navMore,
      header: const _ShellHeader(),
      child: child,
    );
  }
}
