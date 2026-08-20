import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../models/membership_plan.dart';
import '../models/payment.dart';
import '../models/attendance.dart';
import '../models/expense.dart';
import '../models/seat.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const _dbName = "mylibbook_v2.db";
  static const _dbVersion = 2;

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
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        whatsapp TEXT,
        email TEXT,
        address TEXT,
        joining_date TEXT NOT NULL,
        plan_id TEXT,
        start_date TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        seat_number TEXT,
        status TEXT,
        notes TEXT,
        profile_photo TEXT,
        total_fee REAL,
        paid_amount REAL,
        due_amount REAL,
        timing TEXT,
        payment_mode TEXT,
        payment_status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE membership_plans (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        duration_days INTEGER NOT NULL,
        price REAL NOT NULL,
        late_fine REAL,
        grace_period_days INTEGER,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        member_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        method TEXT,
        type TEXT,
        status TEXT,
        transaction_id TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        member_id TEXT NOT NULL,
        date TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        check_out_time TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_method TEXT,
        description TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE seats (
        id TEXT PRIMARY KEY,
        seat_number TEXT NOT NULL,
        status TEXT,
        assigned_member_id TEXT
      )
    ''');

    // Run migration after creating tables
    await _migrateOldData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE members ADD COLUMN timing TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE members ADD COLUMN payment_mode TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE members ADD COLUMN payment_status TEXT'); } catch (_) {}
    }
  }

  Future<void> _migrateOldData(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    final bool migrated = prefs.getBool('data_migrated_v2') ?? false;
    
    if (migrated) return;

    final user = prefs.getString('current_logged_in_user') ?? 'admin';
    final key = 'library_students_user_${user.toLowerCase().trim()}';
    
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> oldStudents = json.decode(raw);
        for (var item in oldStudents) {
          final member = Member.fromJson(item);
          await db.insert('members', member.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        print("Migration error: $e");
      }
    }
    
    await prefs.setBool('data_migrated_v2', true);
  }

  // ---- MEMBER OPERATIONS ----
  Future<int> insertMember(Member member) async {
    final db = await database;
    return await db.insert('members', member.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Member>> getAllMembers() async {
    final db = await database;
    final maps = await db.query('members');
    return maps.map((e) => Member.fromJson(e)).toList();
  }

  Future<int> updateMember(Member member) async {
    final db = await database;
    return await db.update('members', member.toJson(), where: 'id = ?', whereArgs: [member.id]);
  }

  Future<int> deleteMember(String id) async {
    final db = await database;
    return await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  // ---- MEMBERSHIP PLAN OPERATIONS ----
  Future<int> insertMembershipPlan(MembershipPlan plan) async {
    final db = await database;
    return await db.insert('membership_plans', plan.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MembershipPlan>> getAllMembershipPlans() async {
    final db = await database;
    final maps = await db.query('membership_plans');
    return maps.map((e) => MembershipPlan.fromJson(e)).toList();
  }

  // ---- PAYMENT OPERATIONS ----
  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    return await db.insert('payments', payment.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final maps = await db.query('payments');
    return maps.map((e) => Payment.fromJson(e)).toList();
  }
  
  Future<List<Payment>> getPaymentsForMember(String memberId) async {
    final db = await database;
    final maps = await db.query('payments', where: 'member_id = ?', whereArgs: [memberId]);
    return maps.map((e) => Payment.fromJson(e)).toList();
  }

  // ---- ATTENDANCE OPERATIONS ----
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert('attendance', attendance.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Attendance>> getAttendanceByDate(String date) async {
    final db = await database;
    final maps = await db.query('attendance', where: 'date = ?', whereArgs: [date]);
    return maps.map((e) => Attendance.fromJson(e)).toList();
  }

  // ---- EXPENSE OPERATIONS ----
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final maps = await db.query('expenses');
    return maps.map((e) => Expense.fromJson(e)).toList();
  }

  // ---- SEAT OPERATIONS ----
  Future<int> insertSeat(Seat seat) async {
    final db = await database;
    return await db.insert('seats', seat.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Seat>> getAllSeats() async {
    final db = await database;
    final maps = await db.query('seats');
    return maps.map((e) => Seat.fromJson(e)).toList();
  }
  
  Future<int> updateSeat(Seat seat) async {
    final db = await database;
    return await db.update('seats', seat.toJson(), where: 'id = ?', whereArgs: [seat.id]);
  }
}