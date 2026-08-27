import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  // Singleton:
  // حتى لو تم استدعاء FirestoreService() من أكثر من شاشة
  // سنستخدم نفس Service object.
  FirestoreService._internal();

  static final FirestoreService _instance =
      FirestoreService._internal();

  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _guardsCollection = 'guards';
  static const String _guardsImagesFolder = 'guards_images';

  CollectionReference<Map<String, dynamic>> get _guards =>
      _db.collection(_guardsCollection);

  // ============================================================
  // Helpers
  // ============================================================

  String _cleanGuardId(String guardId) {
    final value = guardId.trim();

    if (value.isEmpty) {
      throw ArgumentError('guardId cannot be empty');
    }

    return value;
  }

  String _imageContentType(String path) {
    final lowerPath = path.toLowerCase();

    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerPath.endsWith('.heic') ||
        lowerPath.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  String? _normalizeDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  // ============================================================
  // 1. رفع صورة واحدة
  // ============================================================

  Future<String?> uploadGuardImage({
    required String guardId,
    required File imageFile,
    required bool isFront,
  }) async {
    final id = _cleanGuardId(guardId);

    try {
      if (!await imageFile.exists()) {
        debugPrint(
          'Guard image does not exist: ${imageFile.path}',
        );
        return null;
      }

      final fileName = isFront
          ? 'front_id.jpg'
          : 'back_id.jpg';

      final Reference ref = _storage
          .ref()
          .child(
            '$_guardsImagesFolder/$id/$fileName',
          );

      final metadata = SettableMetadata(
        contentType: _imageContentType(
          imageFile.path,
        ),
        customMetadata: {
          'guardId': id,
          'side': isFront ? 'front' : 'back',
        },
      );

      final TaskSnapshot snapshot =
          await ref.putFile(
        imageFile,
        metadata,
      );

      if (snapshot.state != TaskState.success) {
        debugPrint(
          'Guard image upload did not finish successfully.',
        );
        return null;
      }

      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'Firebase Storage upload error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected guard image upload error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // 2. رفع الصورتين بالتوازي
  // ============================================================

  Future<Map<String, String?>> uploadGuardImages({
    required String guardId,
    required File frontImage,
    required File backImage,
  }) async {
    final id = _cleanGuardId(guardId);

    final results = await Future.wait<String?>([
      uploadGuardImage(
        guardId: id,
        imageFile: frontImage,
        isFront: true,
      ),
      uploadGuardImage(
        guardId: id,
        imageFile: backImage,
        isFront: false,
      ),
    ]);

    return {
      'frontImageUrl': results[0],
      'backImageUrl': results[1],
    };
  }

  // ============================================================
  // 3. إضافة / مزامنة حارس
  // ============================================================

  Future<void> addGuard({
    required String guardId,
    required String name,
    required String phone,

    // للتوافق مع الكود القديم.
    required double baseSalary,

    String role = 'فرد أمن',
    String? nationalId,

    String? frontImageUrl,
    String? backImageUrl,

    String? idExpiryDate,
    String? idStatus,

    // نظام الرواتب الجديد.
    String salaryType = 'monthly',
    double? salaryRate,

    bool isActive = true,
  }) async {
    final id = _cleanGuardId(guardId);

    try {
      final data = <String, dynamic>{
        // نحتفظ بالـ ID داخل المستند أيضاً.
        'guardId': id,

        'name': name.trim(),
        'phone': phone.trim(),

        'role': role.trim(),

        'nationalId':
            nationalId?.trim() ?? '',

        'frontImageUrl':
            frontImageUrl ?? '',

        'backImageUrl':
            backImageUrl ?? '',

        'idExpiryDate':
            idExpiryDate ?? '',

        'idStatus':
            idStatus ?? '',

        // Backward compatibility
        'baseSalary': baseSalary,

        // النظام الجديد
        'salaryType': salaryType,
        'salaryRate':
            salaryRate ?? baseSalary,

        'isActive': isActive,

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),

        // يفيد لو غيرنا Schema لاحقاً.
        'schemaVersion': 2,
      };

      await _guards.doc(id).set(
            data,
            SetOptions(
              merge: true,
            ),
          );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'Firebase addGuard error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected addGuard error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // ============================================================
  // 4. تعديل الحارس
  // ============================================================

  Future<void> updateGuard({
    required String guardId,
    required String name,
    required String phone,

    String? role,
    String? nationalId,

    String? frontImageUrl,
    String? backImageUrl,

    String? idExpiryDate,
    String? idStatus,

    double? baseSalary,
    String? salaryType,
    double? salaryRate,

    bool? isActive,
  }) async {
    final id = _cleanGuardId(guardId);

    try {
      final updateData = <String, dynamic>{
        'guardId': id,

        'name': name.trim(),
        'phone': phone.trim(),

        'updatedAt':
            FieldValue.serverTimestamp(),

        'schemaVersion': 2,
      };

      if (role != null) {
        updateData['role'] = role.trim();
      }

      if (nationalId != null) {
        updateData['nationalId'] =
            nationalId.trim();
      }

      if (frontImageUrl != null &&
          frontImageUrl.isNotEmpty) {
        updateData['frontImageUrl'] =
            frontImageUrl;
      }

      if (backImageUrl != null &&
          backImageUrl.isNotEmpty) {
        updateData['backImageUrl'] =
            backImageUrl;
      }

      if (idExpiryDate != null) {
        updateData['idExpiryDate'] =
            idExpiryDate;
      }

      if (idStatus != null) {
        updateData['idStatus'] =
            idStatus;
      }

      if (baseSalary != null) {
        updateData['baseSalary'] =
            baseSalary;
      }

      if (salaryType != null) {
        updateData['salaryType'] =
            salaryType;
      }

      if (salaryRate != null) {
        updateData['salaryRate'] =
            salaryRate;
      }

      if (isActive != null) {
        updateData['isActive'] =
            isActive;
      }

      // لا نستخدم update().
      //
      // set + merge يضمن أنه حتى لو المستند
      // غير موجود بسبب مشكلة مزامنة، سيتم إنشاؤه.
      await _guards.doc(id).set(
            updateData,
            SetOptions(
              merge: true,
            ),
          );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'Firebase updateGuard error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected updateGuard error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // ============================================================
  // 5. حذف الحارس
  // ============================================================

  Future<void> deleteGuard({
    required String guardId,
  }) async {
    final id = _cleanGuardId(guardId);

    try {
      // نجعل حذف الصور وحذف المستند يعملان بالتوازي.
      //
      // فشل حذف الصور لا يجب أن يمنع حذف بيانات الحارس.
      await Future.wait([
        _deleteGuardImagesSafely(id),
        _guards.doc(id).delete(),
      ]);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'Firebase deleteGuard error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected deleteGuard error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  Future<void> _deleteGuardImagesSafely(
    String guardId,
  ) async {
    final frontRef = _storage.ref().child(
          '$_guardsImagesFolder/'
          '$guardId/front_id.jpg',
        );

    final backRef = _storage.ref().child(
          '$_guardsImagesFolder/'
          '$guardId/back_id.jpg',
        );

    // الحذف بالتوازي.
    await Future.wait([
      _deleteStorageFileSafely(frontRef),
      _deleteStorageFileSafely(backRef),
    ]);
  }

  Future<void> _deleteStorageFileSafely(
    Reference reference,
  ) async {
    try {
      await reference.delete();
    } on FirebaseException catch (e) {
      // إذا لم تكن الصورة موجودة فهذا ليس خطأ
      // يحتاج لإيقاف عملية حذف الحارس.
      if (e.code == 'object-not-found') {
        return;
      }

      debugPrint(
        'Storage delete warning '
        '[${e.code}]: ${e.message}',
      );
    } catch (e) {
      debugPrint(
        'Storage delete warning: $e',
      );
    }
  }

  // ============================================================
  // 6. جلب جميع الحراس
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getAllGuardsFromCloud() async {
    try {
      final QuerySnapshot<Map<String, dynamic>>
          snapshot = await _guards.get();

      final List<Map<String, dynamic>>
          guards = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // في حال استخدام Soft Delete لاحقاً.
          if (data['isActive'] == false) {
            continue;
          }

          guards.add({
            // كلاهما للتوافق مع الأكواد القديمة والجديدة.
            'id': doc.id,
            'guardId': doc.id,

            'name':
                (data['name'] ?? 'بدون اسم')
                    .toString(),

            'phone':
                (data['phone'] ?? '')
                    .toString(),

            'role':
                (data['role'] ?? 'فرد أمن')
                    .toString(),

            'nationalId':
                (data['nationalId'] ??
                        data['national_id'] ??
                        '')
                    .toString(),

            'frontImageUrl':
                (data['frontImageUrl'] ??
                        data['id_front_image'] ??
                        '')
                    .toString(),

            'backImageUrl':
                (data['backImageUrl'] ??
                        data['id_back_image'] ??
                        '')
                    .toString(),

            'idExpiryDate':
                _normalizeDate(
                  data['idExpiryDate'] ??
                      data['id_expiry_date'],
                ) ??
                '',

            'idStatus':
                (data['idStatus'] ??
                        data['id_status'] ??
                        '')
                    .toString(),

            'baseSalary':
                _toDouble(
              data['baseSalary'],
            ),

            'salaryType':
                (data['salaryType'] ??
                        'monthly')
                    .toString(),

            'salaryRate':
                _toDouble(
              data['salaryRate'] ??
                  data['baseSalary'],
            ),

            'isActive':
                data['isActive'] != false,

            'createdAt':
                data['createdAt'],

            'updatedAt':
                data['updatedAt'],
          });
        } catch (e) {
          debugPrint(
            'Skipped invalid cloud guard '
            '${doc.id}: $e',
          );
        }
      }

      return guards;
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'Firebase getAllGuards error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return [];
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected getAllGuards error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  // ============================================================
  // 7. جلب حارس واحد
  // ============================================================

  Future<Map<String, dynamic>?> getGuardById({
    required String guardId,
  }) async {
    final id = _cleanGuardId(guardId);

    try {
      final snapshot =
          await _guards.doc(id).get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      return {
        'id': snapshot.id,
        'guardId': snapshot.id,
        ...data,
      };
    } on FirebaseException catch (e) {
      debugPrint(
        'getGuardById Firebase error '
        '[${e.code}]: ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'getGuardById error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // 8. تغيير حالة الحارس
  // ============================================================

  Future<void> setGuardActiveStatus({
    required String guardId,
    required bool isActive,
  }) async {
    final id = _cleanGuardId(guardId);

    try {
      await _guards.doc(id).set(
        {
          'isActive': isActive,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (e) {
      debugPrint(
        'setGuardActiveStatus error: $e',
      );
      rethrow;
    }
  }
}