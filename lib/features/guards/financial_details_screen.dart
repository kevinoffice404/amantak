import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 

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

  double _totalWorkedHours = 0.0;
  bool _isLoadingHours = true;

  @override
  void initState() {
    super.initState();
    _currentBasicSalary = widget.basicSalary;
    _currentAdvances = widget.totalAdvances;
    _currentPenalties = widget.totalPenalties;
    
    _calculateWorkedHours();
  }

  Future<void> _calculateWorkedHours() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      String currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}-%";
      
      final records = await db.query(
        'attendance',
        where: 'guard_name = ? AND action_date LIKE ?',
        whereArgs: [widget.guardName, currentMonth],
        orderBy: 'action_date ASC, id ASC',
      );

      double totalHours = 0.0;
      double? clockInTimeDouble;

      double parseTimeString(String timeStr) {
        try {
          final parts = timeStr.split(' ');
          final timeParts = parts[0].split(':');
          int hours = int.parse(timeParts[0]);
          int minutes = int.parse(timeParts[1]);
          String ampm = parts[1];

          if (ampm == 'م' && hours != 12) hours += 12;
          if (ampm == 'ص' && hours == 12) hours = 0;

          return hours + (minutes / 60.0);
        } catch (e) {
          return 0.0;
        }
      }

      for (var record in records) {
        String actionType = record['action_type'].toString();
        String actionTime = record['action_time'].toString();

        if (actionType == 'دخول') {
          clockInTimeDouble = parseTimeString(actionTime);
        } else if (actionType == 'انصراف' && clockInTimeDouble != null) {
          double clockOutTimeDouble = parseTimeString(actionTime);
          double hoursWorked = clockOutTimeDouble - clockInTimeDouble;
          
          if (hoursWorked > 0) {
            totalHours += hoursWorked;
          }
          clockInTimeDouble = null; 
        }
      }

      if (mounted) {
        setState(() {
          _totalWorkedHours = totalHours;
          _isLoadingHours = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHours = false);
      }
    }
  }

  Future<void> _generateAndPrintPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز إيصال الراتب...', style: TextStyle(fontFamily: 'Cairo'))),
    );

    final ByteData regularFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final pw.Font font = pw.Font.ttf(regularFontData);

    final ByteData boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final pw.Font boldFont = pw.Font.ttf(boldFontData);
    
    final pdf = pw.Document();
    
    final double dailyRate = _currentBasicSalary / 30.0;
    final double hourlyRate = dailyRate / 12.0;
    final double earnedSalary = _totalWorkedHours * hourlyRate;
    final double netSalary = earnedSalary - _currentAdvances - _currentPenalties;
    
    final String today = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl, 
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🚨 تم التعديل هنا: اسم الشركة الجديد 🚨
              pw.Center(child: pw.Text('شركة أبو رواش جروب للأمن والحراسة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
              pw.SizedBox(height: 5),
              pw.Center(child: pw.Text('إيصال مفردات راتب - شهر (${DateTime.now().month} / ${DateTime.now().year})', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700))),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)), border: pw.Border.all(color: PdfColors.grey300)),
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
              pw.SizedBox(height: 20),

              pw.Text('التفاصيل المالية والدوام:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 1, color: PdfColors.grey400),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
                headerHeight: 40,
                cellHeight: 35,
                cellAlignments: {0: pw.Alignment.centerRight, 1: pw.Alignment.centerLeft},
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 16),
                data: <List<String>>[
                  ['البيان', 'القيمة'],
                  ['الراتب الشهري الأساسي (المتفق عليه)', '${_currentBasicSalary.toStringAsFixed(0)} ج.م'],
                  ['أجر الساعة (على أساس 12 ساعة/يوم)', '${hourlyRate.toStringAsFixed(2)} ج.م'],
                  ['ساعات العمل الفعلية المحتسبة', '${_totalWorkedHours.toStringAsFixed(1)} ساعة'],
                  ['الراتب المستحق عن ساعات العمل', '${earnedSalary.toStringAsFixed(0)} ج.م'],
                  ['السلف المسحوبة', '- ${_currentAdvances.toStringAsFixed(0)} ج.م'],
                  ['الجزاءات والخصومات', '- ${_currentPenalties.toStringAsFixed(0)} ج.م'],
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: const pw.BoxDecoration(color: PdfColors.blue900, borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // 🚨 تم التعديل هنا: اسم الصافي الجديد 🚨
                    pw.Text('صافي مستحقاتك:', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('${netSalary.toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ]
                )
              ),
              pw.SizedBox(height: 50),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [pw.Text('توقيع الإدارة', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 30), pw.Text('.......................................')]),
                  pw.Column(children: [pw.Text('توقيع الحارس', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 30), pw.Text('.......................................')]),
                ]
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ايصال_راتب_${widget.guardName}_$today.pdf',
    );
  }

  void _showEditSalaryDialog() {
    TextEditingController salaryController = TextEditingController(text: _currentBasicSalary.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تعديل الراتب الأساسي', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primaryNavy, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: TextField(
            controller: salaryController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'الراتب الجديد', suffixText: 'ج.م', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
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
            decoration: InputDecoration(labelText: 'قيمة السلفة', suffixText: 'ج.م', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
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

                  await DatabaseHelper.instance.insertAdvance({'guard_name': widget.guardName, 'amount': amount.toString(), 'date': today});
                  setState(() => _currentAdvances += amount);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل السلفة بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
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
    final double dailyRate = _currentBasicSalary / 30.0;
    final double hourlyRate = dailyRate / 12.0;
    final double earnedSalary = _totalWorkedHours * hourlyRate; 
    final double netSalary = earnedSalary - _currentAdvances - _currentPenalties; 

    return GlassPage( 
      title: 'التفاصيل المالية',
      actions: [
        IconButton(
          tooltip: 'طباعة مفردات الراتب (PDF)',
          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryNavy, size: 28),
          onPressed: _isLoadingHours ? null : _generateAndPrintPDF, 
        ),
      ],
      child: _isLoadingHours 
      ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
      : SingleChildScrollView(
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
                  // 🚨 تم التعديل هنا أيضاً في واجهة التطبيق لتتوافق مع الـ PDF 🚨
                  const Text('صافي مستحقاتك', style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo')),
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
                    title: 'الراتب المتفق عليه', amount: _currentBasicSalary, icon: Icons.handshake_rounded, iconColor: Colors.blueGrey, amountColor: Colors.blueGrey, isDeduction: false,
                    actionIcon: Icons.edit, onAction: _showEditSalaryDialog,
                  ),
                  const SizedBox(height: 10),

                  _buildFinancialRow(
                    title: 'ساعات العمل الفعلية', amount: _totalWorkedHours, icon: Icons.access_time_filled_rounded, iconColor: Colors.green, amountColor: Colors.green.shade700, isDeduction: false, suffix: ' ساعة'
                  ),
                  const SizedBox(height: 10),

                  _buildFinancialRow(
                    title: 'الراتب المستحق عن الساعات', amount: earnedSalary, icon: Icons.account_balance_wallet_rounded, iconColor: Colors.blue, amountColor: AppColors.primaryNavy, isDeduction: false,
                  ),
                  const Divider(height: 30, thickness: 1, color: Colors.black12),
                  
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
    IconData? actionIcon, VoidCallback? onAction, String suffix = ' ج.م',
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo'))),
        Text('${isDeduction ? '-' : ''}${amount.toStringAsFixed(amount == _totalWorkedHours ? 1 : 0)}$suffix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor, fontFamily: 'Cairo')),
        
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
