import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// استدعاء مكونات الزجاج
import '../../core/widgets/glass.dart';
// استدعاء شاشة التفاصيل المالية (يجب إنشاء هذا الملف)
import 'financial_details_screen.dart'; 

class GuardDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> person;

  const GuardDetailsScreen({Key? key, required this.person}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String name = person['name'] ?? '';
    String role = person['role'] ?? '';
    String id = person['id'].toString();
    String phone = person['phone'] ?? 'غير متوفر';
    final expiryRaw = person['id_expiry_date'] as String?;
    final expiry = expiryRaw == null ? null : DateTime.tryParse(expiryRaw);
    final expiryDate = expiryRaw ?? 'غير متوفر';
    final today = DateTime.now();
    final status = expiry != null &&
            DateTime(expiry.year, expiry.month, expiry.day)
                .isBefore(DateTime(today.year, today.month, today.day))
        ? 'منتهية'
        : (person['id_status'] ?? 'غير محدد');
    String? frontImg = person['id_front_image'];
    String? backImg = person['id_back_image'];

    // افتراض قيم مالية (قم بتحديثها لتقرأ من قاعدة البيانات لاحقاً)
    double basicSalary = person['basic_salary']?.toDouble() ?? 9000.0;
    double totalAdvances = person['total_advances']?.toDouble() ?? 1000.0;
    double totalPenalties = person['total_penalties']?.toDouble() ?? 250.0;

    Color roleColor = (role == 'مدير الأمن' || role == 'مسؤول') ? Colors.redAccent : (role == 'مشرف' ? AppColors.accentGold : Colors.green);
    IconData roleIcon = (role == 'مدير الأمن' || role == 'مسؤول') ? Icons.admin_panel_settings_rounded : (role == 'مشرف' ? Icons.supervised_user_circle_rounded : Icons.security_rounded);

    // استخدام GlassPage كخلفية متناسقة
    return GlassPage(
      title: 'الملف الشخصي للحارس',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // كارت المعلومات الأساسية الزجاجي
            GlassSurface(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)
                    ),
                    child: Icon(roleIcon, size: 45, color: roleColor),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.15), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: roleColor.withOpacity(0.3))
                    ),
                    child: Text(role, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1, color: Colors.black12),
                  ),
                  _buildInfoRow(Icons.badge_rounded, 'كود الفرد', id),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.phone_rounded, 'رقم الهاتف', phone),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.calendar_month_rounded, 'تاريخ انتهاء البطاقة', expiryDate),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.info_outline_rounded, 
                    'حالة البطاقة', 
                    status, 
                    valueColor: status == 'سارية' ? Colors.green : Colors.red
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // قسم صور البطاقة الشخصية
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 12),
              child: Text('صور البطاقة الشخصية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8, bottom: 6),
                        child: Text('الوجه الأمامي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                      ),
                      // برواز زجاجي للصورة
                      GlassSurface(
                        padding: const EdgeInsets.all(6),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: frontImg != null && File(frontImg).existsSync()
                                ? Image.file(File(frontImg), fit: BoxFit.cover)
                                : const Center(child: Text('لا توجد صورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8, bottom: 6),
                        child: Text('الوجه الخلفي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                      ),
                      // برواز زجاجي للصورة
                      GlassSurface(
                        padding: const EdgeInsets.all(6),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: backImg != null && File(backImg).existsSync()
                                ? Image.file(File(backImg), fit: BoxFit.cover)
                                : const Center(child: Text('لا توجد صورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            // --- الزر الجديد: التفاصيل المالية ---
            SizedBox(
              width: double.infinity, 
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinancialDetailsScreen(
                        guardName: name, 
                        basicSalary: basicSalary, 
                        totalAdvances: totalAdvances, 
                        totalPenalties: totalPenalties, 
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 28),
                label: const Text(
                  'التفاصيل المالية والراتب',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo', 
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy, 
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryNavy),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: valueColor ?? AppColors.primaryNavy)),
      ],
    );
  }
}
