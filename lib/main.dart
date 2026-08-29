import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_colors.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseInitializationError;

  try {
    // يولّد flutterfire configure قيماً مستقلة وصحيحة لكل منصة.
    // لا تضع FirebaseOptions الخاصة بتطبيق Web داخل نسخة Android.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stackTrace) {
    firebaseInitializationError = e;
    debugPrint('Firebase initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (firebaseInitializationError == null) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
      );
    } catch (e, stackTrace) {
      // لا نمنع الوظائف المحلية من العمل، لكن الطلبات السحابية المحمية
      // ستفشل برسالة واضحة حتى يتم ضبط App Check.
      debugPrint('Firebase App Check activation failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(
    SecurityManagerApp(
      firebaseInitializationError: firebaseInitializationError,
    ),
  );
}

class SecurityManagerApp extends StatelessWidget {
  const SecurityManagerApp({
    super.key,
    this.firebaseInitializationError,
  });

  final Object? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Security Guard Manager',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryNavy,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryBlue,
          secondary: AppColors.accentGold,
          surface: AppColors.glassWhite,
        ),
        scaffoldBackgroundColor: AppColors.backgroundGrey,
        cardTheme: CardThemeData(
          color: AppColors.glassWhite,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textDark,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xF2F5FAFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 5,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white54,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: Colors.white70),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(
              color: AppColors.primaryBlue,
              width: 1.4,
            ),
          ),
        ),
        fontFamily: 'Cairo',
      ),
      home: firebaseInitializationError == null
          ? const SplashScreen()
          : const _FirebaseConfigurationErrorScreen(),
    );
  }
}

class _FirebaseConfigurationErrorScreen extends StatelessWidget {
  const _FirebaseConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.redAccent,
                ),
                SizedBox(height: 18),
                Text(
                  'تعذر تهيئة Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'تأكد من تشغيل flutterfire configure ووجود ملف '
                  'lib/firebase_options.dart الصحيح، ثم أعد بناء التطبيق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
