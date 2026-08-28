from pathlib import Path
import shutil

details = Path("lib/features/guards/guard_details_screen.dart")
edit_file = Path("lib/features/guards/edit_guard_screen.dart")

if not details.exists():
    print("guard_details_screen.dart not found")
    exit()

backup = Path("lib/features/guards/guard_details_before_records_edit.dart")
shutil.copy(details, backup)

code = details.read_text(encoding="utf-8")


# إضافة imports
old_import = "import 'financial_details_screen.dart';"

new_import = """import 'financial_details_screen.dart';
import 'guard_records_screen.dart';
import 'edit_guard_screen.dart';"""

if "guard_records_screen.dart" not in code:
    code = code.replace(old_import, new_import)


# إضافة الأزرار قبل نهاية SizedBox الأخير
marker = """
            const SizedBox(height: 30),
          ],
        ),
"""

buttons = r'''
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text(
                  'سجل الحضور والانصراف والجزاءات',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuardRecordsScreen(
                        guardName: name,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_rounded),
                label: const Text(
                  'تعديل بيانات الحارس',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditGuardScreen(
                        guard: person,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
'''

if "تعديل بيانات الحارس" not in code:
    code = code.replace(marker, buttons + """          ],
        ),
""")


details.write_text(code, encoding="utf-8")


# إنشاء شاشة التعديل
edit_code = r'''
import 'package:flutter/material.dart';

import '../../core/utils/database_helper.dart';
import '../../core/theme/app_colors.dart';


class EditGuardScreen extends StatefulWidget {

  final Map<String,dynamic> guard;

  const EditGuardScreen({
    super.key,
    required this.guard,
  });


  @override
  State<EditGuardScreen> createState()=>_EditGuardScreenState();

}


class _EditGuardScreenState extends State<EditGuardScreen>{

late TextEditingController name;
late TextEditingController phone;
late TextEditingController nationalId;


@override
void initState(){

super.initState();

name = TextEditingController(
text: widget.guard['name'] ?? ''
);

phone = TextEditingController(
text: widget.guard['phone'] ?? ''
);

nationalId = TextEditingController(
text: widget.guard['national_id'] ?? ''
);

}



Future<void> save() async {

await DatabaseHelper.instance.updateGuard({

'id': widget.guard['id'],

'name': name.text.trim(),

'phone': phone.text.trim(),

'national_id': nationalId.text.trim(),

'role': widget.guard['role'],

'id_front_image':
widget.guard['id_front_image'],

'id_back_image':
widget.guard['id_back_image'],

'id_expiry_date':
widget.guard['id_expiry_date'],

'id_status':
widget.guard['id_status'],

'basic_salary':
widget.guard['basic_salary'] ?? 9000,

});


if(mounted){

Navigator.pop(context,true);

}

}


@override
Widget build(BuildContext context){

return Scaffold(

appBar: AppBar(
title: const Text(
'تعديل بيانات الحارس',
style: TextStyle(fontFamily:'Cairo'),
),
),

body: Padding(

padding: const EdgeInsets.all(20),

child: Column(

children:[

TextField(
controller:name,
decoration:const InputDecoration(
labelText:'الاسم',
),
),

TextField(
controller:phone,
decoration:const InputDecoration(
labelText:'الهاتف',
),
),

TextField(
controller:nationalId,
decoration:const InputDecoration(
labelText:'الرقم القومي',
),
),

const SizedBox(height:30),

ElevatedButton(

onPressed:save,

child:const Text(
'حفظ',
style:TextStyle(fontFamily:'Cairo'),
),

)

],

),

),

);

}

}
'''

if not edit_file.exists():
    edit_file.write_text(edit_code, encoding="utf-8")


print("Guard features added successfully")
print("Backup:")
print(backup)
