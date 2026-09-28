import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../shared/models/models.dart';

/// Salon-side bookings: list, detail, create (walk-ins), status, cancel, move, pay.
class BookingsRepository {
  BookingsRepository(this._api);
  final ApiClient _api;

  Future<List<Booking>> list({String? from, String? to, String? staffId, String? status, String? q, String? customerId}) async {
    final data = await _api.get<List<dynamic>>('/api/bookings', query: {
      'from': from,
      'to': to,
      'staffId': staffId,
      'status': status,
      'q': q,
      'customerId': customerId,
    });
    return asJsonList(data).map(Booking.fromJson).toList();
  }

  Future<BookingDetail> detail(String id) async => BookingDetail.fromJson(asJson(await _api.get<Object?>('/api/bookings/$id')));

  Future<Booking> create({
    required String serviceId,
    required String? staffId,
    required DateTime start,
    String? customerId,
    Json? newCustomer,
    String? customerNotes,
    String? internalNotes,
    String source = 'ADMIN',
    String status = 'CONFIRMED',
    bool notifyCustomer = true,
  }) async {
    final data = await _api.post<Object?>('/api/bookings', body: {
      'serviceId': serviceId,
      'staffId': staffId,
      'startTime': start.toUtc().toIso8601String(),
      'customerId': ?customerId,
      'newCustomer': ?newCustomer,
      if (customerNotes != null && customerNotes.isNotEmpty) 'customerNotes': customerNotes,
      if (internalNotes != null && internalNotes.isNotEmpty) 'internalNotes': internalNotes,
      'source': source,
      'status': status,
      'notifyCustomer': notifyCustomer,
    });
    return Booking.fromJson(asJson(data));
  }

  Future<Booking> setStatus(String id, String status) async =>
      Booking.fromJson(asJson(await _api.post<Object?>('/api/bookings/$id/status', body: {'status': status})));

  Future<Booking> cancel(String id, {String? reason, bool notify = true}) async {
    final data = asJson(await _api.post<Object?>('/api/bookings/$id/cancel', body: {'reason': reason, 'notifyCustomer': notify}));
    return Booking.fromJson(asJson(data['booking']));
  }

  Future<Booking> restore(String id) async => Booking.fromJson(asJson(await _api.post<Object?>('/api/bookings/$id/restore')));

  Future<Booking> reschedule(String id, DateTime start, {String? staffId}) async => Booking.fromJson(asJson(await _api.post<Object?>(
        '/api/bookings/$id/reschedule',
        body: {'startTime': start.toUtc().toIso8601String(), 'staffId': ?staffId},
      )));

  Future<void> saveNotes(String id, String? internalNotes) => _api.patch<Object?>('/api/bookings/$id', body: {'internalNotes': internalNotes});

  Future<void> recordPayment(String id, {required int amountBaisa, required String method, required String kind}) =>
      _api.post<Object?>('/api/bookings/$id/payments', body: {'amountBaisa': amountBaisa, 'method': method, 'kind': kind});

  Future<({String date, List<Slot> slots})> availability({
    required String salonId,
    required String serviceId,
    required String date,
    String? staffId,
    bool desk = true,
  }) async {
    final data = asJson(await _api.get<Object?>('/api/availability', query: {
      'salon': salonId,
      'serviceId': serviceId,
      'date': date,
      'staffId': staffId,
      if (desk) 'desk': 'true',
    }));
    return (date: data['date'] as String, slots: asJsonList(data['slots']).map(Slot.fromJson).toList());
  }

  Future<List<Json>> blocked(String from, String to) async =>
      asJsonList(await _api.get<List<dynamic>>('/api/blocked-times', query: {'from': from, 'to': to}));

  Future<void> blockTime({String? staffId, required DateTime start, required DateTime end, required String type, String? note, bool force = false}) =>
      _api.post<Object?>('/api/blocked-times', body: {
        'staffId': staffId,
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
        'type': type,
        'note': note,
        'force': force,
      });

  Future<void> deleteBlock(String id) => _api.delete<Object?>('/api/blocked-times/$id');
}

final bookingsRepositoryProvider = Provider((ref) => BookingsRepository(ref.watch(apiClientProvider)));

final bookingDetailProvider = FutureProvider.autoDispose.family<BookingDetail, String>(
  (ref, id) => ref.watch(bookingsRepositoryProvider).detail(id),
);
