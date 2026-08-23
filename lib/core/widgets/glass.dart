import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          // الدوائر الخلفية التي تعطي تأثير الزجاج الملون
          Positioned(top: -90, right: -70, child: _orb(220, const Color(0x553D9BF3))),
          Positioned(top: 220, left: -100, child: _orb(210, const Color(0x4443C6F4))),
          Positioned(bottom: -90, right: -60, child: _orb(230, const Color(0x443A6BE8))),
          child,
        ],
      ),
    );
  }

  static Widget _orb(double size, Color color) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color color;
  final Border? border;
  final List<BoxShadow>? shadows;
  final double blur;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero, // تعديل هام: تم جعله صفر ليسمح بتأثير اللمس بالامتداد للحواف
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.color = AppColors.glassWhite,
    this.border,
    this.shadows,
    this.blur = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: border ?? Border.all(color: AppColors.glassBorder),
            boxShadow: shadows ?? [
              const BoxShadow(color: Color(0x22163A63), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;

  const GlassPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        // تعديل: تأكيد استخدام خط كايرو في شريط العنوان
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo', 
            fontWeight: FontWeight.bold,
            color: AppColors.primaryNavy, // أو لون مناسب لتصميمك
          ),
        ),
        actions: actions,
      ),
      body: GlassBackground(child: SafeArea(child: child)),
    );
  }
}

class GlassActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const GlassActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF274C77), Color(0xFF163A63)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33163A63), blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        // تعديل: تأكيد استخدام خط كايرو في زر الإجراءات
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo', 
            fontWeight: FontWeight.bold, 
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
