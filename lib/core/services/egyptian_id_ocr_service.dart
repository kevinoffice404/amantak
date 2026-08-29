import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

String _encodeImageBytes(Uint8List bytes) => base64Encode(bytes);

class EgyptianIdOcrResult {
  const EgyptianIdOcrResult({
    required this.nationalId,
    required this.fullName,
    required this.expiryDate,
  });

  final String? nationalId;
  final String? fullName;
  final DateTime? expiryDate;

  bool get hasAnyData =>
      nationalId != null || fullName != null || expiryDate != null;

  List<String> get missingFields {
    final fields = <String>[];

    if (fullName == null) fields.add('الاسم');
    if (nationalId == null) fields.add('الرقم القومي');
    if (expiryDate == null) fields.add('تاريخ الانتهاء');

    return fields;
  }

  factory EgyptianIdOcrResult.fromMap(Map<String, dynamic> map) {
    String? cleanString(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final expiryText = cleanString(map['expiryDate']);

    return EgyptianIdOcrResult(
      nationalId: cleanString(map['nationalId']),
      fullName: cleanString(map['fullName']),
      expiryDate: expiryText == null ? null : DateTime.tryParse(expiryText),
    );
  }
}

class EgyptianIdOcrException implements Exception {
  const EgyptianIdOcrException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

class EgyptianIdOcrService {
  EgyptianIdOcrService._internal();

  static final EgyptianIdOcrService _instance =
      EgyptianIdOcrService._internal();

  factory EgyptianIdOcrService() => _instance;

  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const String _region = 'europe-west1';
  static const String _functionName = 'analyzeEgyptianId';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  Future<EgyptianIdOcrResult> analyzeCard({
    required File frontImage,
    required File backImage,
  }) async {
    try {
      final encodedImages = await Future.wait<String>([
        _readAndEncode(frontImage),
        _readAndEncode(backImage),
      ]);

      final callable = _functions.httpsCallable(
        _functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final response = await callable.call({
        'frontImageBase64': encodedImages[0],
        'backImageBase64': encodedImages[1],
      });

      final rawData = response.data;
      if (rawData is! Map) {
        throw const FormatException('OCR response is not a map.');
      }

      final data = rawData.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );

      return EgyptianIdOcrResult.fromMap(data);
    } on EgyptianIdOcrException {
      rethrow;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      debugPrint('Egyptian ID callable error [${e.code}]: ${e.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw EgyptianIdOcrException(_messageForFirebaseCode(e.code));
    } on SocketException catch (e, stackTrace) {
      debugPrint('Egyptian ID network error: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw const EgyptianIdOcrException(
        'لا يوجد اتصال بالإنترنت. احتفظ بالصور وأدخل البيانات يدوياً أو حاول لاحقاً.',
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('Invalid Egyptian ID OCR response: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw const EgyptianIdOcrException(
        'وصل رد غير صالح من خدمة قراءة البطاقة. حاول مرة أخرى.',
      );
    } catch (e, stackTrace) {
      debugPrint('Unexpected Egyptian ID OCR error: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw const EgyptianIdOcrException(
        'تعذر تحليل البطاقة حالياً. يمكنك إدخال البيانات يدوياً.',
      );
    }
  }

  Future<String> _readAndEncode(File image) async {
    if (!await image.exists()) {
      throw const EgyptianIdOcrException(
        'لم يتم العثور على إحدى صور البطاقة. أعد التصوير.',
      );
    }

    final length = await image.length();

    if (length <= 0) {
      throw const EgyptianIdOcrException(
        'إحدى صور البطاقة فارغة. أعد التصوير.',
      );
    }

    if (length > _maxImageBytes) {
      throw const EgyptianIdOcrException(
        'حجم إحدى الصور كبير جداً. أعد التصوير من داخل التطبيق.',
      );
    }

    final bytes = await image.readAsBytes();
    return compute(_encodeImageBytes, bytes);
  }

  String _messageForFirebaseCode(String code) {
    switch (code) {
      case 'unauthenticated':
      case 'permission-denied':
        return 'تعذر التحقق من نسخة التطبيق. تأكد من إعداد App Check ثم حاول مجدداً.';
      case 'invalid-argument':
        return 'صور البطاقة غير صالحة للتحليل. أعد تصوير الوجهين بوضوح.';
      case 'resource-exhausted':
        return 'خدمة قراءة البطاقات مشغولة حالياً. حاول بعد قليل.';
      case 'deadline-exceeded':
      case 'cancelled':
        return 'استغرق تحليل البطاقة وقتاً طويلاً. تحقق من الإنترنت وحاول مجدداً.';
      case 'unavailable':
        return 'خدمة قراءة البطاقة غير متاحة مؤقتاً. حاول لاحقاً.';
      case 'failed-precondition':
        return 'خدمة قراءة البطاقة لم تُفعّل بالكامل على Firebase.';
      default:
        return 'تعذر تحليل البطاقة حالياً. يمكنك إدخال البيانات يدوياً.';
    }
  }
}
