import 'json.dart';

export 'json.dart';

/// Picks the Arabic variant of a bilingual field when the UI is Arabic.
String localized(String en, String? ar, String locale) => locale == 'ar' && (ar?.isNotEmpty ?? false) ? ar! : en;

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

enum HomeRole { superAdmin, salonAdmin, staff, customer }

HomeRole _homeRole(String? v) => switch (v) {
      'SUPER_ADMIN' => HomeRole.superAdmin,
      'SALON_ADMIN' => HomeRole.salonAdmin,
      'STAFF' => HomeRole.staff,
      _ => HomeRole.customer,
    };

class AppUser {
  AppUser({required this.id, required this.name, this.email, this.phone, this.avatarUrl, required this.locale, required this.isSuperAdmin});
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String locale;
  final bool isSuperAdmin;

  String get firstName => name.split(' ').first;

  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: asStr(j['email']),
        phone: asStr(j['phone']),
        avatarUrl: asStr(j['avatarUrl']),
        locale: asStr(j['locale']) ?? 'en',
        isSuperAdmin: j['isSuperAdmin'] == true,
      );
}

class Membership {
  Membership({required this.salonId, required this.salonName, this.salonNameAr, required this.slug, required this.role, this.staffId, required this.timezone});
  final String salonId;
  final String salonName;
  final String? salonNameAr;
  final String slug;
  final String role;
  final String? staffId;
  final String timezone;

  bool get isAdmin => role == 'OWNER' || role == 'MANAGER';
  bool get isFrontDesk => isAdmin || role == 'RECEPTIONIST';

  factory Membership.fromJson(Json j) => Membership(
        salonId: j['salonId'] as String,
        salonName: j['salonName'] as String,
        salonNameAr: asStr(j['salonNameAr']),
        slug: j['slug'] as String,
        role: j['role'] as String,
        staffId: asStr(j['staffId']),
        timezone: asStr(j['timezone']) ?? 'Asia/Muscat',
      );
}

class Me {
  Me({required this.user, required this.memberships, required this.homeRole});
  final AppUser user;
  final List<Membership> memberships;
  final HomeRole homeRole;

  factory Me.fromJson(Json j) => Me(
        user: AppUser.fromJson(asJson(j['user'])),
        memberships: asJsonList(j['memberships']).map(Membership.fromJson).toList(),
        homeRole: _homeRole(j['homeRole'] as String?),
      );
}

// ---------------------------------------------------------------------------
// Catalogue & team
// ---------------------------------------------------------------------------

class Service {
  Service({
    required this.id,
    this.categoryId,
    required this.name,
    this.nameAr,
    this.description,
    this.descriptionAr,
    required this.priceBaisa,
    required this.durationMinutes,
    required this.bufferMinutes,
    this.imageUrl,
    required this.isActive,
    required this.paymentRequirement,
    required this.depositBaisa,
    required this.staffIds,
    this.bookingCount = 0,
  });

  final String id;
  final String? categoryId;
  final String name;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
  final int priceBaisa;
  final int durationMinutes;
  final int bufferMinutes;
  final String? imageUrl;
  final bool isActive;
  final String paymentRequirement;
  final int depositBaisa;
  final List<String> staffIds;
  final int bookingCount;

  bool get needsDeposit => paymentRequirement == 'DEPOSIT';
  bool get needsFull => paymentRequirement == 'FULL';
  int get dueAtBookingBaisa => needsDeposit ? depositBaisa : needsFull ? priceBaisa : 0;

  String title(String locale) => localized(name, nameAr, locale);
  String? blurb(String locale) => locale == 'ar' && descriptionAr != null ? descriptionAr : description;

  factory Service.fromJson(Json j) => Service(
        id: j['id'] as String,
        categoryId: asStr(j['categoryId']),
        name: j['name'] as String,
        nameAr: asStr(j['nameAr']),
        description: asStr(j['description']),
        descriptionAr: asStr(j['descriptionAr']),
        priceBaisa: asInt(j['priceBaisa']),
        durationMinutes: asInt(j['durationMinutes'], 60),
        bufferMinutes: asInt(j['bufferMinutes']),
        imageUrl: asStr(j['imageUrl']),
        isActive: j['isActive'] != false,
        paymentRequirement: asStr(j['paymentRequirement']) ?? 'NONE',
        depositBaisa: asInt(j['depositBaisa']),
        staffIds: asStrList(j['staffIds']),
        bookingCount: asInt(j['bookingCount']),
      );
}

