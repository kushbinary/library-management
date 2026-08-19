import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const String apkDownloadUrl = 'https://kushbinary.github.io/library-management/MyLibbook.apk';
  static const String webAppUrl = 'https://kushbinary.github.io/library-management/';

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

    final isHi = _settings.isHindi;

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
                isHi ? '4-Digit PIN बदलें' : 'Change 4-Digit PIN',
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
                      labelText: isHi ? 'वर्तमान PIN (Current PIN)' : 'Current 4-Digit PIN',
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
                    labelText: isHi ? 'नया PIN (New PIN)' : 'New 4-Digit PIN',
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
                    labelText: isHi ? 'PIN की पुष्टि करें' : 'Confirm New PIN',
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
              child: Text(isHi ? 'रद्द करें' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (_currentPin != null && oldPinCtrl.text.trim() != _currentPin) {
                  setDialogState(() => dialogError = isHi ? 'वर्तमान PIN अमान्य है!' : 'Current PIN is incorrect!');
                  return;
                }
                if (newPinCtrl.text.trim().length != 4) {
                  setDialogState(() => dialogError = isHi ? 'PIN 4 अंकों का होना चाहिए!' : 'PIN must be exactly 4 digits!');
                  return;
                }
                if (newPinCtrl.text.trim() != confirmPinCtrl.text.trim()) {
                  setDialogState(() => dialogError = isHi ? 'PIN मेल नहीं खा रहा है!' : 'PINs do not match!');
                  return;
                }

                await _settings.setUserPin(_currentUser, newPinCtrl.text.trim());
                await _settings.setAppLockEnabled(true);
                setState(() => _currentPin = newPinCtrl.text.trim());
                Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isHi ? '✅ 4-Digit PIN सफलतापूर्वक सेट हो गया!' : '✅ 4-Digit PIN successfully updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(isHi ? 'सुरक्षित करें' : 'Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpiSettingsDialog() {
    final upiCtrl = TextEditingController(text: _settings.upiId);
    final nameCtrl = TextEditingController(text: _settings.businessName);
    final isHi = _settings.isHindi;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4338CA)),
            const SizedBox(width: 8),
            Text(
              isHi ? 'UPI पेमेंट सेटिंग्स' : 'UPI Payment Settings',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHi
                  ? 'शुल्क प्राप्त करने के लिए अपनी UPI ID और लाइब्रेरी का नाम दर्ज करें:'
                  : 'Enter your UPI ID and Library Name to receive fee payments via QR code:',
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
                labelText: isHi ? 'लाइब्रेरी का नाम' : 'Library / Business Name',
                hintText: 'e.g. MyLibbook',
                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isHi ? 'रद्द करें' : 'Cancel')),
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
                    SnackBar(
                      content: Text(isHi ? '✅ UPI सेटिंग्स अपडेट हो गई!' : '✅ UPI settings updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: Text(isHi ? 'सुरक्षित करें' : 'Save Settings'),
          ),
        ],
      ),
    );
  }

  void _shareViaWhatsApp() async {
    const inviteMessage = 
        'Greetings! 🙏\n\n'
        'Looking to digitize and automate your Library Management operations?\n\n'
        'Check out *MyLibbook - Smart Library Management App* 📚✨\n\n'
        '🔥 *Key Features:*\n'
        '✅ Interactive Live Seat Arrangement Matrix\n'
        '✅ 1-Tap Direct WhatsApp Fee & Renewal Reminders\n'
        '✅ Dynamic UPI QR Code for Instant Payments\n'
        '✅ 4-Digit Quick PIN Security Lock\n'
        '✅ Automated Monthly Revenue & Due Fee Tracking\n\n'
        '📲 *Direct Android APK Download:*\n'
        '$apkDownloadUrl\n\n'
        '🌐 *Web Portal:*\n'
        '$webAppUrl\n\n'
        'Download today and simplify your library administration! 🚀';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(inviteMessage)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _copyInviteLink() {
    Clipboard.setData(const ClipboardData(text: apkDownloadUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_settings.isHindi ? '📋 लिंक क्लिपबोर्ड पर कॉपी हो गया!' : '📋 Invite link copied to clipboard!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _openSupportWhatsApp() async {
    const phone = '919170717240';
    final msg = Uri.encodeComponent('Hello MyLibbook Team, I need technical assistance with the application.');
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
          // 1. INVITE FRIENDS TO USE MYLIBBOOK
          _buildSectionHeader(isHi ? 'मित्रों को आमंत्रित करें' : 'Invite Friends', Icons.card_giftcard_rounded),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4338CA),
                  Color(0xFF312E81),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded, color: Colors.amberAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHi ? 'MyLibbook का उपयोग करने के लिए मित्रों को आमंत्रित करें' : 'Invite Friends to Use MyLibbook',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isHi
                                  ? 'साथी लाइब्रेरी संचालकों के साथ ऐप साझा करें'
                                  : 'Share MyLibbook with other library owners & friends',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _shareViaWhatsApp,
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: Text(
                            isHi ? 'WhatsApp पर शेयर करें' : 'Share via WhatsApp',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _copyInviteLink,
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: Text(
                            isHi ? 'लिंक कॉपी करें' : 'Copy Link',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. SECURITY & 4-DIGIT APP LOCK
          _buildSectionHeader(isHi ? 'सुरक्षा एवं 4-Digit ऐप लॉक' : 'Security & 4-Digit App Lock', Icons.lock_clock_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      isHi ? '4-Digit Quick PIN लॉक' : '4-Digit Quick PIN Lock',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E1B4B)),
                    ),
                    subtitle: Text(
                      isHi ? 'ऐप खोलते ही 4-अंकीय PIN द्वारा तुरंत अनलॉक करें' : 'Enable instant 4-digit PIN unlock on app launch',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
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
                        isHi ? '4-Digit PIN बदलें' : 'Change 4-Digit PIN',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E1B4B)),
                      ),
                      subtitle: Text(
                        _currentPin != null ? (isHi ? 'PIN सक्रिय है (••••)' : 'PIN is active (••••)') : (isHi ? 'कोई PIN सेट नहीं है' : 'No PIN configured'),
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
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

          // 3. THEME MODE SECTION
          _buildSectionHeader(isHi ? 'थीम मोड' : 'Appearance & Theme', Icons.palette_outlined),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(isHi ? 'लाइट मोड' : 'Light Theme', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                    subtitle: Text(isHi ? 'हल्का रंग' : 'Bright interface', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                    value: ThemeMode.light,
                    groupValue: _settings.themeMode,
                    activeColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                    onChanged: (mode) {
                      if (mode != null) _settings.setThemeMode(mode);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(isHi ? 'डार्क मोड' : 'Dark Theme', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                    subtitle: Text(isHi ? 'गहरा रंग' : 'Dark interface', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                    value: ThemeMode.dark,
                    groupValue: _settings.themeMode,
                    activeColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                    onChanged: (mode) {
                      if (mode != null) _settings.setThemeMode(mode);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(isHi ? 'सिस्टम डिफॉल्ट' : 'System Default', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                    subtitle: Text(isHi ? 'फ़ोन सेटिंग के अनुसार' : 'Follow phone settings', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                    value: ThemeMode.system,
                    groupValue: _settings.themeMode,
                    activeColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                    onChanged: (mode) {
                      if (mode != null) _settings.setThemeMode(mode);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. LANGUAGE SECTION
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
                  const SizedBox(width: 12),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. UPI PAYMENT CONFIGURATION
          _buildSectionHeader(isHi ? 'UPI पेमेंट सेटिंग्स' : 'UPI Payment Configuration', Icons.qr_code_rounded),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
              ),
              title: Text(_settings.upiId, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
              subtitle: Text(
                isHi ? 'प्राप्तकर्ता का नाम: ${_settings.businessName}' : 'Beneficiary Name: ${_settings.businessName}',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                onPressed: _showUpiSettingsDialog,
                child: Text(isHi ? 'संपादित करें' : 'Edit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 6. HELP & SUPPORT SECTION
          _buildSectionHeader(isHi ? 'सहायता एवं संपर्क' : 'Help & Support', Icons.support_agent_rounded),
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
                  title: Text(isHi ? 'WhatsApp सहायता' : 'WhatsApp Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                  subtitle: Text(isHi ? 'सीधे WhatsApp पर तकनीकी सहायता प्राप्त करें' : 'Get instant technical support on WhatsApp', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
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
                  title: Text(isHi ? 'ईमेल सहायता' : 'Email Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                  subtitle: Text('kushbinary@gmail.com', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final uri = Uri.parse('mailto:kushbinary@gmail.com?subject=MyLibbook%20Support');
                    try {
                      await launchUrl(uri);
                    } catch (_) {}
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.system_update_rounded, color: Colors.orange),
                  ),
                  title: Text(isHi ? 'ऐप अपडेट करें' : 'Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                  subtitle: Text(isHi ? 'नया वर्ज़न डाउनलोड करें' : 'Download latest version', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                  trailing: const Icon(Icons.download_rounded),
                  onTap: () async {
                    final uri = Uri.parse('https://library-management-1-k8rn.onrender.com/download-apk');
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open update link.')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 7. ABOUT US & COPYRIGHT SECTION
          _buildSectionHeader(isHi ? 'ऐप के बारे में' : 'About MyLibbook', Icons.info_outline_rounded),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MyLibbook Pro', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                            Text('Smart. Organized. Knowledge.', style: TextStyle(color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Version 1.0.0 (Official Release Build)', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '© 2026 MyLibbook. All Rights Reserved.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4338CA)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Designed & Developed by Kush Binary',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E1B4B), letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
