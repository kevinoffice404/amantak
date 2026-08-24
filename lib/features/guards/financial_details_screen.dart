import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass.dart'; 

class FinancialDetailsScreen extends StatelessWidget {
  final String guardName;
  final double basicSalary;
  final double totalAdvances;
  final double totalPenalties;

  const FinancialDetailsScreen({
    Key? key,
    required this.guardName,
    required this.basicSalary,
    required this.totalAdvances,
    required this.totalPenalties,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // حساب الصافي
    final double netSalary = basicSalary - totalAdvances - totalPenalties;

    return GlassPage( // استخدام خلفية الزجاج المتناسقة
      title: 'التفاصيل المالية',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // اسم الحارس
            Text(
              guardName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // البطاقة الرئيسية (إجمالي المتبقي)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryNavy, Colors.blueAccent], 
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'إجمالي المتبقي (الصافي)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${netSalary.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // بطاقة تفاصيل الخصومات والراتب باستخدام GlassSurface
            GlassSurface(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل الحساب هذا الشهر',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Divider(height: 30, thickness: 1, color: Colors.black12),
                  
                  // الراتب الأساسي
                  _buildFinancialRow(
                    title: 'الراتب الأساسي',
                    amount: basicSalary,
                    icon: Icons.account_balance,
                    iconColor: Colors.blue,
                    amountColor: AppColors.primaryNavy,
                    isDeduction: false,
                  ),
                  const SizedBox(height: 15),
                  
                  // السلف
                  _buildFinancialRow(
                    title: 'السلف المسحوبة',
                    amount: totalAdvances,
                    icon: Icons.money_off,
                    iconColor: Colors.orange,
                    amountColor: Colors.orange.shade700,
                    isDeduction: true,
                  ),
                  const SizedBox(height: 15),
                  
                  // الجزاءات
                  _buildFinancialRow(
                    title: 'إجمالي الجزاءات',
                    amount: totalPenalties,
                    icon: Icons.gavel,
                    iconColor: Colors.red,
                    amountColor: Colors.red.shade700,
                    isDeduction: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت مساعدة لبناء صفوف البيانات داخل البطاقة
  Widget _buildFinancialRow({
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
    required Color amountColor,
    required bool isDeduction,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15), // تعديل بسيط ليتناسب مع الخلفية الزجاجية
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 15),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
          ),
        ),
        const Spacer(),
        Text(
          '${isDeduction ? '-' : ''}${amount.toStringAsFixed(0)} ج.م',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: amountColor,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}
