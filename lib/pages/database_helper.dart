import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:convert';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Table and column names
  static const String tableName = "my_table";
  static const String columnId = "id";
  static const String columnInfo = "information"; // client name
  static const String columnStatus = "status";    // draft, pending, approved, denied
  static const String columnFormData = "form_data"; // JSON string of form


  // -------------------------------
// CHAT TABLE (NEW)
// -------------------------------
  static const String chatTable = "chats";
  static const String chatAgentCode = "agent_code";
  static const String chatMessage = "message"; // JSON ARRAY STRING


  // Open database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("my_database.db");
    return _database!;
  }

  // Initialize DB
  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,                // 👈 bump version
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Create table (for fresh installs)
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnInfo TEXT,
        $columnStatus TEXT,
        $columnFormData TEXT
      )
    ''');

    await db.execute('''
  CREATE TABLE $chatTable (
    $chatAgentCode TEXT PRIMARY KEY,
    $chatMessage TEXT
  )
''');

  }

  // Upgrade (for existing installs)
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnStatus TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnFormData TEXT',
      );
    }
  }

  // ----------------------------------------------------------
  // INSERT CLIENT (with optional form data)
  // ----------------------------------------------------------
  Future<int> insertClient(String name, String status,
      {String? formData}) async {
    final db = await instance.database;

    return await db.insert(tableName, {
      columnInfo: name,
      columnStatus: status,
      columnFormData: formData,
    });
  }

  // Old simple insert (kept for compatibility if used elsewhere)
  Future<int> insertData(String info) async {
    final db = await instance.database;
    return await db.insert(tableName, {
      columnInfo: info,
      columnStatus: 'pending',
      columnFormData: null,
    });
  }

  // ----------------------------------------------------------
  // GET ALL DATA
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getData() async {
    final db = await instance.database;
    return await db.query(tableName, orderBy: '$columnId DESC');
  }

  // ----------------------------------------------------------
  // UPDATE NAME
  // ----------------------------------------------------------
  Future<int> updateData(int id, String newInfo) async {
    final db = await instance.database;

    return await db.update(
      tableName,
      {columnInfo: newInfo},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // ----------------------------------------------------------
  // UPDATE STATUS
  // ----------------------------------------------------------
  Future<int> updateStatus(int id, String newStatus) async {
    final db = await instance.database;

    return await db.update(
      tableName,
      {columnStatus: newStatus},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // ----------------------------------------------------------
  // UPDATE NAME + STATUS + FORM DATA (generic)
  // ----------------------------------------------------------
  Future<int> updateClient(int id,
      {String? name, String? status, String? formData}) async {
    final db = await instance.database;

    final Map<String, Object?> values = {};
    if (name != null) values[columnInfo] = name;
    if (status != null) values[columnStatus] = status;
    if (formData != null) values[columnFormData] = formData;

    if (values.isEmpty) return 0;

    return await db.update(
      tableName,
      values,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // ----------------------------------------------------------
  // DELETE
  // ----------------------------------------------------------
  Future<int> deleteData(int id) async {
    final db = await instance.database;

    return await db.delete(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }


// ----------------------------------------------------------
// INSERT OR UPDATE CHAT MESSAGE
// ----------------------------------------------------------
  Future<void> insertOrUpdateChat({
    required String agentCode,
    required Map<String, dynamic> messageData,
  }) async {
    final db = await instance.database;

    final result = await db.query(
      chatTable,
      where: '$chatAgentCode = ?',
      whereArgs: [agentCode],
    );

    if (result.isNotEmpty) {
      // Agent exists → append message
      List<dynamic> messages =
      jsonDecode(result.first[chatMessage] as String);

      messages.add(messageData);

      await db.update(
        chatTable,
        {chatMessage: jsonEncode(messages)},
        where: '$chatAgentCode = ?',
        whereArgs: [agentCode],
      );
    } else {
      // New agent → create chat
      await db.insert(chatTable, {
        chatAgentCode: agentCode,
        chatMessage: jsonEncode([messageData]),
      });
    }
  }

}
