import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'task.dart';
import 'task_completion_history.dart';
import 'task_daily_log.dart';
import 'reminder.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dailytask.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Create Tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        displayOrder INTEGER NOT NULL DEFAULT 0,
        colorHex TEXT NOT NULL DEFAULT '#8B5CF6'
      )
    ''');

    // 2. Create Task History table (corresponds to task_history from Room)
    await db.execute('''
      CREATE TABLE task_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        completedCount INTEGER NOT NULL,
        totalCount INTEGER NOT NULL
      )
    ''');

    // 3. Create Task Daily Log table
    await db.execute('''
      CREATE TABLE task_daily_log (
        date TEXT NOT NULL,
        taskId INTEGER NOT NULL,
        taskTitle TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        colorHex TEXT NOT NULL,
        PRIMARY KEY (date, taskId)
      )
    ''');

    // 4. Create Reminders table
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        colorHex TEXT NOT NULL DEFAULT '#8B5CF6'
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          colorHex TEXT NOT NULL DEFAULT '#8B5CF6'
        )
      ''');
    }
  }

  // ── Tasks CRUD ──
  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks', orderBy: 'displayOrder ASC');
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    // Find max displayOrder
    final result = await db.rawQuery('SELECT MAX(displayOrder) as maxOrder FROM tasks');
    final maxOrder = (result.first['maxOrder'] as int?) ?? 0;
    
    final newTask = task.copyWith(displayOrder: maxOrder + 1);
    return await db.insert('tasks', newTask.toMap());
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> resetAllTasksCompletion() async {
    final db = await database;
    return await db.update(
      'tasks',
      {'isCompleted': 0},
    );
  }

  // ── History CRUD ──
  Future<List<TaskCompletionHistory>> getAllHistory() async {
    final db = await database;
    final result = await db.query('task_history', orderBy: 'date ASC');
    return result.map((map) => TaskCompletionHistory.fromMap(map)).toList();
  }

  Future<int> insertHistory(TaskCompletionHistory history) async {
    final db = await database;
    return await db.insert(
      'task_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteAllHistory() async {
    final db = await database;
    return await db.delete('task_history');
  }

  // ── Daily Log CRUD ──
  Future<List<TaskDailyLog>> getAllDailyLogs() async {
    final db = await database;
    final result = await db.query('task_daily_log', orderBy: 'date ASC');
    return result.map((map) => TaskDailyLog.fromMap(map)).toList();
  }

  Future<List<TaskDailyLog>> getDailyLogsForDate(String date) async {
    final db = await database;
    final result = await db.query(
      'task_daily_log',
      where: 'date = ?',
      whereArgs: [date],
    );
    return result.map((map) => TaskDailyLog.fromMap(map)).toList();
  }

  Future<void> insertDailyLogs(List<TaskDailyLog> logs) async {
    final db = await database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert(
        'task_daily_log',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteAllDailyLogs() async {
    final db = await database;
    return await db.delete('task_daily_log');
  }

  // ── Reminders CRUD ──
  Future<List<Reminder>> getActiveReminders() async {
    final db = await database;
    final result = await db.query(
      'reminders',
      where: 'isCompleted = ?',
      whereArgs: [0],
      orderBy: 'id DESC',
    );
    return result.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<String>> getReminderSuggestions() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT title FROM reminders');
    return result.map((row) => row['title'] as String).toList();
  }

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
