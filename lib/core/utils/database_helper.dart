import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const _databaseName = 'security_manager.db';
  static const _databaseVersion = 3;

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
        id_front_image $textNullable,
        id_back_image $textNullable,
        id_expiry_date $textNullable,
        id_status $textNullable
      )
    ''');

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

    await _createIndexes(db);
  }

  Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE guards ADD COLUMN id_front_image TEXT',
      );
      await db.execute(
        'ALTER TABLE guards ADD COLUMN id_back_image TEXT',
      );
      await db.execute(
        'ALTER TABLE guards ADD COLUMN id_expiry_date TEXT',
      );
      await db.execute(
        'ALTER TABLE guards ADD COLUMN id_status TEXT',
      );
    }

    if (oldVersion < 3) {
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_guard_date '
      'ON attendance (guard_name, action_date, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_penalties_guard_date '
      'ON penalties (guard_name, date, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_equipment_status '
      'ON equipment (status)',
    );
  }

  // -------------------- Guards --------------------

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
          await db.rawQuery(
            'SELECT COUNT(*) FROM guards WHERE name = ?',
            [name],
          ),
        ) ??
        1;
    final imagePaths = <String>{
      if (guard['id_front_image'] is String) guard['id_front_image'] as String,
      if (guard['id_back_image'] is String) guard['id_back_image'] as String,
    };

    final deleted = await db.transaction<int>((txn) async {
      // Historical records are name-based in this schema. Only cascade them
      // when the name is unique; this avoids deleting another legacy record
      // if an old database contains duplicate names.
      if (sameNameCount == 1) {
        await txn.delete(
          'attendance',
          where: 'guard_name = ?',
          whereArgs: [name],
        );
        await txn.delete(
          'penalties',
          where: 'guard_name = ?',
          whereArgs: [name],
        );
        await txn.update(
          'equipment',
          {'assigned_to': 'المركز'},
          where: 'assigned_to = ?',
          whereArgs: [name],
        );
      }
      return txn.delete(
        'guards',
        where: 'id = ?',
        whereArgs: [id],
      );
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
      final updated = await txn.update(
        'guards',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );

      // Keep historical records linked when the guard's display name changes.
      final oldNameCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM guards WHERE name = ?',
              [oldName],
            ),
          ) ??
          1;

      if (updated > 0 && newName != oldName && oldNameCount == 1) {
        await txn.update(
          'attendance',
          {'guard_name': newName},
          where: 'guard_name = ?',
          whereArgs: [oldName],
        );
        await txn.update(
          'penalties',
          {'guard_name': newName},
          where: 'guard_name = ?',
          whereArgs: [oldName],
        );
        await txn.update(
          'equipment',
          {'assigned_to': newName},
          where: 'assigned_to = ?',
          whereArgs: [oldName],
        );
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
      ''',
      [today],
    );
  }

  // -------------------- Attendance --------------------

  Future<int> insertAttendance(Map<String, dynamic> record) async {
    final db = await database;
    return db.insert('attendance', record);
  }

  Future<List<Map<String, dynamic>>> getAllAttendance() async {
    final db = await database;
    return db.query('attendance', orderBy: 'action_date DESC, id DESC');
  }

  // -------------------- Penalties --------------------

  Future<int> insertPenalty(Map<String, dynamic> penalty) async {
    final db = await database;
    return db.insert('penalties', penalty);
  }

  Future<List<Map<String, dynamic>>> getAllPenalties() async {
    final db = await database;
    return db.query('penalties', orderBy: 'date DESC, id DESC');
  }

  // -------------------- Equipment --------------------

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

  // -------------------- Destructive reset --------------------

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
      } catch (_) {
        // A missing/unreadable image must not prevent the database operation.
      }
    }
  }
}
