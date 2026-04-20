import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData lightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kForest,
    brightness: Brightness.light,
    primary: kForest,
    onPrimary: Colors.white,
    secondary: kCoral,
    surface: Colors.white,
    onSurface: kInk,
  );
  return _buildTheme(base);
}

ThemeData darkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kForest,
    brightness: Brightness.dark,
    primary: kDarkPrimary,
    onPrimary: kDarkBg,
    secondary: kCoral,
    surface: kDarkSurface,
    onSurface: kDarkText,
  );
  return _buildTheme(base);
}

ThemeData _buildTheme(ColorScheme cs) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.brightness == Brightness.light
        ? kPaper
        : kDarkBg,
    extensions: <ThemeExtension<dynamic>>[_clerkTheme(cs)],
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: cs.brightness == Brightness.light ? kLine : kDarkLine,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: cs.brightness == Brightness.light ? kLine : kDarkLine,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cs.surface,
      selectedColor: cs.brightness == Brightness.light ? kMint : kDarkSurface,
      labelStyle: TextStyle(color: cs.onSurface, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: cs.brightness == Brightness.light ? kLine : kDarkLine,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cs.brightness == Brightness.light
            ? kInk
            : kDarkPrimary,
        foregroundColor: cs.brightness == Brightness.light
            ? Colors.white
            : kDarkBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.brightness == Brightness.light ? kLine : kDarkLine,
          width: 0.5,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cs.brightness == Brightness.light ? kLine : kDarkLine,
      thickness: 0.5,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.brightness == Brightness.light ? kPaper : kDarkBg,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.brightness == Brightness.light
          ? Colors.white
          : kDarkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

ClerkThemeExtension _clerkTheme(ColorScheme cs) {
  final isLight = cs.brightness == Brightness.light;
  return ClerkThemeExtension(
    colors: ClerkThemeColors(
      background: isLight ? Colors.white : kDarkSurface,
      altBackground: isLight
          ? Colors.black.withValues(alpha: .06)
          : Colors.black.withValues(alpha: .18),
      borderSide: isLight ? const Color(0xFFE4ECE7) : kDarkLine,
      text: isLight ? kInk : kDarkText,
      icon: isLight ? kMuted : kDarkMuted,
      lightweightText: isLight ? kMuted : kDarkMuted,
      error: const Color(0xFFE24B4B),
      accent: isLight ? kForest : kDarkPrimary,
    ),
  );
}
