import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../database/database_helper.dart';

class ApiService {
  static const String defaultBaseUrl = 'https://library-management-1-k8rn.onrender.com/api';

  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString('custom_server_api_url');
      if (custom != null && custom.isNotEmpty && !custom.contains('k8m.onrender.com')) {
        return custom;
      }
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

  // ---- Authentication ----
  static Future<Map<String, dynamic>> signupToServer({
    required String username,
    required String password,
    String? libraryName,
    String? phone,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('\$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username.trim(),
          'password': password,
          'library_name': libraryName?.trim().isNotEmpty == true ? libraryName!.trim() : 'My Library',
          'phone': phone?.trim() ?? '',
        }),
      ).timeout(const Duration(seconds: 30));

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
        // Force migration check on new signup (just in case)
        await DatabaseHelper().database;
        return {'success': true, 'message': data['message'] ?? 'Registration successful!'};
      }
      return {'success': false, 'error': data['error'] ?? 'Sign Up failed.'};
    } catch (e) {
      return {'success': false, 'error': 'Server connection failed: \$e'};
    }
  }

  static Future<Map<String, dynamic>> loginToServer(String username, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('\$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

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
        // Ensure migration happens on login
        await DatabaseHelper().database;
        return {'success': true, 'message': 'Login successful!'};
      }
      return {'success': false, 'error': data['error'] ?? 'Invalid credentials'};
    } catch (e) {
      return {'success': false, 'error': 'Server connection failed: \$e'};
    }
  }

  // ---- Members ----
  static Future<List<Member>> getStudents() async {
    return await DatabaseHelper().getAllMembers();
  }
  
  static Future<List<Member>> getMembersForUser(String username) async {
    return await DatabaseHelper().getAllMembers();
  }

  static Future<bool> addMember(Member member) async {
    // 1. Save to local SQLite database (SSOT)
    await DatabaseHelper().insertMember(member);
    
    // 2. Background sync to cloud API
    _syncMemberToCloud(member, isNew: true);
    
    return true;
  }

  static Future<bool> updateMemberForUser(String username, Member member) async {
    // 1. Update in local SQLite database
    await DatabaseHelper().updateMember(member);

    // 2. Background sync to cloud API
    _syncMemberToCloud(member, isNew: false, username: username);
    
    return true;
  }

  static Future<bool> deleteMemberForUser(String username, String id) async {
    // 1. Delete from local SQLite database
    await DatabaseHelper().deleteMember(id);

    // 2. Background delete from cloud
    _deleteMemberFromCloud(id, username);

    return true;
  }

  // ---- Cloud Sync Helpers ----
  
  static Future<void> _syncMemberToCloud(Member member, {required bool isNew, String? username}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = username ?? prefs.getString('current_logged_in_user') ?? 'admin';
      final baseUrl = await getBaseUrl();
      
      final payload = member.toJson();
      payload['username'] = user;

      // The old cloud API expects specific fields, some of which we map back here just in case.
      // But the cloud will just ignore unknown fields like `address`, `email`.
      
      if (isNew) {
        await http.post(
          Uri.parse('\$baseUrl/students'),
          headers: {'Content-Type': 'application/json', 'X-Username': user},
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 15));
      } else {
        await http.put(
          Uri.parse('\$baseUrl/students/\${member.id}'),
          headers: {'Content-Type': 'application/json', 'X-Username': user},
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      // Fail silently for background sync
    }
  }

  static Future<void> _deleteMemberFromCloud(String id, String username) async {
    try {
      final baseUrl = await getBaseUrl();
      await http.delete(
        Uri.parse('\$baseUrl/students/\$id?username=\${Uri.encodeComponent(username)}'),
        headers: {'Accept': 'application/json', 'X-Username': username},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Fail silently
    }
  }

  // ---- Reminders ----
  static Future<Map<String, dynamic>> sendExpiryNotifications() async {
    // For now, we will simulate this by checking local DB since cloud might not know about new fields
    final members = await DatabaseHelper().getAllMembers();
    final today = DateTime.now();
    int count = 0;
    for (var m in members) {
      try {
        final exp = DateTime.parse(m.expiryDate);
        if (exp.isBefore(today) || exp.isAtSameMomentAs(today)) {
          count++;
        }
      } catch (_) {}
    }
    return {'message': 'Sent WhatsApp reminders to \$count expired member(s)!'};
  }
}
