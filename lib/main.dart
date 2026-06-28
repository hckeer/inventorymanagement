import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FilmRentalApp(),
    ),
  );
}

class FilmRentalApp extends ConsumerWidget {
  const FilmRentalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CineRent',
      theme: _buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme() {
    const fontFamily = 'Outfit';

    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF1A1A24),
        surfaceContainerHighest: Color(0xFF252533),
        primary: Color(0xFFE8A838),
        primaryContainer: Color(0xFFFFC94A),
        onPrimary: Color(0xFF0F0F13),
        onSurface: Color(0xFFEEEEF5),
        onSurfaceVariant: Color(0xFF9999AA),
        error: Color(0xFFFF5252),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F13),
      textTheme: base.textTheme
          .apply(fontFamily: fontFamily)
          .copyWith(
            displayLarge: base.textTheme.displayLarge?.copyWith(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              color: const Color(0xFFEEEEF5),
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEEEEF5),
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontFamily: fontFamily,
              color: const Color(0xFFEEEEF5),
            ),
            labelSmall: base.textTheme.labelSmall?.copyWith(
              fontFamily: fontFamily,
              letterSpacing: 0.8,
              color: const Color(0xFF9999AA),
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF252533)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF252533)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8A838), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9999AA)),
        hintStyle: const TextStyle(color: Color(0xFF9999AA)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8A838),
          foregroundColor: const Color(0xFF0F0F13),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A24),
        indicatorColor: const Color(0xFFE8A838).withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFE8A838));
          }
          return const IconThemeData(color: Color(0xFF9999AA));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              color: Color(0xFFE8A838),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            color: Color(0xFF9999AA),
            fontSize: 12,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF252533)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF252533),
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F13),
        foregroundColor: Color(0xFFEEEEF5),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEEEEF5),
        ),
      ),
    );
  }
}
