import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart';

// استدعاء ملفات الزجاج
import '../../core/widgets/glass.dart' hide GlassActionButton;
import '../../core/widgets/glass_dialog.dart'; 

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({Key? key}) : super(key: key);

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  List<Map<String, dynamic>> equipmentList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshEquipment();
  }

  Future<void> _refreshEquipment() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getAllEquipment();
      if (!mounted) return;
      setState(() {
        equipmentList = data;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل العهد والأجهزة.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // استخدام النافذة الزجاجية (GlassDialog) بدلاً من العادية
  void _showAddEquipmentDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isDialogSaving = false; // التحكم بحالة الزر داخل النافذة نفسها

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassDialog(
              title: const Text('إضافة جهاز جديد'),
              titleIcon: const Icon(Icons.radio_rounded, color: AppColors.primaryNavy),
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم/رقم الجهاز',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  prefixIcon: const Icon(Icons.radio_rounded, color: AppColors.primaryNavy),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5), // حقل إدخال شفاف ليتناسب مع الزجاج
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              actions: [
                GlassActionButton(
                  label: 'إلغاء',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                GlassActionButton(
                  label: isDialogSaving ? 'جارٍ الحفظ...' : 'حفظ الجهاز',
                  primary: true,
                  icon: isDialogSaving ? null : Icons.check_rounded,
                  onPressed: isDialogSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('اكتب اسم أو رقم الجهاز أولاً.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setDialogState(() => isDialogSaving = true); // تغيير حالة الزر
                          try {
                            await DatabaseHelper.instance.insertEquipment({
                              'item_name': name,
                              'status': 'متاح',
                              'assigned_to': 'المركز',
                            });

                            if (!mounted) return;
                            Navigator.pop(dialogContext); // إغلاق النافذة
                            await _refreshEquipment(); // تحديث القائمة الرئيسية
                          } catch (_) {
                            if (!mounted) return;
                            setDialogState(() => isDialogSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تعذر حفظ الجهاز.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                            );
                          }
                        },
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _updateEquipmentStatus(int id, String newStatus) async {
    try {
      await DatabaseHelper.instance.updateEquipmentStatus(id, newStatus);
      await _refreshEquipment();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديث حالة الجهاز.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // استخدام القائمة السفلية الزجاجية
  void _showOptions(Map<String, dynamic> item) {
    showGlassBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text(item['item_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primaryNavy)),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: Colors.green)),
              title: const Text('تسجيل استلام (متاح)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                _updateEquipmentStatus(item['id'], 'متاح');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accentGold.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.assignment_return_outlined, color: AppColors.accentGold)),
              title: const Text('تسجيل تسليم (مستلم)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                _updateEquipmentStatus(item['id'], 'مستلم');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.build_circle_outlined, color: Colors.red)),
              title: const Text('إرسال للصيانة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
              onTap: () {
                _updateEquipmentStatus(item['id'], 'صيانة');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تم التبديل إلى GlassPage
    return GlassPage(
      title: 'إدارة العهد والأجهزة',
      child: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : equipmentList.isEmpty
                  ? const Center(
                      child: Text('لا توجد عهد أو أجهزة مسجلة.\nاضغط على "إضافة جهاز" بالأسفل للبدء.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), // مسافة بالأسفل لكي لا يغطي زر الإضافة على آخر عنصر
                      itemCount: equipmentList.length,
                      itemBuilder: (context, index) {
                        return _buildEquipmentCard(equipmentList[index]);
                      },
                    ),
          
          // زر الإضافة العائم متوافق مع اللغة العربية (PositionedDirectional)
          PositionedDirectional(
            bottom: 24,
            end: 24,
            child: FloatingActionButton.extended(
              onPressed: _showAddEquipmentDialog,
              elevation: 4,
              backgroundColor: AppColors.accentGold,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة جهاز', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // كارت الجهاز أصبح زجاجياً بدلاً من الكارت العادي
  Widget _buildEquipmentCard(Map<String, dynamic> item) {
    String statusText = item['status'];
    Color statusColor;
    
    if (statusText == 'متاح') {
      statusColor = Colors.green;
    } else if (statusText == 'مستلم') {
      statusColor = AppColors.accentGold;
    } else {
      statusColor = Colors.red; 
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassSurface(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withOpacity(0.08), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5))
            ),
            child: const Icon(Icons.radio_rounded, color: AppColors.primaryNavy),
          ),
          title: Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primaryNavy, fontSize: 16)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text('الحالة: $statusText', style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 13)),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: statusColor),
          ),
          onTap: () => _showOptions(item),
        ),
      ),
    );
  }
}
