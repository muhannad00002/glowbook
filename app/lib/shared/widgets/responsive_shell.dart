import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../animations/animated_bottom_navigation.dart';

class ShellDestination {
  const ShellDestination({required this.path, required this.icon, required this.selectedIcon, required this.label, this.badge = 0, this.primary = true});
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;

  /// Shown in the phone bottom bar (others live under "More").
  final bool primary;
}

/// Adaptive navigation: bottom bar on phones, a rail on tablets, a full sidebar on
/// desktop. The body cross-fades between destinations.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.destinations,
    required this.currentPath,
    required this.onNavigate,
    required this.child,
    required this.moreLabel,
    this.header,
    this.fab,
  });

  final List<ShellDestination> destinations;
  final String currentPath;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final String moreLabel;

  /// Sidebar header (brand + salon switcher) on large screens.
  final Widget? header;
  final Widget? fab;

  int _indexOf(List<ShellDestination> list) {
    var best = -1;
    var bestLen = -1;
    for (var i = 0; i < list.length; i++) {
      final p = list[i].path;
      if ((currentPath == p || currentPath.startsWith('$p/')) && p.length > bestLen) {
        best = i;
        bestLen = p.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scheme = context.colors;

    if (width >= Breakpoints.tablet) {
      final extended = width >= Breakpoints.desktop;
      final index = _indexOf(destinations);
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            _Sidebar(
              extended: extended,
              destinations: destinations,
              selected: index,
              onSelect: (i) => onNavigate(destinations[i].path),
              header: header,
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            Expanded(child: child),
          ],
        ),
      );
    }

    final primary = destinations.where((d) => d.primary).toList();
    final secondary = destinations.where((d) => !d.primary).toList();
    final idx = _indexOf(primary);
    final items = [
      for (final d in primary) NavItem(icon: d.icon, selectedIcon: d.selectedIcon, label: d.label, badge: d.badge),
      if (secondary.isNotEmpty) NavItem(icon: Icons.menu_rounded, selectedIcon: Icons.menu_open_rounded, label: moreLabel),
    ];
    final selected = idx >= 0 ? idx : (secondary.isNotEmpty ? items.length - 1 : 0);

    return Scaffold(
      extendBody: true,
      floatingActionButton: fab,
      body: child,
      bottomNavigationBar: AnimatedBottomNavigation(
        items: items,
        index: selected,
        onSelect: (i) {
          if (i < primary.length) {
            onNavigate(primary[i].path);
          } else {
            _showMore(context, secondary);
          }
        },
      ),
    );
  }

  void _showMore(BuildContext context, List<ShellDestination> items) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) Padding(padding: const EdgeInsets.only(bottom: Space.md), child: header!),
              for (final d in items)
                ListTile(
                  leading: Badge(isLabelVisible: d.badge > 0, label: Text('${d.badge}'), child: Icon(d.icon)),
                  title: Text(d.label),
                  selected: currentPath.startsWith(d.path),
                  onTap: () {
                    Navigator.pop(ctx);
                    onNavigate(d.path);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.extended, required this.destinations, required this.selected, required this.onSelect, this.header});
  final bool extended;
  final List<ShellDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final scheme = context.colors;
    return AnimatedContainer(
      duration: motion.medium,
      curve: Motion.standard,
      width: extended ? 264 : 88,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? Space.lg : Space.sm, Space.lg, extended ? Space.lg : Space.sm, Space.lg),
              child: extended && header != null ? header! : Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 28),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: extended ? Space.md : Space.sm),
                itemCount: destinations.length,
                itemBuilder: (context, i) {
                  final d = destinations[i];
                  final isSel = i == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      selected: isSel,
                      button: true,
                      label: d.label,
                      child: Tooltip(
                        message: extended ? '' : d.label,
                        child: InkWell(
                          borderRadius: Radii.mdAll,
                          onTap: () => onSelect(i),
                          child: AnimatedContainer(
                            duration: motion.medium,
                            curve: Motion.standard,
                            height: 48,
                            padding: EdgeInsets.symmetric(horizontal: extended ? Space.md : 0),
                            decoration: BoxDecoration(color: isSel ? scheme.primaryContainer : Colors.transparent, borderRadius: Radii.mdAll),
                            child: Row(
                              mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                              children: [
                                Badge(
                                  isLabelVisible: d.badge > 0,
                                  label: Text('${d.badge > 9 ? '9+' : d.badge}'),
                                  child: Icon(isSel ? d.selectedIcon : d.icon, color: isSel ? scheme.onPrimaryContainer : scheme.onSurfaceVariant, size: IconSizes.md),
                                ),
                                if (extended) ...[
                                  const SizedBox(width: Space.md),
                                  Expanded(
                                    child: Text(
                                      d.label,
                                      style: context.text.labelLarge?.copyWith(color: isSel ? scheme.onPrimaryContainer : scheme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
