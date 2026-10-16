// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Glowbook';

  @override
  String get appTagline => 'Beauty bookings, beautifully managed.';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaveChanges => 'Save changes';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDone => 'Done';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionClose => 'Close';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionKeep => 'Keep it';

  @override
  String get labelOptional => 'Optional';

  @override
  String get labelSearch => 'Search';

  @override
  String get labelToday => 'Today';

  @override
  String get labelTomorrow => 'Tomorrow';

  @override
  String get labelYesterday => 'Yesterday';

  @override
  String labelMinutes(int count) {
    return '$count min';
  }

  @override
  String labelHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String labelHours(int hours) {
    return '$hours h';
  }

  @override
  String money(String amount) {
    return 'OMR $amount';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorOffline =>
      'You seem to be offline. Check your connection and try again.';

  @override
  String get errorRequired => 'Required';

  @override
  String get errorEmail => 'Enter a valid email address';

  @override
  String get errorPhone => 'Enter a valid phone number';

  @override
  String get errorPasswordShort => 'At least 8 characters';

  @override
  String get errorNumber => 'Enter a number';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInSubtitle =>
      'Sign in to manage your bookings and glow on.';

  @override
  String get authEmailOrPhone => 'Email or phone';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNoAccount => 'New to Glowbook?';

  @override
  String get authCreateAccount => 'Create an account';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotTitle => 'Reset your password';

  @override
  String get authForgotBody =>
      'Enter your email and we\'ll send you a link to choose a new password.';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authResetSent =>
      'If an account exists for that email, a reset link is on its way.';

  @override
  String get authDevResetHint =>
      'Development mode: no email provider is configured, so use the link below.';

  @override
  String get authOpenResetLink => 'Open reset link';

  @override
  String get authResetTitle => 'Choose a new password';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authPasswordUpdated => 'Password updated. Please sign in.';

  @override
  String get authFullName => 'Full name';

  @override
  String get authPhone => 'Phone number';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authRegisterSubtitle => 'Book your favourite salons in seconds.';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authOwnSalon => 'Own a salon or studio?';

  @override
  String get authRegisterSalon => 'Set up your salon';

  @override
  String get authRegisterSalonTitle => 'Bring your salon to Glowbook';

  @override
  String get authRegisterSalonSubtitle =>
      'Calendar, bookings, reminders and payments — free for 30 days.';

  @override
  String get authSalonName => 'Salon name';

  @override
  String get authCity => 'City';

  @override
  String get authStartTrial => 'Start free trial';

  @override
  String get authPhoneSignIn => 'Continue with phone';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authEnterCode => 'Enter the 6-digit code';

  @override
  String authCodeSentTo(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String authDevCodeHint(String code) {
    return 'Development mode code: $code';
  }

  @override
  String get authVerify => 'Verify';

  @override
  String get authOr => 'or';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutConfirm => 'Sign out of Glowbook?';

  @override
  String get authDemoAccounts => 'Demo accounts';

  @override
  String get navHome => 'Home';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navCustomers => 'Clients';

  @override
  String get navServices => 'Services';

  @override
  String get navStaff => 'Team';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navPayments => 'Payments';

  @override
  String get navReviews => 'Reviews';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navProfile => 'Profile';

  @override
  String get navMyDay => 'My day';

  @override
  String get navMore => 'More';

  @override
  String get navPlatform => 'Platform';

  @override
  String get newBooking => 'New booking';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get summaryAppointments => 'Appointments';

  @override
  String get summaryConfirmed => 'Confirmed';

  @override
  String get summaryPending => 'Pending';

  @override
  String get summaryCompleted => 'Completed';

  @override
  String get summaryRevenue => 'Revenue today';

  @override
  String summaryExpected(String amount) {
    return '$amount booked today';
  }

  @override
  String get todaysSchedule => 'Today\'s schedule';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get quickCustomer => 'Client';

  @override
  String get quickService => 'Service';

  @override
  String get quickBlockTime => 'Block time';

  @override
  String get nextUp => 'Next up';

  @override
  String inMinutes(int minutes) {
    return 'in $minutes min';
  }

  @override
  String get emptyTodayTitle => 'No appointments today';

  @override
  String get emptyTodayBody =>
      'A quiet day. Share your booking link and let the calendar fill up.';

  @override
  String get weekRevenue => 'Last 7 days';

  @override
  String pendingRefunds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count refunds to settle',
      one: '1 refund to settle',
    );
    return '$_temp0';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusArrived => 'Arrived';

  @override
  String get statusInService => 'In service';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusNoShow => 'No show';

  @override
  String get calendarDay => 'Day';

  @override
  String get calendarWeek => 'Week';

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarAllStaff => 'All team';

  @override
  String get calendarClosed => 'Closed';

  @override
  String get calendarBlocked => 'Blocked';

  @override
  String get calendarTimeOff => 'Time off';

  @override
  String get calendarDayOff => 'Day off';

  @override
  String get calendarJumpToday => 'Today';

  @override
  String get calendarPrevious => 'Previous';

  @override
  String get calendarNext => 'Next';

  @override
  String calendarBookingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings',
      one: '1 booking',
      zero: 'No bookings',
    );
    return '$_temp0';
  }

  @override
  String get bookingDetails => 'Appointment';

  @override
  String get bookingReference => 'Reference';

  @override
  String get bookingClient => 'Client';

  @override
  String get bookingService => 'Service';

  @override
  String get bookingArtist => 'Artist';

  @override
  String get bookingWhen => 'When';

  @override
  String get bookingDuration => 'Duration';

  @override
  String get bookingPrice => 'Price';

  @override
  String get bookingDeposit => 'Deposit';

  @override
  String get bookingPaid => 'Paid';

  @override
  String get bookingBalance => 'Balance due';

  @override
  String get bookingClientNotes => 'Note from client';

  @override
  String get bookingInternalNotes => 'Private team notes';

  @override
  String get bookingInternalNotesHint => 'Only your team can see this';

  @override
  String get bookingMarkArrived => 'Mark arrived';

  @override
  String get bookingStartService => 'Start service';

  @override
  String get bookingMarkCompleted => 'Complete';

  @override
  String get bookingMarkNoShow => 'No show';

  @override
  String get bookingConfirm => 'Confirm booking';

  @override
  String get bookingCancel => 'Cancel appointment';

  @override
  String get bookingReschedule => 'Reschedule';

  @override
  String get bookingRecordPayment => 'Record payment';

  @override
  String get bookingHistory => 'History';

  @override
  String get bookingCancelTitle => 'Cancel this appointment?';

  @override
  String get bookingCancelBody =>
      'The client will be notified. Any deposit paid is recorded as a refund to settle.';

  @override
  String get bookingCancelReason => 'Reason (optional)';

  @override
  String get bookingCancelled => 'Appointment cancelled';

  @override
  String get bookingRestored => 'Cancellation undone';

  @override
  String get bookingStatusUpdated => 'Status updated';

  @override
  String get bookingNotesSaved => 'Notes saved';

  @override
  String get bookingRescheduled => 'Appointment moved ✨';

  @override
  String get historyCreated => 'Booked';

  @override
  String historyRescheduled(String from, String to) {
    return 'Moved from $from to $to';
  }

  @override
  String historyStatus(String status) {
    return 'Marked $status';
  }

  @override
  String get historyNote => 'Notes updated';

  @override
  String historyBy(String name) {
    return 'by $name';
  }

  @override
  String get sourceWalkIn => 'Walk-in';

  @override
  String get sourceOnline => 'Online';

  @override
  String get sourceApp => 'App';

  @override
  String get sourceAdmin => 'Front desk';

  @override
  String get wizardClient => 'Client';

  @override
  String get wizardService => 'Service';

  @override
  String get wizardArtist => 'Artist';

  @override
  String get wizardDateTime => 'Date & time';

  @override
  String get wizardConfirm => 'Confirm';

  @override
  String get wizardSearchClients => 'Search by name or phone';

  @override
  String get wizardNewClient => 'New client';

  @override
  String get wizardWalkIn => 'Walk-in';

  @override
  String get wizardMarkArrived => 'Client is here now';

  @override
  String get wizardNotifyClient => 'Send confirmation to client';

  @override
  String get wizardCreate => 'Book appointment';

  @override
  String get wizardCreated => 'Appointment booked ✨';

  @override
  String get anyArtist => 'Any available';

  @override
  String get anyArtistBody => 'We\'ll match you with the first free artist.';

  @override
  String get noSlotsTitle => 'Fully booked';

  @override
  String get noSlotsBody =>
      'No free times on this day. Try another date or artist.';

  @override
  String get slotMorning => 'Morning';

  @override
  String get slotAfternoon => 'Afternoon';

  @override
  String get slotEvening => 'Evening';

  @override
  String get customersTitle => 'Clients';

  @override
  String get customersSearch => 'Search clients';

  @override
  String get customersEmptyTitle => 'No clients yet';

  @override
  String get customersEmptyBody =>
      'Clients appear here as they book. You can also add them yourself.';

  @override
  String get customerAdd => 'Add client';

  @override
  String get customerEdit => 'Edit client';

  @override
  String get customerTotalSpent => 'Total spent';

  @override
  String get customerVisits => 'Visits';

  @override
  String get customerLastVisit => 'Last visit';

  @override
  String get customerUpcoming => 'Upcoming';

  @override
  String get customerHistory => 'Booking history';

  @override
  String get customerPrivateNotes => 'Private notes';

  @override
  String get customerPrivateNotesHint =>
      'Allergies, preferences… never shown to the client';

  @override
  String get customerBirthday => 'Birthday';

  @override
  String get customerPreferredArtist => 'Preferred artist';

  @override
  String get customerFavoriteService => 'Favourite service';

  @override
  String get customerNoShows => 'No-shows';

  @override
  String get customerCancellations => 'Cancellations';

  @override
  String get customerNever => 'Never';

  @override
  String get customerSaved => 'Client saved 💕';

  @override
  String get customerBookNow => 'Book for this client';

  @override
  String get servicesTitle => 'Services';

  @override
  String get serviceAdd => 'Add service';

  @override
  String get serviceEdit => 'Edit service';

  @override
  String get serviceName => 'Service name';

  @override
  String get serviceNameAr => 'Name in Arabic';

  @override
  String get serviceDescription => 'Description';

  @override
  String get serviceDescriptionAr => 'Description in Arabic';

  @override
  String get serviceCategory => 'Category';

  @override
  String get serviceUncategorized => 'Other';

  @override
  String get servicePrice => 'Price (OMR)';

  @override
  String get serviceDuration => 'Duration (minutes)';

  @override
  String get serviceBuffer => 'Clean-up buffer (minutes)';

  @override
  String get serviceBufferHelp =>
      'Blocked after each appointment for tidying up.';

  @override
  String get serviceActive => 'Bookable';

  @override
  String get servicePayment => 'Payment at booking';

  @override
  String get servicePayNone => 'None';

  @override
  String get servicePayDeposit => 'Deposit';

  @override
  String get servicePayFull => 'Full';

  @override
  String get serviceDepositAmount => 'Deposit (OMR)';

  @override
  String get serviceWhoPerforms => 'Who performs it';

  @override
  String get serviceEmptyTitle => 'No services yet';

  @override
  String get serviceEmptyBody => 'Add your menu so clients can start booking.';

  @override
  String get serviceDeleteConfirm =>
      'Remove this service? Past bookings are kept.';

  @override
  String get serviceSaved => 'Service saved ✨';

  @override
  String get serviceInactive => 'Hidden';

  @override
  String get staffTitle => 'Team';

  @override
  String get staffAdd => 'Add team member';

  @override
  String get staffEdit => 'Edit team member';

  @override
  String get staffName => 'Name';

  @override
  String get staffNameAr => 'Name in Arabic';

  @override
  String get staffJobTitle => 'Title';

  @override
  String get staffColor => 'Calendar colour';

  @override
  String get staffHours => 'Working hours';

  @override
  String get staffDayOff => 'Day off';

  @override
  String get staffTimeOff => 'Time off';

  @override
  String get staffAddTimeOff => 'Add time off';

  @override
  String get staffVacation => 'Vacation';

  @override
  String get staffSick => 'Sick';

  @override
  String get staffOther => 'Other';

  @override
  String get staffFrom => 'From';

  @override
  String get staffTo => 'To';

  @override
  String get staffServices => 'Services offered';

  @override
  String get staffActive => 'Taking bookings';

  @override
  String get staffInactive => 'Inactive';

  @override
  String get staffEmptyTitle => 'Build your dream team';

  @override
  String get staffEmptyBody =>
      'Add your artists so clients can choose who they book with.';

  @override
  String get staffSaved => 'Team member saved 💕';

  @override
  String get staffHasLogin => 'Has a login';

  @override
  String get staffTimeOffSaved => 'Time off saved';

  @override
  String staffClashes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings fall in this time.',
      one: '1 booking falls in this time.',
    );
    return '$_temp0 Save anyway?';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get blockTitle => 'Block time';

  @override
  String get blockType => 'Reason';

  @override
  String get blockLunch => 'Lunch';

  @override
  String get blockBreak => 'Break';

  @override
  String get blockPersonal => 'Personal';

  @override
  String get blockMeeting => 'Meeting';

  @override
  String get blockPrivate => 'Private booking';

  @override
  String get blockOther => 'Other';

  @override
  String get blockWholeSalon => 'Whole salon';

  @override
  String get blockSaved => 'Time blocked';

  @override
  String get blockStart => 'Starts';

  @override
  String get blockEnd => 'Ends';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsLast7 => '7 days';

  @override
  String get reportsLast30 => '30 days';

  @override
  String get reportsLast90 => '90 days';

  @override
  String get reportsRevenue => 'Revenue';

  @override
  String get reportsBookings => 'Bookings';

  @override
  String get reportsCancellationRate => 'Cancellation rate';

  @override
  String get reportsNoShowRate => 'No-show rate';

  @override
  String get reportsPopularServices => 'Popular services';

  @override
  String get reportsStaffPerformance => 'Team performance';

  @override
  String get reportsNewClients => 'New clients';

  @override
  String get reportsReturningClients => 'Returning clients';

  @override
  String get reportsRetention => 'Retention';

  @override
  String get reportsDaily => 'Daily';

  @override
  String get reportsWeekly => 'Weekly';

  @override
  String get reportsMonthly => 'Monthly';

  @override
  String reportsCompleted(int count) {
    return '$count completed';
  }

  @override
  String reportsAvgPerDay(String amount) {
    return '$amount / day';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAll => 'Mark all read';

  @override
  String get notificationsEmptyTitle => 'All caught up';

  @override
  String get notificationsEmptyBody =>
      'Booking updates and reminders will appear here.';

  @override
  String get paymentsTitle => 'Payments';

  @override
  String get paymentsCollected => 'Collected';

  @override
  String get paymentsRefunded => 'Refunded';

  @override
  String get paymentsNet => 'Net';

  @override
  String get paymentsOwed => 'Refunds owed';

  @override
  String get paymentsSettle => 'Settle refund';

  @override
  String get paymentsSettled => 'Refund recorded';

  @override
  String get paymentsEmpty => 'No payments in this period.';

  @override
  String get paymentAmount => 'Amount (OMR)';

  @override
  String get paymentMethod => 'Method';

  @override
  String get paymentKind => 'For';

  @override
  String get paymentRecorded => 'Payment recorded';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodCard => 'Card';

  @override
  String get methodBank => 'Bank transfer';

  @override
  String get methodOnline => 'Online';

  @override
  String get kindDeposit => 'Deposit';

  @override
  String get kindBalance => 'Balance';

  @override
  String get kindFull => 'Full payment';

  @override
  String get kindFee => 'Cancellation fee';

  @override
  String get kindRefund => 'Refund';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get paymentStatusPaid => 'Paid';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get reviewsReply => 'Reply';

  @override
  String get reviewsReplyHint => 'Thank her for visiting…';

  @override
  String get reviewsReplied => 'Reply posted';

  @override
  String get reviewsEmpty => 'No reviews yet.';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String get reviewsSalonReply => 'Reply from the salon';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSalonProfile => 'Salon profile';

  @override
  String get settingsBookingRules => 'Booking rules';

  @override
  String get settingsSlotInterval => 'Time slot interval';

  @override
  String get settingsMinNotice => 'Minimum notice for online bookings';

  @override
  String get settingsHorizon => 'How far ahead clients can book';

  @override
  String settingsHorizonDays(int days) {
    return '$days days';
  }

  @override
  String get settingsAutoConfirm => 'Confirm online bookings automatically';

  @override
  String get settingsCancellation => 'Cancellation policy';

  @override
  String get settingsCancellationWindow => 'Free cancellation up to';

  @override
  String settingsHoursBefore(int hours) {
    return '$hours hours before';
  }

  @override
  String get settingsLateFee => 'Late cancellation fee (OMR)';

  @override
  String get settingsDepositPolicy => 'Deposit when cancelled in time';

  @override
  String get settingsDepositRefundable => 'Refunded';

  @override
  String get settingsDepositNonRefundable => 'Kept';

  @override
  String get settingsAllowReschedule => 'Clients can reschedule online';

  @override
  String get settingsChannels => 'Notification channels';

  @override
  String get settingsChannelsBody =>
      'Choose how clients hear about bookings and reminders.';

  @override
  String get channelInApp => 'In-app';

  @override
  String get channelPush => 'Push';

  @override
  String get channelWhatsapp => 'WhatsApp';

  @override
  String get channelEmail => 'Email';

  @override
  String get channelSms => 'SMS';

  @override
  String get channelNotConfigured => 'Provider not connected yet';

  @override
  String get settingsReminders => 'Automatic reminders';

  @override
  String get settingsRemind24h => '24 hours before';

  @override
  String get settingsRemind3h => '3 hours before';

  @override
  String get settingsReviewRequests => 'Ask for a review after the visit';

  @override
  String get settingsOpeningHours => 'Opening hours';

  @override
  String get settingsHolidays => 'Holidays & special hours';

  @override
  String get settingsAddHoliday => 'Add closure';

  @override
  String get settingsClosedAllDay => 'Closed all day';

  @override
  String get settingsSpecialHours => 'Special hours';

  @override
  String get settingsHolidayName => 'Occasion';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsBookingLink => 'Your booking page';

  @override
  String get settingsBookingLinkBody =>
      'Share this link on Instagram and WhatsApp — clients book without downloading anything.';

  @override
  String get settingsCopyLink => 'Copy link';

  @override
  String get settingsLinkCopied => 'Link copied';

  @override
  String get settingsOpenPage => 'Open page';

  @override
  String get settingsDeliveryLog => 'Delivery log';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsTagline => 'Tagline';

  @override
  String get settingsDescription => 'About the salon';

  @override
  String get settingsAddress => 'Address';

  @override
  String get settingsWhatsapp => 'WhatsApp number';

  @override
  String get settingsPhone => 'Phone';

  @override
  String get settingsPublished => 'Visible to clients';

  @override
  String get settingsClosed => 'Closed';

  @override
  String get settingsOpens => 'Opens';

  @override
  String get settingsCloses => 'Closes';

  @override
  String get settingsTeamAccess => 'Team logins';

  @override
  String get settingsRole => 'Role';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleReceptionist => 'Reception';

  @override
  String get roleStaff => 'Artist';

  @override
  String get discoverTitle => 'Find your glow';

  @override
  String get discoverSubtitle =>
      'Book trusted makeup artists and salons near you.';

  @override
  String get discoverSearch => 'Search salons or services';

  @override
  String get discoverEmpty => 'No salons match your search.';

  @override
  String get catAll => 'All';

  @override
  String get catMakeup => 'Makeup';

  @override
  String get catBeauty => 'Beauty';

  @override
  String get catHair => 'Hair';

  @override
  String get catStudio => 'Studio';

  @override
  String get catArtist => 'Artists';

  @override
  String fromPrice(String amount) {
    return 'from $amount';
  }

  @override
  String get salonBook => 'Book appointment';

  @override
  String get salonAbout => 'About';

  @override
  String get salonHours => 'Opening hours';

  @override
  String get salonLocation => 'Location';

  @override
  String get salonReviews => 'Reviews';

  @override
  String get salonTeam => 'Our artists';

  @override
  String get salonServices => 'Services';

  @override
  String salonOpenNow(String hours) {
    return 'Open today · $hours';
  }

  @override
  String get salonClosedToday => 'Closed today';

  @override
  String get salonCall => 'Call';

  @override
  String get salonWhatsapp => 'WhatsApp';

  @override
  String get salonDirections => 'Directions';

  @override
  String get salonSave => 'Save';

  @override
  String get salonSaved => 'Saved';

  @override
  String get salonNotFound => 'We couldn\'t find this salon.';

  @override
  String get salonNextAvailable => 'Next available';

  @override
  String get salonUpcomingClosures => 'Upcoming closures';

  @override
  String get flowService => 'Service';

  @override
  String get flowArtist => 'Artist';

  @override
  String get flowTime => 'Date & time';

  @override
  String get flowDetails => 'Your details';

  @override
  String get flowConfirm => 'Confirm';

  @override
  String get flowChooseService => 'What are we doing today?';

  @override
  String get flowChooseArtist => 'Who would you like?';

  @override
  String get flowChooseTime => 'Pick a time';

  @override
  String get flowYourDetails => 'Almost there';

  @override
  String get flowReview => 'Review & confirm';

  @override
  String get flowNotes => 'Anything we should know?';

  @override
  String get flowNotesHint => 'e.g. inspiration, allergies, event time';

  @override
  String get flowTotal => 'Total';

  @override
  String get flowDepositDue => 'Deposit due now';

  @override
  String get flowPayAtSalon => 'Pay at the salon';

  @override
  String get flowRemaining => 'Remaining at the salon';

  @override
  String get flowPolicy => 'Cancellation policy';

  @override
  String flowPolicyFree(int hours) {
    return 'Free cancellation up to $hours hours before your appointment.';
  }

  @override
  String get flowPolicyDeposit => 'After that, your deposit is non-refundable.';

  @override
  String flowPolicyFee(String amount) {
    return 'Late cancellations may be charged $amount.';
  }

  @override
  String get flowBook => 'Confirm booking';

  @override
  String get flowBookAndPay => 'Book & pay deposit';

  @override
  String get flowConfirmed => 'Appointment confirmed';

  @override
  String get flowConfirmedBody => 'We can\'t wait to see you 💕';

  @override
  String get flowHeld => 'Your spot is held';

  @override
  String get flowHeldBody => 'Pay the deposit within 30 minutes to confirm it.';

  @override
  String get flowViewAppointment => 'View appointment';

  @override
  String get flowBookAnother => 'Book another';

  @override
  String get flowDone => 'Done';

  @override
  String get flowSlotTaken =>
      'Someone just took that time. Here are the latest free slots.';

  @override
  String get flowSignInHint =>
      'Have an account? Sign in to see this booking in the app.';

  @override
  String get flowManageLinkHint =>
      'Save this page — you can use it to view or cancel your booking.';

  @override
  String get payTitle => 'Pay deposit';

  @override
  String get payTestMode => 'Test mode — no real card is charged.';

  @override
  String get payCardNumber => 'Card number';

  @override
  String payNow(String amount) {
    return 'Pay $amount';
  }

  @override
  String get paySuccess => 'Payment received 💕';

  @override
  String get payUnavailable =>
      'Online payment isn\'t available yet — please pay at the salon.';

  @override
  String get myUpcoming => 'Upcoming';

  @override
  String get myPast => 'Past';

  @override
  String get myEmptyTitle => 'No appointments yet';

  @override
  String get myEmptyBody => 'Your next glow-up is a few taps away.';

  @override
  String get myDiscover => 'Discover salons';

  @override
  String get myCancel => 'Cancel appointment';

  @override
  String myCancelFree(String when) {
    return 'Free cancellation until $when.';
  }

  @override
  String myCancelLate(int hours, String amount) {
    return 'It\'s within $hours hours of your appointment — $amount may be kept.';
  }

  @override
  String myCancelRefund(String amount) {
    return '$amount will be refunded.';
  }

  @override
  String get myReschedule => 'Reschedule';

  @override
  String get myRescheduleTitle => 'Choose a new time';

  @override
  String get myLeaveReview => 'Leave a review';

  @override
  String get myReviewTitle => 'How was your visit?';

  @override
  String get myReviewHint => 'Tell others about your experience (optional)';

  @override
  String get myReviewSubmit => 'Post review';

  @override
  String get myReviewThanks => 'Thank you for your review 💕';

  @override
  String get myYourReview => 'Your review';

  @override
  String get myPayDeposit => 'Pay deposit';

  @override
  String get myDirections => 'Get directions';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileFavorites => 'Favourite salons';

  @override
  String get profileNoFavorites => 'Tap the heart on a salon to save it here.';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get platformTitle => 'Platform overview';

  @override
  String get platformSalons => 'Salons';

  @override
  String get platformActive => 'Active (30d)';

  @override
  String get platformUsers => 'Users';

  @override
  String get platformBookings => 'Bookings (30d)';

  @override
  String get platformGmv => 'Payments (30d)';

  @override
  String get platformTenants => 'Tenants';

  @override
  String get platformPublished => 'Live';

  @override
  String get platformHidden => 'Hidden';

  @override
  String get platformPlan => 'Plan';

  @override
  String get flowStepChoose => 'Choose';

  @override
  String get flowStepDetails => 'Details';

  @override
  String get flowStepVerify => 'Verify';

  @override
  String get flowServicesTitle => 'Services';

  @override
  String get flowArtistTitle => 'Artist';

  @override
  String get flowDateTitle => 'Date';

  @override
  String get flowTimeTitle => 'Time';

  @override
  String get flowPickServiceFirst => 'Choose a service to see available times.';

  @override
  String get flowNoCommonArtist =>
      'No single artist offers all of these services together. Try fewer services.';

  @override
  String get flowDayFull => 'Fully booked on this day.';

  @override
  String flowNextAvailable(String date) {
    return 'Next available: $date';
  }

  @override
  String get flowNoAvailability => 'No free times in the next 3 weeks.';

  @override
  String flowServicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count services',
      one: '1 service',
    );
    return '$_temp0';
  }

  @override
  String get flowSendCode => 'Send verification code';

  @override
  String get flowPhoneHelp =>
      'We\'ll send a 6-digit code to confirm your number.';

  @override
  String get flowVerifyTitle => 'Verify your number';

  @override
  String flowVerifyBody(String phone) {
    return 'Enter the 6-digit code we sent to $phone';
  }

  @override
  String flowResendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get flowResend => 'Resend code';

  @override
  String get flowCodeResent => 'A new code is on its way.';

  @override
  String get flowChangeNumber => 'Change number';

  @override
  String flowTestCode(String code) {
    return 'Test mode — your code is $code';
  }

  @override
  String flowWith(String name) {
    return 'with $name';
  }

  @override
  String get flowEnterCode => 'Verification code';

  @override
  String get flowVerifiedAccount =>
      'Your number is already verified — you can confirm right away.';

  @override
  String get anyArtistShort => 'Any';

  @override
  String get navSeasonal => 'Seasonal tokens';

  @override
  String get statusAwaitingPayment => 'Awaiting payment';

  @override
  String get statusExpired => 'Expired';

  @override
  String get seasonTokensBadge => 'Seasonal tokens';

  @override
  String get seasonTakeToken => 'Take a token';

  @override
  String seasonFrom(String price) {
    return 'from $price';
  }

  @override
  String get seasonEventOver => 'This event isn\'t taking tokens any more.';

  @override
  String get seasonChooseOffering => 'Choose a service';

  @override
  String get seasonChooseDay => 'Day';

  @override
  String get seasonChooseTime => 'Token time';

  @override
  String seasonTokenLength(String duration) {
    return '$duration per token';
  }

  @override
  String seasonSeatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left',
      one: '1 left',
    );
    return '$_temp0';
  }

  @override
  String get seasonFull => 'Full';

  @override
  String get seasonNoTimes =>
      'No token times left on this day — try another day.';

  @override
  String get seasonPayInFull => 'Pay in full to book';

  @override
  String seasonPayAdvance(String amount) {
    return '$amount advance to book';
  }

  @override
  String get seasonReminderNote =>
      'We\'ll send your token on WhatsApp and remind you an hour before your turn.';

  @override
  String get seasonStepPay => 'Pay';

  @override
  String get seasonPhoneHelp =>
      'Your token and its reminder are sent to this number on WhatsApp.';

  @override
  String get seasonDueNow => 'Due now';

  @override
  String get seasonPayAtSalon => 'Pay at the salon';

  @override
  String get seasonPayTitle => 'Pay to confirm your token';

  @override
  String get seasonPayBody =>
      'Your token is held for you. Pay in advance to confirm it — unpaid tokens are released.';

  @override
  String seasonHeldFor(String time) {
    return 'Held for $time';
  }

  @override
  String get seasonHoldExpired => 'This hold has expired';

  @override
  String get seasonHoldExpiredBody =>
      'The token was released because it wasn\'t paid in time. You can take a new one.';

  @override
  String get seasonTakeAnother => 'Take a new token';

  @override
  String get seasonTokenConfirmed => 'Your token is confirmed';

  @override
  String get seasonTokenConfirmedBody =>
      'We\'ve sent it to you on WhatsApp and will remind you an hour before your turn.';

  @override
  String get seasonViewToken => 'View my token';

  @override
  String get seasonMyToken => 'My token';

  @override
  String get seasonTokenNumber => 'Token';

  @override
  String seasonArriveBy(String time) {
    return 'Please arrive by $time';
  }

  @override
  String get seasonCancelledBody =>
      'This token was cancelled. The salon will contact you about your payment.';

  @override
  String get seasonQueue => 'Queue';

  @override
  String get seasonEvents => 'Events';

  @override
  String get seasonAllEvents => 'All events';

  @override
  String get seasonWaiting => 'Waiting';

  @override
  String get seasonCollected => 'Collected';

  @override
  String get seasonNoTokens => 'No tokens for this day yet';

  @override
  String get seasonCheckIn => 'Check in';

  @override
  String get seasonMarkDone => 'Done';

  @override
  String get seasonCancelToken => 'Cancel token';

  @override
  String seasonCancelConfirm(int number) {
    return 'Cancel token #$number? The customer is told on WhatsApp — settle any refund at the desk.';
  }

  @override
  String get seasonPaidInFull => 'Paid in full';

  @override
  String get seasonNewEvent => 'New event';

  @override
  String get seasonEditEvent => 'Edit event';

  @override
  String get seasonNoEvents => 'No seasonal events yet';

  @override
  String get seasonNoEventsBody =>
      'Create one for Eid or any busy season. Customers take numbered tokens, pay in advance and get a reminder an hour before.';

  @override
  String get seasonNoOfferings =>
      'Add the services customers can take tokens for.';

  @override
  String get seasonOff => 'Off';

  @override
  String seasonCapacityShort(int count) {
    return '$count at a time';
  }

  @override
  String seasonTokensSold(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens',
      one: '1 token',
      zero: 'No tokens',
    );
    return '$_temp0';
  }

  @override
  String get seasonAddOffering => 'Add service';

  @override
  String get seasonEditOffering => 'Edit service';

  @override
  String get seasonDeleteEventConfirm => 'Delete this event?';

  @override
  String get seasonEventName => 'Event name';

  @override
  String get seasonEventNameHint => 'e.g. Eid al-Adha henna';

  @override
  String get seasonFirstDay => 'First day';

  @override
  String get seasonLastDay => 'Last day';

  @override
  String get seasonOpens => 'Tokens from';

  @override
  String get seasonCloses => 'Until';

  @override
  String get seasonHoursInvalid =>
      'The closing time must be after the opening time.';

  @override
  String get seasonActive => 'Taking tokens';

  @override
  String get seasonOfferingHint => 'e.g. Henna — hands';

  @override
  String get seasonTokenMinutes => 'Token length (min)';

  @override
  String get seasonCapacity => 'Served at once';

  @override
  String get seasonCapacityHelp => 'Chairs or artists working in parallel';

  @override
  String get seasonAdvance => 'Payment to book';

  @override
  String get seasonAdvanceFull => 'Full price';

  @override
  String get seasonAdvanceFixed => 'Fixed amount';

  @override
  String get seasonAdvanceAmount => 'Advance (OMR)';

  @override
  String get seasonAdvanceHelp =>
      'Customers must pay this online to get a token; the rest is paid at the salon.';

  @override
  String get seasonAdvanceTooHigh =>
      'The advance can\'t be more than the price.';

  @override
  String get seasonPositiveNumber => 'Enter a number above 0.';

  @override
  String seasonBalanceDue(String amount) {
    return '$amount due';
  }

  @override
  String flowStepOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get flowServicesHint =>
      'Pick one or more — they\'re done back to back.';

  @override
  String get flowArtistHint =>
      'Who would you like? Any artist shows the most times.';

  @override
  String get flowAnyArtistHint => 'Most available times';

  @override
  String get flowDateHint => 'Days with free times are highlighted.';

  @override
  String get flowPickAnotherDay => 'Pick another day';

  @override
  String get flowLinkSentBody =>
      'We\'ve sent the details and a link to view or change it on WhatsApp.';

  @override
  String get linkExpiredTitle => 'This link has expired';

  @override
  String get linkExpiredBody =>
      'Links work until a day after the appointment. Contact the salon if you need help.';

  @override
  String get linkInvalidTitle => 'This link isn\'t valid';

  @override
  String get linkInvalidBody => 'Please open the link we sent you on WhatsApp.';

  @override
  String get authTeamSignIn => 'Team sign in';

  @override
  String get authTeamSignInSubtitle =>
      'For the salon team. Customers book without an account.';

  @override
  String get authBackToSalon => 'Back to the salon';

  @override
  String get homeTeamSignIn => 'Team sign in';

  @override
  String get manageTitle => 'Your booking';

  @override
  String get manageTooLate =>
      'It\'s too close to your appointment to change it online — please call the salon.';

  @override
  String get manageBookAgain => 'Book again';

  @override
  String get manageNowAt => 'Now:';

  @override
  String get homeHours => 'Hours';

  @override
  String get walletAdd => 'Add to Apple Wallet';

  @override
  String get settingsGallery => 'Gallery photos';

  @override
  String get settingsGalleryHelp =>
      'The first photo shows first. Drag to reorder.';

  @override
  String get settingsGalleryAdd => 'Add photos';

  @override
  String get settingsGalleryAdded => 'Photos added to your gallery';

  @override
  String get settingsGalleryFirst => 'First';
}
