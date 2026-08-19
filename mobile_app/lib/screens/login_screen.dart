import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLogin = true;
  bool _isQuickUnlockMode = false;
  String? _savedUsername;
  bool _isAuthenticating = false;

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
    _checkSavedSessionAndAuthenticate();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSavedSessionAndAuthenticate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('current_logged_in_user');
      final hasLoggedIn = prefs.getBool('has_logged_in_before') ?? false;

      await _loadCustomAccounts();

      if (hasLoggedIn && savedUser != null && savedUser.isNotEmpty) {
        setState(() {
          _savedUsername = savedUser;
          _isQuickUnlockMode = true;
        });

        // Trigger Biometric / Screen Lock automatically
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithDeviceLock();
        });
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithDeviceLock() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // On Web, if logged in before, unlock directly or allow 1-click
        await Future.delayed(const Duration(milliseconds: 300));
        _navigateToHome(_savedUsername ?? 'kushbinary');
        return;
      }

      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Confirm screen lock pattern, PIN, or fingerprint to unlock MyLibbook',
          options: const AuthenticationOptions(
            biometricOnly: false, // Allows PIN, Pattern, Password as well as Biometric
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );

        if (didAuthenticate) {
          _navigateToHome(_savedUsername ?? 'kushbinary');
          return;
        } else {
          setState(() {
            _errorMessage = 'Authentication cancelled. Tap below to unlock.';
          });
        }
      } else {
        // Device does not support screen lock or biometrics, open dashboard
        _navigateToHome(_savedUsername ?? 'kushbinary');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lock verification failed. Tap to retry or use password.';
      });
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _navigateToHome(String username) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
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
        _lockoutTimer?.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _failedAttempts = 0;
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_lockoutSeconds > 0) return;

    final user = _loginUserCtrl.text.trim();
    final pass = _loginPassCtrl.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Username aur Password enter karein.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final normalizedUser = user.toLowerCase();
    if (_registeredAccounts.containsKey(normalizedUser) &&
        _registeredAccounts[normalizedUser] == pass) {
      _failedAttempts = 0;

      // Save persistent session for Screen Lock Auto-Unlock
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_logged_in_user', user);
      await prefs.setBool('has_logged_in_before', true);

      if (mounted) {
        _navigateToHome(user);
      }
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _startLockoutTimer();
      } else {
        setState(() {
          _errorMessage =
              'Galat Username ya Password! (${5 - _failedAttempts} attempts bache hain)';
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    final name = _signupNameCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim();
    final secKey = _signupSecurityKeyCtrl.text.trim();
    final pass = _signupPassCtrl.text;
    final confirmPass = _signupConfirmPassCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty || secKey.isEmpty) {
      setState(() => _errorMessage = 'Sabhi fields bharna anivarya hai.');
      return;
    }

    if (secKey != masterSecurityCode) {
      setState(() {
        _errorMessage =
            'Galat Master Security Key! Naye admin register karne ke liye valid Master Key enter karein.';
      });
      return;
    }

    if (pass != confirmPass) {
      setState(() => _errorMessage = 'Dono passwords match nahi kar rahe hain.');
      return;
    }

    if (pass.length < 6) {
      setState(() => _errorMessage = 'Password kam se kam 6 characters ka hona chahiye.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    final cleanUser = name.replaceAll(' ', '').toLowerCase();
    await _saveCustomAccount(cleanUser, pass);
    await _saveCustomAccount(email.toLowerCase(), pass);

    // Save session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_logged_in_user', name);
    await prefs.setBool('has_logged_in_before', true);

    if (mounted) {
      setState(() => _isLoading = false);
      _navigateToHome(name);
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
                  child: _isQuickUnlockMode ? _buildQuickUnlockView(theme) : _buildPasswordLoginView(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= 1. QUICK UNLOCK WITH SCREEN LOCK / BIOMETRICS =================
  Widget _buildQuickUnlockView(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Official MyLibbook Logo
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/logo.png',
            height: 85,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const Icon(
              Icons.menu_book_rounded,
              size: 60,
              color: Color(0xFF1E3A8A),
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
        const SizedBox(height: 24),

        // User Avatar Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E7FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_rounded, color: Color(0xFF4338CA), size: 20),
              const SizedBox(width: 8),
              Text(
                'Welcome, ${_savedUsername ?? "Admin"}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF312E81), fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Confirm your screen lock pattern, PIN, or password to unlock MyLibbook',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
        ),
        const SizedBox(height: 20),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Big Unlock Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _authenticateWithDeviceLock,
            icon: _isAuthenticating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.fingerprint_rounded, size: 24),
            label: Text(
              _isAuthenticating ? 'Verifying...' : 'Unlock MyLibbook',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Option to switch account / enter password manually
        TextButton.icon(
          onPressed: () {
            setState(() {
              _isQuickUnlockMode = false;
              _errorMessage = null;
            });
          },
          icon: const Icon(Icons.key_rounded, size: 16),
          label: const Text('Login with Password / Switch Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ================= 2. PASSWORD LOGIN / SIGN UP VIEW =================
  Widget _buildPasswordLoginView(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Official MyLibbook Logo
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/logo.png',
            height: 85,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const Icon(
              Icons.menu_book_rounded,
              size: 60,
              color: Color(0xFF1E3A8A),
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

        // Toggle Buttons (Login / Register)
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
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
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Secure Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isLogin ? const Color(0xFF4338CA) : Colors.grey.shade600,
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
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Register Staff',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !_isLogin ? const Color(0xFF4338CA) : Colors.grey.shade600,
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

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_isLogin) ...[
          TextField(
            controller: _loginUserCtrl,
            enabled: _lockoutSeconds == 0,
            decoration: InputDecoration(
              labelText: 'Username or Email',
              prefixIcon: const Icon(Icons.account_circle_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginPassCtrl,
            obscureText: _obscureLoginPass,
            enabled: _lockoutSeconds == 0,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureLoginPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _lockoutSeconds > 0 ? Colors.grey : const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_isLoading || _lockoutSeconds > 0) ? null : _handleLogin,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_open_rounded),
              label: Text(
                _lockoutSeconds > 0 ? 'Locked (${_lockoutSeconds}s)' : 'Authenticate & Enter',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else ...[
          TextField(
            controller: _signupNameCtrl,
            decoration: InputDecoration(
              labelText: 'Staff Name / Username',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signupEmailCtrl,
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signupSecurityKeyCtrl,
            obscureText: _obscureSecurityKey,
            decoration: InputDecoration(
              labelText: 'Master Security Key',
              prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.orange),
              suffixIcon: IconButton(
                icon: Icon(_obscureSecurityKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureSecurityKey = !_obscureSecurityKey),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signupPassCtrl,
            obscureText: _obscureSignupPass,
            decoration: InputDecoration(
              labelText: 'Create Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureSignupPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureSignupPass = !_obscureSignupPass),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signupConfirmPassCtrl,
            obscureText: _obscureSignupConfirmPass,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureSignupConfirmPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureSignupConfirmPass = !_obscureSignupConfirmPass),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleSignup,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.how_to_reg_rounded),
              label: const Text('Create Account & Login', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],

        if (_savedUsername != null && _savedUsername!.isNotEmpty) ...[
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isQuickUnlockMode = true;
                _errorMessage = null;
              });
              _authenticateWithDeviceLock();
            },
            icon: const Icon(Icons.fingerprint_rounded, size: 18),
            label: Text('Use Screen Lock / Fingerprint for $_savedUsername', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
