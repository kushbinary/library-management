import 'dart:io';
import 'package:intl/intl.dart';
import '../models/student.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const _dbName = "library.db";
  static const _dbVersion = 1;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT NOT NULL,
            admissionDate TEXT NOT NULL,
            timing TEXT NOT NULL,
            seatNumber TEXT NOT NULL,
            expiryDate TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Add a new student
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get all students
  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) {
      return Student.fromJson(maps[i]);
    });
  }

  // Get students with expired memberships
  Future<List<Student>> getExpiredStudents() async {
    final db = await database;
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'expiryDate <= ?',
      whereArgs: [now],
    );
    return List.generate(maps.length, (i) {
      return Student.fromJson(maps[i]);
    });
  }

  // Update a student
  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update('students', student.toJson(),
        where: 'id = ?', whereArgs: [student.id]);
  }

  // Delete a student
  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}