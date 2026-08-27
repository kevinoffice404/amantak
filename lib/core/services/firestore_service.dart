import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  // Singleton
  FirestoreService._internal();

  static final FirestoreService _instance =
      FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  static const String _guardsCollection =
      'guards';

  static const String _guardsImagesFolder =
      'guards_images';

  CollectionReference<Map<String, dynamic>>
      get _guards {
    return _db.collection(
      _guardsCollection,
    );
  }

  // =========================================================
  // Helpers
  // =========================================================

  String _cleanGuardId(
    String guardId,
  ) {
    final id = guardId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'guardId cannot be empty',
      );
    }

    return id;
  }

  String _imageContentType(
    String path,
  ) {
    final lower =
        path.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.heic') ||
        lower.endsWith('.heif')) {
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

  String? _normalizeDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value
          .toDate()
          .toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  // =========================================================
  // رفع صورة واحدة
  // =========================================================

  Future<String?> uploadGuardImage({
    required String guardId,
    required File imageFile,
    required bool isFront,
  }) async {
    final id =
        _cleanGuardId(guardId);

    try {
      if (!await imageFile.exists()) {
        debugPrint(
          'Image does not exist: ${imageFile.path}',
        );

        return null;
      }

      final fileName = isFront
          ? 'front_id.jpg'
          : 'back_id.jpg';

      final reference = _storage
          .ref()
          .child(
            '$_guardsImagesFolder/$id/$fileName',
          );

      final metadata =
          SettableMetadata(
        contentType:
            _imageContentType(
          imageFile.path,
        ),
        customMetadata: {
          'guardId': id,
          'side':
              isFront ? 'front' : 'back',
        },
      );

      final snapshot =
          await reference.putFile(
        imageFile,
        metadata,
      );

      if (snapshot.state !=
          TaskState.success) {
        debugPrint(
          'Image upload did not complete successfully.',
        );

        return null;
      }

      return await snapshot.ref
          .getDownloadURL();
    } on FirebaseException catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Firebase Storage upload error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    } catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Unexpected image upload error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  // =========================================================
  // رفع صورتي البطاقة بالتوازي
  // =========================================================

  Future<Map<String, String?>>
      uploadGuardImages({
    required String guardId,
    required File frontImage,
    required File backImage,
  }) async {
    final id =
        _cleanGuardId(guardId);

    final results =
        await Future.wait<String?>(
      [
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
      ],
    );

    return {
      'frontImageUrl': results[0],
      'backImageUrl': results[1],
    };
  }

  // =========================================================
  // إضافة / مزامنة حارس
  // =========================================================

  Future<void> addGuard({
    required String guardId,
    required String name,
    required String phone,

    String role = 'فرد أمن',

    String? nationalId,

    String? frontImageUrl,
    String? backImageUrl,

    String? idExpiryDate,
    String? idStatus,

    double baseSalary = 0.0,

    String salaryType = 'monthly',

    double? salaryRate,

    bool isActive = true,
  }) async {
    final id =
        _cleanGuardId(guardId);

    try {
      final data =
          <String, dynamic>{
        'guardId': id,

        'name':
            name.trim(),

        'phone':
            phone.trim(),

        'role':
            role.trim(),

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

        // للتوافق مع النظام القديم
        'baseSalary':
            baseSalary,

        // نظام الرواتب الجديد
        'salaryType':
            salaryType,

        'salaryRate':
            salaryRate ?? baseSalary,

        'isActive':
            isActive,

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),

        // يسهل عمليات migration لاحقاً
        'schemaVersion': 2,
      };

      await _guards.doc(id).set(
            data,
            SetOptions(
              merge: true,
            ),
          );
    } on FirebaseException catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Firestore addGuard error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Unexpected addGuard error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // =========================================================
  // تعديل بيانات الحارس
  // =========================================================

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
    final id =
        _cleanGuardId(guardId);

    try {
      final updateData =
          <String, dynamic>{
        'guardId': id,

        'name':
            name.trim(),

        'phone':
            phone.trim(),

        'updatedAt':
            FieldValue.serverTimestamp(),

        'schemaVersion': 2,
      };

      if (role != null) {
        updateData['role'] =
            role.trim();
      }

      if (nationalId != null) {
        updateData['nationalId'] =
            nationalId.trim();
      }

      if (frontImageUrl != null &&
          frontImageUrl.isNotEmpty) {
        updateData[
                'frontImageUrl'] =
            frontImageUrl;
      }

      if (backImageUrl != null &&
          backImageUrl.isNotEmpty) {
        updateData[
                'backImageUrl'] =
            backImageUrl;
      }

      if (idExpiryDate != null) {
        updateData[
                'idExpiryDate'] =
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

      // set + merge أكثر أماناً من update
      // في نظام Local-first.
      await _guards.doc(id).set(
            updateData,
            SetOptions(
              merge: true,
            ),
          );
    } on FirebaseException catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Firestore updateGuard error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Unexpected updateGuard error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // =========================================================
  // حذف حارس
  // =========================================================

  Future<void> deleteGuard({
    required String guardId,
  }) async {
    final id =
        _cleanGuardId(guardId);

    try {
      // نحذف البيانات أولاً.
      await _guards
          .doc(id)
          .delete();

      // ثم ننظف الصور.
      // فشل تنظيف Storage لا يعيد الحارس.
      await _deleteGuardImagesSafely(
        id,
      );
    } on FirebaseException catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Firestore deleteGuard error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (
      e,
      stackTrace,
    ) {
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
    final frontReference =
        _storage.ref().child(
      '$_guardsImagesFolder/'
      '$guardId/front_id.jpg',
    );

    final backReference =
        _storage.ref().child(
      '$_guardsImagesFolder/'
      '$guardId/back_id.jpg',
    );

    await Future.wait([
      _deleteStorageFileSafely(
        frontReference,
      ),
      _deleteStorageFileSafely(
        backReference,
      ),
    ]);
  }

  Future<void> _deleteStorageFileSafely(
    Reference reference,
  ) async {
    try {
      await reference.delete();
    } on FirebaseException catch (e) {
      if (e.code ==
          'object-not-found') {
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

  // =========================================================
  // جلب جميع أفراد الأمن
  // =========================================================

  Future<List<Map<String, dynamic>>>
      getAllGuardsFromCloud() async {
    try {
      final snapshot =
          await _guards.get();

      final guards =
          <Map<String, dynamic>>[];

      for (final document
          in snapshot.docs) {
        try {
          final data =
              document.data();

          // لا نظهر الموظف المعطل.
          if (data['isActive'] ==
              false) {
            continue;
          }

          guards.add({
            'id':
                document.id,

            'guardId':
                document.id,

            'name':
                (data['name'] ??
                        'بدون اسم')
                    .toString(),

            'phone':
                (data['phone'] ?? '')
                    .toString(),

            'role':
                (data['role'] ??
                        'فرد أمن')
                    .toString(),

            'nationalId':
                (
                  data['nationalId'] ??
                  data['national_id'] ??
                  ''
                ).toString(),

            'frontImageUrl':
                (
                  data['frontImageUrl'] ??
                  data['id_front_image'] ??
                  ''
                ).toString(),

            'backImageUrl':
                (
                  data['backImageUrl'] ??
                  data['id_back_image'] ??
                  ''
                ).toString(),

            'idExpiryDate':
                _normalizeDate(
                  data['idExpiryDate'] ??
                      data[
                          'id_expiry_date'],
                ) ??
                '',

            'idStatus':
                (
                  data['idStatus'] ??
                  data['id_status'] ??
                  ''
                ).toString(),

            'baseSalary':
                _toDouble(
              data['baseSalary'],
            ),

            'salaryType':
                (
                  data['salaryType'] ??
                  'monthly'
                ).toString(),

            'salaryRate':
                _toDouble(
              data['salaryRate'] ??
                  data['baseSalary'],
            ),

            'isActive':
                data['isActive'] !=
                    false,

            'createdAt':
                data['createdAt'],

            'updatedAt':
                data['updatedAt'],
          });
        } catch (e) {
          debugPrint(
            'Invalid guard skipped '
            '${document.id}: $e',
          );
        }
      }

      return guards;
    } on FirebaseException catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Firestore get guards error '
        '[${e.code}]: ${e.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return [];
    } catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'Unexpected get guards error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  // =========================================================
  // جلب حارس واحد
  // =========================================================

  Future<Map<String, dynamic>?>
      getGuardById({
    required String guardId,
  }) async {
    final id =
        _cleanGuardId(guardId);

    try {
      final snapshot =
          await _guards
              .doc(id)
              .get();

      if (!snapshot.exists) {
        return null;
      }

      final data =
          snapshot.data();

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
        'getGuardById error '
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

  // =========================================================
  // تفعيل / تعطيل حارس
  // =========================================================

  Future<void> setGuardActiveStatus({
    required String guardId,
    required bool isActive,
  }) async {
    final id =
        _cleanGuardId(guardId);

    try {
      await _guards.doc(id).set(
        {
          'isActive':
              isActive,

          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (
      e,
      stackTrace,
    ) {
      debugPrint(
        'setGuardActiveStatus error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }
}