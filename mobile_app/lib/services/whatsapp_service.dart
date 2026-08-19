class WhatsappService {
  static Future<void> init() async {
    // WhatsApp service initialization
  }

  static Future<bool> sendRegistrationMessage({
    required String name,
    required String phone,
    required String seatNumber,
    required String timing,
  }) async {
    // Simulated WhatsApp message
    return true;
  }

  static Future<bool> sendExpiryReminder({
    required String name,
    required String phone,
    required String expiryDate,
  }) async {
    // Simulated WhatsApp message
    return true;
  }
}
