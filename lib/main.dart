import 'dart:async';
import 'package:enough_mail_app/routes.dart';
import 'package:enough_mail_app/screens/all_screens.dart';
import 'package:enough_mail_app/services/app_service.dart';
import 'package:enough_mail_app/services/background_service.dart';
import 'package:enough_mail_app/services/i18n_service.dart';
import 'package:enough_mail_app/services/mail_service.dart';
import 'package:enough_mail_app/services/navigation_service.dart';
import 'package:enough_mail_app/services/notification_service.dart';
import 'package:enough_mail_app/services/scaffold_messenger_service.dart';
import 'package:enough_mail_app/services/settings_service.dart';
import 'package:enough_mail_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'locator.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// AppStyles appStyles = AppStyles.instance;

void main() {
  setupLocator();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Future<void> _appInitialization;
  ThemeMode themeMode = ThemeMode.system;
  ThemeService themeService;
  Locale locale;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _appInitialization = initApp();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    locator<AppService>().didChangeAppLifecycleState(state);
  }

  Future<MailService> initApp() async {
    final settings = await locator<SettingsService>().init();
    themeService = locator<ThemeService>();
    themeService.addListener(() => setState(() {
          themeMode = themeService.themeMode;
        }));
    themeService.init(settings);
    final languageTag = settings.languageTag;
    if (languageTag != null) {
      final settingsLocale = AppLocalizations.supportedLocales.firstWhere(
          (l) => l.toLanguageTag() == languageTag,
          orElse: () => null);
      if (settingsLocale != null) {
        final settingsLocalizations =
            await AppLocalizations.delegate.load(settingsLocale);
        locator<I18nService>().init(settingsLocalizations, settingsLocale);
        setState(() {
          locale = settingsLocale;
        });
      }
    }
    final mailService = locator<MailService>();
    await mailService.init(locator<I18nService>().localizations);

    if (mailService.messageSource != null) {
      /// the app has at least one configured account
      locator<NavigationService>().push(Routes.messageSource,
          arguments: mailService.messageSource, fade: true, replace: true);
      // check for a tapped notification that started the app:
      final notificationInitResult =
          await locator<NotificationService>().init();
      if (notificationInitResult !=
          NotificationServiceInitResult.appLaunchedByNotification) {
        // the app has not been launched by a notification
        await locator<AppService>().checkForShare();
      }
    } else {
      // this app has no mail accounts yet, so switch to welcome screen:
      locator<NavigationService>()
          .push(Routes.welcome, fade: true, replace: true);
    }
    await locator<BackgroundService>().init();
    return mailService;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey:
          locator<ScaffoldMessengerService>().scaffoldMessengerKey,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: locale,
      theme: themeService?.lightTheme ?? ThemeService.defaultLightTheme,
      darkTheme: themeService?.darkTheme ?? ThemeService.defaultDarkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      title: 'Maily',
      onGenerateRoute: AppRouter.generateRoute,
      //initialRoute: Routes.splash,
      navigatorKey: locator<NavigationService>().navigatorKey,
      home: Builder(
        builder: (context) {
          locator<I18nService>().init(
              AppLocalizations.of(context), Localizations.localeOf(context));
          return FutureBuilder<MailService>(
            future: _appInitialization,
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                case ConnectionState.active:
                  return SplashScreen();
                  break;
                case ConnectionState.done:
                  // in the meantime the app has navigated away
                  break;
              }
              return Container();
            },
          );
        },
      ),
    );
  }
}
