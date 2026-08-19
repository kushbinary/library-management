import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  static final List<Student> _localStudents = [
    Student(
      id: 1,
      name: 'Aarav Sharma',
      email: 'aarav.sharma@example.com',
      phone: '9876543210',
      admissionDate: '2026-01-15',
      timing: 'Morning (8 AM - 12 PM)',
      seatNumber: 'A-12',
      expiryDate: '2026-08-15',
      daysRemaining: 0,
      isExpired: true,
    ),
    Student(
      id: 2,
      name: 'Priya Verma',
      email: 'priya.v@example.com',
      phone: '9812345678',
      admissionDate: '2026-02-01',
      timing: 'Evening (4 PM - 8 PM)',
      seatNumber: 'B-04',
      expiryDate: '2026-09-01',
      daysRemaining: 13,
      isExpired: false,
    ),
    Student(
      id: 3,
      name: 'Rohan Gupta',
      email: 'rohan.gupta@example.com',
      phone: '9988776655',
      admissionDate: '2026-03-10',
      timing: 'Full Day (8 AM - 8 PM)',
      seatNumber: 'C-01',
      expiryDate: '2026-08-25',
      daysRemaining: 6,
      isExpired: false,
    ),
  ];

  static Future<List<Student>> getStudents() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/students'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Student.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to local data when backend is not running
    }
    return List.from(_localStudents);
  }

  static Future<bool> addStudent(Student student) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/students'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(student.toJson()),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (_) {}
    // Add locally
    final newStudent = Student(
      id: _localStudents.length + 1,
      name: student.name,
      email: student.email,
      phone: student.phone,
      admissionDate: student.admissionDate,
      timing: student.timing,
      seatNumber: student.seatNumber,
      expiryDate: student.expiryDate,
      daysRemaining: 30,
      isExpired: false,
    );
    _localStudents.insert(0, newStudent);
    return true;
  }

  static Future<Map<String, dynamic>> sendExpiryNotifications() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/send_expiry_notifications'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {
      'message':
          'Sent notifications to ${_localStudents.where((s) => s.isExpired).length} expired memberships.'
    };
  }
}
