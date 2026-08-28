import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/id_card_data.dart';

class IdCardOcrService {

  static Future<IdCardData> analyze(File image) async {

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {

      final inputImage =
          InputImage.fromFile(image);

      final result =
          await recognizer.processImage(inputImage);

      final text = result.text;

      final nationalId =
          _extractNationalId(text);

      final isValid =
          _isValidCard(text, nationalId);

      return IdCardData(
        isValid: isValid,
        nationalId: nationalId,
        expiryDate: _extractExpiryDate(text),
        confidence: isValid ? 0.9 : 0.2,
      );

    } finally {

      recognizer.close();

    }
  }


  static bool _isValidCard(
      String text,
      String? nationalId,
      ) {

    final lower =
        text.toLowerCase();

    int score = 0;


    if(lower.contains('egypt') ||
       lower.contains('arab') ||
       lower.contains('national')) {

      score++;

    }


    if(nationalId != null) {

      score++;

    }


    return score >= 2;

  }


  static String? _extractNationalId(
      String text) {

    final normalized =
        text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );


    final match =
        RegExp(r'[23]\d{13}')
            .firstMatch(normalized);


    return match?.group(0);

  }


  static String? _extractExpiryDate(
      String text) {

    final match =
        RegExp(
          r'\d{2}[\/\-]\d{2}[\/\-]\d{4}',
        ).firstMatch(text);


    return match?.group(0);

  }

}
