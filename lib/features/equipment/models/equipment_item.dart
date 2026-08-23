class EquipmentItem {
  final int id;
  final String name;
  final String status;
  final String assignedTo;

  const EquipmentItem({
    required this.id,
    required this.name,
    required this.status,
    required this.assignedTo,
  });

  factory EquipmentItem.fromMap(Map<String, dynamic> map) {
    return EquipmentItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['item_name'] as String? ?? '',
      status: map['status'] as String? ?? 'متاح',
      assignedTo: map['assigned_to'] as String? ?? 'المركز',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_name': name,
      'status': status,
      'assigned_to': assignedTo,
    };
  }
}
