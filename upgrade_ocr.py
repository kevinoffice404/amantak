from pathlib import Path
import shutil
import re

file = Path("lib/features/guards/guards_screen.dart")

if not file.exists():
    print("File not found")
    exit()

backup = Path("lib/features/guards/guards_screen_before_ocr_upgrade.dart")

shutil.copy(file, backup)

code = file.read_text(encoding="utf-8")


# 1- إضافة استخراج الاسم بعد _extractNationalId
marker = """  DateTime? _extractExpiryDate(
"""

new_functions = r'''
  String? _extractName(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final ignored = [
      'جمهورية',
      'العربية',
      'مصر',
      'بطاقة',
      'شخصية',
      'الرقم',
      'القومي',
      'تاريخ',
      'ميلاد',
      'انتهاء',
      'وزارة',
      'الداخلية'
    ];

    for (final line in lines) {
      if (line.length < 8) continue;

      if (RegExp(r'[0-9]').hasMatch(line)) {
        continue;
      }

      bool bad = false;

      for (final word in ignored) {
        if (line.contains(word)) {
          bad = true;
        }
      }

      if (!bad) {
        return line;
      }
    }

    return null;
  }


  bool _isValidIdCard(String text) {
    final id = _extractNationalId(text);

    final hasArabic =
        RegExp(r'[\u0600-\u06FF]')
            .hasMatch(text);

    return id != null || hasArabic;
  }


'''

if "_extractName(" not in code:
    code = code.replace(marker, new_functions + marker)


# 2- تعديل تحليل الصورة لإضافة التحقق والاسم

old = """
                  if (isFront) {
                    final id =
                        _extractNationalId(
                      recognizedText.text,
                    );

                    if (id != null) {
                      nationalIdController.text =
                          id;
                    }
                  } else {
"""

new = """
                  final ocrText =
                      recognizedText.text;


                  if (!_isValidIdCard(ocrText)) {
                    _showMessage(
                      'الصورة لا تبدو بطاقة شخصية، يرجى إعادة التصوير.',
                      Colors.red,
                    );
                    return;
                  }


                  if (isFront) {

                    final id =
                        _extractNationalId(
                      ocrText,
                    );

                    if (id != null) {
                      nationalIdController.text =
                          id;
                    }


                    final extractedName =
                        _extractName(
                      ocrText,
                    );

                    if (extractedName != null &&
                        nameController.text.trim().isEmpty) {

                      nameController.text =
                          extractedName;
                    }

                  } else {
"""

if old in code:
    code = code.replace(old, new)
else:
    print("OCR block not found - only functions added")


file.write_text(code, encoding="utf-8")

print("OCR upgrade completed successfully")
print("Backup created:")
print(backup)
