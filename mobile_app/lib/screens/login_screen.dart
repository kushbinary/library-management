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

enum AuthMode {
  enterPin,
  createPin,
  confirmPin,
  passwordLogin,
  staffSignup,
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  AuthMode _authMode = AuthMode.passwordLogin;
  String _enteredPin = '';
  String _tempCreatedPin = '';
  String? _savedPin;
  String _currentUser = 'kushbinary';
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscureLoginPass = true;
  bool _obscureSignupPass = true;
  bool _obscureSignupConfirmPass = true;
  bool _obscureSecurityKey = true;

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

  // Stored authorized accounts
  final Map<String, String> _registeredAccounts = {
    'kushbinary': 'Admin@1994',
    'kushbinary@gmail.com': 'Admin@1994',
  };

  @override
  void initState() {
    super.initState();
    _checkSavedSessionAndPin();
  }

  Future<void> _checkSavedSessionAndPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('current_logged_in_user');
      final pin = prefs.getString('library_user_4digit_pin_${savedUser ?? "kushbinary"}');
      final hasLoggedIn = prefs.getBool('has_logged_in_before') ?? false;

      await _loadCustomAccounts();

      if (hasLoggedIn && savedUser != null && savedUser.isNotEmpty) {
        setState(() {
          _currentUser = savedUser;
          _savedPin = pin;
          if (pin != null && pin.length == 4) {
            _authMode = AuthMode.enterPin;
          } else {
            _authMode = AuthMode.createPin;
          }
        });

        // Trigger biometrics optionally if on Android
        if (_authMode == AuthMode.enterPin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _authenticateWithBiometricsSilently();
          });
        }
      } else {
        setState(() {
          _authMode = AuthMode.passwordLogin;
        });
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometricsSilently() async {
    if (kIsWeb) return;
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canCheck) {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'Confirm fingerprint or screen lock to unlock MyLibbook',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        if (didAuth) {
          _unlockAndProceed();
        }
      }
    } catch (_) {}
  }

  void _onKeypadTap(String value) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += value;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _handlePinComplete();
    }
  }

  void _onBackspaceTap() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handlePinComplete() async {
    if (_authMode == AuthMode.enterPin) {
      if (_enteredPin == _savedPin) {
        _unlockAndProceed();
      } else {
        setState(() {
          _errorMessage = 'Galat PIN! Kripya sahi 4-digit PIN enter karein.';
          _enteredPin = '';
        });
      }
    } else if (_authMode == AuthMode.createPin) {
      setState(() {
        _tempCreatedPin = _enteredPin;
        _enteredPin = '';
        _authMode = AuthMode.confirmPin;
        _errorMessage = null;
      });
    } else if (_authMode == AuthMode.confirmPin) {
      if (_enteredPin == _tempCreatedPin) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('library_user_4digit_pin_$_currentUser', _enteredPin);
        setState(() {
          _savedPin = _enteredPin;
        });
        _unlockAndProceed();
      } else {
        setState(() {
          _errorMessage = 'PIN match nahi hua! Dobara create karein.';
          _enteredPin = '';
          _tempCreatedPin = '';
          _authMode = AuthMode.createPin;
        });
      }
    }
  }

  void _unlockAndProceed() {
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
      await prefs.setString('library_secure_users', json.encode(_registeredAccounts));
    } catch (_) {}
  }

  Future<void> _handlePasswordLogin() async {
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
    if (_registeredAccounts.containsKey(normalizedUser) && _registeredAccounts[normalizedUser] == pass) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_logged_in_user', user);
      await prefs.setBool('has_logged_in_before', true);

      final pin = prefs.getString('library_user_4digit_pin_$user');

      setState(() {
        _currentUser = user;
        _isLoading = false;
        if (pin != null && pin.length == 4) {
          _savedPin = pin;
          _unlockAndProceed();
        } else {
          _authMode = AuthMode.createPin;
          _enteredPin = '';
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Galat Username ya Password!';
      });
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
      setState(() => _errorMessage = 'Galat Master Security Key! Contact Admin.');
      return;
    }

    if (pass != confirmPass) {
      setState(() => _errorMessage = 'Passwords match nahi kar rahe hain.');
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

    await Future.delayed(const Duration(milliseconds: 300));

    final cleanUser = name.replaceAll(' ', '').toLowerCase();
    await _saveCustomAccount(cleanUser, pass);
    await _saveCustomAccount(email.toLowerCase(), pass);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_logged_in_user', name);
    await prefs.setBool('has_logged_in_before', true);

    setState(() {
      _currentUser = name;
      _isLoading = false;
      _authMode = AuthMode.createPin;
      _enteredPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 24,
                  shadowColor: const Color(0xFF4338CA).withValues(alpha: 0.3),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: _isPinMode ? _buildPinView() : _buildPasswordOrSignupView(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isPinMode =>
      _authMode == AuthMode.enterPin ||
      _authMode == AuthMode.createPin ||
      _authMode == AuthMode.confirmPin;

  // ================= 1. ULTRA-MODERN 4-DIGIT PIN KEYPAD VIEW =================
  Widget _buildPinView() {
    String title = 'Enter Quick PIN';
    String subtitle = 'Apna 4-digit PIN enter karke instant unlock karein';
    IconData headerIcon = Icons.lock_outline_rounded;

    if (_authMode == AuthMode.createPin) {
      title = 'Set 4-Digit Quick PIN';
      subtitle = 'Baar-baar login se bachne ke liye 4-digit PIN banayein';
      headerIcon = Icons.pin_outlined;
    } else if (_authMode == AuthMode.confirmPin) {
      title = 'Confirm Quick PIN';
      subtitle = 'Confirmation ke liye dobara wahi 4-digit PIN dalein';
      headerIcon = Icons.check_circle_outline_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App Logo
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFF4338CA).withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Color(0xFF4338CA), size: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'MyLibbook',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF1E1B4B), letterSpacing: 0.5),
        ),
        const Text(
          'Smart. Organized. Knowledge.',
          style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),

        // User Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(headerIcon, size: 14, color: const Color(0xFF4338CA)),
              const SizedBox(width: 6),
              Text(
                '$_currentUser',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3730A3)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 20),

        // 4 Animated PIN Circles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? const Color(0xFF4338CA) : Colors.transparent,
                border: Border.all(
                  color: isFilled ? const Color(0xFF4338CA) : Colors.grey.shade400,
                  width: 2.2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4338CA).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Sleek Custom Numeric Keypad
        const SizedBox(height: 6),
        Column(
          children: [
            _buildKeypadRow(['1', '2', '3']),
            const SizedBox(height: 12),
            _buildKeypadRow(['4', '5', '6']),
            const SizedBox(height: 12),
            _buildKeypadRow(['7', '8', '9']),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Biometrics / Clear button
                SizedBox(
                  width: 68,
                  height: 60,
                  child: IconButton(
                    icon: const Icon(Icons.fingerprint_rounded, size: 28, color: Color(0xFF4338CA)),
                    tooltip: 'Use Fingerprint / Screen Lock',
                    onPressed: _authenticateWithBiometricsSilently,
                  ),
                ),
                _buildKeypadButton('0'),
                SizedBox(
                  width: 68,
                  height: 60,
                  child: IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 22, color: Colors.black87),
                    tooltip: 'Backspace',
                    onPressed: _onBackspaceTap,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Switch to Password Login
        TextButton.icon(
          onPressed: () {
            setState(() {
              _authMode = AuthMode.passwordLogin;
              _enteredPin = '';
              _errorMessage = null;
            });
          },
          icon: const Icon(Icons.password_rounded, size: 16),
          label: const Text('Login with Password / Switch Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKeypadButton(k)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadTap(digit),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 68,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= 2. PASSWORD LOGIN / SIGN UP VIEW =================
  Widget _buildPasswordOrSignupView() {
    final isLogin = _authMode == AuthMode.passwordLogin;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF4338CA).withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Color(0xFF4338CA), size: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'MyLibbook',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF1E1B4B), letterSpacing: 0.5),
        ),
        const Text(
          'Smart. Organized. Knowledge.',
          style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),

        // Toggle Buttons (Login / Register)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _authMode = AuthMode.passwordLogin;
                    _errorMessage = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isLogin ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isLogin
                          ? [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Secure Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLogin ? const Color(0xFF4338CA) : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _authMode = AuthMode.staffSignup;
                    _errorMessage = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isLogin ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: !isLogin
                          ? [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Register Staff',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !isLogin ? const Color(0xFF4338CA) : Colors.grey.shade600,
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
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isLogin) ...[
          TextField(
            controller: _loginUserCtrl,
            decoration: InputDecoration(
              labelText: 'Username or Email',
              prefixIcon: const Icon(Icons.account_circle_outlined),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _loginPassCtrl,
            obscureText: _obscureLoginPass,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureLoginPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              onPressed: _isLoading ? null : _handlePasswordLogin,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded),
              label: const Text('Login & Setup Quick PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ] else ...[
          TextField(
            controller: _signupNameCtrl,
            decoration: InputDecoration(
              labelText: 'Staff Name / Username',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signupEmailCtrl,
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isLoading ? null : _handleSignup,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.how_to_reg_rounded),
              label: const Text('Create Account & Setup PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],

        if (_savedPin != null && _savedPin!.isNotEmpty) ...[
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _authMode = AuthMode.enterPin;
                _enteredPin = '';
                _errorMessage = null;
              });
            },
            icon: const Icon(Icons.dialpad_rounded, size: 18),
            label: Text('Use 4-Digit Quick PIN for $_currentUser', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
