import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart';

// استدعاء مكونات الزجاج
import '../../core/widgets/glass.dart';

class GuardRecordsScreen extends StatefulWidget {
  final String guardName;

  const GuardRecordsScreen({Key? key, required this.guardName}) : super(key: key);

  @override
  State<GuardRecordsScreen> createState() => _GuardRecordsScreenState();
}

class _GuardRecordsScreenState extends State<GuardRecordsScreen> {
  List<Map<String, dynamic>> attendanceList = [];
  List<Map<String, dynamic>> penaltiesList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardRecords();
  }

  // جلب سجلات الحضور والجزاءات الخاصة بهذا الحارس فقط من قاعدة البيانات
  Future<void> _loadGuardRecords() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      final attendance = await db.query(
        'attendance',
        where: 'guard_name = ?',
        whereArgs: [widget.guardName],
        orderBy: 'action_date DESC, id DESC',
      );

      final penalties = await db.query(
        'penalties',
        where: 'guard_name = ?',
        whereArgs: [widget.guardName],
        orderBy: 'date DESC, id DESC',
      );

      if (!mounted) return;
      setState(() {
        attendanceList = attendance;
        penaltiesList = penalties;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل السجلات.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true, // ضروري جداً ليمتد الزجاج خلف الشريط العلوي
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text('سجلات: ${widget.guardName}', style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.w800, fontFamily: 'Cairo', fontSize: 16)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.primaryNavy),
          bottom: TabBar(
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
            indicatorColor: AppColors.primaryBlue,
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: AppColors.primaryNavy.withOpacity(0.4), // تعديل لوني ليناسب الخلفية الفاتحة
            dividerColor: Colors.transparent, // إزالة الخط الرمادي السفلي التلقائي من فلاتر
            tabs: const [
              Tab(text: 'سجل الحضور'),
              Tab(text: 'سجل الجزاءات'),
            ],
          ),
        ),
        // استخدام خلفية الزجاج مباشرة هنا
        body: GlassBackground(
          child: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      // ==== تبويب سجل الحضور والانصراف ====
                      attendanceList.isEmpty
                          ? const Center(child: Text('لا توجد سجلات حضور مسجلة لهذا الفرد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontWeight: FontWeight.w700)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: attendanceList.length,
                              itemBuilder: (context, index) {
                                final item = attendanceList[index];
                                bool isLogin = item['action_type'] == 'دخول';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassSurface(
                                    padding: EdgeInsets.zero,
                                    borderRadius: BorderRadius.circular(16),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isLogin ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.5))
                                        ),
                                        child: Icon(
                                          isLogin ? Icons.login_rounded : Icons.logout_rounded,
                                          color: isLogin ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                      title: Text('الحركة: ${item['action_type']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('التاريخ: ${item['action_date']} | الوقت: ${item['action_time']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                      // ==== تبويب سجل الجزاءات ====
                      penaltiesList.isEmpty
                          ? const Center(child: Text('لا توجد جزاءات مسجلة لهذا الفرد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontWeight: FontWeight.w700)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: penaltiesList.length,
                              itemBuilder: (context, index) {
                                final item = penaltiesList[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassSurface(
                                    padding: EdgeInsets.zero,
                                    borderRadius: BorderRadius.circular(16),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.5))
                                        ),
                                        child: const Icon(Icons.gavel_rounded, color: Colors.red),
                                      ),
                                      title: Text('السبب: ${item['reason']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('القيمة: ${item['amount']} | التاريخ: ${item['date']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
