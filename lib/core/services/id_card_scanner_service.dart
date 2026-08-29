
import 'dart:io';

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class IdCardScannerService {

  Future<File?> scanIdCard() async {

    try {

      final scanner =
          DocumentScanner(
            options: DocumentScannerOptions(
              documentFormat:
                  DocumentFormat.jpeg,
              mode:
                  ScannerMode.full,
              pageLimit: 2,
            ),
          );


      final result =
          await scanner.scanDocument();


      if (result.images.isEmpty) {
        return null;
      }


      return File(
        result.images.first,
      );


    } catch (e) {

      return null;

    }

  }

}
