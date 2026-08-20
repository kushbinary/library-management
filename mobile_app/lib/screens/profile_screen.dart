import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/settings_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _settings = SettingsManager();
  bool _isLoading = true;

  late TextEditingController _usernameCtrl;
  late TextEditingController _libraryNameCtrl;
  String _gender = 'Male';

  // Change password
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _showCurrentPw = false;
  bool _showNewPw = false;
  bool _isSavingPassword = false;

  String _currentUser = '';

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _libraryNameCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _libraryNameCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'Admin';
    final libName = prefs.getString('library_custom_business_name') ?? 'MyLibbook';
    final gender = prefs.getString('user_gender') ?? 'Male';

    setState(() {
      _currentUser = user;
      _usernameCtrl.text = user;
      _libraryNameCtrl.text = libName;
      _gender = gender;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final name = _usernameCtrl.text.trim();
    final libName = _libraryNameCtrl.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Username cannot be empty', isError: true);
      return;
    }
    if (libName.isEmpty) {
      _showSnackBar('Library name cannot be empty', isError: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_logged_in_user', name);
    await prefs.setString('user_gender', _gender);
    await _settings.updateUpiSettings(_settings.upiId, libName);

    setState(() => _currentUser = name);
    _showSnackBar('Profile saved successfully! ✓');
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirmPw = _confirmPwCtrl.text;

    if (currentPw.isEmpty) {
      _showSnackBar('Please enter current password', isError: true);
      return;
    }
    if (newPw.length < 6) {
      _showSnackBar('New password must be at least 6 characters', isError: true);
      return;
    }
    if (newPw != confirmPw) {
      _showSnackBar('New password and confirm password do not match', isError: true);
      return;
    }

    setState(() => _isSavingPassword = true);

    try {
      final baseUrl = await ApiService.getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _currentUser,
          'current_password': currentPw,
          'new_password': newPw,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('Password changed successfully! ✓');
        _currentPwCtrl.clear();
        _newPwCtrl.clear();
        _confirmPwCtrl.clear();
      } else {
        _showSnackBar(data['error'] ?? 'Failed to change password', isError: true);
      }
    } catch (e) {
      _showSnackBar('Server connection failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Avatar
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            _gender == 'Female' ? Icons.person_2_rounded : Icons.person_rounded,
                            size: 50,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_currentUser, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(_libraryNameCtrl.text, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Info Section
                  _buildSectionCard('Personal Info', Icons.person_rounded, [
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _libraryNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Library Name',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Gender', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Male', style: TextStyle(fontWeight: FontWeight.w600)),
                            value: 'Male',
                            groupValue: _gender,
                            onChanged: (val) => setState(() => _gender = val ?? 'Male'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Female', style: TextStyle(fontWeight: FontWeight.w600)),
                            value: 'Female',
                            groupValue: _gender,
                            onChanged: (val) => setState(() => _gender = val ?? 'Female'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Profile'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Change Password Section
                  _buildSectionCard('Change Password', Icons.lock_rounded, [
                    TextFormField(
                      controller: _currentPwCtrl,
                      obscureText: !_showCurrentPw,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_showCurrentPw ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showCurrentPw = !_showCurrentPw),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPwCtrl,
                      obscureText: !_showNewPw,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 chars)',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_showNewPw ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showNewPw = !_showNewPw),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPwCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSavingPassword ? null : _changePassword,
                      icon: _isSavingPassword
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.vpn_key_rounded),
                      label: Text(_isSavingPassword ? 'Changing...' : 'Change Password'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}
