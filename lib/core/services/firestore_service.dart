import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. إضافة حارس جديد إلى السحابة (Create)
  Future<void> addGuard({required String guardId, required String name, required String phone, required double baseSalary}) async {
    try {
      await _db.collection('guards').doc(guardId).set({
        'name': name,
        'phone': phone,
        'baseSalary': baseSalary,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding guard: $e');
      rethrow;
    }
  }

  // 2. تعديل بيانات حارس في السحابة (Update)
  Future<void> updateGuard({required String guardId, required String name, required String phone}) async {
    try {
      await _db.collection('guards').doc(guardId).update({
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('تم التعديل في السحابة بنجاح');
    } catch (e) {
      debugPrint('Error updating guard: $e');
      rethrow;
    }
  }

  // 3. حذف حارس من السحابة نهائياً (Delete)
  Future<void> deleteGuard({required String guardId}) async {
    try {
      await _db.collection('guards').doc(guardId).delete();
      debugPrint('تم الحذف من السحابة بنجاح');
    } catch (e) {
      debugPrint('Error deleting guard: $e');
      rethrow;
    }
  }

  // 4. جلب جميع الحراس من السحابة (Read - للاستخدام في المزامنة مستقبلاً)
  Future<List<Map<String, dynamic>>> getAllGuardsFromCloud() async {
    try {
      QuerySnapshot snapshot = await _db.collection('guards').get();
      // تحويل البيانات القادمة من السحابة إلى قائمة يمكن للتطبيق فهمها
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching guards: $e');
      return [];
    }
  }
}
