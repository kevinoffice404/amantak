
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
