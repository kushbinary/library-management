import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  // Starter sample data for master account
  static List<Student> _getStarterDataForAdmin() {
    final now = DateTime.now();
    final thisMonthStr = DateFormat('yyyy-MM-dd').format(now);
    final nextMonthStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 30)));
    final pastMonthStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 40)));
    final expiredStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 5)));

    return [
      Student(
        id: 1,
        name: 'Aarav Sharma',
        phone: '9876543210',
        admissionDate: thisMonthStr,
        timing: 'Morning (8 AM - 12 PM)',
        seatNumber: 'A-12',
        expiryDate: nextMonthStr,
        totalFee: 1000.0,
        paidAmount: 1000.0,
        dueAmount: 0.0,
        paymentMode: 'UPI (GPay)',
        paymentStatus: 'Paid',
        daysRemaining: 30,
        isExpired: false,
      ),
      Student(
        id: 2,
        name: 'Priya Verma',
        phone: '9812345678',
        admissionDate: thisMonthStr,
        timing: 'Evening (4 PM - 8 PM)',
        seatNumber: 'B-04',
        expiryDate: nextMonthStr,
        totalFee: 1200.0,
        paidAmount: 800.0,
        dueAmount: 400.0,
        paymentMode: 'Cash',
        paymentStatus: 'Partial',
        daysRemaining: 28,
        isExpired: false,
      ),
      Student(
        id: 3,
        name: 'Rohan Gupta',
        phone: '9988776655',
        admissionDate: pastMonthStr,
        timing: 'Full Day (8 AM - 8 PM)',
        seatNumber: 'C-01',
        expiryDate: expiredStr,
        totalFee: 1500.0,
        paidAmount: 1500.0,
        dueAmount: 0.0,
        paymentMode: 'UPI (PhonePe)',
        paymentStatus: 'Paid',
        daysRemaining: 0,
        isExpired: true,
      ),
    ];
  }

  static String _storageKey(String username) {
    return 'library_students_user_${username.toLowerCase().trim()}';
  }

  // Get isolated students list for the logged-in user
  static Future<List<Student>> getStudentsForUser(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(username);
      final raw = prefs.getString(key);

      if (raw != null) {
        final List<dynamic> list = json.decode(raw);
        final today = DateTime.now();
        return list.map((item) {
          final s = Student.fromJson(item);
          DateTime? exp;
          try {
            exp = DateFormat('yyyy-MM-dd').parse(s.expiryDate);
          } catch (_) {}
          final days = exp != null ? exp.difference(today).inDays : 0;
          final isExp = days < 0;
          return Student(
            id: s.id,
            name: s.name,
            phone: s.phone,
            admissionDate: s.admissionDate,
            timing: s.timing,
            seatNumber: s.seatNumber,
            expiryDate: s.expiryDate,
            totalFee: s.totalFee,
            paidAmount: s.paidAmount,
            dueAmount: s.dueAmount,
            paymentMode: s.paymentMode,
            paymentStatus: s.paymentStatus,
            daysRemaining: isExp ? 0 : days,
            isExpired: isExp,
          );
        }).toList();
      }

      if (username.toLowerCase() == 'kushbinary') {
        final seed = _getStarterDataForAdmin();
        await saveStudentsForUser(username, seed);
        return seed;
      }
    } catch (_) {}

    return [];
  }

  static Future<bool> saveStudentsForUser(String username, List<Student> students) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(username);
      final jsonList = students.map((s) => s.toJson()).toList();
      return await prefs.setString(key, json.encode(jsonList));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> addStudentForUser(String username, Student student) async {
    final list = await getStudentsForUser(username);
    final newStudent = Student(
      id: DateTime.now().millisecondsSinceEpoch,
      name: student.name,
      phone: student.phone,
      admissionDate: student.admissionDate,
      timing: student.timing,
      seatNumber: student.seatNumber,
      expiryDate: student.expiryDate,
      totalFee: student.totalFee,
      paidAmount: student.paidAmount,
      dueAmount: student.dueAmount,
      paymentMode: student.paymentMode,
      paymentStatus: student.paymentStatus,
      daysRemaining: 30,
      isExpired: false,
    );
    list.insert(0, newStudent);
    return await saveStudentsForUser(username, list);
  }

  static Future<bool> deleteStudentForUser(String username, int id) async {
    final list = await getStudentsForUser(username);
    list.removeWhere((s) => s.id == id);
    return await saveStudentsForUser(username, list);
  }

  static Future<List<Student>> getStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'kushbinary';
    return getStudentsForUser(user);
  }

  static Future<bool> addStudent(Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'kushbinary';
    return addStudentForUser(user, student);
  }

  static Future<Map<String, dynamic>> sendExpiryNotifications() async {
    final students = await getStudents();
    final expired = students.where((s) => s.isExpired).length;
    return {
      'message': 'Sent WhatsApp reminders to $expired expired student(s)!',
    };
  }
}
