// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Glowbook';

  @override
  String get appTagline => 'حجوزات الجمال، بإدارة أنيقة.';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionSaveChanges => 'حفظ التغييرات';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionDone => 'تم';

  @override
  String get actionBack => 'رجوع';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionRetry => 'حاولي مرة أخرى';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionUndo => 'تراجع';

  @override
  String get actionSeeAll => 'عرض الكل';

  @override
  String get actionKeep => 'إبقاء';

  @override
  String get labelOptional => 'اختياري';

  @override
  String get labelSearch => 'بحث';

  @override
  String get labelToday => 'اليوم';

  @override
  String get labelTomorrow => 'غداً';

  @override
  String get labelYesterday => 'أمس';

  @override
  String labelMinutes(int count) {
    return '$count دقيقة';
  }

  @override
  String labelHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String labelHours(int hours) {
    return '$hours ساعة';
  }

  @override
  String money(String amount) {
    return '$amount ر.ع';
  }

  @override
  String get errorGeneric => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get errorOffline =>
      'يبدو أنك غير متصلة بالإنترنت. تحققي من الاتصال وحاولي مجدداً.';

  @override
  String get errorRequired => 'مطلوب';

  @override
  String get errorEmail => 'أدخلي بريداً إلكترونياً صحيحاً';

  @override
  String get errorPhone => 'أدخلي رقم هاتف صحيحاً';

  @override
  String get errorPasswordShort => '٨ أحرف على الأقل';

  @override
  String get errorNumber => 'أدخلي رقماً';

  @override
  String get authWelcomeBack => 'أهلاً بعودتك';

  @override
  String get authSignInSubtitle => 'سجّلي الدخول لإدارة حجوزاتك.';

  @override
  String get authEmailOrPhone => 'البريد الإلكتروني أو الهاتف';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authNoAccount => 'جديدة على Glowbook؟';

  @override
  String get authCreateAccount => 'إنشاء حساب';

  @override
  String get authForgotPassword => 'نسيتِ كلمة المرور؟';

  @override
  String get authForgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get authForgotBody =>
      'أدخلي بريدك الإلكتروني وسنرسل لك رابطاً لاختيار كلمة مرور جديدة.';

  @override
  String get authSendResetLink => 'إرسال الرابط';

  @override
  String get authResetSent =>
      'إذا كان هناك حساب بهذا البريد، فالرابط في طريقه إليك.';

  @override
  String get authDevResetHint =>
      'وضع التطوير: لا يوجد مزود بريد، استخدمي الرابط أدناه.';

  @override
  String get authOpenResetLink => 'فتح رابط إعادة التعيين';

  @override
  String get authResetTitle => 'اختاري كلمة مرور جديدة';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة';

  @override
  String get authPasswordUpdated => 'تم تحديث كلمة المرور. يرجى تسجيل الدخول.';

  @override
  String get authFullName => 'الاسم الكامل';

  @override
  String get authPhone => 'رقم الهاتف';

  @override
  String get authRegisterTitle => 'أنشئي حسابك';

  @override
  String get authRegisterSubtitle => 'احجزي في صالوناتك المفضلة خلال ثوانٍ.';

  @override
  String get authHaveAccount => 'لديكِ حساب؟';

  @override
  String get authOwnSalon => 'تملكين صالوناً أو استوديو؟';

  @override
  String get authRegisterSalon => 'أضيفي صالونك';

  @override
  String get authRegisterSalonTitle => 'انضمي بصالونك إلى Glowbook';

  @override
  String get authRegisterSalonSubtitle =>
      'تقويم، حجوزات، تذكيرات ومدفوعات — مجاناً لمدة ٣٠ يوماً.';

  @override
  String get authSalonName => 'اسم الصالون';

  @override
  String get authCity => 'المدينة';

  @override
  String get authStartTrial => 'ابدئي التجربة المجانية';

  @override
  String get authPhoneSignIn => 'المتابعة برقم الهاتف';

  @override
  String get authSendCode => 'إرسال الرمز';

  @override
  String get authEnterCode => 'أدخلي الرمز المكوّن من ٦ أرقام';

  @override
  String authCodeSentTo(String phone) {
    return 'أرسلنا رمزاً إلى $phone';
  }

  @override
  String authDevCodeHint(String code) {
    return 'رمز وضع التطوير: $code';
  }

  @override
  String get authVerify => 'تحقق';

  @override
  String get authOr => 'أو';

  @override
  String get authSignOut => 'تسجيل الخروج';

  @override
  String get authSignOutConfirm => 'تسجيل الخروج من Glowbook؟';

  @override
  String get authDemoAccounts => 'حسابات تجريبية';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCalendar => 'المواعيد';

  @override
  String get navBookings => 'الحجوزات';

  @override
  String get navCustomers => 'العملاء';

  @override
  String get navServices => 'الخدمات';

  @override
  String get navStaff => 'الموظفات';

  @override
  String get navReports => 'التقارير';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get navInbox => 'الوارد';

  @override
  String get navPayments => 'المدفوعات';

  @override
  String get navReviews => 'التقييمات';

  @override
  String get navDiscover => 'اكتشفي';

  @override
  String get navAppointments => 'مواعيدي';

  @override
  String get navProfile => 'حسابي';

  @override
  String get navMyDay => 'يومي';

  @override
  String get navMore => 'المزيد';

  @override
  String get navPlatform => 'المنصة';

  @override
  String get newBooking => 'حجز جديد';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'مساء النور';

  @override
  String get summaryAppointments => 'المواعيد';

  @override
  String get summaryConfirmed => 'مؤكدة';

  @override
  String get summaryPending => 'قيد الانتظار';

  @override
  String get summaryCompleted => 'مكتملة';

  @override
  String get summaryRevenue => 'إيرادات اليوم';

  @override
  String summaryExpected(String amount) {
    return '$amount محجوزة اليوم';
  }

  @override
  String get todaysSchedule => 'جدول اليوم';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get quickCustomer => 'عميلة';

  @override
  String get quickService => 'خدمة';

  @override
  String get quickBlockTime => 'حجب وقت';

  @override
  String get nextUp => 'الموعد التالي';

  @override
  String inMinutes(int minutes) {
    return 'بعد $minutes دقيقة';
  }

  @override
  String get emptyTodayTitle => 'لا مواعيد اليوم';

  @override
  String get emptyTodayBody => 'يوم هادئ. شاركي رابط الحجز ودعي التقويم يمتلئ.';

  @override
  String get weekRevenue => 'آخر ٧ أيام';

  @override
  String pendingRefunds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مبالغ مستردة بانتظار التسوية',
      one: 'مبلغ مسترد واحد بانتظار التسوية',
    );
    return '$_temp0';
  }

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusConfirmed => 'مؤكد';

  @override
  String get statusArrived => 'وصلت';

  @override
  String get statusInService => 'قيد الخدمة';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusNoShow => 'لم تحضر';

  @override
  String get calendarDay => 'يوم';

  @override
  String get calendarWeek => 'أسبوع';

  @override
  String get calendarMonth => 'شهر';

  @override
  String get calendarAllStaff => 'كل الفريق';

  @override
  String get calendarClosed => 'مغلق';

  @override
  String get calendarBlocked => 'محجوب';

  @override
  String get calendarTimeOff => 'إجازة';

  @override
  String get calendarDayOff => 'يوم عطلة';

  @override
  String get calendarJumpToday => 'اليوم';

  @override
  String get calendarPrevious => 'السابق';

  @override
  String get calendarNext => 'التالي';

  @override
  String calendarBookingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حجزاً',
      few: '$count حجوزات',
      two: 'حجزان',
      one: 'حجز واحد',
      zero: 'لا حجوزات',
    );
    return '$_temp0';
  }

  @override
  String get bookingDetails => 'الموعد';

  @override
  String get bookingReference => 'رقم الحجز';

  @override
  String get bookingClient => 'العميلة';

  @override
  String get bookingService => 'الخدمة';

  @override
  String get bookingArtist => 'الفنانة';

  @override
  String get bookingWhen => 'الموعد';

  @override
  String get bookingDuration => 'المدة';

  @override
  String get bookingPrice => 'السعر';

  @override
  String get bookingDeposit => 'العربون';

  @override
  String get bookingPaid => 'المدفوع';

  @override
  String get bookingBalance => 'المتبقي';

  @override
  String get bookingClientNotes => 'ملاحظة العميلة';

  @override
  String get bookingInternalNotes => 'ملاحظات الفريق الخاصة';

  @override
  String get bookingInternalNotesHint => 'لا يراها إلا فريقك';

  @override
  String get bookingMarkArrived => 'وصلت';

  @override
  String get bookingStartService => 'بدء الخدمة';

  @override
  String get bookingMarkCompleted => 'إكمال';

  @override
  String get bookingMarkNoShow => 'لم تحضر';

  @override
  String get bookingConfirm => 'تأكيد الحجز';

  @override
  String get bookingCancel => 'إلغاء الموعد';

  @override
  String get bookingReschedule => 'تغيير الموعد';

  @override
  String get bookingRecordPayment => 'تسجيل دفعة';

  @override
  String get bookingHistory => 'السجل';

  @override
  String get bookingCancelTitle => 'إلغاء هذا الموعد؟';

  @override
  String get bookingCancelBody =>
      'سيتم إشعار العميلة، وأي عربون مدفوع سيُسجَّل كمبلغ مسترد.';

  @override
  String get bookingCancelReason => 'السبب (اختياري)';

  @override
  String get bookingCancelled => 'تم إلغاء الموعد';

  @override
  String get bookingRestored => 'تم التراجع عن الإلغاء';

  @override
  String get bookingStatusUpdated => 'تم تحديث الحالة';

  @override
  String get bookingNotesSaved => 'تم حفظ الملاحظات';

  @override
  String get bookingRescheduled => 'تم تغيير الموعد ✨';

  @override
  String get historyCreated => 'تم الحجز';

  @override
  String historyRescheduled(String from, String to) {
    return 'نُقل من $from إلى $to';
  }

  @override
  String historyStatus(String status) {
    return 'تم التحديث إلى $status';
  }

  @override
  String get historyNote => 'تم تحديث الملاحظات';

  @override
  String historyBy(String name) {
    return 'بواسطة $name';
  }

  @override
  String get sourceWalkIn => 'حضور مباشر';

  @override
  String get sourceOnline => 'أونلاين';

  @override
  String get sourceApp => 'التطبيق';

  @override
  String get sourceAdmin => 'الاستقبال';

  @override
  String get wizardClient => 'العميلة';

  @override
  String get wizardService => 'الخدمة';

  @override
  String get wizardArtist => 'الفنانة';

  @override
  String get wizardDateTime => 'التاريخ والوقت';

  @override
  String get wizardConfirm => 'تأكيد';

  @override
  String get wizardSearchClients => 'ابحثي بالاسم أو الهاتف';

  @override
  String get wizardNewClient => 'عميلة جديدة';

  @override
  String get wizardWalkIn => 'حضور مباشر';

  @override
  String get wizardMarkArrived => 'العميلة موجودة الآن';

  @override
  String get wizardNotifyClient => 'إرسال تأكيد للعميلة';

  @override
  String get wizardCreate => 'احجزي الموعد';

  @override
  String get wizardCreated => 'تم حجز الموعد ✨';

  @override
  String get anyArtist => 'أي فنانة متاحة';

  @override
  String get anyArtistBody => 'سنختار لكِ أول فنانة متاحة.';

  @override
  String get noSlotsTitle => 'محجوز بالكامل';

  @override
  String get noSlotsBody =>
      'لا أوقات متاحة في هذا اليوم. جربي تاريخاً أو فنانة أخرى.';

  @override
  String get slotMorning => 'صباحاً';

  @override
  String get slotAfternoon => 'ظهراً';

  @override
  String get slotEvening => 'مساءً';

  @override
  String get customersTitle => 'العملاء';

  @override
  String get customersSearch => 'ابحثي عن عميلة';

  @override
  String get customersEmptyTitle => 'لا يوجد عملاء بعد';

  @override
  String get customersEmptyBody =>
      'ستظهر العميلات هنا عند الحجز، ويمكنك إضافتهن بنفسك أيضاً.';

  @override
  String get customerAdd => 'إضافة عميلة';

  @override
  String get customerEdit => 'تعديل العميلة';

  @override
  String get customerTotalSpent => 'إجمالي الإنفاق';

  @override
  String get customerVisits => 'الزيارات';

  @override
  String get customerLastVisit => 'آخر زيارة';

  @override
  String get customerUpcoming => 'الموعد القادم';

  @override
  String get customerHistory => 'سجل الحجوزات';

  @override
  String get customerPrivateNotes => 'ملاحظات خاصة';

  @override
  String get customerPrivateNotesHint =>
      'حساسية، تفضيلات… لا تظهر للعميلة أبداً';

  @override
  String get customerBirthday => 'تاريخ الميلاد';

  @override
  String get customerPreferredArtist => 'الفنانة المفضلة';

  @override
  String get customerFavoriteService => 'الخدمة المفضلة';

  @override
  String get customerNoShows => 'عدم حضور';

  @override
  String get customerCancellations => 'الإلغاءات';

  @override
  String get customerNever => 'لا يوجد';

  @override
  String get customerSaved => 'تم حفظ العميلة 💕';

  @override
  String get customerBookNow => 'احجزي لهذه العميلة';

  @override
  String get servicesTitle => 'الخدمات';

  @override
  String get serviceAdd => 'إضافة خدمة';

  @override
  String get serviceEdit => 'تعديل الخدمة';

  @override
  String get serviceName => 'اسم الخدمة';

  @override
  String get serviceNameAr => 'الاسم بالعربية';

  @override
  String get serviceDescription => 'الوصف';

  @override
  String get serviceDescriptionAr => 'الوصف بالعربية';

  @override
  String get serviceCategory => 'الفئة';

  @override
  String get serviceUncategorized => 'أخرى';

  @override
  String get servicePrice => 'السعر (ر.ع)';

  @override
  String get serviceDuration => 'المدة (دقيقة)';

  @override
  String get serviceBuffer => 'وقت التجهيز بعد الموعد (دقيقة)';

  @override
  String get serviceBufferHelp => 'وقت محجوب بعد كل موعد للترتيب.';

  @override
  String get serviceActive => 'متاحة للحجز';

  @override
  String get servicePayment => 'الدفع عند الحجز';

  @override
  String get servicePayNone => 'لا يوجد';

  @override
  String get servicePayDeposit => 'عربون';

  @override
  String get servicePayFull => 'كامل';

  @override
  String get serviceDepositAmount => 'العربون (ر.ع)';

  @override
  String get serviceWhoPerforms => 'من تقدم الخدمة';

  @override
  String get serviceEmptyTitle => 'لا توجد خدمات بعد';

  @override
  String get serviceEmptyBody => 'أضيفي قائمة خدماتك لتبدأ العميلات بالحجز.';

  @override
  String get serviceDeleteConfirm =>
      'إزالة هذه الخدمة؟ ستبقى الحجوزات السابقة.';

  @override
  String get serviceSaved => 'تم حفظ الخدمة ✨';

  @override
  String get serviceInactive => 'مخفية';

  @override
  String get staffTitle => 'الموظفات';

  @override
  String get staffAdd => 'إضافة موظفة';

  @override
  String get staffEdit => 'تعديل الموظفة';

  @override
  String get staffName => 'الاسم';

  @override
  String get staffNameAr => 'الاسم بالعربية';

  @override
  String get staffJobTitle => 'المسمى';

  @override
  String get staffColor => 'لون التقويم';

  @override
  String get staffHours => 'ساعات العمل';

  @override
  String get staffDayOff => 'عطلة';

  @override
  String get staffTimeOff => 'الإجازات';

  @override
  String get staffAddTimeOff => 'إضافة إجازة';

  @override
  String get staffVacation => 'إجازة';

  @override
  String get staffSick => 'مرضية';

  @override
  String get staffOther => 'أخرى';

  @override
  String get staffFrom => 'من';

  @override
  String get staffTo => 'إلى';

  @override
  String get staffServices => 'الخدمات المقدمة';

  @override
  String get staffActive => 'تستقبل حجوزات';

  @override
  String get staffInactive => 'غير نشطة';

  @override
  String get staffEmptyTitle => 'كوّني فريق أحلامك';

  @override
  String get staffEmptyBody => 'أضيفي فناناتك لتختار العميلات مع من يحجزن.';

  @override
  String get staffSaved => 'تم حفظ الموظفة 💕';

  @override
  String get staffHasLogin => 'لديها حساب دخول';

  @override
  String get staffTimeOffSaved => 'تم حفظ الإجازة';

  @override
  String staffClashes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يوجد $count حجوزات في هذا الوقت.',
      one: 'يوجد حجز واحد في هذا الوقت.',
    );
    return '$_temp0 الحفظ على أي حال؟';
  }

  @override
  String get saveAnyway => 'الحفظ على أي حال';

  @override
  String get blockTitle => 'حجب وقت';

  @override
  String get blockType => 'السبب';

  @override
  String get blockLunch => 'غداء';

  @override
  String get blockBreak => 'استراحة';

  @override
  String get blockPersonal => 'شخصي';

  @override
  String get blockMeeting => 'اجتماع';

  @override
  String get blockPrivate => 'حجز خاص';

  @override
  String get blockOther => 'أخرى';

  @override
  String get blockWholeSalon => 'الصالون بالكامل';

  @override
  String get blockSaved => 'تم حجب الوقت';

  @override
  String get blockStart => 'يبدأ';

  @override
  String get blockEnd => 'ينتهي';

  @override
  String get reportsTitle => 'التقارير';

  @override
  String get reportsLast7 => '٧ أيام';

  @override
  String get reportsLast30 => '٣٠ يوماً';

  @override
  String get reportsLast90 => '٩٠ يوماً';

  @override
  String get reportsRevenue => 'الإيرادات';

  @override
  String get reportsBookings => 'الحجوزات';

  @override
  String get reportsCancellationRate => 'نسبة الإلغاء';

  @override
  String get reportsNoShowRate => 'نسبة عدم الحضور';

  @override
  String get reportsPopularServices => 'الخدمات الأكثر طلباً';

  @override
  String get reportsStaffPerformance => 'أداء الفريق';

  @override
  String get reportsNewClients => 'عميلات جدد';

  @override
  String get reportsReturningClients => 'عميلات عائدات';

  @override
  String get reportsRetention => 'نسبة العودة';

  @override
  String get reportsDaily => 'يومي';

  @override
  String get reportsWeekly => 'أسبوعي';

  @override
  String get reportsMonthly => 'شهري';

  @override
  String reportsCompleted(int count) {
    return '$count مكتمل';
  }

  @override
  String reportsAvgPerDay(String amount) {
    return '$amount / يوم';
  }

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsMarkAll => 'تعليم الكل كمقروء';

  @override
  String get notificationsEmptyTitle => 'لا جديد';

  @override
  String get notificationsEmptyBody => 'ستظهر هنا تحديثات الحجوزات والتذكيرات.';

  @override
  String get paymentsTitle => 'المدفوعات';

  @override
  String get paymentsCollected => 'المحصّل';

  @override
  String get paymentsRefunded => 'المسترد';

  @override
  String get paymentsNet => 'الصافي';

  @override
  String get paymentsOwed => 'مبالغ مستردة مستحقة';

  @override
  String get paymentsSettle => 'تسوية المبلغ المسترد';

  @override
  String get paymentsSettled => 'تم تسجيل الاسترداد';

  @override
  String get paymentsEmpty => 'لا توجد مدفوعات في هذه الفترة.';

  @override
  String get paymentAmount => 'المبلغ (ر.ع)';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get paymentKind => 'مقابل';

  @override
  String get paymentRecorded => 'تم تسجيل الدفعة';

  @override
  String get methodCash => 'نقداً';

  @override
  String get methodCard => 'بطاقة';

  @override
  String get methodBank => 'تحويل بنكي';

  @override
  String get methodOnline => 'أونلاين';

  @override
  String get kindDeposit => 'عربون';

  @override
  String get kindBalance => 'المتبقي';

  @override
  String get kindFull => 'دفع كامل';

  @override
  String get kindFee => 'رسوم إلغاء';

  @override
  String get kindRefund => 'استرداد';

  @override
  String get paymentStatusPending => 'قيد الانتظار';

  @override
  String get paymentStatusPaid => 'مدفوع';

  @override
  String get reviewsTitle => 'التقييمات';

  @override
  String get reviewsReply => 'رد';

  @override
  String get reviewsReplyHint => 'اشكريها على زيارتها…';

  @override
  String get reviewsReplied => 'تم نشر الرد';

  @override
  String get reviewsEmpty => 'لا توجد تقييمات بعد.';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييماً',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String get reviewsSalonReply => 'رد الصالون';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSalonProfile => 'ملف الصالون';

  @override
  String get settingsBookingRules => 'قواعد الحجز';

  @override
  String get settingsSlotInterval => 'الفاصل بين الأوقات';

  @override
  String get settingsMinNotice => 'أقل مدة قبل الحجز أونلاين';

  @override
  String get settingsHorizon => 'إلى أي مدى يمكن الحجز مسبقاً';

  @override
  String settingsHorizonDays(int days) {
    return '$days يوماً';
  }

  @override
  String get settingsAutoConfirm => 'تأكيد الحجوزات الإلكترونية تلقائياً';

  @override
  String get settingsCancellation => 'سياسة الإلغاء';

  @override
  String get settingsCancellationWindow => 'إلغاء مجاني حتى';

  @override
  String settingsHoursBefore(int hours) {
    return '$hours ساعة قبل الموعد';
  }

  @override
  String get settingsLateFee => 'رسوم الإلغاء المتأخر (ر.ع)';

  @override
  String get settingsDepositPolicy => 'العربون عند الإلغاء في الوقت';

  @override
  String get settingsDepositRefundable => 'يُسترد';

  @override
  String get settingsDepositNonRefundable => 'لا يُسترد';

  @override
  String get settingsAllowReschedule => 'السماح للعميلات بتغيير الموعد أونلاين';

  @override
  String get settingsChannels => 'قنوات الإشعارات';

  @override
  String get settingsChannelsBody =>
      'اختاري كيف تصل التأكيدات والتذكيرات للعميلات.';

  @override
  String get channelInApp => 'داخل التطبيق';

  @override
  String get channelPush => 'إشعارات الهاتف';

  @override
  String get channelWhatsapp => 'واتساب';

  @override
  String get channelEmail => 'البريد الإلكتروني';

  @override
  String get channelSms => 'رسائل SMS';

  @override
  String get channelNotConfigured => 'لم يتم ربط المزود بعد';

  @override
  String get settingsReminders => 'التذكيرات التلقائية';

  @override
  String get settingsRemind24h => 'قبل ٢٤ ساعة';

  @override
  String get settingsRemind3h => 'قبل ٣ ساعات';

  @override
  String get settingsReviewRequests => 'طلب تقييم بعد الزيارة';

  @override
  String get settingsOpeningHours => 'ساعات العمل';

  @override
  String get settingsHolidays => 'العطلات والساعات الخاصة';

  @override
  String get settingsAddHoliday => 'إضافة إغلاق';

  @override
  String get settingsClosedAllDay => 'مغلق طوال اليوم';

  @override
  String get settingsSpecialHours => 'ساعات خاصة';

  @override
  String get settingsHolidayName => 'المناسبة';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsBookingLink => 'صفحة الحجز الخاصة بك';

  @override
  String get settingsBookingLinkBody =>
      'شاركي هذا الرابط على إنستغرام وواتساب — تحجز العميلات دون تحميل أي تطبيق.';

  @override
  String get settingsCopyLink => 'نسخ الرابط';

  @override
  String get settingsLinkCopied => 'تم نسخ الرابط';

  @override
  String get settingsOpenPage => 'فتح الصفحة';

  @override
  String get settingsDeliveryLog => 'سجل الإرسال';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsTagline => 'الشعار';

  @override
  String get settingsDescription => 'عن الصالون';

  @override
  String get settingsAddress => 'العنوان';

  @override
  String get settingsWhatsapp => 'رقم واتساب';

  @override
  String get settingsPhone => 'الهاتف';

  @override
  String get settingsPublished => 'ظاهر للعميلات';

  @override
  String get settingsClosed => 'مغلق';

  @override
  String get settingsOpens => 'يفتح';

  @override
  String get settingsCloses => 'يغلق';

  @override
  String get settingsTeamAccess => 'حسابات الفريق';

  @override
  String get settingsRole => 'الدور';

  @override
  String get roleOwner => 'المالكة';

  @override
  String get roleManager => 'مديرة';

  @override
  String get roleReceptionist => 'الاستقبال';

  @override
  String get roleStaff => 'فنانة';

  @override
  String get discoverTitle => 'اكتشفي إطلالتك';

  @override
  String get discoverSubtitle =>
      'احجزي لدى أفضل خبيرات المكياج والصالونات بالقرب منك.';

  @override
  String get discoverSearch => 'ابحثي عن صالون أو خدمة';

  @override
  String get discoverEmpty => 'لا توجد صالونات مطابقة لبحثك.';

  @override
  String get catAll => 'الكل';

  @override
  String get catMakeup => 'مكياج';

  @override
  String get catBeauty => 'تجميل';

  @override
  String get catHair => 'شعر';

  @override
  String get catStudio => 'استوديو';

  @override
  String get catArtist => 'فنانات';

  @override
  String fromPrice(String amount) {
    return 'يبدأ من $amount';
  }

  @override
  String get salonBook => 'احجزي موعداً';

  @override
  String get salonAbout => 'نبذة';

  @override
  String get salonHours => 'ساعات العمل';

  @override
  String get salonLocation => 'الموقع';

  @override
  String get salonReviews => 'التقييمات';

  @override
  String get salonTeam => 'فناناتنا';

  @override
  String get salonServices => 'الخدمات';

  @override
  String salonOpenNow(String hours) {
    return 'مفتوح اليوم · $hours';
  }

  @override
  String get salonClosedToday => 'مغلق اليوم';

  @override
  String get salonCall => 'اتصال';

  @override
  String get salonWhatsapp => 'واتساب';

  @override
  String get salonDirections => 'الاتجاهات';

  @override
  String get salonSave => 'حفظ';

  @override
  String get salonSaved => 'محفوظ';

  @override
  String get salonNotFound => 'لم نتمكن من العثور على هذا الصالون.';

  @override
  String get salonNextAvailable => 'أقرب موعد متاح';

  @override
  String get salonUpcomingClosures => 'أيام الإغلاق القادمة';

  @override
  String get flowService => 'الخدمة';

  @override
  String get flowArtist => 'الفنانة';

  @override
  String get flowTime => 'التاريخ والوقت';

  @override
  String get flowDetails => 'بياناتك';

  @override
  String get flowConfirm => 'التأكيد';

  @override
  String get flowChooseService => 'ماذا نحضّر لكِ اليوم؟';

  @override
  String get flowChooseArtist => 'مع من تحبين الحجز؟';

  @override
  String get flowChooseTime => 'اختاري الوقت';

  @override
  String get flowYourDetails => 'اقتربنا';

  @override
  String get flowReview => 'المراجعة والتأكيد';

  @override
  String get flowNotes => 'هل هناك ما يجب أن نعرفه؟';

  @override
  String get flowNotesHint => 'مثل: صورة إلهام، حساسية، وقت المناسبة';

  @override
  String get flowTotal => 'الإجمالي';

  @override
  String get flowDepositDue => 'العربون المستحق الآن';

  @override
  String get flowPayAtSalon => 'الدفع في الصالون';

  @override
  String get flowRemaining => 'المتبقي في الصالون';

  @override
  String get flowPolicy => 'سياسة الإلغاء';

  @override
  String flowPolicyFree(int hours) {
    return 'إلغاء مجاني حتى $hours ساعة قبل موعدك.';
  }

  @override
  String get flowPolicyDeposit => 'بعد ذلك لا يُسترد العربون.';

  @override
  String flowPolicyFee(String amount) {
    return 'قد تُفرض رسوم $amount على الإلغاء المتأخر.';
  }

  @override
  String get flowBook => 'تأكيد الحجز';

  @override
  String get flowBookAndPay => 'احجزي وادفعي العربون';

  @override
  String get flowConfirmed => 'تم تأكيد موعدك';

  @override
  String get flowConfirmedBody => 'بانتظار رؤيتك 💕';

  @override
  String get flowHeld => 'تم حجز مكانك مؤقتاً';

  @override
  String get flowHeldBody => 'ادفعي العربون خلال ٣٠ دقيقة لتأكيده.';

  @override
  String get flowViewAppointment => 'عرض الموعد';

  @override
  String get flowBookAnother => 'حجز آخر';

  @override
  String get flowDone => 'تم';

  @override
  String get flowSlotTaken =>
      'حجز أحدهم هذا الوقت للتو. إليك أحدث الأوقات المتاحة.';

  @override
  String get flowSignInHint =>
      'لديكِ حساب؟ سجّلي الدخول لتري هذا الحجز في التطبيق.';

  @override
  String get flowManageLinkHint =>
      'احتفظي بهذه الصفحة — يمكنك من خلالها عرض الحجز أو إلغاؤه.';

  @override
  String get payTitle => 'دفع العربون';

  @override
  String get payTestMode => 'وضع تجريبي — لن يتم خصم أي مبلغ فعلي.';

  @override
  String get payCardNumber => 'رقم البطاقة';

  @override
  String payNow(String amount) {
    return 'ادفعي $amount';
  }

  @override
  String get paySuccess => 'تم استلام الدفعة 💕';

  @override
  String get payUnavailable =>
      'الدفع الإلكتروني غير متاح بعد — يرجى الدفع في الصالون.';

  @override
  String get myUpcoming => 'القادمة';

  @override
  String get myPast => 'السابقة';

  @override
  String get myEmptyTitle => 'لا مواعيد بعد';

  @override
  String get myEmptyBody => 'إطلالتك القادمة على بُعد لمسات.';

  @override
  String get myDiscover => 'اكتشفي الصالونات';

  @override
  String get myCancel => 'إلغاء الموعد';

  @override
  String myCancelFree(String when) {
    return 'إلغاء مجاني حتى $when.';
  }

  @override
  String myCancelLate(int hours, String amount) {
    return 'تبقّى أقل من $hours ساعة على موعدك — قد يُحتفظ بمبلغ $amount.';
  }

  @override
  String myCancelRefund(String amount) {
    return 'سيتم استرداد $amount.';
  }

  @override
  String get myReschedule => 'تغيير الموعد';

  @override
  String get myRescheduleTitle => 'اختاري وقتاً جديداً';

  @override
  String get myLeaveReview => 'أضيفي تقييماً';

  @override
  String get myReviewTitle => 'كيف كانت زيارتك؟';

  @override
  String get myReviewHint => 'شاركي تجربتك (اختياري)';

  @override
  String get myReviewSubmit => 'نشر التقييم';

  @override
  String get myReviewThanks => 'شكراً لتقييمك 💕';

  @override
  String get myYourReview => 'تقييمك';

  @override
  String get myPayDeposit => 'دفع العربون';

  @override
  String get myDirections => 'الاتجاهات';

  @override
  String get profileTitle => 'حسابي';

  @override
  String get profileFavorites => 'الصالونات المفضلة';

  @override
  String get profileNoFavorites => 'اضغطي على القلب في أي صالون لحفظه هنا.';

  @override
  String get profileEdit => 'تعديل الحساب';

  @override
  String get profileSaved => 'تم حفظ الحساب';

  @override
  String get platformTitle => 'نظرة على المنصة';

  @override
  String get platformSalons => 'الصالونات';

  @override
  String get platformActive => 'نشطة (٣٠ يوماً)';

  @override
  String get platformUsers => 'المستخدمون';

  @override
  String get platformBookings => 'الحجوزات (٣٠ يوماً)';

  @override
  String get platformGmv => 'المدفوعات (٣٠ يوماً)';

  @override
  String get platformTenants => 'الصالونات المشتركة';

  @override
  String get platformPublished => 'ظاهر';

  @override
  String get platformHidden => 'مخفي';

  @override
  String get platformPlan => 'الباقة';

  @override
  String get flowStepChoose => 'اختاري';

  @override
  String get flowStepDetails => 'بياناتك';

  @override
  String get flowStepVerify => 'التحقق';

  @override
  String get flowServicesTitle => 'الخدمات';

  @override
  String get flowArtistTitle => 'الفنانة';

  @override
  String get flowDateTitle => 'التاريخ';

  @override
  String get flowTimeTitle => 'الوقت';

  @override
  String get flowPickServiceFirst => 'اختاري خدمة لعرض الأوقات المتاحة.';

  @override
  String get flowNoCommonArtist =>
      'لا توجد فنانة واحدة تقدم كل هذه الخدمات معاً. جربي خدمات أقل.';

  @override
  String get flowDayFull => 'محجوز بالكامل في هذا اليوم.';

  @override
  String flowNextAvailable(String date) {
    return 'أقرب موعد: $date';
  }

  @override
  String get flowNoAvailability =>
      'لا توجد أوقات متاحة خلال الأسابيع الثلاثة القادمة.';

  @override
  String flowServicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خدمة',
      few: '$count خدمات',
      two: 'خدمتان',
      one: 'خدمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get flowSendCode => 'إرسال رمز التحقق';

  @override
  String get flowPhoneHelp => 'سنرسل رمزاً من ٦ أرقام لتأكيد رقمك.';

  @override
  String get flowVerifyTitle => 'تأكيد رقمك';

  @override
  String flowVerifyBody(String phone) {
    return 'أدخلي الرمز المكوّن من ٦ أرقام المرسل إلى $phone';
  }

  @override
  String flowResendIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get flowResend => 'إعادة إرسال الرمز';

  @override
  String get flowCodeResent => 'تم إرسال رمز جديد.';

  @override
  String get flowChangeNumber => 'تغيير الرقم';

  @override
  String flowTestCode(String code) {
    return 'وضع تجريبي — رمزك هو $code';
  }

  @override
  String flowWith(String name) {
    return 'مع $name';
  }

  @override
  String get flowEnterCode => 'رمز التحقق';

  @override
  String get flowVerifiedAccount => 'رقمك موثّق مسبقاً — يمكنك التأكيد مباشرة.';

  @override
  String get anyArtistShort => 'أي فنانة';
}
