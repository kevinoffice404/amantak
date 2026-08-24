import 'package:flutter/material.dart';
// 🚨 المكتبات الجديدة الخاصة بالـ PDF 🚨
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass.dart'; 
import '../../core/utils/database_helper.dart'; 

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

  // ==== 🚨 الدالة السحرية لتوليد وطباعة الـ PDF 🚨 ====
  Future<void> _generateAndPrintPDF() async {
    // إظهار مؤشر تحميل أثناء تجهيز الملف
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز إيصال الراتب...', style: TextStyle(fontFamily: 'Cairo'))),
    );

    // استخدام خط Cairo ليدعم اللغة العربية في الـ PDF
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    
    final pdf = pw.Document();
    final double netSalary = _currentBasicSalary - _currentAdvances - _currentPenalties;
    final String today = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

    // بناء صفحة الـ PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl, // تحديد اتجاه النص من اليمين لليسار
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ترويسة الإيصال (Header)
              pw.Center(
                child: pw.Text('نظام إدارة الأمن الشامل', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text('إيصال مفردات راتب - شهر (${DateTime.now().month} / ${DateTime.now().year})', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 30),

              // بيانات الحارس
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('اسم الفرد: ${widget.guardName}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text('كود الفرد: ${widget.guardId}', style: const pw.TextStyle(fontSize: 14)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('تاريخ الإصدار:', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                        pw.SizedBox(height: 5),
                        pw.Text(today, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                  ]
                )
              ),
              pw.SizedBox(height: 30),

              // جدول التفاصيل المالية
              pw.Text('التفاصيل المالية:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 1, color: PdfColors.grey400),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
                headerHeight: 40,
                cellHeight: 35,
                cellAlignments: {
                  0: pw.Alignment.centerRight,
                  1: pw.Alignment.centerLeft,
                },
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 16),
                data: <List<String>>[
                  ['البيان', 'المبلغ (ج.م)'],
                  ['الراتب الأساسي', _currentBasicSalary.toStringAsFixed(0)],
                  ['السلف المسحوبة', '- ${_currentAdvances.toStringAsFixed(0)}'],
                  ['الجزاءات والخصومات', '- ${_currentPenalties.toStringAsFixed(0)}'],
                ],
              ),
              pw.SizedBox(height: 20),

              // المربع النهائي (الصافي)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الصافي المستحق للدفع:', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('${netSalary.toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ]
                )
              ),
              pw.SizedBox(height: 60),

              // التوقيعات
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('توقيع المشرف / الإدارة', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 30),
                      pw.Text('.......................................'),
                    ]
                  ),
                  pw.Column(
                    children: [
                      pw.Text('توقيع الحارس بالاستلام', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 30),
                      pw.Text('.......................................'),
                    ]
                  ),
                ]
              ),
            ],
          );
        },
      ),
    );

    // فتح شاشة المعاينة والطباعة
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ايصال_راتب_${widget.guardName}_$today.pdf',
    );
  }
  // ==========================================

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
                  String today = DateTime.now().toString().split(' ')[0]; 

                  await DatabaseHelper.instance.insertAdvance({
                    'guard_name': widget.guardName,
                    'amount': amount.toString(),
                    'date': today,
                  });
                  
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
      // 🚨 إضافة زر الطباعة (PDF) في شريط الشاشة العلوي 🚨
      actions: [
        IconButton(
          tooltip: 'طباعة مفردات الراتب (PDF)',
          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryNavy, size: 28),
          onPressed: _generateAndPrintPDF,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(widget.guardName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo'), textAlign: TextAlign.center),
            const SizedBox(height: 20),

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

            GlassSurface(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تفاصيل الحساب هذا الشهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
                  const Divider(height: 30, thickness: 1, color: Colors.black12),
                  
                  _buildFinancialRow(
                    title: 'الراتب الأساسي', amount: _currentBasicSalary, icon: Icons.account_balance, iconColor: Colors.blue, amountColor: AppColors.primaryNavy, isDeduction: false,
                    actionIcon: Icons.edit, onAction: _showEditSalaryDialog,
                  ),
                  const SizedBox(height: 15),
                  
                  _buildFinancialRow(
                    title: 'السلف المسحوبة', amount: _currentAdvances, icon: Icons.money_off, iconColor: Colors.orange, amountColor: Colors.orange.shade700, isDeduction: true,
                    actionIcon: Icons.add_circle_outline, onAction: _showAddAdvanceDialog, 
                  ),
                  const SizedBox(height: 15),
                  
                  _buildFinancialRow(
                    title: 'إجمالي الجزاءات', amount: _currentPenalties, icon: Icons.gavel, iconColor: Colors.red, amountColor: Colors.red.shade700, isDeduction: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
