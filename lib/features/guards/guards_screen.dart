import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart'; 
import '../../core/services/firestore_service.dart';
import 'guard_details_screen.dart'; 
import 'guard_records_screen.dart';

import '../../core/widgets/glass.dart' hide GlassActionButton; 
import '../../core/widgets/glass_dialog.dart'; 

class GuardsScreen extends StatefulWidget {
  const GuardsScreen({Key? key}) : super(key: key);

  @override
  State<GuardsScreen> createState() => _GuardsScreenState();
}

class _GuardsScreenState extends State<GuardsScreen> {
  // متغيرات الشاشة الأساسية
  List<Map<String, dynamic>> guardsList = [];
  bool isLoading = true;
  
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _refreshGuards();
  }

  // ==== دالة استرجاع وعرض البيانات (الذكية) ====
  Future<void> _refreshGuards() async {
    if (mounted) setState(() => isLoading = true);

    try {
      // 1. محاولة جلب البيانات من قاعدة البيانات المحلية (الهاتف) أولاً
      List<Map<String, dynamic>> data = await DatabaseHelper.instance.getAllGuards();

      // 2. إذا كانت ذاكرة الهاتف فارغة (بعد حذف التطبيق مثلاً)
      if (data.isEmpty) {
        debugPrint('الذاكرة المحلية فارغة، جاري استرجاع البيانات من Firebase...');
        
        // جلب البيانات من السحابة
        final cloudData = await _firestoreService.getAllGuardsFromCloud();

        // إعادة حفظ البيانات القادمة من السحابة داخل هاتف المستخدم
        for (var guard in cloudData) {
          await DatabaseHelper.instance.insertGuard({
            'name': guard['name'] ?? 'بدون اسم',
            'phone': guard['phone'] ?? 'غير متوفر',
            'role': 'فرد أمن', 
            'id_front_image': '', // مسار فارغ مؤقتاً لحين برمجة رفع الصور للسحابة
            'id_back_image': '',
            'id_expiry_date': DateTime.now().add(const Duration(days: 365)).toString(), 
            'id_status': 'سارية',
          });
        }
        
        // تحديث القائمة بالبيانات الجديدة التي تم حفظها للتو
        data = await DatabaseHelper.instance.getAllGuards();
      }

      // 3. عرض البيانات على الشاشة
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
          content: Text('تعذر تحميل بيانات أفراد الأمن.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة للتحقق مما إذا كان تاريخ البطاقة منتهياً
  bool _isExpired(DateTime date) {
    final now = DateTime.now();
    return DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(now));
  }

  // دالة لحفظ الصور محلياً في مجلد التطبيق
  Future<String> _saveImageLocally(File image, String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(p.join(directory.path, 'guard_images'));
    await imageDirectory.create(recursive: true);

    final extension = p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path).toLowerCase();
    final now = DateTime.now();
    final fileName = '${prefix}_${now.microsecondsSinceEpoch}$extension';

    final savedImage = await image.copy(p.join(imageDirectory.path, fileName));
    return savedImage.path;
  }

  // دالة لحذف الصورة القديمة عند استبدالها بصورة جديدة
  Future<void> _deleteImageIfReplaced(String? oldPath, String? newPath) async {
    if (oldPath == null || oldPath.isEmpty || oldPath == newPath) return;
    try {
      final file = File(oldPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ==== نافذة تأكيد الحذف الزجاجية (مع الحذف من السحابة) ====
  void _confirmDelete(BuildContext context, int id, String name) {
    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return GlassDialog(
          title: const Text('تأكيد الحذف'),
          titleIcon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          danger: true,
          content: Text('هل أنت متأكد أنك تريد حذف "$name" نهائياً؟', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15)),
          actions: [
            GlassActionButton(
              label: 'إلغاء',
              onPressed: () => Navigator.pop(dialogContext),
            ),
            GlassActionButton(
              label: 'حذف',
              icon: Icons.delete_outline,
              danger: true,
              onPressed: () async {
                // 1. الحذف من قاعدة البيانات المحلية (الهاتف)
                await DatabaseHelper.instance.deleteGuard(id);
                
                // 2. الحذف من السحابة (Firebase) بالتزامن
                try {
                  await _firestoreService.deleteGuard(guardId: id.toString())
                      .timeout(const Duration(seconds: 5));
                } catch (e) {
                  debugPrint('تعذر الحذف من السحابة حالياً');
                }

                if (mounted) {
                  Navigator.pop(dialogContext);
                  _refreshGuards();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الحذف بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ==== نافذة التعديل الزجاجية (مع التعديل في السحابة) ====
  void _showEditGuardDialog(Map<String, dynamic> person) {
    final TextEditingController nameController = TextEditingController(text: person['name']);
    final TextEditingController phoneController = TextEditingController(text: person['phone']);
    String selectedRole = person['role']; 
    
    DateTime? selectedExpiryDate = person['id_expiry_date'] != null 
        ? DateTime.tryParse(person['id_expiry_date']) 
        : null;

    File? frontImage;
    File? backImage;
    String? existingFrontPath = person['id_front_image'];
    String? existingBackPath = person['id_back_image'];
    bool isDialogSaving = false;

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            
            Future<void> _pickImage(bool isFront) async {
              final XFile? pickedFile = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
                maxWidth: 2000,
                maxHeight: 2000,
              );
              if (pickedFile != null && context.mounted) {
                setDialogState(() {
                  if (isFront) {
                    frontImage = File(pickedFile.path);
                  } else {
                    backImage = File(pickedFile.path);
                  }
                });
              }
            }

            return GlassDialog(
              title: const Text('تعديل بيانات الحارس'),
              titleIcon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryNavy),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController, 
                    decoration: InputDecoration(
                      labelText: 'الاسم الرباعي', 
                      prefixIcon: const Icon(Icons.person_rounded), 
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController, 
                    keyboardType: TextInputType.phone, 
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف', 
                      prefixIcon: const Icon(Icons.phone_rounded), 
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRole,
                        dropdownColor: AppColors.glassWhite.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        items: ['مدير الأمن', 'مشرف', 'فرد أمن'].map((String role) => DropdownMenuItem(value: role, child: Text(role, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (newValue) => setDialogState(() => selectedRole = newValue!),
                      ),
                    ),
                  ),
                  const Divider(height: 30, color: Colors.black12),
                  const Text('صور البطاقة الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickImage(true),
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                            child: frontImage != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(frontImage!, fit: BoxFit.cover))
                                : (existingFrontPath != null && File(existingFrontPath).existsSync()
                                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(existingFrontPath), fit: BoxFit.cover))
                                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_rounded, color: Colors.grey), SizedBox(height: 4), Text('الوجه الأمامي', style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey))])),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickImage(false),
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                            child: backImage != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(backImage!, fit: BoxFit.cover))
                                : (existingBackPath != null && File(existingBackPath).existsSync()
                                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(existingBackPath), fit: BoxFit.cover))
                                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_rounded, color: Colors.grey), SizedBox(height: 4), Text('الوجه الخلفي', style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey))])),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      DateTime? picked = await showGlassDatePicker(
                        context: context,
                        initialDate: selectedExpiryDate ?? DateUtils.dateOnly(now),
                        firstDate: DateUtils.dateOnly(now),
                        lastDate: DateTime(now.year + 20),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedExpiryDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedExpiryDate == null
                                ? 'تاريخ الانتهاء (يوم/شهر/سنة)'
                                : 'الانتهاء: ${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: selectedExpiryDate == null ? Colors.grey : AppColors.textDark,
                            ),
                          ),
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primaryNavy, size: 20),
                        ],
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
                  label: isDialogSaving ? 'جارٍ الحفظ...' : 'تعديل',
                  primary: true,
                  icon: isDialogSaving ? null : Icons.check_rounded,
                  onPressed: isDialogSaving 
                    ? null 
                    : () async {
                      String inputName = nameController.text.trim();
                      if (inputName.isEmpty || selectedExpiryDate == null) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إكمال الاسم وتاريخ الانتهاء', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                         return;
                      }

                      final duplicate = guardsList.any(
                        (guard) =>
                            guard['id'] != person['id'] &&
                            (guard['name'] as String?)?.trim() == inputName,
                      );
                      if (duplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('هذا الاسم مسجل بالفعل! يرجى إدخال اسم مختلف.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isDialogSaving = true);

                      String? finalFrontPath = frontImage != null ? await _saveImageLocally(frontImage!, 'front') : existingFrontPath;
                      String? finalBackPath = backImage != null ? await _saveImageLocally(backImage!, 'back') : existingBackPath;

                      if (finalFrontPath == null || finalBackPath == null) {
                         setDialogState(() => isDialogSaving = false);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب توفر صورتي البطاقة (الوجهين)!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                         return;
                      }

                      String expiryStr = "${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}";
                      String finalStatus = _isExpired(selectedExpiryDate!) ? 'منتهية' : 'سارية';

                      try {
                        // 1. التعديل في الهاتف محلياً
                        await DatabaseHelper.instance.updateGuard({
                          'id': person['id'],
                          'name': inputName,
                          'phone': phoneController.text.trim(),
                          'role': selectedRole,
                          'id_front_image': finalFrontPath,
                          'id_back_image': finalBackPath,
                          'id_expiry_date': expiryStr,
                          'id_status': finalStatus,
                        });
                        
                        // 2. التعديل في السحابة فوراً
                        await _firestoreService.updateGuard(
                          guardId: person['id'].toString(),
                          name: inputName,
                          phone: phoneController.text.trim(),
                        ).timeout(const Duration(seconds: 5));

                      } catch (_) {
                        if (frontImage != null && finalFrontPath != null) {
                          try {
                            final file = File(finalFrontPath);
                            if (await file.exists()) await file.delete();
                          } catch (_) {}
                        }
                        if (backImage != null && finalBackPath != null) {
                          try {
                            final file = File(finalBackPath);
                            if (await file.exists()) await file.delete();
                          } catch (_) {}
                        }
                        if (mounted) {
                          setDialogState(() => isDialogSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التعديلات. يرجى المحاولة لاحقاً.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                        }
                        return;
                      }

                      if (frontImage != null) await _deleteImageIfReplaced(existingFrontPath, finalFrontPath);
                      if (backImage != null) await _deleteImageIfReplaced(existingBackPath, finalBackPath);

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        _refreshGuards();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل البيانات بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                      }
                    },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  // ==== نافذة الإضافة الزجاجية (مع الإضافة للسحابة) ====
  void _showAddGuardDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    String selectedRole = 'فرد أمن'; 
    
    DateTime? selectedExpiryDate; 
    File? frontImage;
    File? backImage;
    bool isDialogSaving = false;
    bool isDialogClosed = false; 

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            
            Future<void> _pickImage(bool isFront) async {
              final XFile? pickedFile = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
                maxWidth: 2000,
                maxHeight: 2000,
              );
              if (pickedFile != null && context.mounted) {
                setDialogState(() {
                  if (isFront) {
                    frontImage = File(pickedFile.path);
                  } else {
                    backImage = File(pickedFile.path);
                  }
                });
              }
            }

            return GlassDialog(
              title: const Text('إضافة فرد أمن جديد'),
              titleIcon: const Icon(Icons.person_add_rounded, color: AppColors.primaryNavy),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController, 
                    decoration: InputDecoration(
                      labelText: 'الاسم الرباعي', 
                      prefixIcon: const Icon(Icons.person_rounded), 
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController, 
                    keyboardType: TextInputType.phone, 
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف', 
                      prefixIcon: const Icon(Icons.phone_rounded), 
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRole,
                        dropdownColor: AppColors.glassWhite.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        items: ['مدير الأمن', 'مشرف', 'فرد أمن'].map((String role) => DropdownMenuItem(value: role, child: Text(role, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (newValue) => setDialogState(() => selectedRole = newValue!),
                      ),
                    ),
                  ),
                  const Divider(height: 30, color: Colors.black12),
                  const Text('صور البطاقة الشخصية (إلزامي)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickImage(true),
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                            child: frontImage != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(frontImage!, fit: BoxFit.cover)) 
                                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_rounded, color: Colors.grey), SizedBox(height: 4), Text('الوجه الأمامي *', style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.red))]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickImage(false),
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                            child: backImage != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(backImage!, fit: BoxFit.cover)) 
                                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_rounded, color: Colors.grey), SizedBox(height: 4), Text('الوجه الخلفي *', style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.red))]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      DateTime? picked = await showGlassDatePicker(
                        context: context,
                        initialDate: DateUtils.dateOnly(now),
                        firstDate: DateUtils.dateOnly(now),
                        lastDate: DateTime(now.year + 20),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedExpiryDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedExpiryDate == null
                                ? 'تاريخ الانتهاء (يوم/شهر/سنة) *'
                                : 'الانتهاء: ${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: selectedExpiryDate == null ? Colors.grey : AppColors.textDark,
                            ),
                          ),
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primaryNavy, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                GlassActionButton(
                  label: 'إلغاء',
                  onPressed: () {
                    isDialogClosed = true;
                    Navigator.pop(dialogContext);
                  },
                ),
                GlassActionButton(
                  label: isDialogSaving ? 'جارٍ الحفظ...' : 'حفظ',
                  primary: true,
                  icon: isDialogSaving ? null : Icons.check_rounded,
                  onPressed: isDialogSaving 
                    ? null 
                    : () async {
                      String inputName = nameController.text.trim();
                      String inputPhone = phoneController.text.trim();
                      
                      if (inputName.isEmpty || selectedExpiryDate == null || frontImage == null || backImage == null) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('الرجاء إدخال الاسم، تاريخ الانتهاء، وصور البطاقة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
                         );
                         return;
                      }

                      bool isDuplicate = guardsList.any((guard) => guard['name'] == inputName);
                      if (isDuplicate) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا الاسم مسجل بالفعل! يرجى إدخال اسم مختلف.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                         return;
                      }

                      setDialogState(() => isDialogSaving = true);

                      String? savedFrontPath;
                      String? savedBackPath;
                      try {
                        savedFrontPath = await _saveImageLocally(frontImage!, 'front');
                        savedBackPath = await _saveImageLocally(backImage!, 'back');

                        String expiryStr = "${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}";
                        String finalStatus = _isExpired(selectedExpiryDate!) ? 'منتهية' : 'سارية';

                        // 1. الإضافة محلياً
                        int newGuardId = await DatabaseHelper.instance.insertGuard({
                          'name': inputName,
                          'phone': inputPhone,
                          'role': selectedRole,
                          'id_front_image': savedFrontPath,
                          'id_back_image': savedBackPath,
                          'id_expiry_date': expiryStr,
                          'id_status': finalStatus,
                        });
                        
                        // 2. الإضافة في السحابة
                        await _firestoreService.addGuard(
                          guardId: newGuardId.toString(),
                          name: inputName,
                          phone: inputPhone.isNotEmpty ? inputPhone : "غير متوفر",
                          baseSalary: 0.0,
                        ).timeout(const Duration(seconds: 5), onTimeout: () {
                           debugPrint('انتهى وقت الاتصال بالسحابة (سيتم الحفظ محلياً فقط)');
                        });

                      } catch (e) {
                        if (isDialogClosed) return;
                        for (final path in [savedFrontPath, savedBackPath]) {
                          if (path == null) continue;
                          try {
                            final file = File(path);
                            if (await file.exists()) await file.delete();
                          } catch (_) {}
                        }
                        if (mounted) {
                          setDialogState(() => isDialogSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ بيانات الحارس.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                        }
                        return;
                      }

                      if (mounted && !isDialogClosed) {
                        Navigator.pop(dialogContext);
                        _refreshGuards();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                      }
                    },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      isDialogClosed = true;
      nameController.dispose();
      phoneController.dispose();
    });
  }

  // ==== القائمة السفلية للخيارات ====
  void _showGuardOptions(Map<String, dynamic> person) {
    showGlassBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text(person['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo', color: AppColors.primaryNavy)),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 10),
              
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.assignment_outlined, color: Colors.blue)),
                title: const Text('سجل الحضور والجزاءات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => GuardRecordsScreen(guardName: person['name'])));
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: Colors.orange)),
                title: const Text('تعديل البيانات والصور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditGuardDialog(person);
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
                title: const Text('حذف الحارس', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, person['id'], person['name']);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  // ==== دالة بناء الشاشة الأساسية ====
  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'إدارة أفراد الأمن',
      child: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : guardsList.isEmpty
                  ? const Center(child: Text('لا يوجد أفراد أمن مسجلين حالياً.\nاضغط على "إضافة حارس" للبدء.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.textMuted, fontFamily: 'Cairo', fontWeight: FontWeight.w600)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: guardsList.length,
                      itemBuilder: (context, index) {
                        return _buildPersonCard(guardsList[index]);
                      },
                    ),
          
          PositionedDirectional(
            bottom: 24,
            end: 24,
            child: FloatingActionButton.extended(
              onPressed: _showAddGuardDialog,
              elevation: 4,
              backgroundColor: AppColors.accentGold,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة حارس', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
            ),
          ),
        ],
      ),
    );
  }

  // ==== دالة بناء بطاقة الحارس ====
  Widget _buildPersonCard(Map<String, dynamic> person) {
    String name = person['name'];
    String role = person['role'];
    String id = person['id'].toString();
    String phone = person['phone'] ?? 'غير متوفر';
    String idStatus = person['id_status'] ?? '';

    Color roleColor = (role == 'مدير الأمن' || role == 'مسؤول') ? Colors.redAccent : (role == 'مشرف' ? AppColors.accentGold : Colors.green);
    IconData roleIcon = (role == 'مدير الأمن' || role == 'مسؤول') ? Icons.admin_panel_settings_rounded : (role == 'مشرف' ? Icons.supervised_user_circle_rounded : Icons.security_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassSurface(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5))
            ),
            child: Icon(roleIcon, color: roleColor, size: 26)
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis),
              ),
              if (idStatus == 'منتهية') 
                const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.warning_rounded, color: Colors.red, size: 18))
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كود: $id', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                Text('هاتف: $phone', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: roleColor.withOpacity(0.3))),
            child: Text(role, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => GuardDetailsScreen(person: person)));
          },
          onLongPress: () {
            _showGuardOptions(person);
          },
        ),
      ),
    );
  }
}
