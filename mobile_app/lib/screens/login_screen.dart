import 'package:flutter/material.dart';
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
  final _loginUserCtrl = TextEditingController(text: 'admin');
  final _loginPassCtrl = TextEditingController(text: 'admin123');
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

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkSavedSession();
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

  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('current_logged_in_user');
      final hasLoggedIn = prefs.getBool('has_logged_in_before') ?? false;

      if (hasLoggedIn && savedUser != null && savedUser.isNotEmpty) {
        _loginUserCtrl.text = savedUser;
      }
    } catch (_) {}
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, $username!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account for "$libraryName" created successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Registration failed. Please try again.';
      });
    }
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
                const SizedBox(height: 24),

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
                        height: 380,
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
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Default demo account: admin / admin123',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
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
                const SizedBox(height: 16),
                Text(
                  'Each account gets private, isolated database storage.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
