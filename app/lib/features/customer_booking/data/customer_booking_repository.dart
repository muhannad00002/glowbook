import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../shared/models/models.dart';

class BookingResult {
  BookingResult({required this.bookings, required this.manageToken, required this.requiresPayment, required this.onlinePaymentAvailable});

  /// One booking per service, back to back (a single service → one booking).
  final List<MyBooking> bookings;
  MyBooking get booking => bookings.first;
  final String manageToken;
  final bool requiresPayment;
  final bool onlinePaymentAvailable;
}

/// Customer-side booking actions. Customers have no accounts: everything after booking
/// goes through the signed link token returned at booking time (and sent on WhatsApp).
class CustomerBookingRepository {
  CustomerBookingRepository(this._api);
  final ApiClient _api;

  /// Sends a 6-digit code to [phone]. Returns the code itself only when the server runs
  /// in test mode (no SMS/WhatsApp provider connected yet).
  Future<String?> requestCode(String phone, String locale) async =>
      asStr(asJson(await _api.post<Object?>('/api/public/phone/request', body: {'phone': phone, 'locale': locale}))['testCode']);

  /// Checks the code; returns a short-lived token proving the phone for the booking.
  Future<String> verifyCode(String phone, String code) async =>
      asJson(await _api.post<Object?>('/api/public/phone/verify', body: {'phone': phone, 'code': code}))['phoneToken'] as String;

  Future<BookingResult> book({
    required String salon,
    required List<String> serviceIds,
    required String? staffId,
    required DateTime start,
    required String name,
    required String phone,
    String? phoneToken,
    String? email,
    String? notes,
  }) async {
    final j = asJson(
      await _api.post<Object?>(
        '/api/public/bookings',
        body: {
          'salon': salon,
          'serviceIds': serviceIds,
          'phoneToken': ?phoneToken,
          'staffId': staffId,
          'startTime': start.toUtc().toIso8601String(),
          'customer': {'name': name, 'phone': phone, if (email != null && email.isNotEmpty) 'email': email},
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'source': 'PUBLIC_PAGE',
        },
      ),
    );
    final list = asJsonList(j['bookings']);
    return BookingResult(
      bookings: (list.isEmpty ? [asJson(j['booking'])] : list).map(MyBooking.fromJson).toList(),
      manageToken: j['manageToken'] as String,
      requiresPayment: j['requiresPayment'] == true,
      onlinePaymentAvailable: j['onlinePaymentAvailable'] == true,
    );
  }

  String _base(String id, String? token) => '/api/public/bookings/$id';
  Map<String, dynamic>? _q(String? token) => token == null ? null : {'token': token};

  Future<MyBooking> detail(String id, {String? token}) async => MyBooking.fromJson(asJson(await _api.get<Object?>(_base(id, token), query: _q(token))));

  Future<void> cancel(String id, {String? token, String? reason}) =>
      _api.post<Object?>('${_base(id, token)}/cancel', query: _q(token), body: {'reason': ?reason});

  Future<void> reschedule(String id, DateTime start, {String? staffId, String? token}) =>
      _api.post<Object?>('${_base(id, token)}/reschedule', query: _q(token), body: {'startTime': start.toUtc().toIso8601String(), 'staffId': ?staffId});

  /// Starts an online payment; returns the payment id (and a checkout URL for real gateways).
  Future<({String paymentId, int amountBaisa, String? checkoutUrl, String? provider})> startPayment(String id, {String? token, String kind = 'DEPOSIT'}) async {
    final j = asJson(await _api.post<Object?>('${_base(id, token)}/pay', query: _q(token), body: {'kind': kind}));
    return (paymentId: j['paymentId'] as String, amountBaisa: asInt(j['amountBaisa']), checkoutUrl: asStr(j['checkoutUrl']), provider: asStr(j['provider']));
  }

  /// Test-gateway confirmation (only works when the server runs PAYMENT_PROVIDER=test).
  Future<MyBooking> confirmTestPayment(String paymentId, {String? token}) async {
    final j = asJson(await _api.post<Object?>('/api/payments/$paymentId/test-confirm', body: {'token': ?token}));
    return MyBooking.fromJson(asJson(j['booking']));
  }
}

final customerBookingRepositoryProvider = Provider((ref) => CustomerBookingRepository(ref.watch(apiClientProvider)));

final myBookingProvider = FutureProvider.autoDispose.family<MyBooking, ({String id, String? token})>(
  (ref, a) => ref.watch(customerBookingRepositoryProvider).detail(a.id, token: a.token),
);
