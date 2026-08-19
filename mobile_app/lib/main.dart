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
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 16),
              bodyMedium: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14),
              titleMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 16),
              titleSmall: TextStyle(color: Color(0xFF1E1B4B), fontWeight: FontWeight.w800),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF4338CA),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.3),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shadowColor: const Color(0xFF4338CA).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              labelStyle: const TextStyle(color: Color(0xFF1E1B4B), fontWeight: FontWeight.w800, fontSize: 14),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w900, fontSize: 14),
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 13),
              prefixIconColor: const Color(0xFF4338CA),
              suffixIconColor: const Color(0xFF4338CA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.6),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.6),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4338CA), width: 2.2),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF6366F1),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Roboto',
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              bodyMedium: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600, fontSize: 14),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.3),
            ),
            cardTheme: CardThemeData(
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFF1E293B),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              labelStyle: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w800, fontSize: 14),
              floatingLabelStyle: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w900, fontSize: 14),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 13),
              prefixIconColor: const Color(0xFF818CF8),
              suffixIconColor: const Color(0xFF818CF8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF475569), width: 1.6),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF475569), width: 1.6),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2.2),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              contentTextStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF1E293B),
              modalBackgroundColor: Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFF334155),
              selectedColor: const Color(0xFF312E81),
              labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
              secondaryLabelStyle: const TextStyle(color: Colors.white),
              side: const BorderSide(color: Color(0xFF475569)),
            ),
            listTileTheme: const ListTileThemeData(
              textColor: Colors.white,
              iconColor: Color(0xFF818CF8),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFF334155),
            ),
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