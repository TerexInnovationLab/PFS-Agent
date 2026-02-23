import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// Simple model for one digital registration.
/// We store the actual form in [data] as JSON.
class DigitalRegistration {
  int? id;
  String status; // "draft" or "pending" (and later maybe "approved", "rejected", etc.)
  Map<String, dynamic> data;
  String? reason; // bounce reason
  DateTime createdAt;
  DateTime updatedAt;

  DigitalRegistration({
    this.id,
    required this.status,
    required this.data,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'data': jsonEncode(data),
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DigitalRegistration.fromMap(Map<String, dynamic> map) {
    return DigitalRegistration(
      id: map['id'] as int?,
      status: map['status'] as String,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      reason: map['reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Singleton DB helper
class DigitalRegistrationDb {
  DigitalRegistrationDb._();
  static final DigitalRegistrationDb instance = DigitalRegistrationDb._();

  static const _dbName = 'pinnacle_registrations.db';
  static const _dbVersion = 2;
  static const _table = 'digital_registrations';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    return await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            status TEXT NOT NULL,
            data TEXT NOT NULL,
            reason TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN reason TEXT');
        }
      },
    );
  }

  Future<int> upsert(DigitalRegistration reg) async {
    final db = await database;
    final map = reg.toMap();

    if (reg.id == null) {
      // INSERT
      return await db.insert(
        _table,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // UPDATE
      await db.update(
        _table,
        map,
        where: 'id = ?',
        whereArgs: [reg.id],
      );
      return reg.id!;
    }
  }

  /// Latest draft (for resuming)
  Future<DigitalRegistration?> getLatestDraft() async {
    final db = await database;
    final res = await db.query(
      _table,
      where: 'status = ?',
      whereArgs: ['draft'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    return DigitalRegistration.fromMap(res.first);
  }

  /// Update status only (e.g. draft -> pending)
  Future<void> updateStatus(int id, String status) async {
    final db = await database;
    await db.update(
      _table,
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateReason(int id, String reason) async {
    final db = await database;
    await db.update(
      _table,
      {
        'reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all registrations (for "My Clients" page later)
  Future<List<DigitalRegistration>> getAll() async {
    final db = await database;
    final res = await db.query(
      _table,
      orderBy: 'created_at DESC',
    );
    return res.map((e) => DigitalRegistration.fromMap(e)).toList();
  }
}
