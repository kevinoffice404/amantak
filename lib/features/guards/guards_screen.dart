import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/egyptian_id_ocr_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/database_helper.dart';
import '../../core/widgets/glass.dart' hide GlassActionButton;
import '../../core/widgets/glass_dialog.dart';
import 'guard_details_screen.dart';

class GuardsScreen extends StatefulWidget {
  const GuardsScreen({super.key});

  @override
  State<GuardsScreen> createState() => _GuardsScreenState();
}

class _GuardsScreenState extends State<GuardsScreen>
    with AutomaticKeepAliveClientMixin<GuardsScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final EgyptianIdOcrService _idOcrService = EgyptianIdOcrService();

  List<Map<String, dynamic>> guardsList = [];

  bool isLoading = true;
  bool _isRefreshing = false;
  bool _cloudSyncAttempted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGuards());
  }

  // =========================================================
  // تحميل أفراد الأمن
  // =========================================================

  Future<void> _loadGuards({bool allowCloudSync = true}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    try {
      final data = await DatabaseHelper.instance.getAllGuards();
      final normalizedData = data.map(_normalizeGuardRecord).toList();

      if (!mounted) return;

      setState(() {
        guardsList = normalizedData;
        isLoading = false;
      });

      // إذا كانت قاعدة البيانات المحلية فارغة، نحاول الاستعادة من
      // Firebase في الخلفية بدون تعطيل الواجهة.
      if (normalizedData.isEmpty && allowCloudSync && !_cloudSyncAttempted) {
        _cloudSyncAttempted = true;
        unawaited(_restoreFromCloud());
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading guards: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage('تعذر تحميل بيانات أفراد الأمن.', Colors.red);
    } finally {
      _isRefreshing = false;
    }
  }

  Map<String, dynamic> _normalizeGuardRecord(Map<String, dynamic> guard) {
    final normalized = Map<String, dynamic>.from(guard);
    final expiryDate = _parseDate(
      guard['id_expiry_date'] ?? guard['idExpiryDate'],
    );

    if (expiryDate != null) {
      normalized['id_expiry_date'] = _formatDate(expiryDate);
      normalized['id_status'] = _isExpired(expiryDate) ? 'منتهية' : 'سارية';
    } else {
      final currentStatus = (normalized['id_status'] ?? '').toString().trim();
      if (currentStatus.isEmpty) {
        normalized['id_status'] = 'غير محددة';
      }
    }

    return normalized;
  }

  // =========================================================
  // استعادة البيانات من Firebase
  // =========================================================

  Future<void> _restoreFromCloud() async {
    try {
      final cloudData = await _firestoreService.getAllGuardsFromCloud().timeout(
        const Duration(seconds: 12),
      );

      if (cloudData.isEmpty) return;

      // نتأكد مرة أخرى أن القاعدة المحلية ما زالت فارغة حتى لا نكرر السجلات.
      final currentLocal = await DatabaseHelper.instance.getAllGuards();
      if (currentLocal.isNotEmpty) return;

      for (final guard in cloudData) {
        try {
          final cloudId = int.tryParse(
            (guard['guardId'] ?? guard['id'] ?? '').toString(),
          );

          final expiryDate = _parseDate(
            guard['idExpiryDate'] ?? guard['id_expiry_date'],
          );

          String status = (guard['idStatus'] ?? guard['id_status'] ?? '')
              .toString()
              .trim();

          if (expiryDate != null) {
            status = _isExpired(expiryDate) ? 'منتهية' : 'سارية';
          } else if (status.isEmpty) {
            status = 'غير محددة';
          }

          final cloudSalary =
              double.tryParse(
                (guard['baseSalary'] ?? guard['basic_salary'] ?? '').toString(),
              ) ??
              0.0;

          final localGuard = <String, dynamic>{
            if (cloudId != null) 'id': cloudId,
            'name': (guard['name'] ?? 'بدون اسم').toString(),
            'phone': (guard['phone'] ?? 'غير متوفر').toString(),
            'role': (guard['role'] ?? 'فرد أمن').toString(),
            'id_front_image':
                (guard['frontImageUrl'] ?? guard['id_front_image'] ?? '')
                    .toString(),
            'id_back_image':
                (guard['backImageUrl'] ?? guard['id_back_image'] ?? '')
                    .toString(),
            'id_expiry_date': expiryDate == null ? '' : _formatDate(expiryDate),
            'id_status': status,
            'national_id': (guard['nationalId'] ?? guard['national_id'] ?? '')
                .toString(),
            'basic_salary': cloudSalary > 0 ? cloudSalary : 9000.0,
          };

          await DatabaseHelper.instance.insertGuard(localGuard);
        } catch (e, stackTrace) {
          debugPrint('Failed restoring cloud guard: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      if (!mounted) return;
      await _loadGuards(allowCloudSync: false);
    } catch (e, stackTrace) {
      // فشل الإنترنت لا يمنع التطبيق من العمل محلياً.
      debugPrint('Cloud restore failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // =========================================================
  // Helpers
  // =========================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return DateUtils.dateOnly(value);
    }

    if (value is Timestamp) {
      return DateUtils.dateOnly(value.toDate());
    }

    if (value is int) {
      final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
      return DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(milliseconds),
      );
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final directDate = DateTime.tryParse(text);
    if (directDate != null) {
      return DateUtils.dateOnly(directDate);
    }

    final normalized = _normalizeDigits(text);
    final dayFirst = RegExp(r'^(\d{1,2})[\-/\.](\d{1,2})[\-/\.](\d{4})$')
        .firstMatch(normalized);

    if (dayFirst == null) return null;

    return _safeDate(
      int.tryParse(dayFirst.group(3)!),
      int.tryParse(dayFirst.group(2)!),
      int.tryParse(dayFirst.group(1)!),
    );
  }

  bool _isExpired(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(date).isBefore(today);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  int? _getGuardId(Map<String, dynamic> guard) {
    final value = guard['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // حفظ الصور محلياً
  // =========================================================

  Future<String> _saveImageLocally(File image, String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(p.join(directory.path, 'guard_images'));

    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }

    String extension = p.extension(image.path).toLowerCase();
    if (extension.isEmpty || extension.length > 6) {
      extension = '.jpg';
    }

    final fileName =
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = p.join(imageDirectory.path, fileName);
    final savedImage = await image.copy(destination);

    return savedImage.path;
  }

  Future<void> _deleteFileSafely(String? path) async {
    if (path == null || path.trim().isEmpty || _isNetworkPath(path)) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stackTrace) {
      debugPrint('Failed deleting local guard image: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _isNetworkPath(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  // =========================================================
  // OCR
  // =========================================================

  String _normalizeDigits(String value) {
    const source = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
    const target = '01234567890123456789';

    var result = value;
    for (var i = 0; i < source.length; i++) {
      result = result.replaceAll(source[i], target[i]);
    }
    return result;
  }

  bool _isValidNationalId(String value) {
    if (!RegExp(r'^[23]\d{13}$').hasMatch(value)) return false;

    final century = value[0] == '2' ? 1900 : 2000;
    final year = century + int.parse(value.substring(1, 3));
    final month = int.parse(value.substring(3, 5));
    final day = int.parse(value.substring(5, 7));
    final birthDate = _safeDate(year, month, day);

    return birthDate != null &&
        !DateUtils.dateOnly(birthDate)
            .isAfter(DateUtils.dateOnly(DateTime.now()));
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;

    if (year < 1950 ||
        year > 2100 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }

    final result = DateTime(year, month, day);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }

    return result;
  }

  // =========================================================
  // حذف فرد أمن
  // =========================================================

  Future<void> _confirmDelete(Map<String, dynamic> guard) async {
    final id = _getGuardId(guard);
    if (id == null) {
      _showMessage('تعذر تحديد كود فرد الأمن.', Colors.red);
      return;
    }

    final name = (guard['name'] ?? 'بدون اسم').toString();

    await showGlassDialog(
      context: context,
      builder: (dialogContext) {
        return GlassDialog(
          title: const Text('تأكيد الحذف'),
          titleIcon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          danger: true,
          content: Text(
            'هل أنت متأكد أنك تريد حذف "$name" نهائياً؟',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
          ),
          actions: [
            GlassActionButton(
              label: 'إلغاء',
              onPressed: () => Navigator.pop(dialogContext),
            ),
            GlassActionButton(
              label: 'حذف',
              icon: Icons.delete_outline,
              danger: true,
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_deleteGuard(guard));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGuard(Map<String, dynamic> guard) async {
    final id = _getGuardId(guard);
    if (id == null) {
      _showMessage('تعذر تحديد كود فرد الأمن.', Colors.red);
      return;
    }

    final name = (guard['name'] ?? 'بدون اسم').toString();
    final frontPath = guard['id_front_image']?.toString();
    final backPath = guard['id_back_image']?.toString();
    final oldList = List<Map<String, dynamic>>.from(guardsList);

    if (mounted) {
      setState(() {
        guardsList = guardsList
            .where((item) => _getGuardId(item) != id)
            .toList();
      });
    }

    try {
      await DatabaseHelper.instance.deleteGuard(id);

      // بعد نجاح حذف السجل فقط، نحذف الصور المحلية المرتبطة به.
      await Future.wait<void>([
        _deleteFileSafely(frontPath),
        _deleteFileSafely(backPath),
      ]);

      _showMessage('تم حذف $name.', Colors.green);
      unawaited(_deleteGuardFromCloud(id));
    } catch (e, stackTrace) {
      debugPrint('Local delete failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        guardsList = oldList;
      });

      _showMessage('تعذر حذف فرد الأمن.', Colors.red);
    }
  }

  Future<void> _deleteGuardFromCloud(int id) async {
    try {
      await _firestoreService
          .deleteGuard(guardId: id.toString())
          .timeout(const Duration(seconds: 10));
    } catch (e, stackTrace) {
      debugPrint('Cloud delete failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // =========================================================
  // إضافة فرد أمن
  // =========================================================

  Future<void> _showAddGuardDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final nationalIdController = TextEditingController();

    var selectedRole = 'فرد أمن';
    DateTime? selectedExpiryDate;
    File? frontImage;
    File? backImage;
    var isDialogSaving = false;
    var isAnalyzing = false;
    var dialogActive = true;
    var canCloseDialog = true;
    Future<void>? activeTask;

    try {
      await showGlassDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> analyzeCapturedCard() async {
                final currentFront = frontImage;
                final currentBack = backImage;

                if (currentFront == null || currentBack == null) return;

                try {
                  final result = await _idOcrService.analyzeCard(
                    frontImage: currentFront,
                    backImage: currentBack,
                  );

                  if (!dialogActive || !dialogContext.mounted) return;

                  var fieldsApplied = 0;

                  final nationalId = result.nationalId;
                  if (nationalId != null && _isValidNationalId(nationalId)) {
                    nationalIdController.text = nationalId;
                    fieldsApplied++;
                  }

                  final fullName = result.fullName;
                  if (fullName != null && fullName.trim().isNotEmpty) {
                    nameController.text = fullName.trim();
                    fieldsApplied++;
                  }

                  final expiryDate = result.expiryDate;
                  if (expiryDate != null) {
                    selectedExpiryDate = expiryDate;
                    fieldsApplied++;
                  }

                  setDialogState(() {});

                  if (fieldsApplied == 3) {
                    _showMessage(
                      'تم استخراج بيانات البطاقة. راجعها قبل الحفظ.',
                      Colors.green,
                    );
                  } else if (fieldsApplied > 0) {
                    final missing = result.missingFields.join(' و');
                    _showMessage(
                      missing.isEmpty
                          ? 'تم استخراج بعض البيانات. راجعها قبل الحفظ.'
                          : 'تم استخراج بعض البيانات. أدخل $missing يدوياً.',
                      Colors.orange,
                    );
                  } else {
                    _showMessage(
                      'لم نتمكن من قراءة بيانات واضحة. أعد التصوير بإضاءة أفضل أو أدخلها يدوياً.',
                      Colors.orange,
                    );
                  }
                } on EgyptianIdOcrException catch (e) {
                  if (dialogActive && dialogContext.mounted) {
                    _showMessage(e.userMessage, Colors.orange);
                  }
                } catch (e, stackTrace) {
                  debugPrint('Cloud OCR error: $e');
                  debugPrintStack(stackTrace: stackTrace);

                  if (dialogActive && dialogContext.mounted) {
                    _showMessage(
                      'تعذر تحليل البطاقة حالياً. يمكنك إدخال البيانات يدوياً.',
                      Colors.orange,
                    );
                  }
                }
              }

              Future<void> pickIdImage(bool isFront) async {
                if (isAnalyzing || isDialogSaving || !dialogActive) return;

                setDialogState(() {
                  isAnalyzing = true;
                  canCloseDialog = false;
                });

                try {
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 2048,
                    maxHeight: 2048,
                    imageQuality: 85,
                  );

                  if (pickedFile == null ||
                      !dialogActive ||
                      !dialogContext.mounted) {
                    return;
                  }

                  final file = File(pickedFile.path);
                  setDialogState(() {
                    if (isFront) {
                      frontImage = file;
                    } else {
                      backImage = file;
                    }
                  });

                  if (frontImage != null && backImage != null) {
                    await analyzeCapturedCard();
                  } else {
                    _showMessage(
                      isFront
                          ? 'تم التقاط الوجه الأمامي. التقط الوجه الخلفي لاستكمال التحليل.'
                          : 'تم التقاط الوجه الخلفي. التقط الوجه الأمامي لاستكمال التحليل.',
                      Colors.blue,
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint('Image capture error: $e');
                  debugPrintStack(stackTrace: stackTrace);

                  _showMessage(
                    'تعذر التقاط الصورة. حاول مرة أخرى.',
                    Colors.orange,
                  );
                } finally {
                  if (dialogActive && dialogContext.mounted) {
                    setDialogState(() {
                      isAnalyzing = false;
                      canCloseDialog = true;
                    });
                  }
                }
              }

              Future<void> saveGuard() async {
                if (isDialogSaving || isAnalyzing || !dialogActive) return;

                final inputName = nameController.text.trim();
                final phone = _normalizeDigits(phoneController.text.trim());
                final nationalId = _normalizeDigits(
                  nationalIdController.text.trim(),
                );

                if (inputName.isEmpty) {
                  _showMessage('أدخل اسم فرد الأمن.', Colors.red);
                  return;
                }

                if (nationalId.isNotEmpty && nationalId.length != 14) {
                  _showMessage(
                    'الرقم القومي يجب أن يكون 14 رقماً.',
                    Colors.red,
                  );
                  return;
                }

                if (nationalId.isNotEmpty && !_isValidNationalId(nationalId)) {
                  _showMessage(
                    'الرقم القومي غير صحيح. راجع تاريخ الميلاد والأرقام.',
                    Colors.red,
                  );
                  return;
                }

                if (selectedExpiryDate == null) {
                  _showMessage('حدد تاريخ انتهاء البطاقة.', Colors.red);
                  return;
                }

                if (frontImage == null || backImage == null) {
                  _showMessage('يجب تصوير وجهي البطاقة.', Colors.red);
                  return;
                }

                setDialogState(() {
                  isDialogSaving = true;
                  canCloseDialog = false;
                });

                String? savedFrontPath;
                String? savedBackPath;
                late final int newGuardId;
                final expiry = selectedExpiryDate!;
                final finalStatus = _isExpired(expiry) ? 'منتهية' : 'سارية';

                try {
                  // الحفظ بالتتابع يتيح تنظيف أي ملف نُسخ قبل حدوث خطأ.
                  savedFrontPath = await _saveImageLocally(
                    frontImage!,
                    'front',
                  );
                  savedBackPath = await _saveImageLocally(backImage!, 'back');

                  newGuardId = await DatabaseHelper.instance.insertGuard({
                    'name': inputName,
                    'phone': phone,
                    'role': selectedRole,
                    'id_front_image': savedFrontPath,
                    'id_back_image': savedBackPath,
                    'id_expiry_date': _formatDate(expiry),
                    'id_status': finalStatus,
                    'national_id': nationalId,
                    'basic_salary': 9000.0,
                  });
                } catch (e, stackTrace) {
                  debugPrint('Local guard save error: $e');
                  debugPrintStack(stackTrace: stackTrace);

                  await _deleteFileSafely(savedFrontPath);
                  await _deleteFileSafely(savedBackPath);

                  if (dialogActive && dialogContext.mounted) {
                    setDialogState(() {
                      isDialogSaving = false;
                      canCloseDialog = true;
                    });
                  }

                  _showMessage('حدث خطأ أثناء حفظ فرد الأمن.', Colors.red);
                  return;
                }

                // أصبح السجل محفوظاً؛ لا تدخل عمليات الواجهة أو المزامنة داخل
                // catch السابق حتى لا تُحذف الصور بعد نجاح SQLite.
                final frontPath = savedFrontPath;
                final backPath = savedBackPath;

                if (dialogContext.mounted) {
                  setDialogState(() {
                    canCloseDialog = true;
                  });
                  await WidgetsBinding.instance.endOfFrame;
                }

                dialogActive = false;
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                await _loadGuards(allowCloudSync: false);
                _showMessage('تم حفظ فرد الأمن بنجاح.', Colors.green);

                unawaited(
                  _syncNewGuardToCloud(
                    guardId: newGuardId,
                    name: inputName,
                    phone: phone,
                    nationalId: nationalId,
                    role: selectedRole,
                    idExpiryDate: _formatDate(expiry),
                    idStatus: finalStatus,
                    frontPath: frontPath,
                    backPath: backPath,
                  ),
                );
              }

              void startTask(Future<void> Function() operation) {
                final task = operation();
                activeTask = task;
                unawaited(task);
              }

              return PopScope(
                canPop: canCloseDialog,
                child: GlassDialog(
                  title: const Text('إضافة فرد أمن جديد'),
                  titleIcon: const Icon(
                    Icons.person_add_rounded,
                    color: AppColors.primaryNavy,
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.22),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'التقط وجهي البطاقة بوضوح لاستخراج الاسم والرقم القومي وتاريخ الانتهاء سحابياً، ثم راجع البيانات.',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildIdImagePicker(
                                image: frontImage,
                                label: 'الوجه الأمامي *',
                                enabled: !isAnalyzing && !isDialogSaving,
                                onTap: () => startTask(() => pickIdImage(true)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildIdImagePicker(
                                image: backImage,
                                label: 'الوجه الخلفي *',
                                enabled: !isAnalyzing && !isDialogSaving,
                                onTap: () =>
                                    startTask(() => pickIdImage(false)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: nationalIdController,
                          keyboardType: TextInputType.number,
                          maxLength: 14,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9٠-٩۰-۹]'),
                            ),
                            LengthLimitingTextInputFormatter(14),
                          ],
                          decoration: _inputDecoration(
                            label: 'الرقم القومي',
                            icon: Icons.badge_rounded,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'الاسم الرباعي *',
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9٠-٩۰-۹+]'),
                            ),
                          ],
                          decoration: _inputDecoration(
                            label: 'رقم الهاتف',
                            icon: Icons.phone_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedRole,
                              borderRadius: BorderRadius.circular(20),
                              items: const ['مدير الأمن', 'مشرف', 'فرد أمن']
                                  .map((role) {
                                    return DropdownMenuItem<String>(
                                      value: role,
                                      child: Text(
                                        role,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: isDialogSaving || isAnalyzing
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setDialogState(() {
                                        selectedRole = value;
                                      });
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isDialogSaving || isAnalyzing
                              ? null
                              : () async {
                                  final now = DateTime.now();
                                  final picked = await showGlassDatePicker(
                                    context: dialogContext,
                                    initialDate:
                                        selectedExpiryDate ??
                                        DateUtils.dateOnly(now),
                                    firstDate: DateTime(now.year - 20, 1, 1),
                                    lastDate: DateTime(now.year + 20, 12, 31),
                                  );

                                  if (picked != null &&
                                      dialogActive &&
                                      dialogContext.mounted) {
                                    setDialogState(() {
                                      selectedExpiryDate = picked;
                                    });
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedExpiryDate == null
                                        ? 'تاريخ انتهاء البطاقة *'
                                        : 'الانتهاء: ${_formatDate(selectedExpiryDate!)}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: selectedExpiryDate == null
                                          ? Colors.grey
                                          : AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primaryNavy,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isAnalyzing) ...[
                          const SizedBox(height: 18),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    GlassActionButton(
                      label: 'إلغاء',
                      onPressed: isDialogSaving || isAnalyzing
                          ? null
                          : () {
                              dialogActive = false;
                              Navigator.pop(dialogContext);
                            },
                    ),
                    GlassActionButton(
                      label: isDialogSaving
                          ? 'جارٍ الحفظ...'
                          : isAnalyzing
                          ? 'جاري التحليل...'
                          : 'حفظ',
                      primary: true,
                      icon: isDialogSaving || isAnalyzing
                          ? null
                          : Icons.check_rounded,
                      onPressed: isDialogSaving || isAnalyzing
                          ? null
                          : () => startTask(saveGuard),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      dialogActive = false;

      // إذا أُغلقت النافذة من النظام ننتظر أي عملية جارية قبل التخلص
      // من وحدات التحكم.
      final pendingTask = activeTask;
      if (pendingTask != null) {
        try {
          await pendingTask;
        } catch (e, stackTrace) {
          debugPrint('Pending guard dialog task failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      nameController.dispose();
      phoneController.dispose();
      nationalIdController.dispose();
    }
  }

  // =========================================================
  // مزامنة الحارس الجديد مع Firebase
  // =========================================================

  Future<void> _syncNewGuardToCloud({
    required int guardId,
    required String name,
    required String phone,
    required String nationalId,
    required String role,
    required String idExpiryDate,
    required String idStatus,
    required String frontPath,
    required String backPath,
  }) async {
    try {
      final imageUrls = await _firestoreService
          .uploadGuardImages(
            guardId: guardId.toString(),
            frontImage: File(frontPath),
            backImage: File(backPath),
          )
          .timeout(const Duration(seconds: 30));

      final frontImageUrl = (imageUrls['frontImageUrl'] ?? '').toString();
      final backImageUrl = (imageUrls['backImageUrl'] ?? '').toString();

      if (frontImageUrl.isEmpty || backImageUrl.isEmpty) {
        throw StateError('Guard image upload returned an empty URL.');
      }

      await _firestoreService
          .addGuard(
            guardId: guardId.toString(),
            name: name,
            phone: phone,
            role: role,
            nationalId: nationalId,
            idExpiryDate: idExpiryDate,
            idStatus: idStatus,
            baseSalary: 9000.0,
            frontImageUrl: frontImageUrl,
            backImageUrl: backImageUrl,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e, stackTrace) {
      debugPrint('Cloud guard sync failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(
          'تم حفظ الحارس على الجهاز، لكن المزامنة السحابية لم تكتمل.',
          Colors.orange,
        );
      }
    }
  }

  // =========================================================
  // تصميم حقول الإدخال
  // =========================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: label,
      counterText: counterText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
      ),
    );
  }

  Widget _buildIdImagePicker({
    required File? image,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image == null
                ? Colors.black12
                : Colors.green.withValues(alpha: 0.35),
          ),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth: 600,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded, color: Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Cairo',
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // =========================================================
  // قائمة الخيارات
  // =========================================================

  Future<void> _showGuardOptions(Map<String, dynamic> person) async {
    final id = _getGuardId(person);
    final name = (person['name'] ?? 'بدون اسم').toString();

    await showGlassBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Cairo',
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 10),
              ListTile(
                enabled: id != null,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'حذف الحارس',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                onTap: id == null
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        unawaited(_confirmDelete(person));
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GlassPage(
      title: 'إدارة أفراد الأمن',
      child: Stack(
        children: [
          Positioned.fill(child: _buildGuardsBody()),
          PositionedDirectional(
            bottom: 24,
            end: 24,
            child: FloatingActionButton.extended(
              heroTag: 'guards_add_guard_button',
              onPressed: () => unawaited(_showAddGuardDialog()),
              elevation: 3,
              backgroundColor: AppColors.accentGold,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'إضافة حارس',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardsBody() {
    if (isLoading && guardsList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (guardsList.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadGuards(allowCloudSync: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.security_rounded, size: 70, color: AppColors.textMuted),
            SizedBox(height: 20),
            Text(
              'لا يوجد أفراد أمن مسجلون حالياً.\nاضغط على "إضافة حارس" للبدء.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textMuted,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadGuards(allowCloudSync: false),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 450,
        itemCount: guardsList.length,
        itemBuilder: (context, index) {
          final person = guardsList[index];
          return RepaintBoundary(
            key: ValueKey(person['id'] ?? index),
            child: _buildPersonCard(person),
          );
        },
      ),
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> person) {
    final name = (person['name'] ?? 'بدون اسم').toString();
    final role = (person['role'] ?? 'فرد أمن').toString();
    final id = (person['id'] ?? '-').toString();
    final phone = (person['phone'] ?? 'غير متوفر').toString();
    final idStatus = (person['id_status'] ?? '').toString();

    late final Color roleColor;
    late final IconData roleIcon;

    switch (role) {
      case 'مدير الأمن':
        roleColor = Colors.redAccent;
        roleIcon = Icons.admin_panel_settings_rounded;
        break;
      case 'مشرف':
        roleColor = AppColors.accentGold;
        roleIcon = Icons.supervised_user_circle_rounded;
        break;
      default:
        roleColor = Colors.green;
        roleIcon = Icons.security_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.84),
        elevation: 1,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: () => unawaited(_showGuardOptions(person)),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuardDetailsScreen(person: person),
              ),
            );

            if (mounted) {
              await _loadGuards(allowCloudSync: false);
            }
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: roleColor.withValues(alpha: 0.20)),
              ),
              child: Icon(roleIcon, color: roleColor, size: 26),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryNavy,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                if (idStatus == 'منتهية')
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: Tooltip(
                      message: 'البطاقة منتهية',
                      child: Icon(
                        Icons.warning_rounded,
                        color: Colors.red,
                        size: 19,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'كود: $id',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    phone.trim().isEmpty ? 'هاتف: غير متوفر' : 'هاتف: $phone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
