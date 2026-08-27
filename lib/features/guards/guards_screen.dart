import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // 🚨 مكتبة الذكاء الاصطناعي 🚨

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
  List<Map<String, dynamic>> guardsList = [];
  bool isLoading = true;
  
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _refreshGuards();
  }

  Future<void> _refreshGuards() async {
    if (mounted) setState(() => isLoading = true);
    try {
      List<Map<String, dynamic>> data = await DatabaseHelper.instance.getAllGuards();
      if (data.isEmpty) {
        final cloudData = await _firestoreService.getAllGuardsFromCloud();
        for (var guard in cloudData) {
          await DatabaseHelper.instance.insertGuard({
            'name': guard['name'] ?? 'بدون اسم',
            'phone': guard['phone'] ?? 'غير متوفر',
            'role': 'فرد أمن', 
            'id_front_image': guard['frontImageUrl'] ?? '', 
            'id_back_image': guard['backImageUrl'] ?? '',
            'id_expiry_date': DateTime.now().add(const Duration(days: 365)).toString(), 
            'id_status': 'سارية',
          });
        }
        data = await DatabaseHelper.instance.getAllGuards();
      }
      if (!mounted) return;
      setState(() {
        guardsList = data;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  bool _isExpired(DateTime date) {
    final now = DateTime.now();
    return DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(now));
  }

  Future<String> _saveImageLocally(File image, String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(p.join(directory.path, 'guard_images'));
    await imageDirectory.create(recursive: true);
    final extension = p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path).toLowerCase();
    final fileName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final savedImage = await image.copy(p.join(imageDirectory.path, fileName));
    return savedImage.path;
  }

  // ==== نافذة تأكيد الحذف ====
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
            GlassActionButton(label: 'إلغاء', onPressed: () => Navigator.pop(dialogContext)),
            GlassActionButton(
              label: 'حذف',
              icon: Icons.delete_outline,
              danger: true,
              onPressed: () async {
                await DatabaseHelper.instance.deleteGuard(id);
                try {
                  await _firestoreService.deleteGuard(guardId: id.toString()).timeout(const Duration(seconds: 5));
                } catch (_) {}
                if (mounted) {
                  Navigator.pop(dialogContext);
                  _refreshGuards();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ==== نافذة الإضافة (مع التحليل الذكي) ====
  void _showAddGuardDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController nationalIdController = TextEditingController(); // 🚨 حقل جديد للرقم القومي
    String selectedRole = 'فرد أمن'; 
    DateTime? selectedExpiryDate; 
    File? frontImage;
    File? backImage;
    bool isDialogSaving = false;
    bool isDialogClosed = false; 

    // تهيئة محرك التعرف على النصوص باللغة العربية
    final textRecognizer = TextRecognizer(); // المحرك الافتراضي للذكاء الاصطناعي

    showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            
            // 🚨 دالة التقاط الصورة وتحليلها 🚨
            Future<void> _pickAndAnalyzeImage(bool isFront) async {
              final XFile? pickedFile = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 90,
              );
              
              if (pickedFile != null && context.mounted) {
                // 1. عرض إشعار جاري التحليل
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 15),
                        Text(isFront ? 'جاري تحليل الوجه الأمامي...' : 'جاري تحليل الوجه الخلفي...', style: const TextStyle(fontFamily: 'Cairo')),
                      ],
                    ),
                    backgroundColor: AppColors.primaryNavy,
                    duration: const Duration(seconds: 4),
                  ),
                );

                setDialogState(() {
                  if (isFront) frontImage = File(pickedFile.path);
                  else backImage = File(pickedFile.path);
                });

                // 2. بدء التحليل الذكي للصورة
                try {
                  final inputImage = InputImage.fromFilePath(pickedFile.path);
                  final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
                  String fullText = recognizedText.text;

                  setDialogState(() {
                    if (isFront) {
                      // أ. استخراج الرقم القومي (14 رقم تبدأ بـ 2 أو 3)
                      RegExp idRegExp = RegExp(r'\b[2-3]\d{13}\b');
                      var idMatch = idRegExp.firstMatch(fullText);
                      if (idMatch != null) {
                        nationalIdController.text = idMatch.group(0) ?? '';
                      }

                      // ب. استخراج الاسم (أطول جملة عربية بدون أرقام)
                      String bestName = '';
                      for (TextBlock block in recognizedText.blocks) {
                        for (TextLine line in block.lines) {
                          String text = line.text.trim();
                          // التحقق من أن السطر يحتوي على حروف عربية ومسافات فقط
                          if (RegExp(r'^[\u0600-\u06FF\s]+$').hasMatch(text)) {
                            // نختار السطر الذي يحتوي على 3 كلمات أو أكثر
                            if (text.split(' ').length >= 3 && text.length > bestName.length) {
                              bestName = text;
                            }
                          }
                        }
                      }
                      if (bestName.isNotEmpty && nameController.text.isEmpty) nameController.text = bestName;
                      
                    } else {
                      // ج. استخراج تاريخ الانتهاء من الوجه الخلفي (يبحث عن تنسيق سنة/شهر/يوم)
                      RegExp dateRegExp = RegExp(r'\d{4}[-/]\d{2}[-/]\d{2}');
                      var dateMatch = dateRegExp.firstMatch(fullText);
                      if (dateMatch != null) {
                        String dateStr = dateMatch.group(0)!.replaceAll('/', '-');
                        selectedExpiryDate = DateTime.tryParse(dateStr);
                      }
                    }
                  });
                  
                  // 3. إخفاء الإشعار القديم وإظهار رسالة النجاح
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم استخراج البيانات بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
              }
            }

            return GlassDialog(
              title: const Text('إضافة فرد أمن جديد'),
              titleIcon: const Icon(Icons.person_add_rounded, color: AppColors.primaryNavy),
              content: SingleChildScrollView( // لتجنب مشكلة الشاشة الصغيرة
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // التنبيه للمستخدم ليصور البطاقة أولاً
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text('التقط صور البطاقة أولاً ليقوم الذكاء الاصطناعي بتعبئة البيانات تلقائياً!', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickAndAnalyzeImage(true),
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
                            onTap: () => _pickAndAnalyzeImage(false),
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

                    TextField(
                      controller: nationalIdController, 
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'الرقم القومي', 
                        prefixIcon: const Icon(Icons.badge_rounded), 
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                      )
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedExpiryDate == null
                                  ? 'تاريخ الانتهاء (يوم/شهر/سنة) *'
                                  : 'الانتهاء: ${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: selectedExpiryDate == null ? Colors.grey : AppColors.textDark),
                            ),
                            const Icon(Icons.calendar_month_rounded, color: AppColors.primaryNavy, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                      if (inputName.isEmpty || selectedExpiryDate == null || frontImage == null || backImage == null) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة البيانات وصور البطاقة!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                         return;
                      }

                      setDialogState(() => isDialogSaving = true);

                      try {
                        // حفظ الصور محلياً
                        String savedFrontPath = await _saveImageLocally(frontImage!, 'front');
                        String savedBackPath = await _saveImageLocally(backImage!, 'back');

                        String expiryStr = "${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}";
                        String finalStatus = _isExpired(selectedExpiryDate!) ? 'منتهية' : 'سارية';

                        // حفظ الحارس محلياً في الهاتف
                        int newGuardId = await DatabaseHelper.instance.insertGuard({
                          'name': inputName,
                          'phone': phoneController.text.trim(),
                          'role': selectedRole,
                          'id_front_image': savedFrontPath,
                          'id_back_image': savedBackPath,
                          'id_expiry_date': expiryStr,
                          'id_status': finalStatus,
                        });
                        
                        // 🚨 رفع الصور والبيانات إلى السحابة فوراً 🚨
                        String? cloudFrontUrl = await _firestoreService.uploadGuardImage(guardId: newGuardId.toString(), imageFile: frontImage!, isFront: true);
                        String? cloudBackUrl = await _firestoreService.uploadGuardImage(guardId: newGuardId.toString(), imageFile: backImage!, isFront: false);

                        await _firestoreService.addGuard(
                          guardId: newGuardId.toString(),
                          name: inputName,
                          phone: phoneController.text.trim(),
                          baseSalary: 0.0,
                          frontImageUrl: cloudFrontUrl,
                          backImageUrl: cloudBackUrl,
                        ).timeout(const Duration(seconds: 10));

                      } catch (e) {
                         if (mounted) {
                           setDialogState(() => isDialogSaving = false);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ محلياً فقط. تحقق من الإنترنت.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.orange));
                         }
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
      textRecognizer.close(); // 🚨 إغلاق المحرك لتحرير ذاكرة الهاتف 🚨
      nameController.dispose();
      phoneController.dispose();
      nationalIdController.dispose();
    });
  }

  // ==== القائمة السفلية ==== (لم تتغير)
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

  Widget _buildPersonCard(Map<String, dynamic> person) {
    String name = person['name'];
    String role = person['role'];
    String id = person['id'].toString();
    String phone = person['phone'] ?? 'غير متوفر';
    String idStatus = person['id_status'] ?? '';
    Color roleColor = (role == 'مدير الأمن') ? Colors.redAccent : (role == 'مشرف' ? AppColors.accentGold : Colors.green);
    IconData roleIcon = (role == 'مدير الأمن') ? Icons.admin_panel_settings_rounded : (role == 'مشرف' ? Icons.supervised_user_circle_rounded : Icons.security_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassSurface(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5))),
            child: Icon(roleIcon, color: roleColor, size: 26)
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
              if (idStatus == 'منتهية') const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.warning_rounded, color: Colors.red, size: 18))
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GuardDetailsScreen(person: person))),
          onLongPress: () => _showGuardOptions(person),
        ),
      ),
    );
  }
}