class ServiceCategory {
  ServiceCategory({required this.id, required this.name, this.nameAr, this.sortOrder = 0});
  final String id;
  final String name;
  final String? nameAr;
  final int sortOrder;
  String title(String locale) => localized(name, nameAr, locale);
  factory ServiceCategory.fromJson(Json j) =>
      ServiceCategory(id: j['id'] as String, name: j['name'] as String, nameAr: asStr(j['nameAr']), sortOrder: asInt(j['sortOrder']));
}

class Shift {
  Shift({required this.dayOfWeek, required this.startMinute, required this.endMinute});
  final int dayOfWeek; // 0 = Sunday
  final int startMinute;
  final int endMinute;
  factory Shift.fromJson(Json j) => Shift(
        dayOfWeek: asInt(j['dayOfWeek']),
        startMinute: asInt(j['startMinute'] ?? j['openMinute']),
        endMinute: asInt(j['endMinute'] ?? j['closeMinute']),
      );
  Json toJson() => {'dayOfWeek': dayOfWeek, 'startMinute': startMinute, 'endMinute': endMinute};
}

class TimeOff {
  TimeOff({required this.id, required this.start, required this.end, required this.type, this.reason});
  final String id;
  final DateTime start;
  final DateTime end;
  final String type;
  final String? reason;
  factory TimeOff.fromJson(Json j) => TimeOff(
        id: j['id'] as String,
        start: asDateReq(j['startTime']),
        end: asDateReq(j['endTime']),
        type: asStr(j['type']) ?? 'OTHER',
        reason: asStr(j['reason']),
      );
}

class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    this.nameAr,
    this.title,
    this.titleAr,
    this.photoUrl,
    this.phone,
    this.email,
    this.bio,
    required this.color,
    required this.isActive,
    required this.serviceIds,
    required this.hours,
    this.timeOff = const [],
    this.hasLogin = false,
  });

  final String id;
  final String name;
  final String? nameAr;
  final String? title;
  final String? titleAr;
  final String? photoUrl;
  final String? phone;
  final String? email;
  final String? bio;
  final String color;
  final bool isActive;
  final List<String> serviceIds;
  final List<Shift> hours;
  final List<TimeOff> timeOff;
  final bool hasLogin;

  String displayName(String locale) => localized(name, nameAr, locale);
  String? displayTitle(String locale) => locale == 'ar' && titleAr != null ? titleAr : title;

  factory StaffMember.fromJson(Json j) => StaffMember(
        id: j['id'] as String,
        name: j['name'] as String,
        nameAr: asStr(j['nameAr']),
        title: asStr(j['title']),
        titleAr: asStr(j['titleAr']),
        photoUrl: asStr(j['photoUrl']),
        phone: asStr(j['phone']),
        email: asStr(j['email']),
        bio: asStr(j['bio']),
        color: asStr(j['color']) ?? '#8E4B61',
        isActive: j['isActive'] != false,
        serviceIds: asStrList(j['serviceIds']),
        hours: asJsonList(j['hours']).map(Shift.fromJson).toList(),
        timeOff: asJsonList(j['timeOff']).map(TimeOff.fromJson).toList(),
        hasLogin: j['hasLogin'] == true,
      );
}

// ---------------------------------------------------------------------------
// Bookings
// ---------------------------------------------------------------------------

class BookingRef {
  BookingRef({required this.id, required this.name, this.nameAr, this.color, this.photoUrl, this.phone, this.email, this.durationMinutes});
  final String id;
  final String name;
  final String? nameAr;
  final String? color;
  final String? photoUrl;
  final String? phone;
  final String? email;
  final int? durationMinutes;
  String display(String locale) => localized(name, nameAr, locale);
  factory BookingRef.fromJson(Json j) => BookingRef(
        id: j['id'] as String,
        name: j['name'] as String,
        nameAr: asStr(j['nameAr']),
        color: asStr(j['color']),
        photoUrl: asStr(j['photoUrl']),
        phone: asStr(j['phone']),
        email: asStr(j['email']),
        durationMinutes: j['durationMinutes'] == null ? null : asInt(j['durationMinutes']),
      );
}

/// A booking as the salon team sees it.
class Booking {
  Booking({
    required this.id,
    required this.reference,
    required this.status,
    required this.source,
    required this.start,
    required this.end,
    required this.priceBaisa,
    required this.paymentRequirement,
    required this.depositBaisa,
    required this.paidBaisa,
    this.customerNotes,
    this.internalNotes,
    required this.staff,
    required this.service,
    required this.customer,
  });

