import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import 'backend/push_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/nav/nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();
  await _activateAppCheck();

  await FlutterFlowTheme.initialize();

  runApp(MyApp());
}

/// Clave de reCAPTCHA v3 para App Check en web:
/// flutter build web --dart-define=APP_CHECK_SITE_KEY=...
const _appCheckSiteKey = String.fromEnvironment('APP_CHECK_SITE_KEY');

/// App Check: prueba al servidor que la llamada viene de la app real.
/// Si falla no bloquea el arranque; el servidor decide (APP_CHECK_MODE).
Future<void> _activateAppCheck() async {
  try {
    if (kIsWeb) {
      if (_appCheckSiteKey.isEmpty) return;
      await FirebaseAppCheck.instance
          .activate(webProvider: ReCaptchaV3Provider(_appCheckSiteKey));
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    }
  } catch (e) {
    debugPrint('App Check no se activó: $e');
  }
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    // Notificaciones push: al tocar una, abrir la pantalla indicada;
    // con la app abierta, mostrar una barra con botón "Ver".
    PushService.instance.onOpenLink = (link) => _router.push(link);
    PushService.instance.onForegroundMessage = (title, body, link) {
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Ver', onPressed: () => _router.push(link)),
      ));
    };

    userStream = bidStreamFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
        final uid = user.uid;
        if (user.loggedIn && uid != null) {
          PushService.instance.register(uid);
        }
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  // Por ahora la app usa siempre el tema claro (el oscuro aún no está
  // diseñado); se guarda la preferencia para cuando exista.
  void setThemeMode(ThemeMode mode) => FlutterFlowTheme.saveThemeMode(mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Subástalo Aquí',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      // Estilo claro tipo marketplace (el modo oscuro se diseñará después).
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
