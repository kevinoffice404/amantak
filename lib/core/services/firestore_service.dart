import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// الفئة المسؤولة عن إدارة جميع العمليات مع قاعدة بيانات Firebase Firestore.
/// تم تجميع كل الدوال هنا لسهولة الصيانة وإعادة الاستخدام في أي شاشة.
class FirestoreService {
  // أخذ نسخة ثابتة (Instance) للاتصال بقاعدة البيانات
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =================================================================
  // 1. قسم أفراد الأمن (Guards)
  // =================================================================

  /// دالة لإضافة فرد أمن جديد إلى السحابة.
  /// تستقبل الدالة بيانات الحارس وتنشئ له مستنداً فريداً برقم الـ [guardId].
  Future<void> addGuard({
    required String guardId, 
    required String name,
    required String phone,
    required double baseSalary,
  }) async {
    try {
      // استخدام guardId كمعرف للمستند لسهولة البحث عنه لاحقاً
      await _db.collection('guards').doc(guardId).set({
        'name': name,
        'phone': phone,
        'baseSalary': baseSalary,
        'createdAt': FieldValue.serverTimestamp(), // توقيت الإنشاء من الخادم
        'isActive': true, // حالة الحارس الافتراضية
      });
      debugPrint('✅ السحابة: تم حفظ بيانات الحارس $name بنجاح.');
    } catch (e) {
      debugPrint('❌ السحابة: خطأ في إضافة الحارس: $e');
      throw Exception('تعذر حفظ بيانات الحارس في السحابة.');
    }
  }

  // =================================================================
  // 2. قسم الحضور والانصراف (Attendance)
  // =================================================================

  /// دالة لتسجيل الحضور أو الانصراف لحارس معين.
  Future<void> recordAttendance({
    required String guardId,
    required String status, // يقبل 'حضور' أو 'انصراف'
    required DateTime time,
  }) async {
    try {
      // نستخدم .add() لإنشاء مستند بمعرف عشوائي تلقائي
      await _db.collection('attendance').add({
        'guardId': guardId,
        'status': status,
        // حفظ الوقت بصيغة نصية معيارية لتسهيل تحويلها لاحقاً
        'time': time.toIso8601String(), 
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ السحابة: تم تسجيل ال$status للحارس ($guardId).');
    } catch (e) {
      debugPrint('❌ السحابة: خطأ في تسجيل الحضور: $e');
      throw Exception('تعذر تسجيل الحضور/الانصراف.');
    }
  }

  // =================================================================
  // 3. قسم العهدة والمعدات (Custody)
  // =================================================================

  /// دالة لتسليم عهدة (مثل جهاز لاسلكي أو زي) لفرد أمن.
  Future<void> addCustody({
    required String guardId,
    required String itemName, // اسم العهدة
    required int quantity, // الكمية المسلمة
  }) async {
    try {
      await _db.collection('custody').add({
        'guardId': guardId,
        'itemName': itemName,
        'quantity': quantity,
        'assignedAt': FieldValue.serverTimestamp(), // تاريخ التسليم
        'isReturned': false, // الحالة الافتراضية للعهدة أنها لم تُسترد
      });
      debugPrint('✅ السحابة: تم تسجيل عهدة ($itemName) للحارس.');
    } catch (e) {
      debugPrint('❌ السحابة: خطأ في تسجيل العهدة: $e');
      throw Exception('تعذر تسجيل العهدة.');
    }
  }

  // =================================================================
  // 4. قسم الجزاءات والمفردات (Penalties / Salary Deductions)
  // =================================================================

  /// دالة لتسجيل جزاء أو خصم على راتب فرد الأمن.
  Future<void> addPenalty({
    required String guardId,
    required double amount, // قيمة الخصم
    required String reason, // سبب الخصم
    required DateTime date,
  }) async {
    try {
      await _db.collection('penalties').add({
        'guardId': guardId,
        'amount': amount,
        'reason': reason,
        'date': date.toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ السحابة: تم تسجيل جزاء بقيمة $amount للحارس.');
    } catch (e) {
      debugPrint('❌ السحابة: خطأ في تسجيل الجزاء: $e');
      throw Exception('تعذر تسجيل الجزاء.');
    }
  }
}
