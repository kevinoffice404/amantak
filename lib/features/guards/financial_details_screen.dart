import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass.dart'; 
import '../../core/utils/database_helper.dart'; // مسار الداتا بيز

class FinancialDetailsScreen extends StatefulWidget {
  final String guardId;
  final String guardName;
  final double basicSalary;
  final double totalAdvances;
  final double totalPenalties;

  const FinancialDetailsScreen({
    Key? key,
    required this.guardId,
    required this.guardName,
    required this.basicSalary,
    required this.totalAdvances,
    required this.totalPenalties,
  }) : super(key: key);

  @override
  State<FinancialDetailsScreen> createState() => _FinancialDetailsScreenState();
}

class _FinancialDetailsScreenState extends State<FinancialDetailsScreen> {
  late double _currentBasicSalary;
  late double _currentAdvances;
  late double _currentPenalties;

  @override
  void initState() {
    super.initState();
    _currentBasicSalary = widget.basicSalary;
    _currentAdvances = widget.totalAdvances;
    _currentPenalties = widget.totalPenalties;
  }

  // 1. نافذة تعديل الراتب الأساسي (موجودة مسبقاً)
  void _showEditSalaryDialog() {
    TextEditingController salaryController = TextEditingController(
      text: _currentBasicSalary.toStringAsFixed(0)
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تعديل الراتب الأساسي', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primaryNavy, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: TextField(
            controller: salaryController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الراتب الجديد',
              suffixText: 'ج.م',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
              onPressed: () async {
                if (salaryController.text.isNotEmpty) {
                  double newSalary = double.parse(salaryController.text);
                  
                  // تحديث الراتب في قاعدة البيانات
                  await DatabaseHelper.instance.updateGuardSalary(int.parse(widget.guardId), newSalary);
                  
                  setState(() => _currentBasicSalary = newSalary);
                  Navigator.pop(context);
                }
              },
              child: const Text('حفظ التعديل', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      }
    );
  }

  // 2. 🚨 نافذة تسجيل سلفة جديدة (الجديدة) 🚨
  void _showAddAdvanceDialog() {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل سلفة جديدة', style: TextStyle(fontFamily: 'Cairo', color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'قيمة السلفة',
              suffixText: 'ج.م',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  double amount = double.parse(amountController.text);
                  String today = DateTime.now().toString().split(' ')[0]; // تاريخ اليوم

                  // إضافة السلفة في قاعدة البيانات
                  await DatabaseHelper.instance.insertAdvance({
                    'guard_name': widget.guardName,
                    'amount': amount.toString(),
                    'date': today,
                  });
                  
                  // تحديث الواجهة لزيادة السلف وخصمها من الصافي
                  setState(() => _currentAdvances += amount);
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل السلفة بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green)
                  );
                }
              },
              child: const Text('تسجيل السلفة', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final double netSalary = _currentBasicSalary - _currentAdvances - _currentPenalties;

    return GlassPage( 
      title: 'التفاصيل المالية',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(widget.guardName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo'), textAlign: TextAlign.center),
            const SizedBox(height: 20),

            // البطاقة الرئيسية
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryNavy, Colors.blueAccent], begin: Alignment.topRight, end: Alignment.bottomLeft),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  const Text('إجمالي المتبقي (الصافي)', style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  Text('${netSalary.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // بطاقة التفاصيل
            GlassSurface(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تفاصيل الحساب هذا الشهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
                  const Divider(height: 30, thickness: 1, color: Colors.black12),
                  
                  // الراتب الأساسي
                  _buildFinancialRow(
                    title: 'الراتب الأساسي', amount: _currentBasicSalary, icon: Icons.account_balance, iconColor: Colors.blue, amountColor: AppColors.primaryNavy, isDeduction: false,
                    actionIcon: Icons.edit, onAction: _showEditSalaryDialog,
                  ),
                  const SizedBox(height: 15),
                  
                  // 🚨 السلف (تم إضافة زر الإضافة هنا) 🚨
                  _buildFinancialRow(
                    title: 'السلف المسحوبة', amount: _currentAdvances, icon: Icons.money_off, iconColor: Colors.orange, amountColor: Colors.orange.shade700, isDeduction: true,
                    actionIcon: Icons.add_circle_outline, onAction: _showAddAdvanceDialog, // زر جديد بلون برتقالي
                  ),
                  const SizedBox(height: 15),
                  
                  // الجزاءات
                  _buildFinancialRow(
                    title: 'إجمالي الجزاءات', amount: _currentPenalties, icon: Icons.gavel, iconColor: Colors.red, amountColor: Colors.red.shade700, isDeduction: true,
                    // لم نضف زر هنا لأن الجزاءات عادة تسجل من شاشة "تسجيل جزاء إداري" التي تمتلكها بالفعل
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تحديث دالة بناء الصفوف لتدعم الأيقونات المختلفة (Edit للراتب، و Add للسلف)
  Widget _buildFinancialRow({
    required String title, required double amount, required IconData icon, required Color iconColor, required Color amountColor, required bool isDeduction,
    IconData? actionIcon, VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 15),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
        const Spacer(),
        Text('${isDeduction ? '-' : ''}${amount.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: amountColor, fontFamily: 'Cairo')),
        
        if (onAction != null && actionIcon != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(actionIcon, size: 20, color: iconColor),
            ),
          ),
        ]
      ],
    );
  }
}
