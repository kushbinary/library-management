import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true; // true = Login, false = Sign Up

  // Login Controllers
  final _loginUserCtrl = TextEditingController(text: 'admin');
  final _loginPassCtrl = TextEditingController(text: 'admin123');

  // Sign Up Controllers
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupConfirmPassCtrl = TextEditingController();

  bool _obscureLoginPass = true;
  bool _obscureSignupPass = true;
  bool _obscureSignupConfirmPass = true;
  String? _errorMessage;
  bool _isLoading = false;

  // Registered accounts stored in memory & SharedPreferences
  final Map<String, String> _registeredAccounts = {
    'admin': 'admin123',
    'admin@library.com': 'admin123',
    'kushbinary': 'Admin@1994',
  };

  @override
  void initState() {
    super.initState();
    _loadCustomAccounts();
  }

  Future<void> _loadCustomAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('library_registered_users');
      if (savedData != null) {
        final Map<String, dynamic> decoded = json.decode(savedData);
        decoded.forEach((key, value) {
          _registeredAccounts[key.toLowerCase()] = value.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCustomAccount(String user, String pass) async {
    _registeredAccounts[user.toLowerCase()] = pass;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'library_registered_users',
        json.encode(_registeredAccounts),
      );
    } catch (_) {}
  }

  void _handleLogin() async {
    final username = _loginUserCtrl.text.trim().toLowerCase();
    final password = _loginPassCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username aur Password enter karein.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (_registeredAccounts.containsKey(username) &&
        _registeredAccounts[username] == password) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('Welcome ${_loginUserCtrl.text.trim()}! Login Successful 🎉'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Galat Username ya Password! Kripya check karein.';
        });
      }
    }
  }

  void _handleSignUp() async {
    final name = _signupNameCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim().toLowerCase();
    final phone = _signupPhoneCtrl.text.trim();
    final password = _signupPassCtrl.text.trim();
    final confirmPass = _signupConfirmPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Kripya sabhi zaroori fields bharein.');
      return;
    }

    if (!email.contains('@') && email.length < 3) {
      setState(() => _errorMessage = 'Sahi Email address enter karein.');
      return;
    }

    if (password.length < 4) {
      setState(() => _errorMessage = 'Password kam se kam 4 characters ka hona chahiye.');
      return;
    }

    if (password != confirmPass) {
      setState(() => _errorMessage = 'Password aur Confirm Password match nahi kar rahe!');
      return;
    }

    if (_registeredAccounts.containsKey(email)) {
      setState(() => _errorMessage = 'Yeh Email pehle se registered hai! Login karein.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    await _saveCustomAccount(email, password);
    if (phone.isNotEmpty) {
      await _saveCustomAccount(phone, password);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLogin = true;
        _loginUserCtrl.text = email;
        _loginPassCtrl.text = password;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account "$name" successfully ban gaya! Ab login karein 🎉'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.deepPurple.shade700,
              Colors.indigo.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_library_rounded,
                          size: 42,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Library Hub',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLogin
                            ? 'Admin & Staff Login'
                            : 'Create New Admin / Staff Account',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Segmented Button Toggle for Login / Sign Up
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isLogin = true;
                                  _errorMessage = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isLogin ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _isLogin
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Login',
                                      style: TextStyle(
                                        fontWeight: _isLogin ? FontWeight.bold : FontWeight.normal,
                                        color: _isLogin
                                            ? Colors.deepPurple.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isLogin = false;
                                  _errorMessage = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isLogin ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !_isLogin
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontWeight: !_isLogin ? FontWeight.bold : FontWeight.normal,
                                        color: !_isLogin
                                            ? Colors.deepPurple.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error Message Box
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // FORM FIELDS
                      if (_isLogin) ...[
                        // LOGIN FORM
                        TextField(
                          controller: _loginUserCtrl,
                          decoration: InputDecoration(
                            labelText: 'Admin Username / Email',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _loginPassCtrl,
                          obscureText: _obscureLoginPass,
                          onSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureLoginPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureLoginPass = !_obscureLoginPass;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Account nahi hai? ",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isLogin = false;
                                _errorMessage = null;
                              }),
                              child: Text(
                                'Sign Up karein',
                                style: TextStyle(
                                  color: Colors.deepPurple.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // SIGN UP FORM
                        TextField(
                          controller: _signupNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _signupEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address / Username',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _signupPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number (Optional)',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _signupPassCtrl,
                          obscureText: _obscureSignupPass,
                          decoration: InputDecoration(
                            labelText: 'Create Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureSignupPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureSignupPass = !_obscureSignupPass;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _signupConfirmPassCtrl,
                          obscureText: _obscureSignupConfirmPass,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.check_circle_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureSignupConfirmPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureSignupConfirmPass = !_obscureSignupConfirmPass;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already account hai? ",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isLogin = true;
                                _errorMessage = null;
                              }),
                              child: Text(
                                'Login karein',
                                style: TextStyle(
                                  color: Colors.deepPurple.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
