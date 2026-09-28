import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Glowbook'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Beauty bookings, beautifully managed.'**
  String get appTagline;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get actionSaveChanges;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// No description provided for @actionKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get actionKeep;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get labelOptional;

  /// No description provided for @labelSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get labelSearch;

  /// No description provided for @labelToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get labelToday;

  /// No description provided for @labelTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get labelTomorrow;

  /// No description provided for @labelYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get labelYesterday;

  /// No description provided for @labelMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String labelMinutes(int count);

  /// No description provided for @labelHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String labelHoursMinutes(int hours, int minutes);

  /// No description provided for @labelHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String labelHours(int hours);

  /// No description provided for @money.
  ///
  /// In en, this message translates to:
  /// **'OMR {amount}'**
  String money(String amount);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You seem to be offline. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get errorRequired;

  /// No description provided for @errorEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get errorEmail;

  /// No description provided for @errorPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get errorPhone;

  /// No description provided for @errorPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get errorPasswordShort;

  /// No description provided for @errorNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get errorNumber;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your bookings and glow on.'**
  String get authSignInSubtitle;

  /// No description provided for @authEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get authEmailOrPhone;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New to Glowbook?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAccount;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authForgotTitle;

  /// No description provided for @authForgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to choose a new password.'**
  String get authForgotBody;

  /// No description provided for @authSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, a reset link is on its way.'**
  String get authResetSent;

  /// No description provided for @authDevResetHint.
  ///
  /// In en, this message translates to:
  /// **'Development mode: no email provider is configured, so use the link below.'**
  String get authDevResetHint;

  /// No description provided for @authOpenResetLink.
  ///
  /// In en, this message translates to:
  /// **'Open reset link'**
  String get authOpenResetLink;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get authResetTitle;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please sign in.'**
  String get authPasswordUpdated;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhone;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book your favourite salons in seconds.'**
  String get authRegisterSubtitle;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// No description provided for @authOwnSalon.
  ///
  /// In en, this message translates to:
  /// **'Own a salon or studio?'**
  String get authOwnSalon;

  /// No description provided for @authRegisterSalon.
  ///
  /// In en, this message translates to:
  /// **'Set up your salon'**
  String get authRegisterSalon;

  /// No description provided for @authRegisterSalonTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your salon to Glowbook'**
  String get authRegisterSalonTitle;

  /// No description provided for @authRegisterSalonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar, bookings, reminders and payments — free for 30 days.'**
  String get authRegisterSalonSubtitle;

  /// No description provided for @authSalonName.
  ///
  /// In en, this message translates to:
  /// **'Salon name'**
  String get authSalonName;

  /// No description provided for @authCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get authCity;

  /// No description provided for @authStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get authStartTrial;

  /// No description provided for @authPhoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone'**
  String get authPhoneSignIn;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendCode;

  /// No description provided for @authEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get authEnterCode;

  /// No description provided for @authCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {phone}'**
  String authCodeSentTo(String phone);

  /// No description provided for @authDevCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Development mode code: {code}'**
  String authDevCodeHint(String code);

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Glowbook?'**
  String get authSignOutConfirm;

  /// No description provided for @authDemoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Demo accounts'**
  String get authDemoAccounts;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get navBookings;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get navCustomers;

  /// No description provided for @navServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// No description provided for @navStaff.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get navStaff;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get navPayments;

  /// No description provided for @navReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get navReviews;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get navAppointments;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navMyDay.
  ///
  /// In en, this message translates to:
  /// **'My day'**
  String get navMyDay;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get navPlatform;

  /// No description provided for @newBooking.
  ///
  /// In en, this message translates to:
  /// **'New booking'**
  String get newBooking;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @summaryAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get summaryAppointments;

  /// No description provided for @summaryConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get summaryConfirmed;

  /// No description provided for @summaryPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get summaryPending;

  /// No description provided for @summaryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get summaryCompleted;

  /// No description provided for @summaryRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue today'**
  String get summaryRevenue;

  /// No description provided for @summaryExpected.
  ///
  /// In en, this message translates to:
  /// **'{amount} booked today'**
  String summaryExpected(String amount);

  /// No description provided for @todaysSchedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get todaysSchedule;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @quickCustomer.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get quickCustomer;

  /// No description provided for @quickService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get quickService;

  /// No description provided for @quickBlockTime.
  ///
  /// In en, this message translates to:
  /// **'Block time'**
  String get quickBlockTime;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @inMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String inMinutes(int minutes);

  /// No description provided for @emptyTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'No appointments today'**
  String get emptyTodayTitle;

  /// No description provided for @emptyTodayBody.
  ///
  /// In en, this message translates to:
  /// **'A quiet day. Share your booking link and let the calendar fill up.'**
  String get emptyTodayBody;

  /// No description provided for @weekRevenue.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get weekRevenue;

  /// No description provided for @pendingRefunds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 refund to settle} other{{count} refunds to settle}}'**
  String pendingRefunds(int count);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get statusArrived;

  /// No description provided for @statusInService.
  ///
  /// In en, this message translates to:
  /// **'In service'**
  String get statusInService;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No show'**
  String get statusNoShow;

  /// No description provided for @calendarDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calendarDay;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarWeek;

  /// No description provided for @calendarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarMonth;

  /// No description provided for @calendarAllStaff.
  ///
  /// In en, this message translates to:
  /// **'All team'**
  String get calendarAllStaff;

  /// No description provided for @calendarClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get calendarClosed;

  /// No description provided for @calendarBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get calendarBlocked;

  /// No description provided for @calendarTimeOff.
  ///
  /// In en, this message translates to:
  /// **'Time off'**
  String get calendarTimeOff;

  /// No description provided for @calendarDayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get calendarDayOff;

  /// No description provided for @calendarJumpToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarJumpToday;

  /// No description provided for @calendarPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calendarPrevious;

  /// No description provided for @calendarNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calendarNext;

  /// No description provided for @calendarBookingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No bookings} =1{1 booking} other{{count} bookings}}'**
  String calendarBookingsCount(int count);

  /// No description provided for @bookingDetails.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get bookingDetails;

  /// No description provided for @bookingReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get bookingReference;

  /// No description provided for @bookingClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get bookingClient;

  /// No description provided for @bookingService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingService;

  /// No description provided for @bookingArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get bookingArtist;

  /// No description provided for @bookingWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get bookingWhen;

  /// No description provided for @bookingDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get bookingDuration;

  /// No description provided for @bookingPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get bookingPrice;

  /// No description provided for @bookingDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get bookingDeposit;

  /// No description provided for @bookingPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get bookingPaid;

  /// No description provided for @bookingBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get bookingBalance;

  /// No description provided for @bookingClientNotes.
  ///
  /// In en, this message translates to:
  /// **'Note from client'**
  String get bookingClientNotes;

  /// No description provided for @bookingInternalNotes.
  ///
  /// In en, this message translates to:
  /// **'Private team notes'**
  String get bookingInternalNotes;

  /// No description provided for @bookingInternalNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Only your team can see this'**
  String get bookingInternalNotesHint;

  /// No description provided for @bookingMarkArrived.
  ///
  /// In en, this message translates to:
  /// **'Mark arrived'**
  String get bookingMarkArrived;

  /// No description provided for @bookingStartService.
  ///
  /// In en, this message translates to:
  /// **'Start service'**
  String get bookingStartService;

  /// No description provided for @bookingMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get bookingMarkCompleted;

  /// No description provided for @bookingMarkNoShow.
  ///
  /// In en, this message translates to:
  /// **'No show'**
  String get bookingMarkNoShow;

  /// No description provided for @bookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get bookingConfirm;

  /// No description provided for @bookingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get bookingCancel;

  /// No description provided for @bookingReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get bookingReschedule;

  /// No description provided for @bookingRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get bookingRecordPayment;

  /// No description provided for @bookingHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get bookingHistory;

  /// No description provided for @bookingCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this appointment?'**
  String get bookingCancelTitle;

  /// No description provided for @bookingCancelBody.
  ///
  /// In en, this message translates to:
  /// **'The client will be notified. Any deposit paid is recorded as a refund to settle.'**
  String get bookingCancelBody;

  /// No description provided for @bookingCancelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get bookingCancelReason;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled'**
  String get bookingCancelled;

  /// No description provided for @bookingRestored.
  ///
  /// In en, this message translates to:
  /// **'Cancellation undone'**
  String get bookingRestored;

  /// No description provided for @bookingStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated'**
  String get bookingStatusUpdated;

  /// No description provided for @bookingNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved'**
  String get bookingNotesSaved;

  /// No description provided for @bookingRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Appointment moved ✨'**
  String get bookingRescheduled;

  /// No description provided for @historyCreated.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get historyCreated;

  /// No description provided for @historyRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Moved from {from} to {to}'**
  String historyRescheduled(String from, String to);

  /// No description provided for @historyStatus.
  ///
  /// In en, this message translates to:
  /// **'Marked {status}'**
  String historyStatus(String status);

  /// No description provided for @historyNote.
  ///
  /// In en, this message translates to:
  /// **'Notes updated'**
  String get historyNote;

  /// No description provided for @historyBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String historyBy(String name);

  /// No description provided for @sourceWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get sourceWalkIn;

  /// No description provided for @sourceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get sourceOnline;

  /// No description provided for @sourceApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get sourceApp;

  /// No description provided for @sourceAdmin.
  ///
  /// In en, this message translates to:
  /// **'Front desk'**
  String get sourceAdmin;

  /// No description provided for @wizardClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get wizardClient;

  /// No description provided for @wizardService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get wizardService;

  /// No description provided for @wizardArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get wizardArtist;

  /// No description provided for @wizardDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get wizardDateTime;

  /// No description provided for @wizardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get wizardConfirm;

  /// No description provided for @wizardSearchClients.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get wizardSearchClients;

  /// No description provided for @wizardNewClient.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get wizardNewClient;

  /// No description provided for @wizardWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get wizardWalkIn;

  /// No description provided for @wizardMarkArrived.
  ///
  /// In en, this message translates to:
  /// **'Client is here now'**
  String get wizardMarkArrived;

  /// No description provided for @wizardNotifyClient.
  ///
  /// In en, this message translates to:
  /// **'Send confirmation to client'**
  String get wizardNotifyClient;

  /// No description provided for @wizardCreate.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get wizardCreate;

  /// No description provided for @wizardCreated.
  ///
  /// In en, this message translates to:
  /// **'Appointment booked ✨'**
  String get wizardCreated;

  /// No description provided for @anyArtist.
  ///
  /// In en, this message translates to:
  /// **'Any available'**
  String get anyArtist;

  /// No description provided for @anyArtistBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll match you with the first free artist.'**
  String get anyArtistBody;

  /// No description provided for @noSlotsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fully booked'**
  String get noSlotsTitle;

  /// No description provided for @noSlotsBody.
  ///
  /// In en, this message translates to:
  /// **'No free times on this day. Try another date or artist.'**
  String get noSlotsBody;

  /// No description provided for @slotMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get slotMorning;

  /// No description provided for @slotAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get slotAfternoon;

  /// No description provided for @slotEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get slotEvening;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get customersTitle;

  /// No description provided for @customersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search clients'**
  String get customersSearch;

  /// No description provided for @customersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get customersEmptyTitle;

  /// No description provided for @customersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Clients appear here as they book. You can also add them yourself.'**
  String get customersEmptyBody;

  /// No description provided for @customerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add client'**
  String get customerAdd;

  /// No description provided for @customerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit client'**
  String get customerEdit;

  /// No description provided for @customerTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get customerTotalSpent;

  /// No description provided for @customerVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get customerVisits;

  /// No description provided for @customerLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get customerLastVisit;

  /// No description provided for @customerUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get customerUpcoming;

  /// No description provided for @customerHistory.
  ///
  /// In en, this message translates to:
  /// **'Booking history'**
  String get customerHistory;

  /// No description provided for @customerPrivateNotes.
  ///
  /// In en, this message translates to:
  /// **'Private notes'**
  String get customerPrivateNotes;

  /// No description provided for @customerPrivateNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Allergies, preferences… never shown to the client'**
  String get customerPrivateNotesHint;

  /// No description provided for @customerBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get customerBirthday;

  /// No description provided for @customerPreferredArtist.
  ///
  /// In en, this message translates to:
  /// **'Preferred artist'**
  String get customerPreferredArtist;

  /// No description provided for @customerFavoriteService.
  ///
  /// In en, this message translates to:
  /// **'Favourite service'**
  String get customerFavoriteService;

  /// No description provided for @customerNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get customerNoShows;

  /// No description provided for @customerCancellations.
  ///
  /// In en, this message translates to:
  /// **'Cancellations'**
  String get customerCancellations;

  /// No description provided for @customerNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get customerNever;

  /// No description provided for @customerSaved.
  ///
  /// In en, this message translates to:
  /// **'Client saved 💕'**
  String get customerSaved;

  /// No description provided for @customerBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book for this client'**
  String get customerBookNow;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @serviceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get serviceAdd;

  /// No description provided for @serviceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get serviceEdit;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get serviceName;

  /// No description provided for @serviceNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name in Arabic'**
  String get serviceNameAr;

  /// No description provided for @serviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get serviceDescription;

  /// No description provided for @serviceDescriptionAr.
  ///
  /// In en, this message translates to:
  /// **'Description in Arabic'**
  String get serviceDescriptionAr;

  /// No description provided for @serviceCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get serviceCategory;

  /// No description provided for @serviceUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get serviceUncategorized;

  /// No description provided for @servicePrice.
  ///
  /// In en, this message translates to:
  /// **'Price (OMR)'**
  String get servicePrice;

  /// No description provided for @serviceDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get serviceDuration;

  /// No description provided for @serviceBuffer.
  ///
  /// In en, this message translates to:
  /// **'Clean-up buffer (minutes)'**
  String get serviceBuffer;

  /// No description provided for @serviceBufferHelp.
  ///
  /// In en, this message translates to:
  /// **'Blocked after each appointment for tidying up.'**
  String get serviceBufferHelp;

  /// No description provided for @serviceActive.
  ///
  /// In en, this message translates to:
  /// **'Bookable'**
  String get serviceActive;

  /// No description provided for @servicePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment at booking'**
  String get servicePayment;

  /// No description provided for @servicePayNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get servicePayNone;

  /// No description provided for @servicePayDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get servicePayDeposit;

  /// No description provided for @servicePayFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get servicePayFull;

  /// No description provided for @serviceDepositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit (OMR)'**
  String get serviceDepositAmount;

  /// No description provided for @serviceWhoPerforms.
  ///
  /// In en, this message translates to:
  /// **'Who performs it'**
  String get serviceWhoPerforms;

  /// No description provided for @serviceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get serviceEmptyTitle;

  /// No description provided for @serviceEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your menu so clients can start booking.'**
  String get serviceEmptyBody;

  /// No description provided for @serviceDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this service? Past bookings are kept.'**
  String get serviceDeleteConfirm;

  /// No description provided for @serviceSaved.
  ///
  /// In en, this message translates to:
  /// **'Service saved ✨'**
  String get serviceSaved;

  /// No description provided for @serviceInactive.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get serviceInactive;

  /// No description provided for @staffTitle.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get staffTitle;

  /// No description provided for @staffAdd.
  ///
  /// In en, this message translates to:
  /// **'Add team member'**
  String get staffAdd;

  /// No description provided for @staffEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit team member'**
  String get staffEdit;

  /// No description provided for @staffName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get staffName;

  /// No description provided for @staffNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name in Arabic'**
  String get staffNameAr;

  /// No description provided for @staffJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get staffJobTitle;

  /// No description provided for @staffColor.
  ///
  /// In en, this message translates to:
  /// **'Calendar colour'**
  String get staffColor;

  /// No description provided for @staffHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get staffHours;

  /// No description provided for @staffDayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get staffDayOff;

  /// No description provided for @staffTimeOff.
  ///
  /// In en, this message translates to:
  /// **'Time off'**
  String get staffTimeOff;

  /// No description provided for @staffAddTimeOff.
  ///
  /// In en, this message translates to:
  /// **'Add time off'**
  String get staffAddTimeOff;

  /// No description provided for @staffVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get staffVacation;

  /// No description provided for @staffSick.
  ///
  /// In en, this message translates to:
  /// **'Sick'**
  String get staffSick;

  /// No description provided for @staffOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get staffOther;

  /// No description provided for @staffFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get staffFrom;

  /// No description provided for @staffTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get staffTo;

  /// No description provided for @staffServices.
  ///
  /// In en, this message translates to:
  /// **'Services offered'**
  String get staffServices;

  /// No description provided for @staffActive.
  ///
  /// In en, this message translates to:
  /// **'Taking bookings'**
  String get staffActive;

  /// No description provided for @staffInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get staffInactive;

  /// No description provided for @staffEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your dream team'**
  String get staffEmptyTitle;

  /// No description provided for @staffEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your artists so clients can choose who they book with.'**
  String get staffEmptyBody;

  /// No description provided for @staffSaved.
  ///
  /// In en, this message translates to:
  /// **'Team member saved 💕'**
  String get staffSaved;

  /// No description provided for @staffHasLogin.
  ///
  /// In en, this message translates to:
  /// **'Has a login'**
  String get staffHasLogin;

  /// No description provided for @staffTimeOffSaved.
  ///
  /// In en, this message translates to:
  /// **'Time off saved'**
  String get staffTimeOffSaved;

  /// No description provided for @staffClashes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking falls in this time.} other{{count} bookings fall in this time.}} Save anyway?'**
  String staffClashes(int count);

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @blockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block time'**
  String get blockTitle;

  /// No description provided for @blockType.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get blockType;

  /// No description provided for @blockLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get blockLunch;

  /// No description provided for @blockBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get blockBreak;

  /// No description provided for @blockPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get blockPersonal;

  /// No description provided for @blockMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get blockMeeting;

  /// No description provided for @blockPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private booking'**
  String get blockPrivate;

  /// No description provided for @blockOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get blockOther;

  /// No description provided for @blockWholeSalon.
  ///
  /// In en, this message translates to:
  /// **'Whole salon'**
  String get blockWholeSalon;

  /// No description provided for @blockSaved.
  ///
  /// In en, this message translates to:
  /// **'Time blocked'**
  String get blockSaved;

  /// No description provided for @blockStart.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get blockStart;

  /// No description provided for @blockEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get blockEnd;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsLast7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get reportsLast7;

  /// No description provided for @reportsLast30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get reportsLast30;

  /// No description provided for @reportsLast90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get reportsLast90;

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get reportsBookings;

  /// No description provided for @reportsCancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation rate'**
  String get reportsCancellationRate;

  /// No description provided for @reportsNoShowRate.
  ///
  /// In en, this message translates to:
  /// **'No-show rate'**
  String get reportsNoShowRate;

  /// No description provided for @reportsPopularServices.
  ///
  /// In en, this message translates to:
  /// **'Popular services'**
  String get reportsPopularServices;

  /// No description provided for @reportsStaffPerformance.
  ///
  /// In en, this message translates to:
  /// **'Team performance'**
  String get reportsStaffPerformance;

  /// No description provided for @reportsNewClients.
  ///
  /// In en, this message translates to:
  /// **'New clients'**
  String get reportsNewClients;

  /// No description provided for @reportsReturningClients.
  ///
  /// In en, this message translates to:
  /// **'Returning clients'**
  String get reportsReturningClients;

  /// No description provided for @reportsRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get reportsRetention;

  /// No description provided for @reportsDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get reportsDaily;

  /// No description provided for @reportsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get reportsWeekly;

  /// No description provided for @reportsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get reportsMonthly;

  /// No description provided for @reportsCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String reportsCompleted(int count);

  /// No description provided for @reportsAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'{amount} / day'**
  String reportsAvgPerDay(String amount);

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAll;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Booking updates and reminders will appear here.'**
  String get notificationsEmptyBody;

  /// No description provided for @paymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsTitle;

  /// No description provided for @paymentsCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get paymentsCollected;

  /// No description provided for @paymentsRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get paymentsRefunded;

  /// No description provided for @paymentsNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get paymentsNet;

  /// No description provided for @paymentsOwed.
  ///
  /// In en, this message translates to:
  /// **'Refunds owed'**
  String get paymentsOwed;

  /// No description provided for @paymentsSettle.
  ///
  /// In en, this message translates to:
  /// **'Settle refund'**
  String get paymentsSettle;

  /// No description provided for @paymentsSettled.
  ///
  /// In en, this message translates to:
  /// **'Refund recorded'**
  String get paymentsSettled;

  /// No description provided for @paymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments in this period.'**
  String get paymentsEmpty;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (OMR)'**
  String get paymentAmount;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get paymentMethod;

  /// No description provided for @paymentKind.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get paymentKind;

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecorded;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get methodCard;

  /// No description provided for @methodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get methodBank;

  /// No description provided for @methodOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get methodOnline;

  /// No description provided for @kindDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get kindDeposit;

  /// No description provided for @kindBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get kindBalance;

  /// No description provided for @kindFull.
  ///
  /// In en, this message translates to:
  /// **'Full payment'**
  String get kindFull;

  /// No description provided for @kindFee.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fee'**
  String get kindFee;

  /// No description provided for @kindRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get kindRefund;

  /// No description provided for @paymentStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentStatusPaid;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// No description provided for @reviewsReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reviewsReply;

  /// No description provided for @reviewsReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Thank her for visiting…'**
  String get reviewsReplyHint;

  /// No description provided for @reviewsReplied.
  ///
  /// In en, this message translates to:
  /// **'Reply posted'**
  String get reviewsReplied;

  /// No description provided for @reviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get reviewsEmpty;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews} =1{1 review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @reviewsSalonReply.
  ///
  /// In en, this message translates to:
  /// **'Reply from the salon'**
  String get reviewsSalonReply;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSalonProfile.
  ///
  /// In en, this message translates to:
  /// **'Salon profile'**
  String get settingsSalonProfile;

  /// No description provided for @settingsBookingRules.
  ///
  /// In en, this message translates to:
  /// **'Booking rules'**
  String get settingsBookingRules;

  /// No description provided for @settingsSlotInterval.
  ///
  /// In en, this message translates to:
  /// **'Time slot interval'**
  String get settingsSlotInterval;

  /// No description provided for @settingsMinNotice.
  ///
  /// In en, this message translates to:
  /// **'Minimum notice for online bookings'**
  String get settingsMinNotice;

  /// No description provided for @settingsHorizon.
  ///
  /// In en, this message translates to:
  /// **'How far ahead clients can book'**
  String get settingsHorizon;

  /// No description provided for @settingsHorizonDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String settingsHorizonDays(int days);

  /// No description provided for @settingsAutoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm online bookings automatically'**
  String get settingsAutoConfirm;

  /// No description provided for @settingsCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation policy'**
  String get settingsCancellation;

  /// No description provided for @settingsCancellationWindow.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation up to'**
  String get settingsCancellationWindow;

  /// No description provided for @settingsHoursBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours before'**
  String settingsHoursBefore(int hours);

  /// No description provided for @settingsLateFee.
  ///
  /// In en, this message translates to:
  /// **'Late cancellation fee (OMR)'**
  String get settingsLateFee;

  /// No description provided for @settingsDepositPolicy.
  ///
  /// In en, this message translates to:
  /// **'Deposit when cancelled in time'**
  String get settingsDepositPolicy;

  /// No description provided for @settingsDepositRefundable.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get settingsDepositRefundable;

  /// No description provided for @settingsDepositNonRefundable.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get settingsDepositNonRefundable;

  /// No description provided for @settingsAllowReschedule.
  ///
  /// In en, this message translates to:
  /// **'Clients can reschedule online'**
  String get settingsAllowReschedule;

  /// No description provided for @settingsChannels.
  ///
  /// In en, this message translates to:
  /// **'Notification channels'**
  String get settingsChannels;

  /// No description provided for @settingsChannelsBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how clients hear about bookings and reminders.'**
  String get settingsChannelsBody;

  /// No description provided for @channelInApp.
  ///
  /// In en, this message translates to:
  /// **'In-app'**
  String get channelInApp;

  /// No description provided for @channelPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get channelPush;

  /// No description provided for @channelWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get channelWhatsapp;

  /// No description provided for @channelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get channelEmail;

  /// No description provided for @channelSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get channelSms;

  /// No description provided for @channelNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Provider not connected yet'**
  String get channelNotConfigured;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Automatic reminders'**
  String get settingsReminders;

  /// No description provided for @settingsRemind24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours before'**
  String get settingsRemind24h;

  /// No description provided for @settingsRemind3h.
  ///
  /// In en, this message translates to:
  /// **'3 hours before'**
  String get settingsRemind3h;

  /// No description provided for @settingsReviewRequests.
  ///
  /// In en, this message translates to:
  /// **'Ask for a review after the visit'**
  String get settingsReviewRequests;

  /// No description provided for @settingsOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get settingsOpeningHours;

  /// No description provided for @settingsHolidays.
  ///
  /// In en, this message translates to:
  /// **'Holidays & special hours'**
  String get settingsHolidays;

  /// No description provided for @settingsAddHoliday.
  ///
  /// In en, this message translates to:
  /// **'Add closure'**
  String get settingsAddHoliday;

  /// No description provided for @settingsClosedAllDay.
  ///
  /// In en, this message translates to:
  /// **'Closed all day'**
  String get settingsClosedAllDay;

  /// No description provided for @settingsSpecialHours.
  ///
  /// In en, this message translates to:
  /// **'Special hours'**
  String get settingsSpecialHours;

  /// No description provided for @settingsHolidayName.
  ///
  /// In en, this message translates to:
  /// **'Occasion'**
  String get settingsHolidayName;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsBookingLink.
  ///
  /// In en, this message translates to:
  /// **'Your booking page'**
  String get settingsBookingLink;

  /// No description provided for @settingsBookingLinkBody.
  ///
  /// In en, this message translates to:
  /// **'Share this link on Instagram and WhatsApp — clients book without downloading anything.'**
  String get settingsBookingLinkBody;

  /// No description provided for @settingsCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get settingsCopyLink;

  /// No description provided for @settingsLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get settingsLinkCopied;

  /// No description provided for @settingsOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open page'**
  String get settingsOpenPage;

  /// No description provided for @settingsDeliveryLog.
  ///
  /// In en, this message translates to:
  /// **'Delivery log'**
  String get settingsDeliveryLog;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsTagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get settingsTagline;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'About the salon'**
  String get settingsDescription;

  /// No description provided for @settingsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsAddress;

  /// No description provided for @settingsWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get settingsWhatsapp;

  /// No description provided for @settingsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settingsPhone;

  /// No description provided for @settingsPublished.
  ///
  /// In en, this message translates to:
  /// **'Visible to clients'**
  String get settingsPublished;

  /// No description provided for @settingsClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get settingsClosed;

  /// No description provided for @settingsOpens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get settingsOpens;

  /// No description provided for @settingsCloses.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get settingsCloses;

  /// No description provided for @settingsTeamAccess.
  ///
  /// In en, this message translates to:
  /// **'Team logins'**
  String get settingsTeamAccess;

  /// No description provided for @settingsRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get settingsRole;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleReceptionist.
  ///
  /// In en, this message translates to:
  /// **'Reception'**
  String get roleReceptionist;

  /// No description provided for @roleStaff.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get roleStaff;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your glow'**
  String get discoverTitle;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book trusted makeup artists and salons near you.'**
  String get discoverSubtitle;

  /// No description provided for @discoverSearch.
  ///
  /// In en, this message translates to:
  /// **'Search salons or services'**
  String get discoverSearch;

  /// No description provided for @discoverEmpty.
  ///
  /// In en, this message translates to:
  /// **'No salons match your search.'**
  String get discoverEmpty;

  /// No description provided for @catAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get catAll;

  /// No description provided for @catMakeup.
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get catMakeup;

  /// No description provided for @catBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get catBeauty;

  /// No description provided for @catHair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get catHair;

  /// No description provided for @catStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get catStudio;

  /// No description provided for @catArtist.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get catArtist;

  /// No description provided for @fromPrice.
  ///
  /// In en, this message translates to:
  /// **'from {amount}'**
  String fromPrice(String amount);

  /// No description provided for @salonBook.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get salonBook;

  /// No description provided for @salonAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get salonAbout;

  /// No description provided for @salonHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get salonHours;

  /// No description provided for @salonLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get salonLocation;

  /// No description provided for @salonReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get salonReviews;

  /// No description provided for @salonTeam.
  ///
  /// In en, this message translates to:
  /// **'Our artists'**
  String get salonTeam;

  /// No description provided for @salonServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get salonServices;

  /// No description provided for @salonOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open today · {hours}'**
  String salonOpenNow(String hours);

  /// No description provided for @salonClosedToday.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get salonClosedToday;

  /// No description provided for @salonCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get salonCall;

  /// No description provided for @salonWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get salonWhatsapp;

  /// No description provided for @salonDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get salonDirections;

  /// No description provided for @salonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get salonSave;

  /// No description provided for @salonSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get salonSaved;

  /// No description provided for @salonNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this salon.'**
  String get salonNotFound;

  /// No description provided for @salonNextAvailable.
  ///
  /// In en, this message translates to:
  /// **'Next available'**
  String get salonNextAvailable;

  /// No description provided for @salonUpcomingClosures.
  ///
  /// In en, this message translates to:
  /// **'Upcoming closures'**
  String get salonUpcomingClosures;

  /// No description provided for @flowService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get flowService;

  /// No description provided for @flowArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get flowArtist;

  /// No description provided for @flowTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get flowTime;

  /// No description provided for @flowDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get flowDetails;

  /// No description provided for @flowConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get flowConfirm;

  /// No description provided for @flowChooseService.
  ///
  /// In en, this message translates to:
  /// **'What are we doing today?'**
  String get flowChooseService;

  /// No description provided for @flowChooseArtist.
  ///
  /// In en, this message translates to:
  /// **'Who would you like?'**
  String get flowChooseArtist;

  /// No description provided for @flowChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get flowChooseTime;

  /// No description provided for @flowYourDetails.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get flowYourDetails;

  /// No description provided for @flowReview.
  ///
  /// In en, this message translates to:
  /// **'Review & confirm'**
  String get flowReview;

  /// No description provided for @flowNotes.
  ///
  /// In en, this message translates to:
  /// **'Anything we should know?'**
  String get flowNotes;

  /// No description provided for @flowNotesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. inspiration, allergies, event time'**
  String get flowNotesHint;

  /// No description provided for @flowTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get flowTotal;

  /// No description provided for @flowDepositDue.
  ///
  /// In en, this message translates to:
  /// **'Deposit due now'**
  String get flowDepositDue;

  /// No description provided for @flowPayAtSalon.
  ///
  /// In en, this message translates to:
  /// **'Pay at the salon'**
  String get flowPayAtSalon;

  /// No description provided for @flowRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining at the salon'**
  String get flowRemaining;

  /// No description provided for @flowPolicy.
  ///
  /// In en, this message translates to:
  /// **'Cancellation policy'**
  String get flowPolicy;

  /// No description provided for @flowPolicyFree.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation up to {hours} hours before your appointment.'**
  String flowPolicyFree(int hours);

  /// No description provided for @flowPolicyDeposit.
  ///
  /// In en, this message translates to:
  /// **'After that, your deposit is non-refundable.'**
  String get flowPolicyDeposit;

  /// No description provided for @flowPolicyFee.
  ///
  /// In en, this message translates to:
  /// **'Late cancellations may be charged {amount}.'**
  String flowPolicyFee(String amount);

  /// No description provided for @flowBook.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get flowBook;

  /// No description provided for @flowBookAndPay.
  ///
  /// In en, this message translates to:
  /// **'Book & pay deposit'**
  String get flowBookAndPay;

  /// No description provided for @flowConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Appointment confirmed'**
  String get flowConfirmed;

  /// No description provided for @flowConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'We can\'t wait to see you 💕'**
  String get flowConfirmedBody;

  /// No description provided for @flowHeld.
  ///
  /// In en, this message translates to:
  /// **'Your spot is held'**
  String get flowHeld;

  /// No description provided for @flowHeldBody.
  ///
  /// In en, this message translates to:
  /// **'Pay the deposit within 30 minutes to confirm it.'**
  String get flowHeldBody;

  /// No description provided for @flowViewAppointment.
  ///
  /// In en, this message translates to:
  /// **'View appointment'**
  String get flowViewAppointment;

  /// No description provided for @flowBookAnother.
  ///
  /// In en, this message translates to:
  /// **'Book another'**
  String get flowBookAnother;

  /// No description provided for @flowDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flowDone;

  /// No description provided for @flowSlotTaken.
  ///
  /// In en, this message translates to:
  /// **'Someone just took that time. Here are the latest free slots.'**
  String get flowSlotTaken;

  /// No description provided for @flowSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Have an account? Sign in to see this booking in the app.'**
  String get flowSignInHint;

  /// No description provided for @flowManageLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Save this page — you can use it to view or cancel your booking.'**
  String get flowManageLinkHint;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay deposit'**
  String get payTitle;

  /// No description provided for @payTestMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode — no real card is charged.'**
  String get payTestMode;

  /// No description provided for @payCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get payCardNumber;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payNow(String amount);

  /// No description provided for @paySuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment received 💕'**
  String get paySuccess;

  /// No description provided for @payUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Online payment isn\'t available yet — please pay at the salon.'**
  String get payUnavailable;

  /// No description provided for @myUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get myUpcoming;

  /// No description provided for @myPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get myPast;

  /// No description provided for @myEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No appointments yet'**
  String get myEmptyTitle;

  /// No description provided for @myEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your next glow-up is a few taps away.'**
  String get myEmptyBody;

  /// No description provided for @myDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover salons'**
  String get myDiscover;

  /// No description provided for @myCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get myCancel;

  /// No description provided for @myCancelFree.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation until {when}.'**
  String myCancelFree(String when);

  /// No description provided for @myCancelLate.
  ///
  /// In en, this message translates to:
  /// **'It\'s within {hours} hours of your appointment — {amount} may be kept.'**
  String myCancelLate(int hours, String amount);

  /// No description provided for @myCancelRefund.
  ///
  /// In en, this message translates to:
  /// **'{amount} will be refunded.'**
  String myCancelRefund(String amount);

  /// No description provided for @myReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get myReschedule;

  /// No description provided for @myRescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new time'**
  String get myRescheduleTitle;

  /// No description provided for @myLeaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get myLeaveReview;

  /// No description provided for @myReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your visit?'**
  String get myReviewTitle;

  /// No description provided for @myReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Tell others about your experience (optional)'**
  String get myReviewHint;

  /// No description provided for @myReviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Post review'**
  String get myReviewSubmit;

  /// No description provided for @myReviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your review 💕'**
  String get myReviewThanks;

  /// No description provided for @myYourReview.
  ///
  /// In en, this message translates to:
  /// **'Your review'**
  String get myYourReview;

  /// No description provided for @myPayDeposit.
  ///
  /// In en, this message translates to:
  /// **'Pay deposit'**
  String get myPayDeposit;

  /// No description provided for @myDirections.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get myDirections;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favourite salons'**
  String get profileFavorites;

  /// No description provided for @profileNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a salon to save it here.'**
  String get profileNoFavorites;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @platformTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform overview'**
  String get platformTitle;

  /// No description provided for @platformSalons.
  ///
  /// In en, this message translates to:
  /// **'Salons'**
  String get platformSalons;

  /// No description provided for @platformActive.
  ///
  /// In en, this message translates to:
  /// **'Active (30d)'**
  String get platformActive;

  /// No description provided for @platformUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get platformUsers;

  /// No description provided for @platformBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings (30d)'**
  String get platformBookings;

  /// No description provided for @platformGmv.
  ///
  /// In en, this message translates to:
  /// **'Payments (30d)'**
  String get platformGmv;

  /// No description provided for @platformTenants.
  ///
  /// In en, this message translates to:
  /// **'Tenants'**
  String get platformTenants;

  /// No description provided for @platformPublished.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get platformPublished;

  /// No description provided for @platformHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get platformHidden;

  /// No description provided for @platformPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get platformPlan;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
