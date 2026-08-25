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
  // متغيرات حفظ اختيارات المستخدم
  String? selectedGuard;
  String? selectedPenaltyType;
  
  // متحكمات النصوص (Controllers)
  final TextEditingController amountController = TextEditingController(); 
  final TextEditingController reasonController = TextEditingController();

  List<Map<String, dynamic>> guardsList = [];
  bool isLoading = true;
  bool _isSaving = false;
  
  // القائمة الثابتة لأنواع الجزاءات
  final List<String> penaltyTypes = const ['غياب', 'تأخير', 'مخالفة تعليمات', 'إنذار'];

  @override
  void initState() {
    super.initState();
    _loadGuards(); 
  }

  // 🚀 خطوة مهمة جداً للأداء: إغلاق المتحكمات عند الخروج من الشاشة لتحرير الذاكرة
  @override
  void dispose() {
    amountController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  // جلب أسماء الحراس من قاعدة البيانات
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

  // دالة حفظ الجزاء في قاعدة البيانات
  Future<void> _submitPenalty() async {
    if (_isSaving) return;

    // التحقق من إدخال جميع البيانات المهمة
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

    // معالجة قيمة الخصم إذا تركها المستخدم فارغة
    String amountValue = amountController.text.trim();
    if (amountValue.isEmpty) {
      amountValue = selectedPenaltyType == 'إنذار' ? 'إنذار إداري' : 'بدون خصم';
    }

    String fullReason = '[$selectedPenaltyType] ${reasonController.text.trim()}';

    // جلب التاريخ الحالي بشكل آمن وسريع
    final now = DateTime.now();
    String todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    setState(() => _isSaving = true);
    
    try {
      // إرسال البيانات لقاعدة البيانات
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

    // إذا نجح الحفظ
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل "$selectedPenaltyType" للفرد "$selectedGuard" بنجاح', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.green.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      // 🚀 إكمال الكود الناقص: تفريغ الحقول بعد الحفظ بنجاح
      setState(() {
        selectedGuard = null;
        selectedPenaltyType = null;
        _isSaving = false;
      });
      amountController.clear();
      reasonController.clear();
    }
  }

  // 🚀 بناء واجهة المستخدم باستخدام العناصر الزجاجية
  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'تسجيل الجزاءات',
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // اختيار الحارس
                  _buildLabel('اسم فرد الأمن'),
                  _buildGlassDropdown(
                    hint: 'اختر فرد الأمن',
                    value: selectedGuard,
                    items: guardsList.map((g) => g['name'].toString()).toList(),
                    onChanged: (val) => setState(() => selectedGuard = val as String?),
                  ),
                  const SizedBox(height: 20),

                  // اختيار نوع الجزاء
                  _buildLabel('نوع الجزاء'),
                  _buildGlassDropdown(
                    hint: 'اختر النوع (غياب، تأخير...)',
                    value: selectedPenaltyType,
                    items: penaltyTypes,
                    onChanged: (val) => setState(() => selectedPenaltyType = val as String?),
                  ),
                  const SizedBox(height: 20),

                  // قيمة الخصم (اختياري)
                  _buildLabel('قيمة الخصم (إن وجد)'),
                  GlassSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primaryNavy),
                      decoration: const InputDecoration(
                        hintText: 'مثال: 50 (أو اتركه فارغاً)',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                        icon: Icon(Icons.money_off_rounded, color: AppColors.primaryNavy),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // سبب الجزاء (إجباري)
                  _buildLabel('سبب وتفاصيل الجزاء'),
                  GlassSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primaryNavy),
                      decoration: const InputDecoration(
                        hintText: 'اكتب تفاصيل المخالفة هنا...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // زر الحفظ
                  GlassSurface(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.primaryBlue.withOpacity(0.8), // لون مميز للزر
                    child: InkWell(
                      onTap: _submitPenalty,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _isSaving
                            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.gavel_rounded, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'تسجيل الجزاء',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // دالة مساعدة لرسم العناوين (لتنظيف الكود)
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
      ),
    );
  }

  // دالة مساعدة لرسم القوائم المنسدلة بتصميم زجاجي
  Widget _buildGlassDropdown({required String hint, required String? value, required List<String> items, required Function(dynamic) onChanged}) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: BorderRadius.circular(16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
          isExpanded: true,
          dropdownColor: Colors.white.withOpacity(0.9), // خلفية بيضاء شفافة للقائمة عند فتحها
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryNavy),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
