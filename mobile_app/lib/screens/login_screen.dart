import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login Controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _obscureLoginPass = true;
  bool _isLoginLoading = false;

  // Sign Up Controllers
  final _signupFormKey = GlobalKey<FormState>();
  final _signupLibraryNameCtrl = TextEditingController();
  final _signupUserCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupConfirmPassCtrl = TextEditingController();
  bool _obscureSignupPass = true;
  bool _obscureSignupConfirmPass = true;
  bool _isSignupLoading = false;

  // Quick PIN Mode
  bool _showPinMode = false;
  String _enteredPin = '';
  String? _savedPin;
  String? _savedUsername;
  String? _savedLibraryName;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkSavedSessionAndPin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _signupLibraryNameCtrl.dispose();
    _signupUserCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupPassCtrl.dispose();
    _signupConfirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSavedSessionAndPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('current_logged_in_user');
      final libName = prefs.getString('library_custom_business_name');

      if (savedUser != null && savedUser.isNotEmpty) {
        _savedUsername = savedUser;
        _savedLibraryName = libName;
        _loginUserCtrl.text = savedUser;

        final pin = prefs.getString('library_user_4digit_pin_$savedUser');
        if (pin != null && pin.length == 4) {
          setState(() {
            _savedPin = pin;
            _showPinMode = true;
          });
        }
      }
    } catch (_) {}
  }

  void _onPinKeypadTap(String value) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _enteredPin += value;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _verifyAndUnlockPin();
    }
  }

  void _onPinBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyAndUnlockPin() async {
    if (_enteredPin == _savedPin) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${_savedUsername ?? "Admin"}!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Incorrect 4-Digit PIN. Please try again.';
        _enteredPin = '';
      });
    }
  }

  Future<void> _performLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoginLoading = true;
      _errorMessage = null;
    });

    final username = _loginUserCtrl.text.trim();
    final password = _loginPassCtrl.text.trim();

    final result = await ApiService.loginToServer(username, password);

    setState(() => _isLoginLoading = false);

    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_logged_in_user', username);
      await prefs.setBool('has_logged_in_before', true);

      final pin = prefs.getString('library_user_4digit_pin_$username');
      if (pin == null || pin.length != 4) {
        // Prompt to set 4-digit PIN for quick login
        if (mounted) {
          _promptSetQuickPin(username);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, $username!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Invalid username or password.';
      });
    }
  }

  Future<void> _performSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    final password = _signupPassCtrl.text.trim();
    final confirmPassword = _signupConfirmPassCtrl.text.trim();

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSignupLoading = true;
      _errorMessage = null;
    });

    final username = _signupUserCtrl.text.trim();
    final libraryName = _signupLibraryNameCtrl.text.trim();
    final phone = _signupPhoneCtrl.text.trim();

    final result = await ApiService.signupToServer(
      username: username,
      password: password,
      libraryName: libraryName,
      phone: phone,
    );

    setState(() => _isSignupLoading = false);

    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_logged_in_user', username);
      await prefs.setBool('has_logged_in_before', true);

      if (mounted) {
        // Prompt to create 4-digit PIN immediately
        _promptSetQuickPin(username, isNewAccount: true);
      }
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Registration failed. Please try again.';
      });
    }
  }

  void _promptSetQuickPin(String username, {bool isNewAccount = false}) {
    final pinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;

          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: modalBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4338CA).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pin_rounded, color: Color(0xFF4338CA), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set 4-Digit Quick PIN',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                              ),
                            ),
                            Text(
                              'क्विक लॉगिन के लिए 4 अंकों का PIN सेट करें',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (dialogError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        dialogError!,
                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Enter 4-Digit PIN (4 अंकों का PIN)',
                      prefixIcon: const Icon(Icons.dialpad_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Confirm 4-Digit PIN (PIN दोबारा डालें)',
                      prefixIcon: const Icon(Icons.shield_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final pin = pinCtrl.text.trim();
                      final confirmPin = confirmPinCtrl.text.trim();

                      if (pin.length != 4 || int.tryParse(pin) == null) {
                        setModalState(() => dialogError = 'Please enter a valid 4-digit numeric PIN.');
                        return;
                      }

                      if (pin != confirmPin) {
                        setModalState(() => dialogError = 'PINs do not match. Please re-enter.');
                        return;
                      }

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('library_user_4digit_pin_$username', pin);

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quick PIN saved! Use this for instant logins.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                    child: const Text(
                      'Save PIN & Continue (PIN सुरक्षित करें)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Text(
                      'Skip for now (बाद में सेट करें)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    // Render Quick PIN Unlock Screen if user has configured a PIN
    if (_showPinMode && _savedPin != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_person_rounded, size: 44, color: primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _savedLibraryName ?? 'MyLibbook',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome, ${_savedUsername ?? "Admin"}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PIN Dots
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Enter 4-Digit Quick PIN (PIN दर्ज करें)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                color: isFilled ? primaryColor : Colors.transparent,
                                border: Border.all(
                                  color: isFilled ? primaryColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                  width: 2.2,
                                ),
                              ),
                            );
                          }),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Numeric Keypad
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      children: [
                        for (var row = 0; row < 3; row++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (var col = 1; col <= 3; col++)
                                  _buildKeypadButton('${row * 3 + col}', isDark),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Empty placeholder
                              const SizedBox(width: 72, height: 72),
                              _buildKeypadButton('0', isDark),
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: IconButton(
                                  onPressed: _onPinBackspace,
                                  icon: Icon(
                                    Icons.backspace_outlined,
                                    size: 26,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Switch to password login
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _showPinMode = false;
                      _enteredPin = '';
                      _errorMessage = null;
                    }),
                    icon: Icon(Icons.password_rounded, size: 18, color: primaryColor),
                    label: Text(
                      'Login with Password (पासवर्ड से लॉगिन करें)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Default Sign In / Sign Up Screen
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Header Branding
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_library_rounded,
                    size: 48,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'MyLibbook',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Library Management Cloud Platform',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Error Banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Card with Tabs
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab Bar (Sign In / Sign Up)
                      Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          tabs: const [
                            Tab(text: 'Sign In (लॉगिन)'),
                            Tab(text: 'Sign Up (खाता बनाएं)'),
                          ],
                        ),
                      ),

                      // Tab Views
                      SizedBox(
                        height: 340,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // 1. Sign In Tab
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                              child: Form(
                                key: _loginFormKey,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      children: [
                                        TextFormField(
                                          controller: _loginUserCtrl,
                                          style: textStyle,
                                          decoration: InputDecoration(
                                            labelText: 'Username *',
                                            hintText: 'Enter your username',
                                            prefixIcon: Icon(Icons.person_rounded, color: primaryColor, size: 20),
                                          ),
                                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter username' : null,
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _loginPassCtrl,
                                          obscureText: _obscureLoginPass,
                                          style: textStyle,
                                          decoration: InputDecoration(
                                            labelText: 'Password *',
                                            hintText: 'Enter your password',
                                            prefixIcon: Icon(Icons.lock_rounded, color: primaryColor, size: 20),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscureLoginPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                              onPressed: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
                                            ),
                                          ),
                                          validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton.icon(
                                        onPressed: _isLoginLoading ? null : _performLogin,
                                        icon: _isLoginLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.login_rounded, size: 20),
                                        label: Text(
                                          _isLoginLoading ? 'Signing In...' : 'Sign In to Dashboard',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 2. Sign Up Tab
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                              child: Form(
                                key: _signupFormKey,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _signupLibraryNameCtrl,
                                        style: textStyle,
                                        decoration: InputDecoration(
                                          labelText: 'Library / Hub Name *',
                                          hintText: 'e.g. Kush Study Hub',
                                          prefixIcon: Icon(Icons.storefront_rounded, color: primaryColor, size: 20),
                                        ),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter library name' : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signupUserCtrl,
                                        style: textStyle,
                                        decoration: InputDecoration(
                                          labelText: 'Username *',
                                          hintText: 'e.g. kush_library',
                                          prefixIcon: Icon(Icons.person_outline_rounded, color: primaryColor, size: 20),
                                        ),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter username' : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signupPhoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        style: textStyle,
                                        decoration: InputDecoration(
                                          labelText: 'Mobile Number (WhatsApp)',
                                          hintText: 'e.g. 9838127461',
                                          prefixIcon: Icon(Icons.phone_rounded, color: primaryColor, size: 20),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signupPassCtrl,
                                        obscureText: _obscureSignupPass,
                                        style: textStyle,
                                        decoration: InputDecoration(
                                          labelText: 'Password *',
                                          hintText: 'At least 4 characters',
                                          prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryColor, size: 20),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureSignupPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                            onPressed: () => setState(() => _obscureSignupPass = !_obscureSignupPass),
                                          ),
                                        ),
                                        validator: (v) => (v == null || v.length < 4) ? 'Min 4 characters' : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _signupConfirmPassCtrl,
                                        obscureText: _obscureSignupConfirmPass,
                                        style: textStyle,
                                        decoration: InputDecoration(
                                          labelText: 'Confirm Password *',
                                          hintText: 'Re-enter password',
                                          prefixIcon: Icon(Icons.shield_outlined, color: primaryColor, size: 20),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureSignupConfirmPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                            onPressed: () => setState(() => _obscureSignupConfirmPass = !_obscureSignupConfirmPass),
                                          ),
                                        ),
                                        validator: (v) => v == null || v.isEmpty ? 'Confirm password' : null,
                                      ),
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton.icon(
                                          onPressed: _isSignupLoading ? null : _performSignup,
                                          icon: _isSignupLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                                          label: Text(
                                            _isSignupLoading ? 'Creating Account...' : 'Register New Account',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_savedPin != null) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => setState(() => _showPinMode = true),
                    icon: Icon(Icons.dialpad_rounded, size: 18, color: primaryColor),
                    label: Text(
                      'Use 4-Digit Quick PIN (PIN से लॉगिन करें)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String text, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onPinKeypadTap(text),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
