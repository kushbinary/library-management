import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;

  // Master Security Passcode required to register any new admin/staff
  static const String masterSecurityCode = "LIB@2026";

  // Login Controllers
  final _loginUserCtrl = TextEditingController(text: 'kushbinary');
  final _loginPassCtrl = TextEditingController();

  // Sign Up Controllers
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupSecurityKeyCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupConfirmPassCtrl = TextEditingController();

  bool _obscureLoginPass = true;
  bool _obscureSignupPass = true;
  bool _obscureSignupConfirmPass = true;
  bool _obscureSecurityKey = true;
  String? _errorMessage;
  bool _isLoading = false;

  // Brute Force Protection
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  // Stored authorized accounts
  final Map<String, String> _registeredAccounts = {
    'kushbinary': 'Admin@1994',
    'kushbinary@gmail.com': 'Admin@1994',
  };

  @override
  void initState() {
    super.initState();
    _loadCustomAccounts();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('library_secure_users');
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
        'library_secure_users',
        json.encode(_registeredAccounts),
      );
    } catch (_) {}
  }

  void _startLockoutTimer() {
    setState(() {
      _lockoutSeconds = 60;
      _errorMessage =
          'Security Alert: 5 galat attempts! System 60 seconds ke liye lock ho gaya hai.';
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_lockoutSeconds > 1) {
        setState(() {
          _lockoutSeconds--;
          _errorMessage =
              'Security Lockout: Kripya $_lockoutSeconds seconds wait karein.';
        });
      } else {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _failedAttempts = 0;
          _errorMessage = null;
        });
      }
    });
  }

  void _handleLogin() async {
    if (_lockoutSeconds > 0) return;

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

    await Future.delayed(const Duration(milliseconds: 350));

    if (_registeredAccounts.containsKey(username) &&
        _registeredAccounts[username] == password) {
      _failedAttempts = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_logged_in_user', username);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('Secure Login Verified! Welcome $username 🎉'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (mounted) {
        _failedAttempts++;
        setState(() {
          _isLoading = false;
          if (_failedAttempts >= 5) {
            _startLockoutTimer();
          } else {
            _errorMessage =
                'Access Denied: Galat Username ya Password! (${5 - _failedAttempts} attempts left)';
          }
        });
      }
    }
  }

  void _handleSignUp() async {
    final name = _signupNameCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim().toLowerCase();
    final secretKey = _signupSecurityKeyCtrl.text.trim();
    final password = _signupPassCtrl.text.trim();
    final confirmPass = _signupConfirmPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || secretKey.isEmpty) {
      setState(() => _errorMessage = 'Kripya sabhi fields bharein.');
      return;
    }

    // Validate Master Security Key
    if (secretKey != masterSecurityCode && secretKey != "Admin@1994") {
      setState(() {
        _errorMessage =
            'Unauthorized: Galat Master Security Key! Sirf authorized admin hi new staff register kar sakte hain.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() =>
          _errorMessage = 'Password kam se kam 6 characters ka hona chahiye.');
      return;
    }

    if (password != confirmPass) {
      setState(() =>
          _errorMessage = 'Password aur Confirm Password match nahi kar rahe!');
      return;
    }

    if (_registeredAccounts.containsKey(email)) {
      setState(
          () => _errorMessage = 'Yeh Account pehle se registered hai! Login karein.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    await _saveCustomAccount(email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLogin = true;
        _loginUserCtrl.text = email;
        _loginPassCtrl.text = password;
        _signupSecurityKeyCtrl.clear();
        _signupPassCtrl.clear();
        _signupConfirmPassCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Authorized Account "$name" Created! Ab login kar sakte hain 🎉'),
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
              const Color(0xFF1E1035),
              Colors.deepPurple.shade900,
              const Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Card(
                elevation: 20,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Official MyLibbook Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 85,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => Icon(
                            Icons.menu_book_rounded,
                            size: 60,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'MyLibbook',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'Smart. Organized. Knowledge.',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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
                                onTap: _lockoutSeconds > 0
                                    ? null
                                    : () => setState(() {
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
                                      'Secure Login',
                                      style: TextStyle(
                                        fontWeight:
                                            _isLogin ? FontWeight.bold : FontWeight.normal,
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
                                onTap: _lockoutSeconds > 0
                                    ? null
                                    : () => setState(() {
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
                                      'Register Staff',
                                      style: TextStyle(
                                        fontWeight:
                                            !_isLogin ? FontWeight.bold : FontWeight.normal,
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

                      // Error / Warning Message Box
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _lockoutSeconds > 0
                                ? Colors.orange.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _lockoutSeconds > 0
                                  ? Colors.orange.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _lockoutSeconds > 0
                                    ? Icons.timer_outlined
                                    : Icons.gpp_bad_outlined,
                                color: _lockoutSeconds > 0
                                    ? Colors.orange.shade900
                                    : Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: _lockoutSeconds > 0
                                        ? Colors.orange.shade900
                                        : Colors.red.shade900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // FORMS
                      if (_isLogin) ...[
                        // SECURE LOGIN FORM
                        TextField(
                          controller: _loginUserCtrl,
                          enabled: _lockoutSeconds == 0,
                          decoration: InputDecoration(
                            labelText: 'Username or Email',
                            prefixIcon: const Icon(Icons.account_circle_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _loginPassCtrl,
                          obscureText: _obscureLoginPass,
                          enabled: _lockoutSeconds == 0,
                          onSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.password_rounded),
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
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                (_isLoading || _lockoutSeconds > 0) ? null : _handleLogin,
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
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_open_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _lockoutSeconds > 0
                                            ? 'Locked ($_lockoutSeconds s)'
                                            : 'Authenticate & Enter',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ] else ...[
                        // RESTRICTED SIGN UP FORM (REQUIRES MASTER SECURITY KEY)
                        TextField(
                          controller: _signupNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Staff / Admin Full Name',
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
                            labelText: 'Username or Email',
                            prefixIcon: const Icon(Icons.alternate_email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Master Passcode Field
                        TextField(
                          controller: _signupSecurityKeyCtrl,
                          obscureText: _obscureSecurityKey,
                          decoration: InputDecoration(
                            labelText: 'Master Security Key (Secret PIN)',
                            hintText: 'Required to authorize new staff',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureSecurityKey
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureSecurityKey = !_obscureSecurityKey;
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
                          controller: _signupPassCtrl,
                          obscureText: _obscureSignupPass,
                          decoration: InputDecoration(
                            labelText: 'Create Password (min 6 chars)',
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
                                  _obscureSignupConfirmPass =
                                      !_obscureSignupConfirmPass;
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
                          height: 50,
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
                                      Icon(Icons.how_to_reg_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Authorize & Create Account',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
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
