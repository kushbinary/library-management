import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsManager();
  String _currentUser = 'kushbinary';
  String? _currentPin;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_logged_in_user') ?? 'kushbinary';
    final pin = await _settings.getUserPin(user);
    setState(() {
      _currentUser = user;
      _currentPin = pin;
    });
  }

  void _showChangePinDialog() {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dialpad_rounded, color: Color(0xFF4338CA)),
              ),
              const SizedBox(width: 10),
              Text(
                _settings.isHindi ? '4-Digit PIN बदलें' : 'Change 4-Digit PIN',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentPin != null) ...[
                  TextField(
                    controller: oldPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _settings.isHindi ? 'Purana 4-Digit PIN' : 'Current 4-Digit PIN',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: newPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _settings.isHindi ? 'Naya 4-Digit PIN' : 'New 4-Digit PIN',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _settings.isHindi ? 'Naye PIN ki Pushti Karein' : 'Confirm New PIN',
                    prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_settings.isHindi ? 'Cancel' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (_currentPin != null && oldPinCtrl.text.trim() != _currentPin) {
                  setDialogState(() => dialogError = _settings.isHindi ? 'Purana PIN galat hai!' : 'Current PIN is incorrect!');
                  return;
                }
                if (newPinCtrl.text.trim().length != 4) {
                  setDialogState(() => dialogError = _settings.isHindi ? 'PIN 4 digit ka hona chahiye!' : 'PIN must be 4 digits!');
                  return;
                }
                if (newPinCtrl.text.trim() != confirmPinCtrl.text.trim()) {
                  setDialogState(() => dialogError = _settings.isHindi ? 'Naye PIN match nahi kar rahe!' : 'New PINs do not match!');
                  return;
                }

                await _settings.setUserPin(_currentUser, newPinCtrl.text.trim());
                await _settings.setAppLockEnabled(true);
                setState(() => _currentPin = newPinCtrl.text.trim());
                Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_settings.isHindi ? '✅ 4-Digit PIN successfully set ho gaya!' : '✅ 4-Digit PIN successfully updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(_settings.isHindi ? 'PIN Save Karein' : 'Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpiSettingsDialog() {
    final upiCtrl = TextEditingController(text: _settings.upiId);
    final nameCtrl = TextEditingController(text: _settings.businessName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4338CA)),
            const SizedBox(width: 8),
            Text(
              _settings.isHindi ? 'UPI Payment Settings' : 'UPI Payment Settings',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _settings.isHindi ? 'Apni UPI ID enter karein jisme fees QR code se receive karni hai:' : 'Enter UPI ID to receive fees via QR code:',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: InputDecoration(
                labelText: 'UPI ID (VPA)',
                hintText: 'e.g. kushbinary@okaxis',
                prefixIcon: const Icon(Icons.payment_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Library / Business Name',
                hintText: 'e.g. MyLibbook',
                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
            onPressed: () async {
              if (upiCtrl.text.trim().isNotEmpty) {
                await _settings.updateUpiSettings(
                  upiCtrl.text.trim(),
                  nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'MyLibbook',
                );
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ UPI settings updated!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: Text(_settings.isHindi ? 'Save Karein' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _openSupportWhatsApp() async {
    const phone = '919838147651';
    final msg = Uri.encodeComponent('Namaste! Mujhe MyLibbook Application ke baare mein sahayata chahiye.');
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHi = _settings.isHindi;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isHi ? 'सेटिंग्स (Settings)' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. APP LOCK & 4-DIGIT PIN SECTION
          _buildSectionHeader(isHi ? 'सुरक्षा एवं 4-Digit App Lock' : 'Security & 4-Digit App Lock', Icons.lock_clock_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      isHi ? '4-Digit Quick PIN Lock' : '4-Digit Quick PIN Lock',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      isHi ? 'App open hote hi 4-digit PIN se instant unlock hoga' : 'Instant unlock with 4-digit PIN on app launch',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _settings.isAppLockEnabled ? Colors.indigo.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.dialpad_rounded, color: _settings.isAppLockEnabled ? const Color(0xFF4338CA) : Colors.grey),
                    ),
                    value: _settings.isAppLockEnabled,
                    activeTrackColor: const Color(0xFF4338CA),
                    onChanged: (val) async {
                      if (val && (_currentPin == null || _currentPin!.length != 4)) {
                        _showChangePinDialog();
                      } else {
                        await _settings.setAppLockEnabled(val);
                      }
                    },
                  ),
                  if (_settings.isAppLockEnabled) ...[
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: const Icon(Icons.edit_rounded, color: Color(0xFF4338CA)),
                      title: Text(
                        isHi ? '4-Digit PIN बदलें (Change PIN)' : 'Change 4-Digit PIN',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        _currentPin != null ? (isHi ? 'PIN Set Hai (••••)' : 'PIN is active (••••)') : (isHi ? 'PIN set nahi hai' : 'No PIN set'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showChangePinDialog,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. THEME MODE SECTION (Light, Dark, Device)
          _buildSectionHeader(isHi ? 'थीम (Theme Mode)' : 'Appearance & Theme', Icons.palette_outlined),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(isHi ? '☀️ लाइट मोड (Light Mode)' : '☀️ Light Mode', style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: ThemeMode.light,
                    groupValue: _settings.themeMode,
                    activeColor: const Color(0xFF4338CA),
                    onChanged: (mode) {
                      if (mode != null) _settings.setThemeMode(mode);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(isHi ? '🌙 डार्क मोड (Dark Mode)' : '🌙 Dark Mode', style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: ThemeMode.dark,
                    groupValue: _settings.themeMode,
                    activeColor: const Color(0xFF4338CA),
                    onChanged: (mode) {
                      if (mode != null) _settings.setThemeMode(mode);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(isHi ? '⚙️ सिस्टम / डिवाइस अनुसार (System Default)' : '⚙️ Device / System Default', style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: ThemeMode.system,
                    groupValue: _settings.themeMode,
                    activeColor: const Color(0xFF4338CA),
                    onChanged: (mode) {
                      if (mode != null) _settings.setThemeMode(mode);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. LANGUAGE SECTION (English / Hindi)
          _buildSectionHeader(isHi ? 'भाषा (Language)' : 'Language', Icons.language_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _settings.setLanguage('hi'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isHi ? const Color(0xFFEEF2FF) : Colors.transparent,
                          border: Border.all(color: isHi ? const Color(0xFF4338CA) : Colors.grey.shade300, width: isHi ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text('हिन्दी (Hindi)', style: TextStyle(fontWeight: FontWeight.bold, color: isHi ? const Color(0xFF4338CA) : (isDark ? Colors.white : Colors.black87))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _settings.setLanguage('en'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isHi ? const Color(0xFFEEF2FF) : Colors.transparent,
                          border: Border.all(color: !isHi ? const Color(0xFF4338CA) : Colors.grey.shade300, width: !isHi ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text('English', style: TextStyle(fontWeight: FontWeight.bold, color: !isHi ? const Color(0xFF4338CA) : (isDark ? Colors.white : Colors.black87))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. UPI QR SETTINGS
          _buildSectionHeader(isHi ? 'UPI पेमेंट सेटिंग्स' : 'UPI Payment Settings', Icons.qr_code_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
              ),
              title: Text(_settings.upiId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Payee Name: ${_settings.businessName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                onPressed: _showUpiSettingsDialog,
                child: Text(isHi ? 'बदलें' : 'Edit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. HELP & SUPPORT SECTION
          _buildSectionHeader(isHi ? 'सहायता एवं संपर्क (Help & Support)' : 'Help & Support', Icons.support_agent_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chat_rounded, color: Colors.green),
                  ),
                  title: Text(isHi ? 'WhatsApp सहायता' : 'WhatsApp Support', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(isHi ? 'Direct WhatsApp par team se sampark karein' : 'Chat with technical support team', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: _openSupportWhatsApp,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.email_outlined, color: Colors.blue),
                  ),
                  title: Text(isHi ? 'Email Support' : 'Email Support', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('kushbinary@gmail.com', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final uri = Uri.parse('mailto:kushbinary@gmail.com?subject=MyLibbook%20Support');
                    try {
                      await launchUrl(uri);
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. ABOUT US SECTION
          _buildSectionHeader(isHi ? 'ऐप के बारे में (About Us)' : 'About Us', Icons.info_outline_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MyLibbook Pro', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1E1B4B))),
                            Text('Smart. Organized. Knowledge.', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w600)),
                            SizedBox(height: 2),
                            Text('Version 1.0.0 (Release Build)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    isHi
                        ? 'MyLibbook ek modern automated library management platform hai jo seat allocation, automated WhatsApp reminders, UPI QR collection, aur secure 4-digit lock pradan karta hai.'
                        : 'MyLibbook is an automated library management platform providing intelligent seat matrices, direct WhatsApp notifications, UPI QR fee collections, and instant 4-digit PIN security.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4338CA)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E1B4B), letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
