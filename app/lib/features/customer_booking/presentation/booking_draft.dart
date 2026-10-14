import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../salon/data/salon_repository.dart';
import '../data/customer_booking_repository.dart';

/// The booking steps — one decision per screen, so no step ever needs to scroll.
abstract final class BookStep {
  static const services = 0;
  static const artist = 1;
  static const date = 2;
  static const time = 3;
  static const details = 4;
  static const verify = 5;
  static const count = 6;
}

/// Booking state for the customer flow, kept apart from the widgets so steps can animate
/// in and out without losing what she picked.
class BookingDraft {
  const BookingDraft({
    this.step = 0,
    this.forward = true,
    this.serviceIds = const [],
    this.staffId,
    this.date,
    this.slot,
    this.name = '',
    this.phone = '',
    this.codeSentTo,
    this.codeSentAt,
    this.testCode,
    this.result,
    this.paid = false,
  });

  final int step;
  final bool forward;

  /// Chosen services, in the order they'll be performed (back to back).
  final List<String> serviceIds;

  /// null = "Any available".
  final String? staffId;
  final String? date; // salon-local YYYY-MM-DD
  final Slot? slot;
  final String name;
  final String phone;
  final String? codeSentTo;
  final DateTime? codeSentAt;

  /// Shown only when the server runs in test mode (no SMS provider yet).
  final String? testCode;
  final BookingResult? result;
  final bool paid;

  String get servicesKey => serviceIds.join(',');

  BookingDraft copyWith({
    int? step,
    bool? forward,
    List<String>? serviceIds,
    String? staffId,
    bool clearStaff = false,
    String? date,
    bool clearDate = false,
    Slot? slot,
    bool clearSlot = false,
    String? name,
    String? phone,
    String? codeSentTo,
    DateTime? codeSentAt,
    String? testCode,
    bool clearTestCode = false,
    BookingResult? result,
    bool? paid,
  }) => BookingDraft(
    step: step ?? this.step,
    forward: forward ?? this.forward,
    serviceIds: serviceIds ?? this.serviceIds,
    staffId: clearStaff ? null : (staffId ?? this.staffId),
    date: clearDate ? null : (date ?? this.date),
    slot: clearSlot ? null : (slot ?? this.slot),
    name: name ?? this.name,
    phone: phone ?? this.phone,
    codeSentTo: codeSentTo ?? this.codeSentTo,
    codeSentAt: codeSentAt ?? this.codeSentAt,
    testCode: clearTestCode ? null : (testCode ?? this.testCode),
    result: result ?? this.result,
    paid: paid ?? this.paid,
  );
}

/// Artists who can do every chosen service (the visit stays with one artist).
List<StaffMember> eligibleStaff(SalonProfile profile, List<String> serviceIds) {
  final chosen = profile.services.where((s) => serviceIds.contains(s.id)).toList();
  return profile.staff.where((m) => chosen.every((s) => s.staffIds.contains(m.id))).toList();
}

class BookingDraftController extends AutoDisposeFamilyNotifier<BookingDraft, String> {
  @override
  BookingDraft build(String slug) => const BookingDraft();

  CustomerBookingRepository get _repo => ref.read(customerBookingRepositoryProvider);

  void goTo(int step) => state = state.copyWith(step: step, forward: step > state.step);

  void toggleService(Service service, SalonProfile profile) {
    final ids = [...state.serviceIds];
    ids.contains(service.id) ? ids.remove(service.id) : ids.add(service.id);
    final keepStaff = state.staffId != null && eligibleStaff(profile, ids).any((m) => m.id == state.staffId);
    state = state.copyWith(serviceIds: ids, clearStaff: !keepStaff, clearSlot: true);
  }

  void pickStaff(String? id) => state = id == null ? state.copyWith(clearStaff: true, clearSlot: true) : state.copyWith(staffId: id, clearSlot: true);
  void pickDate(String date) => state = state.copyWith(date: date, clearSlot: true, forward: state.date == null || date.compareTo(state.date!) >= 0);
  void pickSlot(Slot slot) => state = state.copyWith(slot: slot);
  void details({required String name, required String phone}) => state = state.copyWith(name: name, phone: phone);

  /// Details → Verify: text a code to her phone.
  Future<void> sendCode(String locale) async {
    final testCode = await _repo.requestCode(state.phone, locale);
    state = state.copyWith(
      codeSentTo: state.phone,
      codeSentAt: DateTime.now(),
      testCode: testCode,
      clearTestCode: testCode == null,
      step: BookStep.verify,
      forward: true,
    );
  }

  /// Verify: check the code, then book with the resulting phone token.
  Future<void> verifyAndBook(String code) async {
    final token = await _repo.verifyCode(state.phone, code);
    await _book(token);
  }

  Future<void> _book(String phoneToken) async {
    final s = state;
    final result = await _repo.book(
      salon: arg,
      serviceIds: s.serviceIds,
      staffId: s.staffId,
      start: s.slot!.start,
      name: s.name.trim(),
      phone: s.phone,
      phoneToken: phoneToken,
    );
    state = state.copyWith(result: result);
  }

  /// Someone else just took the time: back to the times with fresh availability.
  void slotTaken() {
    ref.invalidate(visitSlotsProvider);
    ref.invalidate(visitDaysProvider);
    state = state.copyWith(step: BookStep.time, forward: false, clearSlot: true);
  }

  /// Pays every outstanding deposit in the visit (test gateway confirms in place;
  /// a real gateway would hand back a checkout URL instead).
  Future<void> payDeposits() async {
    final r = state.result!;
    final updated = <MyBooking>[];
    for (final b in r.bookings) {
      if (b.depositOutstanding) {
        final payment = await _repo.startPayment(b.id, token: r.manageToken);
        updated.add(await _repo.confirmTestPayment(payment.paymentId, token: r.manageToken));
      } else {
        updated.add(b);
      }
    }
    state = state.copyWith(
      paid: true,
      result: BookingResult(bookings: updated, manageToken: r.manageToken, requiresPayment: false, onlinePaymentAvailable: r.onlinePaymentAvailable),
    );
  }
}

final bookingDraftProvider = AutoDisposeNotifierProviderFamily<BookingDraftController, BookingDraft, String>(BookingDraftController.new);

// ---------------------------------------------------------------------------
// Availability for the chosen visit (server state, cached per services/artist/day)
// ---------------------------------------------------------------------------

typedef VisitDaysQuery = ({String salon, String services, String? staffId, String from});
typedef VisitSlotsQuery = ({String salon, String services, String? staffId, String date});

final visitDaysProvider = FutureProvider.autoDispose.family<List<DayAvailability>, VisitDaysQuery>(
  (ref, q) => ref.watch(salonRepositoryProvider).days(salon: q.salon, serviceIds: q.services.split(','), from: q.from, staffId: q.staffId),
);

final visitSlotsProvider = FutureProvider.autoDispose.family<List<Slot>, VisitSlotsQuery>(
  (ref, q) => ref.watch(salonRepositoryProvider).slots(salon: q.salon, serviceIds: q.services.split(','), date: q.date, staffId: q.staffId),
);
