import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// استدعاء مكتبة فايربيز الأساسية
import 'package:firebase_core/firebase_core.dart'; 

import 'core/theme/app_colors.dart';
import 'features/splash/splash_screen.dart';

// تحويل الدالة الرئيسية إلى async لتنتظر الاتصال بالسحابة قبل تشغيل التطبيق
void main() async {
  // التأكد من تهيئة واجهة المستخدم ومحرك فلاتر أولاً
  WidgetsFlutterBinding.ensureInitialized();
  
  // محاولة الاتصال بقاعدة بيانات فايربيز باستخدام مفاتيحك الخاصة
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyA7eO1_OqT8pzSu_n9ssB6OO3TOJlYVkiM", 
        appId: "1:383666012257:web:07171f165f7394df74ea20", 
        messagingSenderId: "383666012257",
        projectId: "amantak2-30b21", 
      ),
    );
    debugPrint("✅ تم الاتصال بخوادم Firebase بنجاح!");
  } catch (e) {
    debugPrint("❌ حدث خطأ أثناء الاتصال: $e");
  }

  // تشغيل واجهة التطبيق بعد الانتهاء من التهيئة
  runApp(const SecurityManagerApp());
}

class SecurityManagerApp extends StatelessWidget {
  const SecurityManagerApp({super.key});

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textDark,
          titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xF2F5FAFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 5,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white54,
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: Colors.white70)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.4)),
        ),
        fontFamily: 'Cairo',
      ),
      home: const SplashScreen(),
    );
  }
}
