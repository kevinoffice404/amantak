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
  List<Map<String, dynamic>> guardsList = []; // قائمة الحراس لاستخدامها في التسليم
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // 🚀 دالة تهيئة البيانات وإنشاء جدول السجلات إن لم يكن موجوداً
  Future<void> _initData() async {
    if (mounted) setState(() => isLoading = true);
    
    try {
      final db = await DatabaseHelper.instance.database;
      // التأكد من وجود جدول سجلات العهد لحفظ الحركات
      await db.execute('''
        CREATE TABLE IF NOT EXISTS equipment_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          equipment_id INTEGER,
          guard_name TEXT,
          action TEXT,
          action_time TEXT
        )
      ''');

      // جلب الأجهزة والحراس معاً
      final data = await DatabaseHelper.instance.getAllEquipment();
      final guards = await DatabaseHelper.instance.getAllGuards();
      
      if (!mounted) return;
      setState(() {
        equipmentList = data;
        guardsList = guards;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل البيانات. يرجى المحاولة لاحقاً.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // تسجيل حركة جديدة في السجل
  Future<void> _logAction(int equipmentId, String guardName, String action) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    
    // تنسيق الوقت بشكل مفهوم (مثال: 2026-08-25 02:30 م)
    int h = now.hour;
    String ampm = h >= 12 ? 'م' : 'ص';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    String formattedTime = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} | $h:${now.minute.toString().padLeft(2, '0')} $ampm";

    await db.insert('equipment_history', {
      'equipment_id': equipmentId,
      'guard_name': guardName,
      'action': action,
      'action_time': formattedTime,
    });
  }

  // إضافة جهاز جديد
  void _showAddEquipmentDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isDialogSaving = false; 

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
                  fillColor: Colors.white.withOpacity(0.5), 
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

                          setDialogState(() => isDialogSaving = true); 
                          try {
                            await DatabaseHelper.instance.insertEquipment({
                              'item_name': name,
                              'status': 'متاح',
                              'assigned_to': 'المركز',
                            });

                            if (!mounted) return;
                            Navigator.pop(dialogContext); 
                            await _initData(); // تحديث القائمة
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
    ).then((_) => nameController.dispose()); // 🚀 تنظيف الذاكرة بعد الإغلاق
  }

  // نافذة اختيار الحارس لتسليمه العهدة
  void _showAssignGuardDialog(Map<String, dynamic> item) {
    String? selectedGuard;
    bool isSaving = false;

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassDialog(
              title: const Text('تسليم عهدة لشخص'),
              titleIcon: const Icon(Icons.assignment_ind_rounded, color: AppColors.accentGold),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الجهاز: ${item['item_name']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  const Text('اختر فرد الأمن المستلم:', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('اختر من القائمة', style: TextStyle(fontFamily: 'Cairo')),
                        value: selectedGuard,
                        dropdownColor: AppColors.glassWhite.withOpacity(0.9),
                        items: guardsList.map((g) => DropdownMenuItem(value: g['name'].toString(), child: Text(g['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) => setDialogState(() => selectedGuard = val),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                GlassActionButton(
                  label: 'إلغاء',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                GlassActionButton(
                  label: isSaving ? 'جارٍ التسجيل...' : 'تأكيد التسليم',
                  primary: true,
                  icon: Icons.check_circle_rounded,
                  onPressed: isSaving 
                    ? null 
                    : () async {
                      if (selectedGuard == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار فرد أمن.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final db = await DatabaseHelper.instance.database;
                        // تحديث حالة الجهاز وتحديد من استلمه
                        await db.update(
                          'equipment', 
                          {'status': 'مستلم', 'assigned_to': selectedGuard}, 
                          where: 'id = ?', 
                          whereArgs: [item['id']]
                        );
                        // تسجيل الحركة في السجل
                        await _logAction(item['id'], selectedGuard!, 'استلم العهدة');
                        
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        _initData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسليم العهدة بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                      } catch (_) {
                        if (mounted) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء التسليم.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                        }
                      }
                    }
                )
              ],
            );
          }
        );
      }
    );
  }

  // استلام العهدة وإعادتها للمركز
  Future<void> _returnEquipment(Map<String, dynamic> item) async {
    try {
      final db = await DatabaseHelper.instance.database;
      // معرفة من كان معه العهدة لتسجيل أنه أعادها
      String previousGuard = item['assigned_to'] != 'المركز' ? item['assigned_to'] : 'شخص غير معروف';
      
      // تحديث الحالة
      await db.update(
        'equipment', 
        {'status': 'متاح', 'assigned_to': 'المركز'}, 
        where: 'id = ?', 
        whereArgs: [item['id']]
      );
      
      // تسجيل الإعادة
      await _logAction(item['id'], previousGuard, 'أعاد العهدة للمركز');
      
      _initData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام العهدة وإعادتها للمركز', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      }
    } catch (_) {}
  }

  // إرسال للصيانة
  Future<void> _sendToMaintenance(Map<String, dynamic> item) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('equipment', {'status': 'صيانة', 'assigned_to': 'ورشة الصيانة'}, where: 'id = ?', whereArgs: [item['id']]);
      await _logAction(item['id'], 'المركز', 'إرسال الجهاز للصيانة');
      _initData();
    } catch (_) {}
  }

  // 🚀 نافذة عرض سجل الحركات (History) الاحترافية
  void _showEquipmentHistory(Map<String, dynamic> item) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> history = await db.query(
      'equipment_history',
      where: 'equipment_id = ?',
      whereArgs: [item['id']],
      orderBy: 'id DESC', // ترتيب من الأحدث للأقدم
    );

    if (!mounted) return;

    showGlassBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 16),
            Text('سجل حركات: ${item['item_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primaryNavy), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 10),
            
            // قائمة السجلات
            history.isEmpty 
              ? const Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Text('لا توجد حركات مسجلة لهذا الجهاز حتى الآن.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                )
              : SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4, // تحديد ارتفاع للقائمة
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      bool isReturn = record['action'] == 'أعاد العهدة للمركز';
                      bool isMaintenance = record['action'].contains('صيانة');
                      
                      Color iconColor = isReturn ? Colors.green : (isMaintenance ? Colors.red : AppColors.accentGold);
                      IconData icon = isReturn ? Icons.check_circle_rounded : (isMaintenance ? Icons.build_circle_rounded : Icons.person_rounded);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        title: Text(record['guard_name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(record['action'], style: TextStyle(fontFamily: 'Cairo', color: iconColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(record['action_time'], style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            
            const SizedBox(height: 10),
            GlassActionButton(
              label: 'إغلاق السجل',
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      ),
    );
  }

  // خيارات الجهاز 
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
            
            // 🚀 زر السجل الجديد
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.history_rounded, color: AppColors.primaryBlue)),
              title: const Text('سجل حركات الجهاز', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              onTap: () {
                Navigator.pop(context);
                _showEquipmentHistory(item); // فتح نافذة السجل
              },
            ),
            const Divider(height: 20, color: Colors.black12),

            if (item['status'] != 'متاح')
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: Colors.green)),
                title: const Text('إرجاع العهدة للمركز (متاح)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _returnEquipment(item);
                },
              ),

            if (item['status'] == 'متاح')
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accentGold.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.assignment_ind_outlined, color: AppColors.accentGold)),
                title: const Text('تسليم عهدة لفرد أمن (مستلم)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _showAssignGuardDialog(item); // فتح نافذة اختيار الحارس
                },
              ),

            if (item['status'] != 'صيانة')
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.build_circle_outlined, color: Colors.red)),
                title: const Text('إرسال للصيانة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _sendToMaintenance(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), 
                      itemCount: equipmentList.length,
                      itemBuilder: (context, index) {
                        return _buildEquipmentCard(equipmentList[index]);
                      },
                    ),
          
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

  Widget _buildEquipmentCard(Map<String, dynamic> item) {
    String statusText = item['status'];
    String assignedTo = item['assigned_to'] ?? 'المركز';
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5))
            ),
            child: Icon(Icons.radio_rounded, color: statusColor),
          ),
          title: Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primaryNavy, fontSize: 16)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('الحالة: $statusText', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                // 🚀 عرض اسم الشخص المستلم للعهدة على الكارت مباشرة
                Text('بعهدة: $assignedTo', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 12)),
              ],
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryNavy.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.primaryNavy),
          ),
          onTap: () => _showOptions(item),
        ),
      ),
    );
  }
}
