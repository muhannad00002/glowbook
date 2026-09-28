import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../data/customer_booking_repository.dart';

/// Booking state for the customer flow, kept apart from the widgets so the steps can
/// come and go (and animate) without losing what she picked.
class BookingDraft {
  const BookingDraft({
    this.step = 0,
    this.forward = true,
    this.service,
    this.staffId,
    this.slot,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.result,
    this.paid = false,
    this.slotRefresh = 0,
  });

  final int step;
  final bool forward;
  final Service? service;
  final String? staffId; // null = any available
  final Slot? slot;
  final String name;
  final String phone;
  final String email;
  final String notes;
  final BookingResult? result;
  final bool paid;
  final int slotRefresh;

  BookingDraft copyWith({
    int? step,
    bool? forward,
    Service? service,
    String? staffId,
    bool clearStaff = false,
    Slot? slot,
    bool clearSlot = false,
    String? name,
    String? phone,
    String? email,
    String? notes,
    BookingResult? result,
    bool? paid,
    int? slotRefresh,
  }) =>
      BookingDraft(
        step: step ?? this.step,
        forward: forward ?? this.forward,
        service: service ?? this.service,
        staffId: clearStaff ? null : (staffId ?? this.staffId),
        slot: clearSlot ? null : (slot ?? this.slot),
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        notes: notes ?? this.notes,
        result: result ?? this.result,
        paid: paid ?? this.paid,
        slotRefresh: slotRefresh ?? this.slotRefresh,
      );
}

class BookingDraftController extends AutoDisposeFamilyNotifier<BookingDraft, String> {
  @override
  BookingDraft build(String slug) => const BookingDraft();

  void goTo(int step) => state = state.copyWith(step: step, forward: step > state.step);
  void pickService(Service s) => state = state.copyWith(
        service: s,
        clearSlot: true,
        clearStaff: state.staffId != null && !s.staffIds.contains(state.staffId),
      );
  void pickStaff(String? id) => state = id == null ? state.copyWith(clearStaff: true, clearSlot: true) : state.copyWith(staffId: id, clearSlot: true);
  void pickSlot(Slot? s) => state = s == null ? state.copyWith(clearSlot: true) : state.copyWith(slot: s);
  void details({String? name, String? phone, String? email, String? notes}) => state = state.copyWith(name: name, phone: phone, email: email, notes: notes);

  /// Creates the booking. On a slot conflict, returns to the time step with fresh slots.
  Future<BookingResult> confirm() async {
    final s = state;
    final result = await ref.read(customerBookingRepositoryProvider).book(
          salon: arg,
          serviceId: s.service!.id,
          staffId: s.staffId,
          start: s.slot!.start,
          name: s.name.trim(),
          phone: s.phone.trim(),
          email: s.email.trim(),
          notes: s.notes.trim(),
        );
    state = state.copyWith(result: result);
    return result;
  }

  void slotTaken() => state = state.copyWith(step: 2, forward: false, clearSlot: true, slotRefresh: state.slotRefresh + 1);

  Future<void> payDeposit() async {
    final r = state.result!;
    final repo = ref.read(customerBookingRepositoryProvider);
    final token = r.manageToken;
    final payment = await repo.startPayment(r.booking.id, token: token);
    // Test gateway: confirm in place. A real gateway would return a checkoutUrl to open.
    final booking = await repo.confirmTestPayment(payment.paymentId, token: token);
    state = state.copyWith(
      paid: true,
      result: BookingResult(booking: booking, manageToken: token, requiresPayment: false, onlinePaymentAvailable: r.onlinePaymentAvailable),
    );
  }
}

final bookingDraftProvider = AutoDisposeNotifierProviderFamily<BookingDraftController, BookingDraft, String>(BookingDraftController.new);
