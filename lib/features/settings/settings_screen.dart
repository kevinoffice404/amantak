import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart';

// استدعاء مكونات الزجاج
import '../../core/widgets/glass.dart' hide GlassActionButton;
import '../../core/widgets/glass_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isExporting = false;
  String adminName = 'مدير النظام'; // الاسم الافتراضي

  @override
  void initState() {
    super.initState();
    _loadAdminName(); 
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
    } catch (e) {
      debugPrint("Error loading admin name: $e");
    }
  }

  Future<bool> _saveAdminName(String newName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/admin_name.txt');
      await file.writeAsString(newName, flush: true);
      if (!mounted) return false;
      setState(() {
        adminName = newName;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  List<CellValue> _createRow(List<dynamic> rawData) {
    return rawData.map((data) {
      if (data == null) return TextCellValue('');
      if (data is int) return IntCellValue(data);
      if (data is double) return DoubleCellValue(data);
      return TextCellValue(data.toString());
    }).toList();
  }

  Future<void> _exportDataToExcel() async {
    if (isExporting) return;
    setState(() => isExporting = true);

    try {
      var excel = Excel.createExcel();
      final db = await DatabaseHelper.instance.database;

      // 1. شيت الحضور والانصراف
      Sheet attendanceSheet = excel['الحضور والانصراف'];
      excel.setDefaultSheet('الحضور والانصراف');
      attendanceSheet.appendRow(_createRow(['م', 'اسم الحارس', 'نوع الحركة', 'الوقت', 'التاريخ']));
      var attendanceData = await db.query('attendance');
      for (var row in attendanceData) {
        attendanceSheet.appendRow(_createRow([row['id'], row['guard_name'], row['action_type'], row['action_time'], row['action_date']]));
      }

      // 2. شيت الجزاءات
      Sheet penaltiesSheet = excel['الجزاءات'];
      penaltiesSheet.appendRow(_createRow(['م', 'اسم الحارس', 'القيمة/الجزاء', 'السبب', 'التاريخ']));
      var penaltiesData = await db.query('penalties');
      for (var row in penaltiesData) {
        penaltiesSheet.appendRow(_createRow([row['id'], row['guard_name'], row['amount'], row['reason'], row['date']]));
      }

      // 3. شيت العهد
      Sheet equipmentSheet = excel['العهد'];
      equipmentSheet.appendRow(_createRow(['م', 'اسم الجهاز', 'الحالة']));
      var equipmentData = await db.query('equipment');
      for (var row in equipmentData) {
        equipmentSheet.appendRow(_createRow([row['id'], row['item_name'], row['status']]));
      }

      // 4. شيت أفراد الأمن
      Sheet guardsSheet = excel['أفراد الأمن'];
      guardsSheet.appendRow(_createRow(['م', 'الاسم', 'الهاتف', 'الرتبة', 'حالة البطاقة']));
      var guardsData = await db.query('guards');
      for (var row in guardsData) {
        guardsSheet.appendRow(_createRow([row['id'], row['name'], row['phone'], row['role'], row['id_status']]));
      }

      // 5. شيت الرواتب والماليات
      Sheet salariesSheet = excel['الرواتب والماليات'];
      salariesSheet.appendRow(_createRow(['م', 'الاسم', 'الراتب الأساسي', 'إجمالي السلف', 'إجمالي الجزاءات', 'الصافي المستحق']));
      
      for (var row in guardsData) { 
        String name = row['name'].toString();
        String id = row['id'].toString();
        
        double basicSalary = row['basic_salary'] != null 
            ? double.tryParse(row['basic_salary'].toString()) ?? 9000.0 
            : 9000.0;
            
        final totals = await DatabaseHelper.instance.getGuardFinancialTotals(name);
        double totalAdvances = (totals['total_advances'] as num?)?.toDouble() ?? 0.0;
        double totalPenalties = (totals['total_penalties'] as num?)?.toDouble() ?? 0.0;
        
        double netSalary = basicSalary - totalAdvances - totalPenalties;

        salariesSheet.appendRow(_createRow([
          id,
          name,
          basicSalary,
          totalAdvances,
          totalPenalties,
          netSalary,
        ]));
      }

      if (excel.tables.keys.contains('Sheet1')) {
        excel.delete('Sheet1');
      }

      final fileBytes = excel.save();
      if (fileBytes == null || fileBytes.isEmpty) {
        throw StateError('Excel export returned no data.');
      }

      final directory = await getTemporaryDirectory();
      
      // 🚀 التعديل: جلب الوقت مرة واحدة فقط
      final now = DateTime.now();
      String today = "${now.year}-${now.month}-${now.day}";
      final filePath = '${directory.path}/تقرير_الأمن_$today.xlsx';

      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'مرفق تقرير الأمن الشامل بتاريخ $today.',
      );

    } catch (e) {
      // 🚀 التعديل: تجميع التحقق من mounted لضمان عدم حدوث Crash
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء التصدير!', style: TextStyle(fontFamily: 'Cairo')), 
            backgroundColor: Colors.red
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }

  // ==== نافذة تأكيد مسح البيانات الزجاجية ====
  void _showClearDataDialog(BuildContext context) {
    bool isDialogClearing = false;

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassDialog(
              title: const Text('تحذير خطير'),
              titleIcon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              danger: true,
              content: const Text(
                'هل أنت متأكد أنك تريد مسح جميع بيانات التطبيق؟ سيتم حذف جميع أفراد الأمن، الحضور، العهد، والجزاءات نهائياً ولن يمكنك استعادتها.',
                style: TextStyle(fontFamily: 'Cairo', height: 1.5, fontSize: 14),
              ),
              actions: [
                GlassActionButton(
                  label: 'إلغاء',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                GlassActionButton(
                  label: isDialogClearing ? 'جارٍ المسح...' : 'مسح البيانات',
                  icon: isDialogClearing ? null : Icons.delete_forever_rounded,
                  danger: true,
                  onPressed: isDialogClearing
                      ? null
                      : () async {
                          setDialogState(() => isDialogClearing = true);
                          try {
                            await DatabaseHelper.instance.clearAllData();

                            final directory = await getApplicationDocumentsDirectory();
                            final adminFile = File('${directory.path}/admin_name.txt');
                            if (await adminFile.exists()) {
                              await adminFile.delete();
                            }

                            if (!mounted) return;
                            setState(() => adminName = 'مدير النظام');
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم مسح جميع البيانات بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (_) {
                            if (!mounted) return;
                            setDialogState(() => isDialogClearing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر مسح البيانات. حاول مرة أخرى.', style: TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==== نافذة تعديل بيانات المشرف الزجاجية ====
  void _showAdminDialog() {
    final TextEditingController controller = TextEditingController(text: adminName);
    bool isSaving = false;

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassDialog(
              title: const Text('بيانات المشرف'),
              titleIcon: const Icon(Icons.person_rounded, color: AppColors.primaryNavy),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'اسم المشرف / مدير الأمن',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primaryNavy),
                ),
              ),
              actions: [
                GlassActionButton(
                  label: 'إلغاء',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                GlassActionButton(
                  label: isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديل',
                  icon: isSaving ? null : Icons.check_rounded,
                  primary: true,
                  onPressed: isSaving 
                    ? null 
                    : () async {
                      final newName = controller.text.trim();
                      if (newName.isEmpty) return;
                      
                      setDialogState(() => isSaving = true);
                      final saved = await _saveAdminName(newName);
                      
                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            saved ? 'تم حفظ اسم المشرف بنجاح!' : 'تعذر حفظ اسم المشرف.',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          backgroundColor: saved ? Colors.green : Colors.red,
                        ),
                      );
                    },
                ),
              ],
            );
          },
        );
      },
    ).then((_) => controller.dispose());
  }

  // ==== نافذة معلومات الإصدار الزجاجية ====
  void _showAboutDialog() {
    showGlassDialog(
      context: context,
      builder: (context) {
        return GlassDialog(
          title: const Text('حول النظام'),
          titleIcon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryNavy),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5))
                ),
                child: const Icon(Icons.security_rounded, size: 50, color: AppColors.accentGold),
              ),
              const SizedBox(height: 16),
              const Text('نظام إدارة الأمن الشامل', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
              const SizedBox(height: 4),
              const Text('الإصدار: 1.0.0 (النسخة النهائية)', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 16),
              const Text(
                'تم تصميم وتطوير هذا النظام ليكون أداة متكاملة واحترافية لإدارة أفراد الأمن، الحضور والانصراف، الجزاءات، والعهد. يعمل النظام محلياً بالكامل لضمان السرعة القصوى والأمان.', 
                style: TextStyle(fontFamily: 'Cairo', height: 1.5, color: AppColors.textDark), 
                textAlign: TextAlign.center
              ),
            ],
          ),
          actions: [
            GlassActionButton(
              label: 'إغلاق',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  // ==== نافذة سياسة الخصوصية الزجاجية ====
  void _showPrivacyDialog() {
    showGlassDialog(
      context: context,
      builder: (context) {
        return GlassDialog(
          title: const Text('سياسة الخصوصية والأمان'),
          titleIcon: const Icon(Icons.privacy_tip_rounded, color: AppColors.primaryNavy),
          content: const Text(
            'بيانات التطبيق تُحفظ محلياً على الهاتف ولا يحتوي هذا الإصدار على خدمة مزامنة أو خادم خاص بالتطبيق.\n\n'
            'قاعدة البيانات المحلية ليست مشفّرة في هذا الإصدار؛ لذلك يجب حماية الهاتف نفسه واستخدام قفل شاشة قوي. '
            'كما أن مشاركة التقارير أو الصور عبر تطبيقات أخرى قد تنقل نسخة من البيانات خارج التطبيق.',
            style: TextStyle(fontFamily: 'Cairo', height: 1.5, color: AppColors.textDark),
          ),
          actions: [
            GlassActionButton(
              label: 'فهمت ذلك',
              primary: true,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'الإعدادات',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('إدارة البيانات والتقارير'),
          _buildListTile(
            icon: Icons.file_download_outlined,
            title: 'تصدير التقارير (Excel)',
            subtitle: 'استخراج سجلات الحضور، العهد، والجزاءات',
            isLoading: isExporting,
            onTap: isExporting ? () {} : _exportDataToExcel,
          ),
          _buildListTile(
            icon: Icons.delete_forever_rounded,
            title: 'مسح بيانات التطبيق',
            subtitle: 'حذف جميع السجلات والحراس (لا يمكن التراجع)',
            color: Colors.red,
            onTap: () => _showClearDataDialog(context),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('الحساب الشخصي'),
          _buildListTile(
            icon: Icons.person_outline_rounded,
            title: 'بيانات المشرف',
            subtitle: adminName,
            onTap: _showAdminDialog,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('حول النظام'),
          _buildListTile(
            icon: Icons.info_outline_rounded,
            title: 'إصدار التطبيق',
            subtitle: 'الإصدار 1.0.0 (Offline Mode)',
            onTap: _showAboutDialog,
          ),
          _buildListTile(
            icon: Icons.security_rounded,
            title: 'سياسة الخصوصية والأمان',
            subtitle: 'تخزين محلي بدون مزامنة مع خادم التطبيق',
            onTap: _showPrivacyDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo'),
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required String subtitle, Color? color, required VoidCallback onTap, bool isLoading = false}) {
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
              color: (color ?? AppColors.primaryNavy).withOpacity(0.12), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5))
            ),
            child: Icon(icon, color: color ?? AppColors.primaryNavy, size: 24),
          ),
          title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: color ?? AppColors.primaryNavy)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          trailing: isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentGold))
              : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }
}
