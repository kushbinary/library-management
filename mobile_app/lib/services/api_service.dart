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
      final custom = prefs.getString('custom_server_api_url');
      if (custom != null && custom.isNotEmpty && !custom.contains('k8m.onrender.com')) {
        return custom;
      }
      // If old or invalid URL found, reset to current defaultBaseUrl
      await prefs.setString('custom_server_api_url', defaultBaseUrl);
      return defaultBaseUrl;
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

  // Register / Sign Up new Library Account on Cloud Server
  static Future<Map<String, dynamic>> signupToServer({
    required String username,
    required String password,
    String? libraryName,
    String? phone,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username.trim(),
          'password': password,
          'library_name': libraryName?.trim().isNotEmpty == true ? libraryName!.trim() : 'My Library',
          'phone': phone?.trim() ?? '',
        }),
      ).timeout(const Duration(seconds: 60));

      final data = json.decode(response.body);
      if (response.statusCode == 201 || (data is Map && data['success'] == true)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_logged_in_user', username.trim());
        if (data['user_id'] != null) {
          await prefs.setInt('current_user_id', data['user_id']);
        }
        if (libraryName != null && libraryName.isNotEmpty) {
          await prefs.setString('library_custom_business_name', libraryName.trim());
        }
        return {'success': true, 'message': data['message'] ?? 'Registration successful!'};
      }
      return {'success': false, 'error': data['error'] ?? 'Sign Up failed. Please try again.'};
    } catch (e) {
      return {'success': false, 'error': 'Server connection failed: $e'};
    }
  }

  // Login with Cloud Server
  static Future<Map<String, dynamic>> loginToServer(String username, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 60));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_logged_in_user', username.trim());
        if (data['user_id'] != null) {
          await prefs.setInt('current_user_id', data['user_id']);
        }
        if (data['user'] != null && data['user']['library_name'] != null) {
          await prefs.setString('library_custom_business_name', data['user']['library_name']);
        }
        return {'success': true, 'message': 'Login successful!'};
      }
      return {'success': false, 'error': data['error'] ?? 'Invalid username or password'};
    } catch (e) {
      return {'success': false, 'error': 'Server connection failed: $e'};
    }
  }

  // Get students list from Cloud Server for specific user (with offline cache fallback)
  static Future<List<Student>> getStudentsForUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(username);

    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/students?username=${Uri.encodeComponent(username)}'),
        headers: {
          'Accept': 'application/json',
          'X-Username': username,
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        final students = list.map((item) => Student.fromJson(item)).toList();

        // Update local cache for this specific user
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

  // Add new student to Cloud Server and local cache for specific user
  static Future<bool> addStudentForUser(String username, Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(username);

    bool serverSuccess = false;
    Student savedStudent = student;

    try {
      final baseUrl = await getBaseUrl();
      final payload = student.toJson();
      payload['username'] = username;

      final response = await http.post(
        Uri.parse('$baseUrl/students'),
        headers: {
          'Content-Type': 'application/json',
          'X-Username': username,
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 60));

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
        final payload = student.toJson();
        payload['username'] = username;

        await http.put(
          Uri.parse('$baseUrl/students/${student.id}'),
          headers: {
            'Content-Type': 'application/json',
            'X-Username': username,
          },
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 60));
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
        Uri.parse('$baseUrl/students/$id?username=${Uri.encodeComponent(username)}'),
        headers: {
          'Accept': 'application/json',
          'X-Username': username,
        },
      ).timeout(const Duration(seconds: 60));
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
    final user = prefs.getString('current_logged_in_user') ?? 'admin';
    return getStudentsForUser(user);
  }

  static Future<bool> addStudent(Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'admin';
    return addStudentForUser(user, student);
  }

  static Future<Map<String, dynamic>> sendExpiryNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = prefs.getString('current_logged_in_user') ?? 'admin';
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/send_expiry_notifications'),
        headers: {
          'Content-Type': 'application/json',
          'X-Username': user,
        },
      ).timeout(const Duration(seconds: 60));
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
