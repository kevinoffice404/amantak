import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const _databaseName = 'security_manager.db';
  // الإصدار 5 يضيف الرقم القومي وسجل حركة العهد ويحسن الفهارس.
  static const _databaseVersion = 5;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB(_databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE guards (
        id $idType,
        name $textType,
        phone $textType,
        role $textType,
        national_id $textNullable,
        id_front_image $textNullable,
        id_back_image $textNullable,
        id_expiry_date $textNullable,
        id_status $textNullable,
        basic_salary REAL DEFAULT 9000.0 
      )
    '''); // تمت إضافة basic_salary هنا

    await db.execute('''
      CREATE TABLE attendance (
        id $idType,
        guard_name $textType,
        action_type $textType,
        action_time $textType,
        action_date $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE equipment (
        id $idType,
        item_name $textType,
        status $textType,
        assigned_to $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE penalties (
        id $idType,
        guard_name $textType,
        reason $textType,
        amount $textType,
        date $textType
      )
    ''');

    // جدول السلف
    await db.execute('''
      CREATE TABLE advances (
        id $idType,
        guard_name $textType,
        amount $textType,
        date $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE equipment_history (
        id $idType,
        equipment_id INTEGER NOT NULL,
        guard_name $textType,
        action $textType,
        action_time $textType
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE guards ADD COLUMN id_front_image TEXT');
      await db.execute('ALTER TABLE guards ADD COLUMN id_back_image TEXT');
      await db.execute('ALTER TABLE guards ADD COLUMN id_expiry_date TEXT');
      await db.execute('ALTER TABLE guards ADD COLUMN id_status TEXT');
    }


    // 🚨 التحديث الجديد للإصدار 4 (إضافة السلف والراتب) 🚨
    if (oldVersion < 4) {
      // إضافة الراتب للجدول القديم
      await db.execute('ALTER TABLE guards ADD COLUMN basic_salary REAL DEFAULT 9000.0');
      
      // إنشاء جدول السلف
      await db.execute('''
        CREATE TABLE advances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          guard_name TEXT NOT NULL,
          amount TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_advances_guard_date '
        'ON advances (guard_name, date, id)',
      );
    }


    if (oldVersion < 5) {
      await db.execute('ALTER TABLE guards ADD COLUMN national_id TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS equipment_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          equipment_id INTEGER NOT NULL,
          guard_name TEXT NOT NULL,
          action TEXT NOT NULL,
          action_time TEXT NOT NULL
        )
      ''');
    }

    // ضمان إنشاء جميع الفهارس حتى عند الترقية من إصدارات قديمة.
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_guard_date '
      'ON attendance (guard_name, action_date, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_date_type_guard '
      'ON attendance (action_date, action_type, guard_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_penalties_guard_date '
      'ON penalties (guard_name, date, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_advances_guard_date '
      'ON advances (guard_name, date, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_equipment_status '
      'ON equipment (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_equipment_history_equipment '
      'ON equipment_history (equipment_id, id)',
    );
  }

  // -------------------- Guards (الحراس) --------------------

  Future<int> insertGuard(Map<String, dynamic> guard) async {
    final db = await database;
    return db.insert('guards', guard);
  }

  Future<List<Map<String, dynamic>>> getAllGuards() async {
    final db = await database;
    await refreshExpiredIdStatuses();
    return db.query('guards', orderBy: 'name COLLATE NOCASE ASC, id ASC');
  }

  Future<int> deleteGuard(int id) async {
    final db = await database;

    final existing = await db.query(
      'guards',
      columns: ['name', 'id_front_image', 'id_back_image'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isEmpty) return 0;

    final guard = existing.first;
    final name = guard['name'] as String;
    final sameNameCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM guards WHERE name = ?', [name]),
        ) ?? 1;
    
    final imagePaths = <String>{
      if (guard['id_front_image'] is String) guard['id_front_image'] as String,
      if (guard['id_back_image'] is String) guard['id_back_image'] as String,
    };

    final deleted = await db.transaction<int>((txn) async {
      if (sameNameCount == 1) {
        await txn.delete('attendance', where: 'guard_name = ?', whereArgs: [name]);
        await txn.delete('penalties', where: 'guard_name = ?', whereArgs: [name]);
        await txn.delete('advances', where: 'guard_name = ?', whereArgs: [name]); // مسح السلف
        await txn.update('equipment', {'assigned_to': 'المركز'}, where: 'assigned_to = ?', whereArgs: [name]);
      }
      return txn.delete('guards', where: 'id = ?', whereArgs: [id]);
    });

    if (deleted > 0) {
      await _deleteFiles(imagePaths);
    }
    return deleted;
  }

  Future<int> updateGuard(Map<String, dynamic> guard) async {
    final db = await database;
    final id = guard['id'];

    if (id == null) {
      throw ArgumentError('updateGuard requires a guard id.');
    }

    final existing = await db.query(
      'guards',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isEmpty) return 0;

    final oldName = existing.first['name'] as String;
    final values = Map<String, dynamic>.from(guard)..remove('id');
    final newName = values['name'] as String? ?? oldName;

    return db.transaction<int>((txn) async {
      final updated = await txn.update('guards', values, where: 'id = ?', whereArgs: [id]);

      final oldNameCount = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM guards WHERE name = ?', [oldName]),
          ) ?? 1;

      if (updated > 0 && newName != oldName && oldNameCount == 1) {
        await txn.update('attendance', {'guard_name': newName}, where: 'guard_name = ?', whereArgs: [oldName]);
        await txn.update('penalties', {'guard_name': newName}, where: 'guard_name = ?', whereArgs: [oldName]);
        await txn.update('advances', {'guard_name': newName}, where: 'guard_name = ?', whereArgs: [oldName]); // تحديث اسم الحارس في السلف
        await txn.update('equipment', {'assigned_to': newName}, where: 'assigned_to = ?', whereArgs: [oldName]);
      }
      return updated;
    });
  }

  Future<void> refreshExpiredIdStatuses() async {
    final db = await database;
    final today = _dateOnly(DateTime.now());

    await db.rawUpdate(
      '''
      UPDATE guards
      SET id_status = CASE
        WHEN id_expiry_date < ? THEN 'منتهية'
        ELSE 'سارية'
      END
      WHERE id_expiry_date IS NOT NULL
        AND id_expiry_date != ''
        AND COALESCE(id_status, '') != CASE
          WHEN id_expiry_date < ? THEN 'منتهية'
          ELSE 'سارية'
        END
      ''',
      [today, today],
    );
  }

  // -------------------- Financials (الراتب والسلف والجزاءات) --------------------

  // 1. تحديث الراتب الأساسي
  Future<int> updateGuardSalary(int id, double newSalary) async {
    final db = await database;
    return db.update(
      'guards',
      {'basic_salary': newSalary},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 2. تسجيل سلفة جديدة
  Future<int> insertAdvance(Map<String, dynamic> advance) async {
    final db = await database;
    return db.insert('advances', advance);
  }

  // 3. جلب جميع البيانات المالية للحارس (لخصمها من الراتب)
  Future<Map<String, double>> getGuardFinancialTotals(String guardName) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE((SELECT SUM(CAST(amount AS REAL)) FROM penalties WHERE guard_name = ?), 0) AS total_penalties,
        COALESCE((SELECT SUM(CAST(amount AS REAL)) FROM advances WHERE guard_name = ?), 0) AS total_advances
      ''',
      [guardName, guardName],
    );

    final row = rows.first;
    return {
      'total_penalties': (row['total_penalties'] as num?)?.toDouble() ?? 0.0,
      'total_advances': (row['total_advances'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// يجلب الإجماليات المالية لكل الأفراد باستعلامين فقط بدلاً من N+1.
  Future<Map<String, Map<String, double>>> getAllFinancialTotals() async {
    final db = await database;
    final result = <String, Map<String, double>>{};

    final penalties = await db.rawQuery(
      'SELECT guard_name, COALESCE(SUM(CAST(amount AS REAL)), 0) AS total FROM penalties GROUP BY guard_name',
    );
    for (final row in penalties) {
      final name = row['guard_name']?.toString() ?? '';
      result.putIfAbsent(name, () => {'total_penalties': 0.0, 'total_advances': 0.0});
      result[name]!['total_penalties'] = (row['total'] as num?)?.toDouble() ?? 0.0;
    }

    final advances = await db.rawQuery(
      'SELECT guard_name, COALESCE(SUM(CAST(amount AS REAL)), 0) AS total FROM advances GROUP BY guard_name',
    );
    for (final row in advances) {
      final name = row['guard_name']?.toString() ?? '';
      result.putIfAbsent(name, () => {'total_penalties': 0.0, 'total_advances': 0.0});
      result[name]!['total_advances'] = (row['total'] as num?)?.toDouble() ?? 0.0;
    }

    return result;
  }

  // -------------------- Smart Alerts (التنبيهات الذكية) --------------------
  
  // دالة لجلب قائمة بالتنبيهات الذكية (مالية وإدارية)
  Future<List<Map<String, String>>> getSmartAlerts() async {
    final db = await database;
    List<Map<String, String>> alerts = [];
    final today = DateTime.now();

    final guards = await db.query('guards');
    final financialTotals = await getAllFinancialTotals();
    for (var guard in guards) {
      String name = guard['name'].toString();
      
      // 1. تنبيهات البطاقات المنتهية أو التي ستنتهي قريباً
      String? expiryDateStr = guard['id_expiry_date']?.toString();
      if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
        DateTime? expiryDate = DateTime.tryParse(expiryDateStr);
        if (expiryDate != null) {
          // حساب الفرق بالأيام بين تاريخ اليوم وتاريخ الانتهاء
          final difference = DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
              .difference(DateTime(today.year, today.month, today.day))
              .inDays;
          
          if (difference < 0) {
            alerts.add({
              'title': 'بطاقة منتهية',
              'message': 'بطاقة الحارس ($name) منتهية منذ ${difference.abs()} يوم.',
              'type': 'danger', // لون أحمر
            });
          } else if (difference <= 15) { // إذا تبقى 15 يوم أو أقل
            alerts.add({
              'title': 'تجديد بطاقة',
              'message': 'بطاقة الحارس ($name) ستنتهي قريباً بعد $difference يوم.',
              'type': 'warning', // لون برتقالي
            });
          }
        }
      }

      // 2. تنبيهات مالية (سلف تتجاوز 50% من الراتب)
      double basicSalary = guard['basic_salary'] != null 
          ? double.tryParse(guard['basic_salary'].toString()) ?? 9000.0 
          : 9000.0;
          
      final totals = financialTotals[name];
      double totalAdvances = totals?['total_advances'] ?? 0.0;
      
      if (totalAdvances > (basicSalary / 2)) {
        alerts.add({
          'title': 'تجاوز الحد المالي للسلف',
          'message': 'الحارس ($name) سحب سلف بقيمة ${totalAdvances.toStringAsFixed(0)} ج.م (أكثر من نصف راتبه الأساسي).',
          'type': 'warning',
        });
      }
    }

    return alerts;
  }

  // -------------------- Attendance (الحضور والانصراف) --------------------
  
  Future<int> insertAttendance(Map<String, dynamic> record) async {
    final db = await database;
    return db.insert('attendance', record);
  }

  Future<List<Map<String, dynamic>>> getAllAttendance() async {
    final db = await database;
    return db.query('attendance', orderBy: 'action_date DESC, id DESC');
  }

  // -------------------- Penalties (الجزاءات) --------------------
  
  Future<int> insertPenalty(Map<String, dynamic> penalty) async {
    final db = await database;
    return db.insert('penalties', penalty);
  }

  Future<List<Map<String, dynamic>>> getAllPenalties() async {
    final db = await database;
    return db.query('penalties', orderBy: 'date DESC, id DESC');
  }

  // -------------------- Equipment (العهد) --------------------
  
  Future<int> insertEquipment(Map<String, dynamic> equipment) async {
    final db = await database;
    return db.insert('equipment', equipment);
  }

  Future<List<Map<String, dynamic>>> getAllEquipment() async {
    final db = await database;
    return db.query('equipment', orderBy: 'id DESC');
  }

  Future<int> updateEquipmentStatus(int id, String status) async {
    final db = await database;
    return db.update(
      'equipment',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------- Destructive reset (مسح البيانات) --------------------
  
  Future<void> clearAllData() async {
    final db = await database;

    final guards = await db.query(
      'guards',
      columns: ['id_front_image', 'id_back_image'],
    );

    final imagePaths = <String>{};
    for (final guard in guards) {
      final front = guard['id_front_image'];
      final back = guard['id_back_image'];
      if (front is String && front.isNotEmpty) imagePaths.add(front);
      if (back is String && back.isNotEmpty) imagePaths.add(back);
    }

    await db.transaction((txn) async {
      await txn.delete('attendance');
      await txn.delete('equipment');
      await txn.delete('penalties');
      await txn.delete('advances'); // تفريغ جدول السلف
      await txn.delete('equipment_history');
      await txn.delete('guards');
    });

    await _deleteFiles(imagePaths);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  static String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }
}
