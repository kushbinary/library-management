class AppConstants {
  // Threshold in days to consider a membership "expiring soon"
  static const int expiringSoonThresholdDays = 5;

  // WhatsApp Message Templates
  
  static String getExpiredMessage(String memberName, String seatNumber) {
    return "Namaste $memberName ji, aapki library membership expire ho chuki hai. Kripya jaldi se apni fees renew karwayein taaki aapki seat $seatNumber active rahe. Dhanyavaad!";
  }

  static String getExpiringSoonMessage(String memberName, String expiryDate, int daysLeft) {
    return "Namaste $memberName ji, aapki membership $expiryDate ko expire hone wali hai (bas $daysLeft din baaki hain). Time se renew karwa lein, taaki koi rukavat na ho.";
  }

  static String getActiveMessage(String memberName, String libraryName) {
    return "Namaste $memberName ji, $libraryName se sampark kar rahe hain. Koi bhi query ho to batayein!";
  }
}
