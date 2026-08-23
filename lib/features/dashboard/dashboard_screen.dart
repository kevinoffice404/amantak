import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'; 

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass.dart';
import '../../core/utils/database_helper.dart'; 

// استدعاء جميع الشاشات
import '../attendance/attendance_screen.dart';
import '../guards/guards_screen.dart';
import '../settings/settings_screen.dart';
import '../equipment/equipment_screen.dart';
import '../penalties/penalties_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String adminName = 'مدير النظام';
  String _timeString = '';
  String _dateString = '';
  Timer? _timer;

  // متغيرات الإحصائيات الديناميكية
  int totalGuards = 0;
  int todayAttendance = 0;
  int totalEquipment = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _loadStatistics(); // جلب الأعداد الحقيقية
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // جلب الأعداد من قاعدة البيانات
  Future<void> _loadStatistics() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final guardsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM guards')) ?? 0;
      
      String today = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      final attendanceCount = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(DISTINCT guard_name) FROM attendance '
              'WHERE action_date = ? AND action_type = ?',
              [today, 'دخول'],
            ),
          ) ??
          0;

      final equipmentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM equipment')) ?? 0;

      if (mounted) {
        setState(() {
          totalGuards = guardsCount;
          todayAttendance = attendanceCount;
          totalEquipment = equipmentCount;
        });
      }
    } catch (e) {
      // تجاهل الخطأ في حال لم يتم إنشاء الجداول بعد
    }
  }

  Future<void> _loadAdminName() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/admin_name.txt');
      if (await file.exists()) {
        final savedName = (await file.readAsString()).trim();
        if (!mounted || savedName.isEmpty) return;
        setState(() {
          adminName = savedName;
        });
      }
    } catch (e) {}
  }

  void _updateTime() {
    final now = DateTime.now();
    int h = now.hour;
    int m = now.minute;
    String ampm = h >= 12 ? 'م' : 'ص';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    String mStr = m.toString().padLeft(2, '0');
    
    final List<String> months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final List<String> days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    String dayName = days[now.weekday - 1];
    String monthName = months[now.month - 1];

    if (mounted) {
      setState(() {
        _timeString = '$h:$mStr $ampm';
        _dateString = '$dayName، ${now.day} $monthName';
      });
    }
  }

  Future<void> _refreshOnReturn(BuildContext context, Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    await Future.wait([
      _loadAdminName(),
      _loadStatistics(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // تم استبدال Scaffold بـ GlassPage للحصول على الخلفية الملونة الجميلة
    return GlassPage(
      title: 'لوحة التحكم',
      showBack: false, // إخفاء سهم الرجوع لأن هذه هي الشاشة الرئيسية
      actions: [
        IconButton(
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings_outlined, color: AppColors.primaryNavy),
          onPressed: () => _refreshOnReturn(context, const SettingsScreen()),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadStatistics,
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كارت الترحيب
              GlassSurface(
                padding: const EdgeInsets.all(20),
                color: const Color(0xCC6E83AA),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(.20),
                        border: Border.all(color: Colors.white.withOpacity(.55)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.accentGold, size: 34),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أهلاً بك يا $adminName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          const Text('مشرف الوردية', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo')),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white70),
                              const SizedBox(width: 5),
                              Expanded(child: Text(_dateString, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo'))),
                              const Icon(Icons.access_time_rounded, size: 13, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              
              // كروت الإحصائيات
              Row(
                children: [
                  Expanded(child: _buildStatCard('إجمالي الحراس', totalGuards.toString(), AppColors.primaryBlue, Icons.people_alt_outlined)),
                  const SizedBox(width: 9),
                  Expanded(child: _buildStatCard('حضور اليوم', todayAttendance.toString(), AppColors.success, Icons.fingerprint)),
                  const SizedBox(width: 9),
                  Expanded(child: _buildStatCard('العهد', totalEquipment.toString(), AppColors.accentGold, Icons.inventory_2_outlined)),
                ],
              ),
              const SizedBox(height: 26),
              const Text('الخدمات الأساسية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Cairo')),
              const SizedBox(height: 12),
              
              // شبكة الخدمات
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
                children: [
                  _buildServiceCard('تسجيل الحضور', Icons.fingerprint_rounded, AppColors.success, () => _refreshOnReturn(context, const AttendanceScreen())),
                  _buildServiceCard('إدارة العهد', Icons.inventory_2_outlined, AppColors.accentGold, () => _refreshOnReturn(context, const EquipmentScreen())),
                  _buildServiceCard('أفراد الأمن', Icons.groups_rounded, const Color(0xFF6B8FF2), () => _refreshOnReturn(context, const GuardsScreen())),
                  _buildServiceCard('الجزاءات', Icons.gavel_rounded, const Color(0xFF9A79E8), () => _refreshOnReturn(context, const PenaltiesScreen())),
                  // تم إزالة زر الإعدادات من هنا لوجوده في الـ AppBar بالأعلى للحفاظ على التناسق
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 5),
          Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, fontFamily: 'Cairo')),
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, fontFamily: 'Cairo'), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GlassSurface(
      padding: EdgeInsets.zero, // التعديل السحري: جعلنا الـ Padding صفر هنا
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(10), // وضعنا الـ Padding داخل InkWell ليتمدد تأثير اللمس
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(.12),
                  border: Border.all(color: color.withOpacity(.18)),
                ),
                child: Icon(icon, size: 29, color: color),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Cairo')),
            ],
          ),
        ),
      ),
    );
  }
}
