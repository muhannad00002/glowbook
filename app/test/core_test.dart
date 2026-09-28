import 'package:flutter_test/flutter_test.dart';
import 'package:glowbook/core/utils/format.dart';
import 'package:glowbook/shared/models/models.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('Ymd', () {
    test('adds days across month ends', () {
      expect(Ymd.add('2026-09-30', 1), '2026-10-01');
      expect(Ymd.add('2026-03-01', -1), '2026-02-28');
    });
    test('day of week uses 0 = Sunday', () {
      expect(Ymd.dayOfWeek('2026-09-27'), 0); // Sunday
      expect(Ymd.dayOfWeek('2026-10-03'), 6); // Saturday
    });
  });

  group('salon time', () {
    test('an instant renders in the salon timezone, not the device one', () {
      final instant = DateTime.parse('2026-09-29T11:15:00.000Z');
      final local = Fmt.inZone(instant, 'Asia/Muscat');
      expect(local.hour, 15);
      expect(local.minute, 15);
    });
    test('salon wall-clock → instant', () {
      final i = Fmt.zonedInstant('2026-09-29', 15 * 60 + 15, 'Asia/Muscat');
      expect(i.toUtc().toIso8601String(), '2026-09-29T11:15:00.000Z');
    });
  });

  test('booking parses the API shape', () {
    final b = Booking.fromJson({
      'id': 'b1',
      'reference': 'GB-ABC123',
      'status': 'CONFIRMED',
      'source': 'PUBLIC_PAGE',
      'startTime': '2026-09-29T11:15:00.000Z',
      'endTime': '2026-09-29T12:15:00.000Z',
      'priceBaisa': 75000,
      'depositBaisa': 20000,
      'paidBaisa': 20000,
      'staff': {'id': 's1', 'name': 'Maryam', 'color': '#B7835A'},
      'service': {'id': 'v1', 'name': 'Bridal Makeup', 'nameAr': 'مكياج عروس'},
      'customer': {'id': 'c1', 'name': 'Aisha'},
    });
    expect(b.durationMinutes, 60);
    expect(b.balanceBaisa, 55000);
    expect(b.service.display('ar'), 'مكياج عروس');
    expect(b.isLive, isTrue);
  });
}
