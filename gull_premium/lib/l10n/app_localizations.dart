import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ku.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ku'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Rehan Rose'**
  String get appTitle;

  /// No description provided for @navFlowers.
  ///
  /// In en, this message translates to:
  /// **'Flowers'**
  String get navFlowers;

  /// No description provided for @navOccasions.
  ///
  /// In en, this message translates to:
  /// **'Occasions'**
  String get navOccasions;

  /// No description provided for @navVendors.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get navVendors;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @ctaBecomeVendor.
  ///
  /// In en, this message translates to:
  /// **'Become a Vendor'**
  String get ctaBecomeVendor;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @heroTitlePart1.
  ///
  /// In en, this message translates to:
  /// **'When words can\'t…\n'**
  String get heroTitlePart1;

  /// No description provided for @heroTitlePart2.
  ///
  /// In en, this message translates to:
  /// **'Let flowers speak.'**
  String get heroTitlePart2;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delivering your deepest emotions, in the most beautiful way.'**
  String get heroSubtitle;

  /// No description provided for @heroTagline.
  ///
  /// In en, this message translates to:
  /// **'Because some moments deserve more than words.'**
  String get heroTagline;

  /// No description provided for @emotionDropdownPrompt.
  ///
  /// In en, this message translates to:
  /// **'What do you want to say today?'**
  String get emotionDropdownPrompt;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose an emotion'**
  String get searchPlaceholder;

  /// No description provided for @chooseEmotion.
  ///
  /// In en, this message translates to:
  /// **'Choose an emotion'**
  String get chooseEmotion;

  /// No description provided for @emotionCelebrateThem.
  ///
  /// In en, this message translates to:
  /// **'Celebrate Them'**
  String get emotionCelebrateThem;

  /// No description provided for @emotionForeverBegins.
  ///
  /// In en, this message translates to:
  /// **'Forever Begins'**
  String get emotionForeverBegins;

  /// No description provided for @emotionImHere.
  ///
  /// In en, this message translates to:
  /// **'I\'m Here'**
  String get emotionImHere;

  /// No description provided for @emotionWithGratitude.
  ///
  /// In en, this message translates to:
  /// **'With Gratitude'**
  String get emotionWithGratitude;

  /// No description provided for @emotionJustBecause.
  ///
  /// In en, this message translates to:
  /// **'Just Because'**
  String get emotionJustBecause;

  /// No description provided for @emotionWellDeserved.
  ///
  /// In en, this message translates to:
  /// **'Well Deserved'**
  String get emotionWellDeserved;

  /// No description provided for @emotionStillYou.
  ///
  /// In en, this message translates to:
  /// **'Still You'**
  String get emotionStillYou;

  /// No description provided for @emotionThinkingOfYou.
  ///
  /// In en, this message translates to:
  /// **'Thinking of You'**
  String get emotionThinkingOfYou;

  /// No description provided for @flowersForEveryFeeling.
  ///
  /// In en, this message translates to:
  /// **'Flowers for every feeling.'**
  String get flowersForEveryFeeling;

  /// No description provided for @eachBouquetCopy.
  ///
  /// In en, this message translates to:
  /// **'Each bouquet is designed to say what your heart already feels.'**
  String get eachBouquetCopy;

  /// No description provided for @loadingBouquets.
  ///
  /// In en, this message translates to:
  /// **'Loading bouquets…'**
  String get loadingBouquets;

  /// No description provided for @couldNotLoadBouquets.
  ///
  /// In en, this message translates to:
  /// **'Could not load bouquets.'**
  String get couldNotLoadBouquets;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noBouquetsYet.
  ///
  /// In en, this message translates to:
  /// **'No bouquets yet.'**
  String get noBouquetsYet;

  /// No description provided for @noBouquetsForFeeling.
  ///
  /// In en, this message translates to:
  /// **'No bouquets for this feeling yet.'**
  String get noBouquetsForFeeling;

  /// No description provided for @carefullyCurated.
  ///
  /// In en, this message translates to:
  /// **'Carefully curated. Thoughtfully delivered.'**
  String get carefullyCurated;

  /// No description provided for @sameDayDelivery.
  ///
  /// In en, this message translates to:
  /// **'Same-day delivery'**
  String get sameDayDelivery;

  /// No description provided for @trustedLocalFlorists.
  ///
  /// In en, this message translates to:
  /// **'Trusted local florists'**
  String get trustedLocalFlorists;

  /// No description provided for @handcraftedBouquets.
  ///
  /// In en, this message translates to:
  /// **'Handcrafted bouquets'**
  String get handcraftedBouquets;

  /// No description provided for @splashMission.
  ///
  /// In en, this message translates to:
  /// **'We believe that every emotion deserves to arrive beautifully.'**
  String get splashMission;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @refreshOrTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please refresh the page or try again later.'**
  String get refreshOrTryAgain;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKurdish.
  ///
  /// In en, this message translates to:
  /// **'کوردی'**
  String get languageKurdish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @ctaButton.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get ctaButton;

  /// No description provided for @microCopyFlowersThatSay.
  ///
  /// In en, this message translates to:
  /// **'Flowers that say {label}'**
  String microCopyFlowersThatSay(String label);

  /// No description provided for @microCopyBouquetsFor.
  ///
  /// In en, this message translates to:
  /// **'Bouquets for {label}'**
  String microCopyBouquetsFor(String label);

  /// No description provided for @cat_love.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get cat_love;

  /// No description provided for @cat_apology.
  ///
  /// In en, this message translates to:
  /// **'I\'m Sorry'**
  String get cat_apology;

  /// No description provided for @cat_gratitude.
  ///
  /// In en, this message translates to:
  /// **'Thank You'**
  String get cat_gratitude;

  /// No description provided for @cat_sympathy.
  ///
  /// In en, this message translates to:
  /// **'Sympathy'**
  String get cat_sympathy;

  /// No description provided for @cat_wellness.
  ///
  /// In en, this message translates to:
  /// **'Get Well'**
  String get cat_wellness;

  /// No description provided for @cat_celebration.
  ///
  /// In en, this message translates to:
  /// **'Celebration'**
  String get cat_celebration;

  /// No description provided for @vendor_emotion_label.
  ///
  /// In en, this message translates to:
  /// **'Primary Emotion'**
  String get vendor_emotion_label;

  /// No description provided for @vendor_emotion_hint.
  ///
  /// In en, this message translates to:
  /// **'Choose the primary emotion this flower conveys (e.g., do not select \'Love\' for a funeral).'**
  String get vendor_emotion_hint;

  /// No description provided for @home_question.
  ///
  /// In en, this message translates to:
  /// **'What do you want to say today?'**
  String get home_question;

  /// No description provided for @makeItPerfectSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Make it Perfect?'**
  String get makeItPerfectSectionTitle;

  /// No description provided for @makeItSpecialSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Make it Special'**
  String get makeItSpecialSectionTitle;

  /// No description provided for @addVaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Vase'**
  String get addVaseLabel;

  /// No description provided for @addChocolateLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Chocolate'**
  String get addChocolateLabel;

  /// No description provided for @addCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCardLabel;

  /// No description provided for @selectLabel.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectLabel;

  /// No description provided for @totalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get totalPriceLabel;

  /// No description provided for @orderViaWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Order via WhatsApp'**
  String get orderViaWhatsApp;

  /// No description provided for @vendorDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendorDefaultName;

  /// No description provided for @vendorSearchBouquetHint.
  ///
  /// In en, this message translates to:
  /// **'Search by bouquet code...'**
  String get vendorSearchBouquetHint;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @noNewNotifications.
  ///
  /// In en, this message translates to:
  /// **'No new notifications.'**
  String get noNewNotifications;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @vendorNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get vendorNavDashboard;

  /// No description provided for @vendorNavOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get vendorNavOrders;

  /// No description provided for @vendorNavBouquets.
  ///
  /// In en, this message translates to:
  /// **'Bouquets'**
  String get vendorNavBouquets;

  /// No description provided for @vendorNavAddBouquet.
  ///
  /// In en, this message translates to:
  /// **'Add Bouquet'**
  String get vendorNavAddBouquet;

  /// No description provided for @vendorNavEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get vendorNavEarnings;

  /// No description provided for @vendorNavNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get vendorNavNotifications;

  /// No description provided for @vendorNavShopSettings.
  ///
  /// In en, this message translates to:
  /// **'Shop Settings'**
  String get vendorNavShopSettings;

  /// No description provided for @vendorNavSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get vendorNavSupport;

  /// No description provided for @vendorDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get vendorDashboardTitle;

  /// No description provided for @vendorTodaysOrders.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Orders'**
  String get vendorTodaysOrders;

  /// No description provided for @vendorPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get vendorPendingOrders;

  /// No description provided for @vendorTodaysRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get vendorTodaysRevenue;

  /// No description provided for @vendorShopStatus.
  ///
  /// In en, this message translates to:
  /// **'Shop Status'**
  String get vendorShopStatus;

  /// No description provided for @vendorAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get vendorAlerts;

  /// No description provided for @vendorNoOrdersNeedingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'No orders needing confirmation.'**
  String get vendorNoOrdersNeedingConfirmation;

  /// No description provided for @vendorNoNewAdminNotices.
  ///
  /// In en, this message translates to:
  /// **'No new admin notices.'**
  String get vendorNoNewAdminNotices;
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
      <String>['ar', 'en', 'ku'].contains(locale.languageCode);

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
    case 'ku':
      return AppLocalizationsKu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
