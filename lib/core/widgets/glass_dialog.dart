import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// iOS-inspired glass modal used consistently across the app.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withOpacity(0.10),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.white.withOpacity(0.035)),
              ),
            ),
            SafeArea(
              child: Center(child: builder(context)),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    this.title,
    this.titleIcon,
    this.content,
    this.actions,
    this.width = 430,
    this.maxHeightFactor = 0.86,
    this.danger = false,
  });

  final Widget? title;
  final Widget? titleIcon;
  final Widget? content;
  final List<Widget>? actions;
  final double width;
  final double maxHeightFactor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.white.withOpacity(0.82),
                    const Color(0xFFEAF4FF).withOpacity(0.70),
                    Colors.white.withOpacity(0.62),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.88),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withOpacity(0.14),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.75),
                    blurRadius: 10,
                    spreadRadius: -3,
                    offset: const Offset(-8, -8),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                        child: Row(
                          children: [
                            if (titleIcon != null) ...[
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: (danger ? Colors.red : AppColors.primaryNavy)
                                      .withOpacity(0.09),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                                child: Center(child: titleIcon),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: DefaultTextStyle(
                                style: theme.textTheme.titleLarge!.copyWith(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  color: danger
                                      ? Colors.red.shade700
                                      : AppColors.primaryNavy,
                                ),
                                child: title!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (content != null)
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                          child: DefaultTextStyle(
                            style: theme.textTheme.bodyMedium!.copyWith(
                              fontFamily: 'Cairo',
                              color: AppColors.textDark,
                              height: 1.55,
                            ),
                            child: content!,
                          ),
                        ),
                      ),
                    if (actions != null && actions!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: 8,
                          runSpacing: 8,
                          children: actions!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }
}

class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final base = danger ? Colors.red : AppColors.primaryNavy;
    
    // توحيد ستايل الزر هنا
    final buttonStyle = ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: primary || danger
          ? base.withOpacity(onPressed == null ? 0.35 : 0.94)
          : Colors.white.withOpacity(0.42),
      foregroundColor: primary || danger ? Colors.white : base,
      disabledForegroundColor: Colors.white54,
      disabledBackgroundColor: base.withOpacity(0.25),
      side: BorderSide(color: Colors.white.withOpacity(0.8)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    // إذا كان هناك أيقونة نستخدم ElevatedButton.icon
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        style: buttonStyle,
      );
    }

    // إذا لم يكن هناك أيقونة نستخدم ElevatedButton العادي لضمان تمركز النص 100%
    return ElevatedButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
    );
  }
}


Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    barrierColor: Colors.black.withOpacity(0.10),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
    ),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.86),
                  const Color(0xFFEAF4FF).withOpacity(0.78),
                ],
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.2),
              ),
            ),
            child: SafeArea(top: false, child: builder(context)),
          ),
      ),
    ),
  );
}

Future<DateTime?> showGlassDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  DateTime selected = DateUtils.dateOnly(initialDate);
  return showGlassDialog<DateTime>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: const Text('اختيار التاريخ'),
      titleIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryNavy),
      content: StatefulBuilder(
        builder: (context, setState) {
          return CalendarDatePicker(
            initialDate: selected,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: (value) => setState(() => selected = value),
          );
        },
      ),
      actions: [
        GlassActionButton(
          label: 'إلغاء',
          onPressed: () => Navigator.pop(dialogContext),
        ),
        GlassActionButton(
          label: 'اختيار',
          icon: Icons.check_rounded,
          primary: true,
          onPressed: () => Navigator.pop(dialogContext, selected),
        ),
      ],
    ),
  );
}
