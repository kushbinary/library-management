import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/whatsapp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WhatsappService.init();
  runApp(const LibraryApp());
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Library Management',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}