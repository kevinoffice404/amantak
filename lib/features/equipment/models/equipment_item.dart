// لاحظ هنا: قمنا بتغيير حرف C الكبير إلى c صغير
class EquipmentItem {
  // تعريف خصائص الجهاز (رقم، اسم، حالة، واسم المستلم)
  final int id;
  final String name;
  final String status;
  final String assignedTo;

  // المُنشئ (Constructor): يطلب هذه البيانات عند إنشاء جهاز جديد
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.status,
    required this.assignedTo,
  });

  // دالة مصنع (Factory): تأخذ البيانات الخام (Map) القادمة من قاعدة البيانات 
  // وتحولها إلى كائن (Object) منظم ويسهل استخدامه.
  factory EquipmentItem.fromMap(Map<String, dynamic> map) {
    return EquipmentItem(
      // تحويل الرقم بأمان، وإذا كان فارغاً نضع 0
      id: (map['id'] as num?)?.toInt() ?? 0,
      // جلب الاسم، وإذا كان فارغاً نضع نصاً فارغاً
      name: map['item_name'] as String? ?? '',
      // جلب الحالة، وإذا كانت غير موجودة نعتبرها "متاح" افتراضياً
      status: map['status'] as String? ?? 'متاح',
      // جلب اسم المستلم، والوضع الافتراضي هو "المركز"
      assignedTo: map['assigned_to'] as String? ?? 'المركز',
    );
  }

  // دالة التحويل (toMap): تأخذ بيانات الكائن المنظمة
  // وتحولها إلى شكل (Map) لكي يسهل حفظها داخل قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_name': name,
      'status': status,
      'assigned_to': assignedTo,
    };
  }
}