  final String id;
  final String reference;
  final String status;
  final String source;
  final DateTime start;
  final DateTime end;
  final int priceBaisa;
  final String paymentRequirement;
  final int depositBaisa;
  final int paidBaisa;
  final String? customerNotes;
  final String? internalNotes;
  final BookingRef staff;
  final BookingRef service;
  final BookingRef customer;

  int get durationMinutes => end.difference(start).inMinutes;
  int get balanceBaisa => (priceBaisa - paidBaisa).clamp(0, 1 << 31);
  bool get isLive => status != 'CANCELLED' && status != 'NO_SHOW';

  Booking copyWith({String? status, String? internalNotes}) => Booking(
        id: id,
        reference: reference,
        status: status ?? this.status,
        source: source,
        start: start,
        end: end,
        priceBaisa: priceBaisa,
        paymentRequirement: paymentRequirement,
        depositBaisa: depositBaisa,
        paidBaisa: paidBaisa,
        customerNotes: customerNotes,
        internalNotes: internalNotes ?? this.internalNotes,
        staff: staff,
        service: service,
        customer: customer,
      );

  factory Booking.fromJson(Json j) => Booking(
        id: j['id'] as String,
        reference: j['reference'] as String,
        status: j['status'] as String,
        source: asStr(j['source']) ?? 'ADMIN',
        start: asDateReq(j['startTime']),
        end: asDateReq(j['endTime']),
        priceBaisa: asInt(j['priceBaisa']),
        paymentRequirement: asStr(j['paymentRequirement']) ?? 'NONE',
        depositBaisa: asInt(j['depositBaisa']),
        paidBaisa: asInt(j['paidBaisa']),
        customerNotes: asStr(j['customerNotes']),
        internalNotes: asStr(j['internalNotes']),
        staff: BookingRef.fromJson(asJson(j['staff'])),
        service: BookingRef.fromJson(asJson(j['service'])),
        customer: BookingRef.fromJson(asJson(j['customer'])),
      );
}

class HistoryEntry {
  HistoryEntry({required this.kind, this.fromStatus, this.toStatus, this.oldStart, this.newStart, this.note, this.byName, required this.at});
  final String kind;
  final String? fromStatus;
  final String? toStatus;
  final DateTime? oldStart;
  final DateTime? newStart;
  final String? note;
  final String? byName;
  final DateTime at;
  factory HistoryEntry.fromJson(Json j) => HistoryEntry(
        kind: j['kind'] as String,
        fromStatus: asStr(j['fromStatus']),
        toStatus: asStr(j['toStatus']),
        oldStart: asDate(j['oldStartTime']),
        newStart: asDate(j['newStartTime']),
        note: asStr(j['note']),
        byName: asStr(j['changedByName']),
        at: asDateReq(j['createdAt']),
      );
}

class Payment {
  Payment({required this.id, required this.amountBaisa, required this.method, required this.kind, required this.status, this.paidAt, required this.createdAt, this.bookingRef, this.customerName, this.serviceName, this.bookingId});
  final String id;
  final int amountBaisa;
  final String method;
  final String kind;
  final String status;
  final DateTime? paidAt;
  final DateTime createdAt;
  final String? bookingRef;
  final String? bookingId;
  final String? customerName;
  final String? serviceName;
  bool get isRefund => kind == 'REFUND';
  factory Payment.fromJson(Json j) {
    final booking = asJson(j['booking']);
    return Payment(
      id: j['id'] as String,
      amountBaisa: asInt(j['amountBaisa']),
      method: asStr(j['method']) ?? 'CASH',
      kind: asStr(j['kind']) ?? 'FULL',
      status: asStr(j['status']) ?? 'PENDING',
      paidAt: asDate(j['paidAt']),
      createdAt: asDate(j['createdAt']) ?? DateTime.now(),
      bookingRef: asStr(booking['reference']),
      bookingId: asStr(booking['id']) ?? asStr(j['bookingId']),
      customerName: asStr(asJson(j['customer'])['name']),
      serviceName: asStr(asJson(booking['service'])['name']),
    );
  }
}

