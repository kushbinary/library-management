with open("lib/screens/add_student_screen.dart", "r") as f:
    content = f.read()

# 1. Import url_launcher
if "package:url_launcher/url_launcher.dart" not in content:
    content = content.replace("import 'package:shared_preferences/shared_preferences.dart';", "import 'package:shared_preferences/shared_preferences.dart';\nimport 'package:url_launcher/url_launcher.dart';")

# 2. Add whatsapp method inside class _AddStudentScreenState
whatsapp_method = """
  Future<void> _launchWhatsAppWelcome(Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final libraryName = prefs.getString('library_custom_business_name') ?? 'MyLibBook';
    
    final message = "Hello ${student.name},\\n\\nWelcome to $libraryName! 🎉\\n\\nYour admission is confirmed.\\nSeat Number: ${student.seatNumber}\\nValid Until: ${student.expiryDate}\\nTotal Fee: ₹${student.totalFee.toInt()}\\nPaid: ₹${student.paidAmount.toInt()}\\nDue: ₹${student.dueAmount.toInt()}\\n\\nThank you for choosing us!";
    
    String cleanPhone = student.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }
"""

if "_launchWhatsAppWelcome" not in content:
    # insert before widget build
    content = content.replace("  @override\n  Widget build(BuildContext context) {", whatsapp_method + "\n  @override\n  Widget build(BuildContext context) {")

# 3. Replace the success handler
old_success = """      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student "${student.name}" added successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context, true);
      } else {"""

new_success = """      if (success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success'),
              ],
            ),
            content: Text('${student.name} has been added successfully!\\nWould you like to send a welcome message?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Skip', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _launchWhatsAppWelcome(student);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.send),
                label: const Text('Send on WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      } else {"""

content = content.replace(old_success, new_success)

with open("lib/screens/add_student_screen.dart", "w") as f:
    f.write(content)
