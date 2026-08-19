import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/whatsapp_service.dart';
import 'services/settings_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WhatsappService.init();
  await SettingsManager().init();
  runApp(const LibraryApp());
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = SettingsManager();

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'MyLibbook',
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: const Color(0xFF4338CA),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF6366F1),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Roboto',
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}