class BookingDetail {
  BookingDetail({required this.booking, required this.history, required this.payments, this.customerPrivateNotes, required this.balanceBaisa});
  final Booking booking;
  final List<HistoryEntry> history;
  final List<Payment> payments;
  final String? customerPrivateNotes;
  final int balanceBaisa;
  factory BookingDetail.fromJson(Json j) => BookingDetail(
        booking: Booking.fromJson(j),
        history: asJsonList(j['history']).map(HistoryEntry.fromJson).toList(),
        payments: asJsonList(j['payments']).map(Payment.fromJson).toList(),
        customerPrivateNotes: asStr(asJson(j['customer'])['notes']),
        balanceBaisa: asInt(j['balanceBaisa']),
      );
}

// ---------------------------------------------------------------------------
// Customers (CRM)
// ---------------------------------------------------------------------------

class CustomerSummary {
  CustomerSummary({required this.id, required this.name, this.phone, this.email, this.bookingCount = 0, this.lastBookingAt, this.totalSpentBaisa = 0});
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final int bookingCount;
  final DateTime? lastBookingAt;
  final int totalSpentBaisa;
  factory CustomerSummary.fromJson(Json j) => CustomerSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: asStr(j['phone']),
        email: asStr(j['email']),
        bookingCount: asInt(j['bookingCount']),
        lastBookingAt: asDate(j['lastBookingAt']),
        totalSpentBaisa: asInt(j['totalSpentBaisa']),
      );
}

