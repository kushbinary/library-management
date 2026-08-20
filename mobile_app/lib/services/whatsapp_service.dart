import 'package:url_launcher/url_launcher.dart';

class WhatsappService {
  static Future<void> init() async {}

  static Future<bool> openWhatsApp(String phone, String message) async {
    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.length == 10) {
      formattedPhone = '91$formattedPhone'; // Assuming India (+91)
    }
    final url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
