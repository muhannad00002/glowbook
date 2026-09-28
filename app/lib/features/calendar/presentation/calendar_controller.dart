import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/format.dart';

enum CalendarView { day, week, month }

/// UI state for the calendar: which view, which date, which artist, and which way
/// the last navigation went (for the slide direction).
class CalendarState {
  const CalendarState({required this.view, required this.date, this.staffId, this.forward = true});
  final CalendarView view;
  final String date; // salon-local YYYY-MM-DD
  final String? staffId;
  final bool forward;

  /// Weeks start on Saturday (Gulf working week).
  String get weekStart => Ymd.add(date, -((Ymd.dayOfWeek(date) + 1) % 7));
  String get weekEnd => Ymd.add(weekStart, 6);
  String get month => date.substring(0, 7);

  CalendarState copyWith({CalendarView? view, String? date, String? staffId, bool clearStaff = false, bool? forward}) => CalendarState(
        view: view ?? this.view,
        date: date ?? this.date,
        staffId: clearStaff ? null : (staffId ?? this.staffId),
        forward: forward ?? this.forward,
      );
}

class CalendarController extends AutoDisposeNotifier<CalendarState> {
  @override
  CalendarState build() {
    final tz = ref.watch(salonTimezoneProvider);
    final m = ref.watch(membershipProvider);
    return CalendarState(view: CalendarView.day, date: Ymd.today(tz), staffId: m?.role == 'STAFF' ? m?.staffId : null);
  }

  void setView(CalendarView v) => state = state.copyWith(view: v);
  void setStaff(String? id) => state = id == null ? state.copyWith(clearStaff: true) : state.copyWith(staffId: id);

  void goTo(String date) => state = state.copyWith(date: date, forward: date.compareTo(state.date) >= 0);

  void today() => goTo(Ymd.today(ref.read(salonTimezoneProvider)));

  void step(int dir) {
    final d = switch (state.view) {
      CalendarView.day => Ymd.add(state.date, dir),
      CalendarView.week => Ymd.add(state.date, 7 * dir),
      CalendarView.month => () {
          final p = Ymd.parse(state.date);
          return Ymd.of(DateTime(p.year, p.month + dir, 1));
        }(),
    };
    state = state.copyWith(date: d, forward: dir > 0);
  }

  void openDay(String date) => state = state.copyWith(view: CalendarView.day, date: date, forward: date.compareTo(state.date) >= 0);
}

final calendarControllerProvider = AutoDisposeNotifierProvider<CalendarController, CalendarState>(CalendarController.new);