class CustomerProfile {
  CustomerProfile({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.birthday,
    this.notes,
    this.preferredStaffId,
    this.preferredStaffName,
    required this.totalSpentBaisa,
    required this.visits,
    required this.cancellations,
    required this.noShows,
    this.lastVisitAt,
    this.favoriteService,
    this.upcoming,
    required this.history,
  });
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? birthday;
  final String? notes;
  final String? preferredStaffId;
  final String? preferredStaffName;
  final int totalSpentBaisa;
  final int visits;
  final int cancellations;
  final int noShows;
  final DateTime? lastVisitAt;
  final String? favoriteService;
  final Booking? upcoming;
  final List<Booking> history;
  factory CustomerProfile.fromJson(Json j) {
    final stats = asJson(j['stats']);
    return CustomerProfile(
      id: j['id'] as String,
      name: j['name'] as String,
      phone: asStr(j['phone']),
      email: asStr(j['email']),
      birthday: asStr(j['birthday']),
      notes: asStr(j['notes']),
      preferredStaffId: asStr(j['preferredStaffId']),
      preferredStaffName: asStr(asJson(j['preferredStaff'])['name']),
      totalSpentBaisa: asInt(stats['totalSpentBaisa']),
      visits: asInt(stats['visits']),
      cancellations: asInt(stats['cancellations']),
      noShows: asInt(stats['noShows']),
      lastVisitAt: asDate(stats['lastVisitAt']),
      favoriteService: asStr(stats['favoriteService']),
      upcoming: j['upcoming'] is Map ? Booking.fromJson(asJson(j['upcoming'])) : null,
      history: asJsonList(j['history']).map(Booking.fromJson).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Public salon & availability
// ---------------------------------------------------------------------------

class SalonCard {
  SalonCard({required this.id, required this.slug, required this.name, this.nameAr, this.tagline, this.taglineAr, required this.category, this.city, this.coverUrl, required this.ratingAvg, required this.ratingCount, this.fromPriceBaisa, this.isFavorite = false});
  final String id;
  final String slug;
  final String name;
  final String? nameAr;
  final String? tagline;
  final String? taglineAr;
  final String category;
  final String? city;
  final String? coverUrl;
  final double ratingAvg;
  final int ratingCount;
  final int? fromPriceBaisa;
  final bool isFavorite;
  String title(String l) => localized(name, nameAr, l);
  String? subtitle(String l) => l == 'ar' && taglineAr != null ? taglineAr : tagline;
  factory SalonCard.fromJson(Json j) => SalonCard(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: j['name'] as String,
        nameAr: asStr(j['nameAr']),
        tagline: asStr(j['tagline']),
        taglineAr: asStr(j['taglineAr']),
        category: asStr(j['category']) ?? 'MAKEUP',
        city: asStr(j['city']),
        coverUrl: asStr(j['coverUrl']),
        ratingAvg: asDouble(j['ratingAvg']),
        ratingCount: asInt(j['ratingCount']),
        fromPriceBaisa: j['fromPriceBaisa'] == null ? null : asInt(j['fromPriceBaisa']),
        isFavorite: j['isFavorite'] == true,
      );
}

class Review {
  Review({required this.id, required this.rating, this.comment, this.reply, required this.customerName, this.staffName, this.serviceName, required this.createdAt});
  final String id;
  final int rating;
  final String? comment;
  final String? reply;
  final String customerName;
  final String? staffName;
  final String? serviceName;
  final DateTime createdAt;
  factory Review.fromJson(Json j) => Review(
        id: j['id'] as String,
        rating: asInt(j['rating'], 5),
        comment: asStr(j['comment']),
        reply: asStr(j['reply']),
        customerName: asStr(asJson(j['customer'])['name']) ?? '',
        staffName: asStr(asJson(j['staff'])['name']),
        serviceName: asStr(asJson(asJson(j['booking'])['service'])['name']),
        createdAt: asDateReq(j['createdAt']),
      );
}

class SalonProfile {
  SalonProfile({
    required this.card,
    this.description,
    this.descriptionAr,
    this.phone,
    this.whatsapp,
    this.address,
    this.addressAr,
    this.latitude,
    this.longitude,
    required this.timezone,
    required this.hours,
    required this.categories,
    required this.services,
    required this.staff,
    required this.reviews,
    required this.cancellationWindowHours,
    required this.lateCancellationFeeBaisa,
    required this.depositPolicy,
    required this.closures,
  });
  final SalonCard card;
  final String? description;
  final String? descriptionAr;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? addressAr;
  final double? latitude;
  final double? longitude;
  final String timezone;
  final List<Shift> hours;
  final List<ServiceCategory> categories;
  final List<Service> services;
  final List<StaffMember> staff;
  final List<Review> reviews;
  final int cancellationWindowHours;
  final int lateCancellationFeeBaisa;
  final String depositPolicy;
  final List<({String date, String name, bool closed})> closures;

  String? about(String l) => l == 'ar' && descriptionAr != null ? descriptionAr : description;
  String? place(String l) => l == 'ar' && addressAr != null ? addressAr : address;

  factory SalonProfile.fromJson(Json j) => SalonProfile(
        card: SalonCard.fromJson(j),
        description: asStr(j['description']),
        descriptionAr: asStr(j['descriptionAr']),
        phone: asStr(j['phone']),
        whatsapp: asStr(j['whatsapp']),
        address: asStr(j['address']),
        addressAr: asStr(j['addressAr']),
        latitude: j['latitude'] == null ? null : asDouble(j['latitude']),
        longitude: j['longitude'] == null ? null : asDouble(j['longitude']),
        timezone: asStr(j['timezone']) ?? 'Asia/Muscat',
        hours: asJsonList(j['workingHours']).map(Shift.fromJson).toList(),
        categories: asJsonList(j['categories']).map(ServiceCategory.fromJson).toList(),
        services: asJsonList(j['services']).map(Service.fromJson).toList(),
        staff: asJsonList(j['staff']).map(StaffMember.fromJson).toList(),
        reviews: asJsonList(j['reviews']).map(Review.fromJson).toList(),
        cancellationWindowHours: asInt(j['cancellationWindowHours'], 24),
        lateCancellationFeeBaisa: asInt(j['lateCancellationFeeBaisa']),
        depositPolicy: asStr(j['depositPolicy']) ?? 'REFUNDABLE_IN_WINDOW',
        closures: asJsonList(j['upcomingClosures'])
            .map((c) => (date: c['date'] as String, name: asStr(c['name']) ?? '', closed: c['isClosed'] != false))
            .toList(),
      );
}

class Slot {
  Slot({required this.start, required this.time, required this.staffIds});
  final DateTime start;
  final String time; // salon-local "HH:mm"
  final List<String> staffIds;
  int get hour => int.parse(time.split(':').first);
  factory Slot.fromJson(Json j) => Slot(start: asDateReq(j['start']), time: j['time'] as String, staffIds: asStrList(j['staffIds']));
}

class DayAvailability {
  DayAvailability({required this.date, required this.closed, required this.slotCount, this.firstSlot});
  final String date;
  final bool closed;
  final int slotCount;
  final String? firstSlot;
  factory DayAvailability.fromJson(Json j) => DayAvailability(
        date: j['date'] as String,
        closed: j['closed'] == true,
        slotCount: asInt(j['slotCount']),
        firstSlot: asStr(j['firstSlot']),
      );
}

// ---------------------------------------------------------------------------
// Customer-side bookings
// ---------------------------------------------------------------------------

class CancellationQuote {
  CancellationQuote({required this.isFree, required this.freeUntil, required this.refundBaisa, required this.retainedBaisa, required this.feeBaisa});
  final bool isFree;
  final DateTime freeUntil;
  final int refundBaisa;
  final int retainedBaisa;
  final int feeBaisa;
  factory CancellationQuote.fromJson(Json j) => CancellationQuote(
        isFree: j['isFreeCancellation'] == true,
        freeUntil: asDate(j['freeUntil']) ?? DateTime.now(),
        refundBaisa: asInt(j['refundBaisa']),
        retainedBaisa: asInt(j['retainedBaisa']),
        feeBaisa: asInt(j['feeBaisa']),
      );
}

class MyBooking {
  MyBooking({
    required this.id,
    required this.reference,
    required this.status,
    required this.start,
    required this.end,
    required this.priceBaisa,
    required this.depositBaisa,
    required this.paidBaisa,
    required this.paymentRequirement,
    required this.salon,
    required this.salonTimezone,
    this.salonPhone,
    this.salonAddress,
    required this.staff,
    required this.service,
    this.reviewRating,
    this.reviewComment,
    this.customerNotes,
    this.canCancel = false,
    this.canReschedule = false,
    this.canReview = false,
    this.quote,
    this.pendingPaymentId,
    this.cancellationWindowHours = 24,
  });
  final String id;
  final String reference;
  final String status;
  final DateTime start;
  final DateTime end;
  final int priceBaisa;
  final int depositBaisa;
  final int paidBaisa;
  final String paymentRequirement;
  final SalonCard salon;
  final String salonTimezone;
  final String? salonPhone;
  final String? salonAddress;
  final BookingRef staff;
  final BookingRef service;
  final int? reviewRating;
  final String? reviewComment;
  final String? customerNotes;
  final bool canCancel;
  final bool canReschedule;
  final bool canReview;
  final CancellationQuote? quote;
  final String? pendingPaymentId;
  final int cancellationWindowHours;

  int get balanceBaisa => (priceBaisa - paidBaisa).clamp(0, 1 << 31);
  bool get depositOutstanding => paymentRequirement != 'NONE' && paidBaisa < depositBaisa && status == 'PENDING';

  factory MyBooking.fromJson(Json j) {
    final salon = asJson(j['salon']);
    final review = asJson(j['review']);
    final payments = asJsonList(j['payments']);
    final pending = payments.where((p) => p['status'] == 'PENDING' && p['kind'] != 'REFUND').toList();
    return MyBooking(
      id: j['id'] as String,
      reference: j['reference'] as String,
      status: j['status'] as String,
      start: asDateReq(j['startTime']),
      end: asDateReq(j['endTime']),
      priceBaisa: asInt(j['priceBaisa']),
      depositBaisa: asInt(j['depositBaisa']),
      paidBaisa: asInt(j['paidBaisa']),
      paymentRequirement: asStr(j['paymentRequirement']) ?? 'NONE',
      salon: SalonCard.fromJson(salon),
      salonTimezone: asStr(salon['timezone']) ?? 'Asia/Muscat',
      salonPhone: asStr(salon['phone']),
      salonAddress: asStr(salon['address']),
      staff: BookingRef.fromJson(asJson(j['staff'])),
      service: BookingRef.fromJson(asJson(j['service'])),
      reviewRating: review.isEmpty ? null : asInt(review['rating']),
      reviewComment: asStr(review['comment']),
      customerNotes: asStr(j['customerNotes']),
      canCancel: j['canCancel'] == true,
      canReschedule: j['canReschedule'] == true,
      canReview: j['canReview'] == true,
      quote: j['cancellationQuote'] is Map ? CancellationQuote.fromJson(asJson(j['cancellationQuote'])) : null,
      pendingPaymentId: pending.isEmpty ? null : pending.first['id'] as String,
      cancellationWindowHours: asInt(salon['cancellationWindowHours'], 24),
    );
  }
}

class AppNotification {
  AppNotification({required this.id, required this.type, required this.title, required this.body, this.bookingId, required this.read, required this.createdAt});
  final String id;
  final String type;
  final String title;
  final String body;
  final String? bookingId;
  final bool read;
  final DateTime createdAt;
  factory AppNotification.fromJson(Json j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        bookingId: asStr(j['bookingId']),
        read: j['readAt'] != null,
        createdAt: asDateReq(j['createdAt']),
      );
}
