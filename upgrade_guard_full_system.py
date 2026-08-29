from pathlib import Path
import shutil
import datetime

ROOT = Path("lib")

print("=== Guard System Upgrade Started ===")

# إنشاء مجلد النسخ الاحتياطية
backup_dir = Path(
    "guard_upgrade_backup_" +
    datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
)

backup_dir.mkdir(exist_ok=True)

files_to_backup = [
    "lib/features/guards/guards_screen.dart",
    "lib/features/guards/edit_guard_screen.dart",
    "lib/features/guards/guard_details_screen.dart",
    "lib/features/guards/guard_records_screen.dart",
    "lib/core/services/firestore_service.dart",
]

for file in files_to_backup:
    src = Path(file)

    if src.exists():
        dst = backup_dir / src.name
        shutil.copy(src, dst)
        print("Backup:", file)

print("Backup completed:", backup_dir)


# إنشاء خدمة فحص البطاقة
scanner_file = Path(
    "lib/core/services/id_card_scanner_service.dart"
)

scanner_file.parent.mkdir(
    parents=True,
    exist_ok=True
)

scanner_code = r'''
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
'''

scanner_file.write_text(
    scanner_code,
    encoding="utf-8"
)

print("Created:", scanner_file)

print("=== Part 1 completed ===")

# =========================================================
# Part 2 : Replace edit_guard_screen.dart
# =========================================================

edit_file = Path(
    "lib/features/guards/edit_guard_screen.dart"
)

edit_code = r'''
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/database_helper.dart';


class EditGuardScreen extends StatefulWidget {

  final Map<String,dynamic> guard;

  const EditGuardScreen({
    super.key,
    required this.guard,
  });


  @override
  State<EditGuardScreen> createState()
      => _EditGuardScreenState();

}


class _EditGuardScreenState
    extends State<EditGuardScreen> {


  final picker = ImagePicker();

  final firestore =
      FirestoreService();


  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController nationalId;


  File? frontImage;
  File? backImage;


  DateTime? expiryDate;


  bool saving = false;


  @override
  void initState(){

    super.initState();


    name =
        TextEditingController(
          text:
          widget.guard['name'] ?? '',
        );


    phone =
        TextEditingController(
          text:
          widget.guard['phone'] ?? '',
        );


    nationalId =
        TextEditingController(
          text:
          widget.guard['national_id'] ?? '',
        );


    final expiry =
        widget.guard['id_expiry_date'];


    if(expiry != null &&
       expiry.toString().isNotEmpty){

      expiryDate =
          DateTime.tryParse(
            expiry.toString(),
          );

    }

  }



  Future<void> pickImage(
      bool front) async {


    final file =
        await picker.pickImage(
          source:
          ImageSource.camera,
          imageQuality: 80,
        );


    if(file == null)
      return;


    setState((){

      if(front){

        frontImage =
            File(file.path);

      }else{

        backImage =
            File(file.path);

      }

    });

  }



  String status(){

    if(expiryDate == null)
      return 'غير محددة';


    final now =
        DateTime.now();


    return expiryDate!
        .isBefore(now)
        ?
        'منتهية'
        :
        'سارية';

  }




  Future<void> save() async {


    setState((){

      saving=true;

    });


    try {


      String? frontUrl;
      String? backUrl;



      if(frontImage != null){

        frontUrl =
        await firestore.uploadGuardImage(
          guardId:
          widget.guard['id']
              .toString(),

          imageFile:
          frontImage!,

          isFront:true,
        );

      }


      if(backImage != null){

        backUrl =
        await firestore.uploadGuardImage(
          guardId:
          widget.guard['id']
              .toString(),

          imageFile:
          backImage!,

          isFront:false,
        );

      }



      await DatabaseHelper.instance
          .updateGuard({

        'id':
        widget.guard['id'],

        'name':
        name.text.trim(),

        'phone':
        phone.text.trim(),

        'national_id':
        nationalId.text.trim(),

        'id_expiry_date':
        expiryDate
            ?.toIso8601String()
            .split('T')
            .first,

        'id_status':
        status(),

        'id_front_image':
        frontImage?.path ??
        widget.guard['id_front_image'],

        'id_back_image':
        backImage?.path ??
        widget.guard['id_back_image'],

      });



      await firestore.updateGuard(

        guardId:
        widget.guard['id']
            .toString(),

        name:
        name.text.trim(),

        phone:
        phone.text.trim(),

        nationalId:
        nationalId.text.trim(),

        frontImageUrl:
        frontUrl,

        backImageUrl:
        backUrl,

        idExpiryDate:
        expiryDate
            ?.toIso8601String()
            .split('T')
            .first,

        idStatus:
        status(),

      );



      if(mounted){

        Navigator.pop(
          context,
          true,
        );

      }



    }catch(e){

      debugPrint(
        'Update guard error: $e',
      );


    }finally{


      if(mounted){

        setState((){

          saving=false;

        });

      }

    }

  }





  Widget imageBox(
      String title,
      bool front){

    return Column(

      children:[

        Text(
          title,
          style:
          const TextStyle(
            fontFamily:'Cairo',
            fontWeight:
            FontWeight.bold,
          ),
        ),


        const SizedBox(height:8),


        GestureDetector(

          onTap: saving
              ?
              null
              :
              ()=>pickImage(front),


          child:
          Container(

            height:120,

            width:160,


            decoration:
            BoxDecoration(

              borderRadius:
              BorderRadius.circular(15),

              border:
              Border.all(
                color:
                Colors.grey,
              ),

            ),


            child:
            Center(

              child:

              Icon(
                Icons.credit_card,
                size:45,
                color:
                Colors.blue,
              ),

            ),

          ),

        ),

      ],

    );

  }




  @override
  Widget build(
      BuildContext context){


    return Scaffold(

      appBar:
      AppBar(

        title:
        const Text(
          'تعديل بيانات الحارس',
          style:
          TextStyle(
            fontFamily:'Cairo',
          ),
        ),

      ),



      body:
      SingleChildScrollView(

        padding:
        const EdgeInsets.all(20),


        child:
        Column(

          children:[


            TextField(
              controller:name,
              decoration:
              const InputDecoration(
                labelText:'الاسم',
              ),
            ),


            TextField(
              controller:phone,
              decoration:
              const InputDecoration(
                labelText:'الهاتف',
              ),
            ),


            TextField(
              controller:nationalId,
              decoration:
              const InputDecoration(
                labelText:'الرقم القومي',
              ),
            ),


            const SizedBox(height:20),


            Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceAround,

              children:[

                imageBox(
                    'الأمامي',
                    true),

                imageBox(
                    'الخلفي',
                    false),

              ],

            ),


            const SizedBox(height:20),


            ElevatedButton(

              onPressed:
              saving
                  ?
              null
                  :
              save,


              child:
              Text(
                saving
                    ?
                'جارٍ الحفظ'
                    :
                'حفظ',

                style:
                const TextStyle(
                  fontFamily:'Cairo',
                ),

              ),

            )


          ],

        ),

      ),

    );


  }


}
'''


