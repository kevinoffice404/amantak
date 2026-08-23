import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart'; 

// استدعاء مكونات الزجاج
import '../../core/widgets/glass.dart';

class PenaltiesScreen extends StatefulWidget {
  const PenaltiesScreen({Key? key}) : super(key: key);

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  String? selectedGuard;
  String? selectedPenaltyType;
  final TextEditingController amountController = TextEditingController(); 
  final TextEditingController reasonController = TextEditingController();

  List<Map<String, dynamic>> guardsList = [];
  bool isLoading = true;
  bool _isSaving = false;
  
  final List<String> penaltyTypes = ['غياب', 'تأخير', 'مخالفة تعليمات', 'إنذار'];

  @override
  void initState() {
    super.initState();
    _loadGuards(); 
  }

  Future<void> _loadGuards() async {
    try {
      final data = await DatabaseHelper.instance.getAllGuards();
      if (!mounted) return;
      setState(() {
        guardsList = data;
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

  Future<void> _submitPenalty() async {
    if (_isSaving) return;

    if (selectedGuard == null || selectedPenaltyType == null || reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى إكمال جميع البيانات المطلوبة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    String amountValue = amountController.text.trim();
    if (amountValue.isEmpty) {
      amountValue = selectedPenaltyType == 'إنذار' ? 'إنذار إداري' : 'بدون خصم';
    }

    String fullReason = '[$selectedPenaltyType] ${reasonController.text.trim()}';

    DateTime now = DateTime.now();
    String todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.insertPenalty({
        'guard_name': selectedGuard,
        'amount': amountValue,
        'reason': fullReason,
        'date': todayDate,
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حفظ الجزاء. حاول مرة أخرى.', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل "$selectedPenaltyType" للفرد "$selectedGuard" بنجاح', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.green.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      setState(() {
        selectedGuard = null;
        selectedPenaltyType = null;
        amountController.clear();
        reasonController.clear();
      });
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // تم التبديل لـ GlassPage
    return GlassPage(
      title: 'الجزاءات والغياب',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 16),
              child: Text(
                'تسجيل إجراء إداري جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo'),
              ),
            ),
            
            // بطاقة نموذج الإدخال الزجاجية
            GlassSurface(
              padding: const EdgeInsets.all(24),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. اختيار اسم الفرد
                  const Text('اسم فرد الأمن', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : guardsList.isEmpty
                      ? const Text('لا يوجد حراس مسجلين حالياً. أضف حراساً أولاً.', style: TextStyle(color: Colors.red, fontFamily: 'Cairo'))
                      : DropdownButtonFormField<String>(
                          value: selectedGuard,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.5), // تأثير زجاجي للحقل
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          dropdownColor: AppColors.glassWhite.withOpacity(0.95), // قائمة منسدلة زجاجية
                          borderRadius: BorderRadius.circular(20),
                          hint: const Text('اضغط لاختيار الاسم', style: TextStyle(fontFamily: 'Cairo')),
                          items: guardsList.map((guardMap) {
                            String guardName = guardMap['name'];
                            return DropdownMenuItem(
                              value: guardName, 
                              child: Text(guardName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primaryNavy))
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedGuard = value),
                        ),
                  const SizedBox(height: 24),

                  // 2. اختيار نوع الإجراء (Choice Chips)
                  const Text('نوع الإجراء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: penaltyTypes.map((type) {
                      bool isSelected = selectedPenaltyType == type;
                      return ChoiceChip(
                        label: Text(type, style: const TextStyle(fontFamily: 'Cairo')),
                        selected: isSelected,
                        selectedColor: AppColors.accentGold,
                        backgroundColor: Colors.white.withOpacity(0.5),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primaryNavy,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: isSelected ? AppColors.accentGold : Colors.white.withOpacity(0.8), width: 1.5)
                        ),
                        onSelected: (selected) {
                          setState(() => selectedPenaltyType = selected ? type : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 3. قيمة أو مدة الخصم
                  const Text('قيمة أو مدة الخصم (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      hintText: 'مثال: 150 جنيه أو خصم يوم...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                      prefixIcon: const Icon(Icons.money_off_rounded, color: Colors.redAccent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. سبب الإجراء
                  const Text('السبب / الملاحظات', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      hintText: 'اكتب تفاصيل المخالفة هنا...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 5. زر الحفظ الاحترافي
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: guardsList.isEmpty || _isSaving 
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [const Color(0xFF274C77), const Color(0xFF163A63)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: guardsList.isEmpty || _isSaving ? [] : const [
                        BoxShadow(color: Color(0x33163A63), blurRadius: 16, offset: Offset(0, 7))
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: guardsList.isEmpty || _isSaving ? null : _submitPenalty, 
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'حفظ الإجراء',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
