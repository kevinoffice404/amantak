import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // خدمة رفع الصور

  // 1. دالة رفع الصورة إلى السحابة (Firebase Storage)
  Future<String?> uploadGuardImage({required String guardId, required File imageFile, required bool isFront}) async {
    try {
      String fileName = isFront ? 'front_id.jpg' : 'back_id.jpg';
      Reference ref = _storage.ref().child('guards_images/$guardId/$fileName');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL(); // إرجاع رابط الصورة
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // 2. دالة إضافة حارس جديد (مع روابط الصور)
  Future<void> addGuard({
    required String guardId, 
    required String name, 
    required String phone, 
    required double baseSalary,
    String? frontImageUrl, 
    String? backImageUrl,
  }) async {
    try {
      await _db.collection('guards').doc(guardId).set({
        'name': name,
        'phone': phone,
        'baseSalary': baseSalary,
        'frontImageUrl': frontImageUrl ?? '',
        'backImageUrl': backImageUrl ?? '',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding guard: $e');
      rethrow;
    }
  }

  // 3. دالة تعديل بيانات الحارس
  Future<void> updateGuard({
    required String guardId, 
    required String name, 
    required String phone,
    String? frontImageUrl,
    String? backImageUrl,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (frontImageUrl != null && frontImageUrl.isNotEmpty) updateData['frontImageUrl'] = frontImageUrl;
      if (backImageUrl != null && backImageUrl.isNotEmpty) updateData['backImageUrl'] = backImageUrl;

      await _db.collection('guards').doc(guardId).update(updateData);
    } catch (e) {
      debugPrint('Error updating guard: $e');
      rethrow;
    }
  }

  // 4. دالة حذف الحارس (وصوره من السحابة)
  Future<void> deleteGuard({required String guardId}) async {
    try {
      await _db.collection('guards').doc(guardId).delete();
      try {
        await _storage.ref().child('guards_images/$guardId/front_id.jpg').delete();
        await _storage.ref().child('guards_images/$guardId/back_id.jpg').delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error deleting guard: $e');
      rethrow;
    }
  }

  // 5. دالة جلب الحراس للمزامنة
  Future<List<Map<String, dynamic>>> getAllGuardsFromCloud() async {
    try {
      QuerySnapshot snapshot = await _db.collection('guards').get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
    } catch (e) {
      debugPrint('Error fetching guards: $e');
      return [];
    }
  }
}
