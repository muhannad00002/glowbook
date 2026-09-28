import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';

/// Fade + slight upward slide, delayed by [index] for a cascading list reveal.
/// Plays once per widget identity (give list items stable keys).
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child, this.offset = 16, this.axis = Axis.vertical});
  final int index;
  final Widget child;
  final double offset;
  final Axis axis;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.standard);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = Motion.of(context);
    if (motion.reduced) {
      _c.value = 1;
    } else {
      Future<void>.delayed(motion.stagger(widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final d = widget.offset * (1 - _t.value);
        return Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: widget.axis == Axis.vertical ? Offset(0, d) : Offset(d, 0), child: child),
        );
      },
    );
  }
}