edit_file.write_text(
    edit_code,
    encoding="utf-8"
)


print(
    "Updated edit_guard_screen.dart"
)


# =========================================================
# Part 3 : Prepare guards_screen OCR migration
# =========================================================

guards_file = Path(
    "lib/features/guards/guards_screen.dart"
)

if guards_file.exists():

    text = guards_file.read_text(
        encoding="utf-8"
    )


    # إضافة import للخدمة الجديدة
    old_import = (
        "import '../../core/services/firestore_service.dart';"
    )

    new_import = (
        "import '../../core/services/firestore_service.dart';\n"
        "import '../../core/services/id_card_scanner_service.dart';"
    )


    if old_import in text and "id_card_scanner_service.dart" not in text:

        text = text.replace(
            old_import,
            new_import
        )


    # إضافة instance للخدمة
    old_instance = (
        "final FirestoreService _firestoreService = FirestoreService();"
    )

    new_instance = (
        "final FirestoreService _firestoreService = FirestoreService();\n"
        "final IdCardScannerService _idCardScannerService = IdCardScannerService();"
    )


    if old_instance in text and "_idCardScannerService" not in text:

        text = text.replace(
            old_instance,
            new_instance
        )


    guards_file.write_text(
        text,
        encoding="utf-8"
    )


    print(
        "guards_screen import prepared"
    )


else:

    print(
        "guards_screen.dart not found"
    )


print(
    "=== Part 3 completed ==="
)

print(
    "Now run flutter analyze from GitHub Actions"
)
