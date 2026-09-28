import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label, this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Floating bottom bar with a soft pill that glides to the selected tab.
class AnimatedBottomNavigation extends StatelessWidget {
  const AnimatedBottomNavigation({super.key, required this.items, required this.index, required this.onSelect});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.md, 0, Space.md, bottom > 0 ? bottom : Space.md),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: Radii.xlAll,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(color: context.glow.shadow, blurRadius: 24, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth / items.length;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final left = (rtl ? items.length - 1 - index : index) * w;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: motion.medium,
                curve: Motion.emphasized,
                left: left,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(Radii.lg))),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: items[i].label,
                        child: InkResponse(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(i);
                          },
                          radius: 36,
                          child: _NavCell(item: items[i], selected: i == index),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.selected});
  final NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final color = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: motion.medium,
            curve: Motion.pop,
            child: Badge(
              isLabelVisible: item.badge > 0,
              label: Text('${item.badge > 9 ? '9+' : item.badge}'),
              child: Icon(selected ? item.selectedIcon : item.icon, color: color, size: IconSizes.md),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: motion.fast,
            style: context.text.labelSmall!.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
            child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
