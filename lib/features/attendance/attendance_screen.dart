import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart'; 
// استدعاء مكونات الزجاج
import '../../core/widgets/glass.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  bool isClockedIn = false;
  String lastActionTime = "جاهز لتسجيل حركة جديدة";
  
  String? selectedGuard; 
  List<Map<String, dynamic>> guardsList = []; 
  bool isLoading = true;
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadGuards(); 
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadGuards() async {
    try {
      final guards = await DatabaseHelper.instance.getAllGuards();
      if (!mounted) return;
      setState(() {
        guardsList = guards;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل قائمة أفراد الأمن.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkGuardLastAction(String? guardName) async {
    if (guardName == null) return;

    String todayDate = _formatDate(DateTime.now());
    final db = await DatabaseHelper.instance.database;
    
    final result = await db.query(
      'attendance',
      where: 'guard_name = ? AND action_date = ?',
      whereArgs: [guardName, todayDate],
      orderBy: 'id DESC', 
      limit: 1, 
    );

    if (!mounted || selectedGuard != guardName) return;

    setState(() {
      if (result.isNotEmpty) {
        final lastAction = result.first['action_type'] as String? ?? '';
        isClockedIn = (lastAction == 'دخول');
        lastActionTime = "آخر حركة: $lastAction الساعة ${result.first['action_time']}";
      } else {
        isClockedIn = false;
        lastActionTime = "لم يتم تسجيل أي حركة لهذا الفرد اليوم";
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    int h = time.hour;
    int m = time.minute;
    String ampm = h >= 12 ? 'م' : 'ص';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    String mStr = m.toString().padLeft(2, '0');
    return '$h:$mStr $ampm';
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleAttendance() async {
    if (_isSubmitting) return;

    if (selectedGuard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'الرجاء اختيار اسم الحارس أولاً!',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return; 
    }

    final now = DateTime.now(); // جلب الوقت عند ضغط الزر
    final actionType = isClockedIn ? 'انصراف' : 'دخول';
    final actionTime = _formatTime(now);
    final actionDate = _formatDate(now);

    setState(() => _isSubmitting = true);
    try {
      await DatabaseHelper.instance.insertAttendance({
        'guard_name': selectedGuard,
        'action_type': actionType,
        'action_time': actionTime,
        'action_date': actionDate,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حفظ حركة الحضور. حاول مرة أخرى.', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;

    setState(() {
      isClockedIn = !isClockedIn;
      lastActionTime = 'تم تسجيل $actionType لـ ($selectedGuard) الساعة $actionTime';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تسجيل $actionType: $selectedGuard',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: actionType == 'دخول' ? Colors.green.withOpacity(0.9) : AppColors.accentGold.withOpacity(0.9),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor = isClockedIn ? AppColors.accentGold : Colors.green;

    return GlassPage(
      title: 'تسجيل الحضور والانصراف',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // القائمة المنسدلة لاختيار الحارس
            GlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isLoading 
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : guardsList.isEmpty 
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا يوجد حراس مسجلين حالياً. يرجى إضافتهم أولاً.', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
                  )
                : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('-- اختر اسم الفرد --', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  value: selectedGuard,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryNavy),
                  dropdownColor: AppColors.glassWhite.withOpacity(0.9), 
                  borderRadius: BorderRadius.circular(20),
                  items: guardsList.map((guardMap) {
                    String guardName = guardMap['name'];
                    return DropdownMenuItem<String>(
                      value: guardName,
                      child: Text(guardName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primaryNavy)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedGuard = newValue;
                    });
                    _checkGuardLastAction(newValue);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 🚀 تم استبدال الكود القديم بـ ClockWidget الذكي المنفصل
            const GlassSurface(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              child: _ClockWidget(), 
            ),
            
            const Spacer(),

            // زر البصمة المتحرك
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withOpacity(0.3),
                        spreadRadius: 20 * _pulseAnimation.value,
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () {
                  if (guardsList.isNotEmpty && !_isSubmitting) {
                    _toggleAttendance();
                  }
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: guardsList.isEmpty ? Colors.grey : buttonColor,
                    gradient: LinearGradient(
                      colors: guardsList.isEmpty 
                        ? [Colors.grey.shade400, Colors.grey]
                        : [buttonColor.withOpacity(0.8), buttonColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2), 
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isSubmitting
                          ? const SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                strokeWidth: 5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.fingerprint,
                              size: 70,
                              color: Colors.white,
                            ),
                      const SizedBox(height: 8),
                      Text(
                        _isSubmitting
                            ? 'جارٍ الحفظ...'
                            : (isClockedIn ? 'انصراف' : 'حضور'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo'
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // بطاقة حالة آخر عملية
            GlassSurface(
              padding: const EdgeInsets.all(20),
              color: (isClockedIn ? Colors.orange : Colors.green).withOpacity(0.15),
              border: Border.all(color: (isClockedIn ? Colors.orange : Colors.green).withOpacity(0.3)),
              child: Row(
                children: [
                  Icon(
                    isClockedIn ? Icons.info_outline : Icons.check_circle,
                    color: isClockedIn ? Colors.orange : Colors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      lastActionTime,
                      style: const TextStyle(
                        color: AppColors.primaryNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo'
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// 🚀 هذا هو الكود الجديد الذكي الذي يحمي المعالج من الاستنزاف!
// قمنا بإنشاء Widget منفصل للساعة يقوم بتحديث نفسه فقط، ولا يُحدث كامل الشاشة.
class _ClockWidget extends StatefulWidget {
  const _ClockWidget();

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  Timer? _timer;
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    // المؤقت يعمل كل ثانية
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    int h = now.hour;
    String ampm = h >= 12 ? 'م' : 'ص';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    String mStr = now.minute.toString().padLeft(2, '0');
    
    String newTimeString = '$h:$mStr $ampm';

    // 🚀 التحقق الذكي: لن يتم تحديث الواجهة إلا إذا تغيرت الدقيقة فعلياً!
    if (_timeString != newTimeString) {
      if (!mounted) return;
      setState(() {
        _timeString = newTimeString;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('الوقت الحالي', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _timeString,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryNavy,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
