import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'translations_fil.dart';

/// Globally readable language code for code that has no [BuildContext], such as
/// validators and input-decoration helpers. Widgets should read the language
/// through [AppLocalizations.of] so they rebuild when it changes.
final ValueNotifier<String> currentLanguageCode = ValueNotifier<String>('en');

/// Translates [source] using the current language, without a context.
///
/// Use this only where a `BuildContext` is unavailable; [AppLocalizations.t] is
/// preferred inside widgets because it is tied to the active locale.
String tr(String source) =>
    currentLanguageCode.value == 'fil' ? translateToFilipino(source) : source;

/// Front-end-only localisation strings for the MTOP operator app.
///
/// Only two languages are supported: English (en) and Filipino (fil).
/// Backend content (announcements, notifications, remarks) is never translated
/// here — only the fixed UI chrome that this build controls.
class AppLocalizations {
  const AppLocalizations(this.languageCode);

  final String languageCode;

  bool get _isFil => languageCode == 'fil';

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// The active strings, or English when there is no localisation ancestor
  /// (for example a widget test that builds a bare [MaterialApp]).
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations('en');
  }

  /// Translates an arbitrary English UI string.
  String t(String source) => _isFil ? translateToFilipino(source) : source;

  // ── Navigation ─────────────────────────────────────────────────────────────
  String get navHome => _isFil ? 'Tahanan' : 'Home';
  String get navApply => _isFil ? 'Mag-apply' : 'Apply';
  String get navTrack => _isFil ? 'Subaybayan' : 'Track';
  String get navDocuments => _isFil ? 'Mga Dokumento' : 'Documents';

  // ── Home screen ────────────────────────────────────────────────────────────
  String get homeTrackAndUpdates =>
      _isFil ? 'Subaybayan at Mga Update' : 'Track & Updates';
  String get homeDocumentsAndCerts =>
      _isFil ? 'Mga Dokumento at Sertipiko' : 'Documents & Certificates';
  String get homeMyAppointments =>
      _isFil ? 'Aking mga Appointment' : 'My Appointments';
  String get homeScheduledVisits =>
      _isFil ? 'Mga nakatakdang pagbisita at pagdinig' : 'Scheduled visits and hearings';
  String get homeMyApplicationStatus =>
      _isFil ? 'Status ng Aking Aplikasyon' : 'My Application Status';
  String get homeFollowSubmissions =>
      _isFil ? 'Subaybayan ang iyong mga submission' : 'Follow your submissions';
  String get homeAnnouncements => _isFil ? 'Mga Anunsyo' : 'Announcements';
  String get homeNoticesFromOffice =>
      _isFil ? 'Mga abiso mula sa tanggapan ng prangkisa' : 'Notices from the franchising office';
  String get homeNotifications => _isFil ? 'Mga Abiso' : 'Notifications';
  String get homeDecisionsAndUpdates =>
      _isFil ? 'Mga desisyon, paalala at update' : 'Decisions, reminders and updates';
  String get homeMyDocuments => _isFil ? 'Aking mga Dokumento' : 'My Documents';
  String get homeManageFiles =>
      _isFil ? 'Pamahalaan ang iyong mga na-upload na file' : 'Manage your uploaded files';
  String get homeCertificateQR =>
      _isFil ? 'Sertipiko at QR Code' : 'Certificate & QR Code';
  String get homeViewCertificate =>
      _isFil ? 'Tingnan ang iyong sertipiko ng prangkisa' : 'View your franchise certificate';
  String get homeViewApplication =>
      _isFil ? 'Tingnan ang aplikasyon' : 'View application';
  String get homeApplicationDetails =>
      _isFil ? 'Detalye ng aplikasyon' : 'Application details';
  String get homeNoApplication =>
      _isFil ? 'Wala pang aplikasyon' : 'No application yet';
  String get homeStartApplication =>
      _isFil ? 'Magsimula ng bagong aplikasyon' : 'Start a new application';
  String get homeStartNew => _isFil ? 'Bagong Prangkisa' : 'New Franchise';
  String get homeRenewal => _isFil ? 'Pag-renew' : 'Renewal';
  String get homeActive => _isFil ? 'Aktibo' : 'Active';
  String get homeInactive => _isFil ? 'Hindi aktibo' : 'Inactive';
  String get homeWelcomeBack =>
      _isFil ? 'Maligayang pagbabalik' : 'Welcome back';
  String get homeAccount => 'Account';

  // ── Status labels ─────────────────────────────────────────────────────────
  String get statusApproved => _isFil ? 'Naaprubahan' : 'Approved';
  String get statusRejected => _isFil ? 'Tinanggihan' : 'Rejected';
  String get statusPending => _isFil ? 'Nakabinbin' : 'Pending';
  String get statusNew => _isFil ? 'Bagong Prangkisa' : 'New franchise';
  String get statusRenewal => _isFil ? 'Pag-renew' : 'Renewal';

  // Application detail rows
  String get detailType => _isFil ? 'Uri' : 'Type';
  String get detailToda => 'TODA';
  String get detailOperator => _isFil ? 'Operator' : 'Operator';
  String get detailContact => _isFil ? 'Kontak' : 'Contact';
  String get detailVehicle => _isFil ? 'Sasakyan' : 'Vehicle';
  String get detailPlate => _isFil ? 'Plaka' : 'Plate number';
  String get detailSubmitted => _isFil ? 'Isinumite' : 'Submitted';
  String get detailReviewed => _isFil ? 'Nasuri' : 'Reviewed';

  // ── Settings screen ────────────────────────────────────────────────────────
  String get settingsTitle => _isFil ? 'Mga Setting' : 'Settings';
  String get settingsPreferences =>
      _isFil ? 'Mga Kagustuhan' : 'Preferences';
  String get settingsCurrentLanguage =>
      _isFil ? 'Kasalukuyang wika' : 'Current language';
  String get settingsTapToUse =>
      _isFil ? 'I-tap para gamitin ang wikang ito' : 'Tap to use this language';
  String get settingsOnlyFullLanguages => _isFil
      ? 'Ang mga wika lamang na ganap na maaaring ipakita ng aplikasyon ang nakalista.'
      : 'Only languages the application can fully display are listed.';
  String get settingsUserAgreement =>
      _isFil ? 'Kasunduan ng Gumagamit' : 'User Agreement';
  String get settingsAccepted => _isFil ? 'Tinanggap' : 'Accepted';
  String get settingsAcceptanceRequired =>
      _isFil ? 'Kinakailangan ang pagtanggap' : 'Acceptance required';
  String get settingsReadAgreement =>
      _isFil ? 'Basahin ang kumpletong kasunduan' : 'Read the complete agreement';
  String get settingsAbout => _isFil ? 'Tungkol sa App' : 'About';
  String get settingsAppVersion =>
      _isFil ? 'Bersyon ng aplikasyon' : 'Application version';
  String get settingsCheckUpdates =>
      _isFil ? 'Suriin ang mga update' : 'Check for updates';
  String get settingsCheckUpdatesSubtitle => _isFil
      ? 'Tingnan kung may mas bagong build na available'
      : 'See whether a newer build is available';
  String get settingsWebAddress => _isFil ? 'Web address' : 'Web address';
  String get settingsLogOut => _isFil ? 'Mag-logout' : 'Log out';
  String get settingsUpdateAvailable =>
      _isFil ? 'Available ang update' : 'Update available';
  String get settingsOpenInstallPage =>
      _isFil ? 'Buksan ang pahina ng pag-install' : 'Open install page';
  String get settingsLater => _isFil ? 'Mamaya' : 'Later';
  String get settingsLatestVersion => _isFil
      ? 'Ikaw ay nasa pinakabagong bersyon'
      : 'You are on the latest version';
  String get settingsCouldNotCheckUpdates => _isFil
      ? 'Hindi ma-check ang mga update. Suriin ang iyong koneksyon at subukan muli.'
      : 'Could not check for updates. Check your connection and try again.';
  String get settingsCouldNotCheckUpdatesShort =>
      _isFil ? 'Hindi ma-check ang mga update.' : 'Could not check for updates.';

  // ── Onboarding ─────────────────────────────────────────────────────────────
  String get onboardingGetStarted => _isFil ? 'Magsimula' : 'Get started';
  String get onboardingContinue => _isFil ? 'Magpatuloy' : 'Continue';
  String get onboardingNext => _isFil ? 'Susunod' : 'Next';
  String get onboardingReviewAgreement =>
      _isFil ? 'Suriin ang kasunduan' : 'Review agreement';
  String get onboardingAcceptAndContinue =>
      _isFil ? 'Tanggapin at magpatuloy' : 'Accept and continue';
  String get onboardingBack => _isFil ? 'Bumalik' : 'Back';
  String get onboardingSkip => _isFil ? 'Laktawan' : 'Skip';

  // Welcome step
  String get welcomeTagline => _isFil
      ? 'Ang iyong prangkisa at pagpaparehistro ng driver, sa isang lugar'
      : 'Your franchise and driver registration, in one place';
  String get welcomeDescription => _isFil
      ? 'Mag-file at subaybayan ang iyong aplikasyon sa prangkisa ng traysikel, pamahalaan ang iyong mga kinakailangan, at itago ang iyong sertipiko at mga opisyal na update — mula sa Munisipyo ng Mabini, Batangas.'
      : 'File and track your tricycle franchise application, manage your requirements, and keep your certificate and official updates within reach — from the Municipality of Mabini, Batangas.';
  String get welcomeNextScreens => _isFil
      ? 'Ang mga susunod na screen ay aabutin ng wala pang isang minuto.'
      : 'The next screens take less than a minute.';
  String get welcomePillApplications =>
      _isFil ? 'Mga Aplikasyon' : 'Applications';
  String get welcomePillTracking => _isFil ? 'Pagsubaybay' : 'Tracking';
  String get welcomePillCertificate => _isFil ? 'Sertipiko' : 'Certificate';

  // Language step
  String get languageStepEyebrow =>
      _isFil ? 'Hakbang 1 ng 3 · Wika' : 'Step 1 of 3 · Language';
  String get languageStepTitle =>
      _isFil ? 'Piliin ang iyong wika' : 'Choose your language';
  String get languageStepSummary => _isFil
      ? 'Piliin ang wikang gagamitin sa buong aplikasyon. Maaari mo itong baguhin sa Mga Setting.'
      : 'Pick the language used across the application. You can change this later in Settings.';
  String get languageInfoNote => _isFil
      ? 'Ang English at Filipino ang mga wikang ganap na available sa release na ito.'
      : 'English and Filipino are the languages fully available in this release.';
  String get languageSelected => _isFil ? 'Napili' : 'Selected';
  String get languageTapToSelect => _isFil ? 'I-tap para piliin' : 'Tap to select';

  // Agreement step
  String get agreementEyebrow =>
      _isFil ? 'Hakbang 3 ng 3 · Mga Tuntunin' : 'Step 3 of 3 · Terms';
  String get agreementTitle =>
      _isFil ? 'Kasunduan ng Gumagamit' : 'User Agreement';
  String get agreementUpdatedNotice => _isFil
      ? 'Ang Kasunduan ng Gumagamit ay na-update. Mangyaring suriin at tanggapin ang rebisyong ito upang magpatuloy.'
      : 'The User Agreement has been updated. Please review and accept this revision to continue.';
  String get agreementReadFull =>
      _isFil ? 'Basahin ang kumpletong kasunduan' : 'Read the complete agreement';
  String get agreementCheckboxLabel => _isFil
      ? 'Nabasa at naunawaan ko ang Kasunduan ng Gumagamit, at tinatanggap ko ang mga tuntunin nito para sa paggamit ng MTOP System.'
      : 'I have read and understood the User Agreement, and I accept its terms for using the MTOP System.';
  String get agreementMustAccept => _isFil
      ? 'Dapat mong tanggapin ang kasunduan bago ka magpatuloy.'
      : 'You must accept the agreement before you can continue.';

  // Finished step
  String get finishedTitle => _isFil ? 'Handa ka na' : "You're all set";
  String get finishedSubtitle => _isFil
      ? 'Naka-save ang iyong mga kagustuhan sa device na ito. Maaari mong suriin ang kasunduan o baguhin ang iyong wika sa Mga Setting.'
      : 'Your preferences are saved on this device. You can review the agreement or change your language later in Settings.';
  String get finishedLabelLanguage => _isFil ? 'Wika' : 'Language';
  String get finishedLabelAgreement => _isFil ? 'Kasunduan' : 'Agreement';
  String get finishedLabelAcceptedOn =>
      _isFil ? 'Tinanggap noong' : 'Accepted on';
  String get finishedNextStep => _isFil
      ? 'Susunod, mag-sign in o lumikha ng iyong account.'
      : 'Next, sign in or create your driver account.';

  // ── Auth screens ───────────────────────────────────────────────────────────
  String get authLogOut => _isFil ? 'Mag-logout?' : 'Log Out?';
  String get authLogOutConfirm => _isFil
      ? 'Sigurado ka bang gusto mong mag-logout?'
      : 'Are you sure you want to log out?';
  String get authCancel => _isFil ? 'Kanselahin' : 'Cancel';
  String get authLogOutButton => _isFil ? 'Mag-logout' : 'Log out';

  // ── Error / loading ────────────────────────────────────────────────────────
  String get errorCouldNotLoadRequest => _isFil
      ? 'Hindi ma-load ang iyong form ng kahilingan. Suriin ang iyong koneksyon at subukan muli.'
      : 'Could not load your request form. Check your connection and try again.';

  // ── Update notice ─────────────────────────────────────────────────────────
  String updateAvailableContent(String version, Object build) => _isFil
      ? 'Ang MTOP $version (build $build) ay maaaring i-download mula sa pahina ng pag-install. Nananatiling buo ang iyong account at mga dokumento.'
      : 'MTOP $version (build $build) can be downloaded from the install page. Your account and documents stay as they are.';

  String latestVersionLabel(String label) => _isFil
      ? 'Ikaw ay nasa pinakabagong bersyon ($label).'
      : 'You are on the latest version ($label).';

  String finishedAgreementAcceptedFor(String version) => _isFil
      ? 'Bersyon $version tinanggap'
      : 'Version $version accepted';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'fil';

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture<
      AppLocalizations>(
    AppLocalizations(locale.languageCode == 'fil' ? 'fil' : 'en'),
  );

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

