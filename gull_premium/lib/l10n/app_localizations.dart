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

  /// No description provided for @navOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get navOffers;

  /// No description provided for @navFlorists.
  ///
  /// In en, this message translates to:
  /// **'Florists'**
  String get navFlorists;

  /// No description provided for @navTrackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get navTrackOrder;

  /// No description provided for @navHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get navHelp;

  /// No description provided for @helpDeliveryAreas.
  ///
  /// In en, this message translates to:
  /// **'Delivery Areas'**
  String get helpDeliveryAreas;

  /// No description provided for @helpContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get helpContactUs;

  /// No description provided for @helpFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get helpFaq;

  /// No description provided for @occasionsShopByRecipient.
  ///
  /// In en, this message translates to:
  /// **'Shop by Recipient'**
  String get occasionsShopByRecipient;

  /// No description provided for @occasionsForMom.
  ///
  /// In en, this message translates to:
  /// **'For Mom'**
  String get occasionsForMom;

  /// No description provided for @occasionsForHer.
  ///
  /// In en, this message translates to:
  /// **'For Her'**
  String get occasionsForHer;

  /// No description provided for @occasionsForHim.
  ///
  /// In en, this message translates to:
  /// **'For Him'**
  String get occasionsForHim;

  /// No description provided for @navOccasionBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get navOccasionBirthday;

  /// No description provided for @trackOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Track Your Order'**
  String get trackOrderTitle;

  /// No description provided for @trackOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your Order ID to see status.'**
  String get trackOrderHint;

  /// No description provided for @orderIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderIdLabel;

  /// No description provided for @trackOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get trackOrderButton;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found. Please check the ID.'**
  String get orderNotFound;

  /// No description provided for @orderStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get orderStatusReceived;

  /// No description provided for @orderStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get orderStatusPreparing;

  /// No description provided for @orderStatusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get orderStatusOnTheWay;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

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

  /// No description provided for @signInRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Register'**
  String get signInRegister;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @signUpWithGmail.
  ///
  /// In en, this message translates to:
  /// **'Sign up using Gmail'**
  String get signUpWithGmail;

  /// No description provided for @orSignUpWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Or sign up with your details'**
  String get orSignUpWithDetails;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your preferences and track orders.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @orSignInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Or sign in with email'**
  String get orSignInWithEmail;

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

  /// No description provided for @reachedEndOfList.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end.'**
  String get reachedEndOfList;

  /// No description provided for @noOffersYet.
  ///
  /// In en, this message translates to:
  /// **'No offers at the moment.'**
  String get noOffersYet;

  /// No description provided for @specialOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Special Offers'**
  String get specialOffersTitle;

  /// No description provided for @noOffersBrowseAll.
  ///
  /// In en, this message translates to:
  /// **'No special offers right now. Browse our full collection below.'**
  String get noOffersBrowseAll;

  /// No description provided for @browseAllBouquets.
  ///
  /// In en, this message translates to:
  /// **'Browse all bouquets'**
  String get browseAllBouquets;

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

  /// No description provided for @cat_birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get cat_birthday;

  /// No description provided for @cat_anniversary.
  ///
  /// In en, this message translates to:
  /// **'Anniversary'**
  String get cat_anniversary;

  /// No description provided for @cat_newborn.
  ///
  /// In en, this message translates to:
  /// **'New Born'**
  String get cat_newborn;

  /// No description provided for @cat_wedding.
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get cat_wedding;

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

  /// No description provided for @occasionsCuratedFor.
  ///
  /// In en, this message translates to:
  /// **'Discover our curated collection crafted perfectly for {label}.'**
  String occasionsCuratedFor(String label);

  /// No description provided for @what_do_you_want_to_say.
  ///
  /// In en, this message translates to:
  /// **'What do you want to say today?'**
  String get what_do_you_want_to_say;

  /// No description provided for @say_love.
  ///
  /// In en, this message translates to:
  /// **'Say \'I love you\'...'**
  String get say_love;

  /// No description provided for @say_sorry.
  ///
  /// In en, this message translates to:
  /// **'Say \'I\'m sorry\'...'**
  String get say_sorry;

  /// No description provided for @say_congrats.
  ///
  /// In en, this message translates to:
  /// **'Say \'Congratulations\'...'**
  String get say_congrats;

  /// No description provided for @say_thanks.
  ///
  /// In en, this message translates to:
  /// **'Say \'Thank you\'...'**
  String get say_thanks;

  /// No description provided for @collection_crafted_for.
  ///
  /// In en, this message translates to:
  /// **'Discover our curated collection crafted perfectly for '**
  String get collection_crafted_for;

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

  /// No description provided for @locationRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'* Required before ordering'**
  String get locationRequiredSubtitle;

  /// No description provided for @locationRequiredSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery location to complete your order.'**
  String get locationRequiredSnackbar;

  /// No description provided for @includesFreeVoiceMessageQRCode.
  ///
  /// In en, this message translates to:
  /// **'Includes Free Voice Message QR Code'**
  String get includesFreeVoiceMessageQRCode;

  /// No description provided for @addOnPersonalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Add-on & Personalization'**
  String get addOnPersonalizationTitle;

  /// No description provided for @addOnAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addOnAddButton;

  /// No description provided for @addOnChooseVases.
  ///
  /// In en, this message translates to:
  /// **'Choose a Vase'**
  String get addOnChooseVases;

  /// No description provided for @addOnChooseChocolates.
  ///
  /// In en, this message translates to:
  /// **'Choose Chocolates'**
  String get addOnChooseChocolates;

  /// No description provided for @addOnChooseCards.
  ///
  /// In en, this message translates to:
  /// **'Choose a Card'**
  String get addOnChooseCards;

  /// No description provided for @addOnChooseAddOn.
  ///
  /// In en, this message translates to:
  /// **'Choose Add-on'**
  String get addOnChooseAddOn;

  /// No description provided for @step1AddOns.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Add-ons'**
  String get step1AddOns;

  /// No description provided for @step2VoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Voice Message'**
  String get step2VoiceMessage;

  /// No description provided for @step3Order.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Order'**
  String get step3Order;

  /// No description provided for @couldNotLoadProduct.
  ///
  /// In en, this message translates to:
  /// **'Could not load product.'**
  String get couldNotLoadProduct;

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found.'**
  String get productNotFound;

  /// No description provided for @voiceMessageAdded.
  ///
  /// In en, this message translates to:
  /// **'Voice message added'**
  String get voiceMessageAdded;

  /// No description provided for @addAmountMoreForFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} IQD more to get FREE Delivery!'**
  String addAmountMoreForFreeDelivery(String amount);

  /// No description provided for @youUnlockedFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'🎉 You unlocked FREE Delivery!'**
  String get youUnlockedFreeDelivery;

  /// No description provided for @payWithFIB.
  ///
  /// In en, this message translates to:
  /// **'Pay with FIB'**
  String get payWithFIB;

  /// No description provided for @currencyIqd.
  ///
  /// In en, this message translates to:
  /// **'IQD'**
  String get currencyIqd;

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

  /// No description provided for @vendorActiveBouquets.
  ///
  /// In en, this message translates to:
  /// **'Active Bouquets'**
  String get vendorActiveBouquets;

  /// No description provided for @vendorPendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get vendorPendingApprovals;

  /// No description provided for @vendorTotalViewsClicks.
  ///
  /// In en, this message translates to:
  /// **'Total Views / Clicks'**
  String get vendorTotalViewsClicks;

  /// No description provided for @vendorMotivationGreatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job! Your shop is looking beautiful.'**
  String get vendorMotivationGreatJob;

  /// No description provided for @vendorMotivationMoreBouquets.
  ///
  /// In en, this message translates to:
  /// **'Add more beautiful bouquets to attract more customers!'**
  String get vendorMotivationMoreBouquets;

  /// No description provided for @footerTagline.
  ///
  /// In en, this message translates to:
  /// **'Delivering emotions, one flower at a time.'**
  String get footerTagline;

  /// No description provided for @footerHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get footerHelpCenter;

  /// No description provided for @footerFlowerCareGuide.
  ///
  /// In en, this message translates to:
  /// **'Flower Care Guide'**
  String get footerFlowerCareGuide;

  /// No description provided for @footerFaqs.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get footerFaqs;

  /// No description provided for @footerCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rehan Rose'**
  String get footerCompanyTitle;

  /// No description provided for @footerAboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get footerAboutUs;

  /// No description provided for @aboutStoryHeading.
  ///
  /// In en, this message translates to:
  /// **'Why we started Rehan Rose'**
  String get aboutStoryHeading;

  /// No description provided for @vendorSignupHeadline.
  ///
  /// In en, this message translates to:
  /// **'Become a Rehan Rose florist'**
  String get vendorSignupHeadline;

  /// No description provided for @footerBecomeFlorist.
  ///
  /// In en, this message translates to:
  /// **'Become a Florist'**
  String get footerBecomeFlorist;

  /// No description provided for @footerPrivacyTerms.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy & Terms'**
  String get footerPrivacyTerms;

  /// No description provided for @footerContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get footerContactUs;

  /// No description provided for @footerChatOnWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Chat on WhatsApp'**
  String get footerChatOnWhatsApp;

  /// No description provided for @footerAddress.
  ///
  /// In en, this message translates to:
  /// **'Sulaymaniyah, Iraq'**
  String get footerAddress;

  /// No description provided for @footerCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} Rehan Rose. All rights reserved.'**
  String footerCopyright(int year);

  /// No description provided for @footerDeliveryZones.
  ///
  /// In en, this message translates to:
  /// **'Delivery Locations'**
  String get footerDeliveryZones;

  /// No description provided for @footerDeliveryZonesIntro.
  ///
  /// In en, this message translates to:
  /// **'We deliver to the following areas:'**
  String get footerDeliveryZonesIntro;

  /// No description provided for @flowerCareGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'Simple tips to keep your flowers fresh longer:'**
  String get flowerCareGuideIntro;

  /// No description provided for @flowerCareTipWater.
  ///
  /// In en, this message translates to:
  /// **'Change water daily'**
  String get flowerCareTipWater;

  /// No description provided for @flowerCareTipSun.
  ///
  /// In en, this message translates to:
  /// **'Keep away from direct sun'**
  String get flowerCareTipSun;

  /// No description provided for @flowerCareTipStems.
  ///
  /// In en, this message translates to:
  /// **'Trim stems'**
  String get flowerCareTipStems;

  /// No description provided for @faqPaymentQuestion.
  ///
  /// In en, this message translates to:
  /// **'What payment methods do you accept?'**
  String get faqPaymentQuestion;

  /// No description provided for @faqPaymentAnswer.
  ///
  /// In en, this message translates to:
  /// **'We accept FastPay, ZainCash, FIB, and Visa. You can also pay via WhatsApp for your convenience.'**
  String get faqPaymentAnswer;

  /// No description provided for @faqDeliveryQuestion.
  ///
  /// In en, this message translates to:
  /// **'How long does delivery take?'**
  String get faqDeliveryQuestion;

  /// No description provided for @faqDeliveryAnswer.
  ///
  /// In en, this message translates to:
  /// **'We offer same-day delivery in supported areas. Orders placed before noon are typically delivered the same day; otherwise the next day.'**
  String get faqDeliveryAnswer;

  /// No description provided for @faqReturnsQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is your return policy?'**
  String get faqReturnsQuestion;

  /// No description provided for @faqReturnsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Due to the perishable nature of flowers, we cannot accept returns. If your order arrives damaged or incorrect, please contact us within 24 hours with photos and we will make it right.'**
  String get faqReturnsAnswer;

  /// No description provided for @legalPrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicyTitle;

  /// No description provided for @legalTermsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTermsOfServiceTitle;

  /// No description provided for @legalPrivacyIntro.
  ///
  /// In en, this message translates to:
  /// **'Rehan Rose (\"we\") respects your privacy. This policy describes how we collect, use, and protect your information when you use our platform.'**
  String get legalPrivacyIntro;

  /// No description provided for @legalPrivacyData.
  ///
  /// In en, this message translates to:
  /// **'We collect information you provide when ordering (name, delivery address, phone, email), account details if you sign in or register as a vendor, and usage data such as device and browsing information to improve our service.'**
  String get legalPrivacyData;

  /// No description provided for @legalPrivacyUse.
  ///
  /// In en, this message translates to:
  /// **'We use this information to process orders, communicate with you, improve our website and services, and comply with legal obligations.'**
  String get legalPrivacyUse;

  /// No description provided for @legalPrivacySharing.
  ///
  /// In en, this message translates to:
  /// **'We do not sell your personal data. We may share information with delivery partners and service providers necessary to fulfil orders and operate the platform, under strict confidentiality.'**
  String get legalPrivacySharing;

  /// No description provided for @legalPrivacyContact.
  ///
  /// In en, this message translates to:
  /// **'For privacy-related questions, contact us at the email or address provided in the footer.'**
  String get legalPrivacyContact;

  /// No description provided for @legalTermsIntro.
  ///
  /// In en, this message translates to:
  /// **'By using Rehan Rose, you agree to these Terms of Service. Please read them carefully.'**
  String get legalTermsIntro;

  /// No description provided for @legalTermsUse.
  ///
  /// In en, this message translates to:
  /// **'You may use our platform for lawful purposes only. You must provide accurate information when placing orders and not misuse the service (e.g. fraud, harassment, or violating applicable laws).'**
  String get legalTermsUse;

  /// No description provided for @legalTermsOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders are subject to availability and acceptance. Pricing and delivery terms are as shown at checkout. We and our florist partners aim to deliver fresh, quality bouquets; specific guarantees are as stated on the product and checkout pages.'**
  String get legalTermsOrders;

  /// No description provided for @legalTermsContact.
  ///
  /// In en, this message translates to:
  /// **'For questions about these terms, contact us using the details in the footer. We may update these terms from time to time; continued use after changes constitutes acceptance.'**
  String get legalTermsContact;

  /// No description provided for @aboutStoryParagraph1.
  ///
  /// In en, this message translates to:
  /// **'Rehan Rose started from a simple belief: every bouquet should carry the care of a real florist and the freshness of flowers that were chosen and arranged by hand. We wanted to bring that experience to you—without the middleman, without the long supply chains.'**
  String get aboutStoryParagraph1;

  /// No description provided for @aboutStoryParagraph2.
  ///
  /// In en, this message translates to:
  /// **'That\'s why we work only with local florists. Each bouquet on Rehan Rose is made by a florist in your region—people who know the seasons, the flowers, and the craft. When you order from us, you\'re supporting small businesses and getting flowers that were prepared the same day, not shipped from far away.'**
  String get aboutStoryParagraph2;

  /// No description provided for @aboutStoryParagraph3.
  ///
  /// In en, this message translates to:
  /// **'Fresh flowers, local talent, and a platform that connects you to both—that\'s the story behind Rehan Rose. Thank you for being part of it.'**
  String get aboutStoryParagraph3;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back Online'**
  String get backOnline;

  /// No description provided for @adminSuperAdminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Super Admin Dashboard'**
  String get adminSuperAdminDashboard;

  /// No description provided for @adminSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to review vendor applications. If you see \"Access restricted\", add your UID to the admins collection in Firestore (instructions shown there).'**
  String get adminSignInPrompt;

  /// No description provided for @adminEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin email'**
  String get adminEmailLabel;

  /// No description provided for @adminEmailHint.
  ///
  /// In en, this message translates to:
  /// **'admin@email.com'**
  String get adminEmailHint;

  /// No description provided for @adminPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminPasswordLabel;

  /// No description provided for @adminPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get adminPasswordHint;

  /// No description provided for @adminSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get adminSigningIn;

  /// No description provided for @adminEnterEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your admin email and password.'**
  String get adminEnterEmailPassword;

  /// No description provided for @adminUnableToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in.'**
  String get adminUnableToSignIn;

  /// No description provided for @adminAccessRestricted.
  ///
  /// In en, this message translates to:
  /// **'Access restricted'**
  String get adminAccessRestricted;

  /// No description provided for @adminNotRegisteredPrompt.
  ///
  /// In en, this message translates to:
  /// **'This account is not registered as a super admin. To grant access, add a document in Firestore:'**
  String get adminNotRegisteredPrompt;

  /// No description provided for @adminFirestoreInstructions.
  ///
  /// In en, this message translates to:
  /// **'Collection: admins\nDocument ID: {uid}'**
  String adminFirestoreInstructions(String uid);

  /// No description provided for @adminFirestoreSteps.
  ///
  /// In en, this message translates to:
  /// **'You can create an empty document in Firebase Console (Firestore → admins → Add document with the ID above). Then sign out and sign in again.'**
  String get adminFirestoreSteps;

  /// No description provided for @adminSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get adminSignOut;

  /// No description provided for @adminPendingApplications.
  ///
  /// In en, this message translates to:
  /// **'Pending vendor applications'**
  String get adminPendingApplications;

  /// No description provided for @adminAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get adminAnalytics;

  /// No description provided for @adminBouquetApproval.
  ///
  /// In en, this message translates to:
  /// **'Bouquet Approval'**
  String get adminBouquetApproval;

  /// No description provided for @adminManageAddOns.
  ///
  /// In en, this message translates to:
  /// **'Manage Add-ons'**
  String get adminManageAddOns;

  /// No description provided for @adminLoadingApplications.
  ///
  /// In en, this message translates to:
  /// **'Loading applications…'**
  String get adminLoadingApplications;

  /// No description provided for @adminUnableToLoadApplications.
  ///
  /// In en, this message translates to:
  /// **'Unable to load applications.'**
  String get adminUnableToLoadApplications;

  /// No description provided for @adminNoPendingApplications.
  ///
  /// In en, this message translates to:
  /// **'No pending applications.'**
  String get adminNoPendingApplications;

  /// No description provided for @adminStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get adminStudio;

  /// No description provided for @adminOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get adminOwner;

  /// No description provided for @adminEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminEmail;

  /// No description provided for @adminPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get adminPhone;

  /// No description provided for @adminLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get adminLocation;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminWorking.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get adminWorking;

  /// No description provided for @adminApplicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Application approved.'**
  String get adminApplicationApproved;

  /// No description provided for @adminApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application rejected.'**
  String get adminApplicationRejected;

  /// No description provided for @adminUnableToApprove.
  ///
  /// In en, this message translates to:
  /// **'Unable to approve application.'**
  String get adminUnableToApprove;

  /// No description provided for @adminUnableToReject.
  ///
  /// In en, this message translates to:
  /// **'Unable to reject application.'**
  String get adminUnableToReject;

  /// No description provided for @profilePremiumMember.
  ///
  /// In en, this message translates to:
  /// **'Premium Member'**
  String get profilePremiumMember;

  /// No description provided for @profileMyOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get profileMyOrders;

  /// No description provided for @profileSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get profileSavedAddresses;

  /// No description provided for @profileMySpecialOccasions.
  ///
  /// In en, this message translates to:
  /// **'My Special Occasions'**
  String get profileMySpecialOccasions;

  /// No description provided for @profileAddOccasion.
  ///
  /// In en, this message translates to:
  /// **'Add Occasion'**
  String get profileAddOccasion;

  /// No description provided for @profileOccasionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you to send flowers for birthdays, anniversaries & more.'**
  String get profileOccasionsSubtitle;

  /// No description provided for @profileContactSupportWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Contact Support (WhatsApp)'**
  String get profileContactSupportWhatsApp;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePassword;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get profileComingSoon;

  /// No description provided for @vendorPleaseCompleteEveryField.
  ///
  /// In en, this message translates to:
  /// **'Please complete every field.'**
  String get vendorPleaseCompleteEveryField;

  /// No description provided for @vendorApplicationSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Application submitted. It has been sent to the super admin for approval. You can sign in once your application is approved.'**
  String get vendorApplicationSubmittedMessage;

  /// No description provided for @vendorUnableToSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit application.'**
  String get vendorUnableToSubmitApplication;

  /// No description provided for @vendorUnableToSubmitApplicationRetry.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit application. Please try again.'**
  String get vendorUnableToSubmitApplicationRetry;

  /// No description provided for @vendorEnterEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get vendorEnterEmailPassword;

  /// No description provided for @vendorApplicationRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your application was rejected. Contact support for details.'**
  String get vendorApplicationRejectedMessage;

  /// No description provided for @vendorApplicationUnderReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Your application is still under review. Only approved vendors can sign in.'**
  String get vendorApplicationUnderReviewMessage;

  /// No description provided for @vendorUnableToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in.'**
  String get vendorUnableToSignIn;

  /// No description provided for @vendorCouldNotSignInFallback.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Please check your email and password, or try again later.'**
  String get vendorCouldNotSignInFallback;

  /// No description provided for @vendorBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get vendorBackToSignIn;

  /// No description provided for @vendorAdminLink.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get vendorAdminLink;

  /// No description provided for @vendorSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Vendor sign in'**
  String get vendorSignInTitle;

  /// No description provided for @vendorStartApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Start your vendor application'**
  String get vendorStartApplicationTitle;

  /// No description provided for @vendorSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Access your storefront and orders.'**
  String get vendorSignInSubtitle;

  /// No description provided for @vendorStartApplicationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your studio so we can review your application.'**
  String get vendorStartApplicationSubtitle;

  /// No description provided for @vendorLabelBusinessEmail.
  ///
  /// In en, this message translates to:
  /// **'Business email'**
  String get vendorLabelBusinessEmail;

  /// No description provided for @vendorLabelPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get vendorLabelPassword;

  /// No description provided for @vendorSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get vendorSigningIn;

  /// No description provided for @vendorForgotPasswordContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password? Contact vendor support.'**
  String get vendorForgotPasswordContactSupport;

  /// No description provided for @vendorStudioName.
  ///
  /// In en, this message translates to:
  /// **'Studio name'**
  String get vendorStudioName;

  /// No description provided for @vendorOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get vendorOwnerName;

  /// No description provided for @vendorOwnerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get vendorOwnerNameHint;

  /// No description provided for @vendorPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get vendorPhoneNumber;

  /// No description provided for @vendorStudioLocation.
  ///
  /// In en, this message translates to:
  /// **'Studio location'**
  String get vendorStudioLocation;

  /// No description provided for @vendorStudioLocationHint.
  ///
  /// In en, this message translates to:
  /// **'city'**
  String get vendorStudioLocationHint;

  /// No description provided for @vendorCreatePassword.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get vendorCreatePassword;

  /// No description provided for @vendorCreatePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'at least 8 characters'**
  String get vendorCreatePasswordHint;

  /// No description provided for @vendorSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get vendorSubmitting;

  /// No description provided for @vendorSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get vendorSubmitApplication;

  /// No description provided for @vendorTermsAgreement.
  ///
  /// In en, this message translates to:
  /// **'By submitting, you agree to our vendor terms and review process.'**
  String get vendorTermsAgreement;

  /// No description provided for @vendorShowcaseCopy.
  ///
  /// In en, this message translates to:
  /// **'Showcase your studio, manage orders, and connect with clients who value artisanal florals.'**
  String get vendorShowcaseCopy;

  /// No description provided for @vendorBenefitWeeklyPayouts.
  ///
  /// In en, this message translates to:
  /// **'Weekly payouts'**
  String get vendorBenefitWeeklyPayouts;

  /// No description provided for @vendorBenefitCuratedClientBase.
  ///
  /// In en, this message translates to:
  /// **'Curated client base'**
  String get vendorBenefitCuratedClientBase;

  /// No description provided for @vendorBenefitDedicatedConcierge.
  ///
  /// In en, this message translates to:
  /// **'Dedicated concierge'**
  String get vendorBenefitDedicatedConcierge;

  /// No description provided for @vendorSuccessToolkitTitle.
  ///
  /// In en, this message translates to:
  /// **'Vendor success toolkit'**
  String get vendorSuccessToolkitTitle;

  /// No description provided for @vendorSuccessToolkitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you need to run a premium floral studio, in one place.'**
  String get vendorSuccessToolkitSubtitle;

  /// No description provided for @vendorToolkitOrderManagement.
  ///
  /// In en, this message translates to:
  /// **'Order management'**
  String get vendorToolkitOrderManagement;

  /// No description provided for @vendorToolkitOrderManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Track inbound orders, confirm delivery windows, and chat with concierge support.'**
  String get vendorToolkitOrderManagementDesc;

  /// No description provided for @vendorToolkitMerchandising.
  ///
  /// In en, this message translates to:
  /// **'Merchandising tools'**
  String get vendorToolkitMerchandising;

  /// No description provided for @vendorToolkitMerchandisingDesc.
  ///
  /// In en, this message translates to:
  /// **'Curate collections, schedule seasonal launches, and highlight your signature style.'**
  String get vendorToolkitMerchandisingDesc;

  /// No description provided for @vendorToolkitInsightsPayouts.
  ///
  /// In en, this message translates to:
  /// **'Insights & payouts'**
  String get vendorToolkitInsightsPayouts;

  /// No description provided for @vendorToolkitInsightsPayoutsDesc.
  ///
  /// In en, this message translates to:
  /// **'Review weekly performance and receive reliable payouts every Friday.'**
  String get vendorToolkitInsightsPayoutsDesc;

  /// No description provided for @vendorToggleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get vendorToggleSignIn;

  /// No description provided for @vendorToggleCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get vendorToggleCreateAccount;

  /// No description provided for @vendorStatSatisfaction.
  ///
  /// In en, this message translates to:
  /// **'Vendor satisfaction'**
  String get vendorStatSatisfaction;

  /// No description provided for @vendorStatAvgRevenue.
  ///
  /// In en, this message translates to:
  /// **'Avg. weekly revenue'**
  String get vendorStatAvgRevenue;

  /// No description provided for @vendorStatFastOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Fast onboarding'**
  String get vendorStatFastOnboarding;
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
