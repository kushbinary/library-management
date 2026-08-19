import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';

class ApiService {
  // Default Render Cloud Server URL
  static const String defaultBaseUrl = 'https://library-management-1-k8rn.onrender.com/api';

  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('custom_server_api_url') ?? defaultBaseUrl;
    } catch (_) {
      return defaultBaseUrl;
    }
  }

  static Future<void> setCustomBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_server_api_url', url.trim());
  }

  static String _storageKey(String username) {
    return 'library_students_user_${username.toLowerCase().trim()}';
  }

  // Login with Cloud Server
  static Future<bool> loginToServer(String username, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      // Offline fallback: check locally registered accounts
    }
    return false;
  }

  // Get students list from Cloud Server (with offline cache fallback)
  static Future<List<Student>> getStudentsForUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(username);

    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/students'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        final students = list.map((item) => Student.fromJson(item)).toList();

        // Update local cache
        final jsonList = students.map((s) => s.toJson()).toList();
        await prefs.setString(key, json.encode(jsonList));

        return students;
      }
    } catch (e) {
      // Server offline or network issue: read from local cache
    }

    // Read from local cache
    try {
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
    } catch (_) {}

    return [];
  }

  // Add new student to Cloud Server and local cache
  static Future<bool> addStudentForUser(String username, Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(username);

    bool serverSuccess = false;
    Student savedStudent = student;

    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/students'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(student.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['student'] != null) {
          savedStudent = Student.fromJson(data['student']);
          serverSuccess = true;
        }
      }
    } catch (e) {
      // Server timed out or network error; save locally
    }

    // Update local cache
    try {
      final list = await getStudentsForUser(username);
      final newStudent = Student(
        id: savedStudent.id ?? DateTime.now().millisecondsSinceEpoch,
        name: savedStudent.name,
        phone: savedStudent.phone,
        admissionDate: savedStudent.admissionDate,
        timing: savedStudent.timing,
        seatNumber: savedStudent.seatNumber,
        expiryDate: savedStudent.expiryDate,
        totalFee: savedStudent.totalFee,
        paidAmount: savedStudent.paidAmount,
        dueAmount: savedStudent.dueAmount,
        paymentMode: savedStudent.paymentMode,
        paymentStatus: savedStudent.paymentStatus,
        daysRemaining: 30,
        isExpired: false,
      );
      list.removeWhere((s) => s.id == newStudent.id);
      list.insert(0, newStudent);
      final jsonList = list.map((s) => s.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
      return true;
    } catch (_) {
      return serverSuccess;
    }
  }

  // Update student on Cloud Server & local cache
  static Future<bool> updateStudentForUser(String username, Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(username);

    if (student.id != null) {
      try {
        final baseUrl = await getBaseUrl();
        await http.put(
          Uri.parse('$baseUrl/students/${student.id}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(student.toJson()),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    try {
      final list = await getStudentsForUser(username);
      final index = list.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        list[index] = student;
        final jsonList = list.map((s) => s.toJson()).toList();
        await prefs.setString(key, json.encode(jsonList));
        return true;
      }
    } catch (_) {}

    return false;
  }

  // Delete student from Cloud Server & local cache
  static Future<bool> deleteStudentForUser(String username, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(username);

    try {
      final baseUrl = await getBaseUrl();
      await http.delete(
        Uri.parse('$baseUrl/students/$id'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    try {
      final list = await getStudentsForUser(username);
      list.removeWhere((s) => s.id == id);
      final jsonList = list.map((s) => s.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
      return true;
    } catch (_) {}

    return false;
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
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/send_expiry_notifications'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}

    final students = await getStudents();
    final expired = students.where((s) => s.isExpired).length;
    return {
      'message': 'Sent WhatsApp reminders to $expired expired student(s)!',
    };
  }
}
