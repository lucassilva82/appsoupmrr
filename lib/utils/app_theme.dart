import 'package:flutter/material.dart';

// ─── Paleta de cores PMRR ────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Identidade visual PMRR
  static const navy = Color(0xFF002154);
  static const blue = Color(0xFF1565C0);
  static const lightBlue = Color(0xFF42A5F5);
  static const gold = Color(0xFFFFB300);
  static const goldLight = Color(0xFFFFD54F);
  static const superRed = Color(0xFF7B2D00);

  // Superfícies modo claro
  static const lightBg = Color(0xFFF0F4F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);

  // Superfícies modo escuro
  static const darkBg = Color(0xFF0D1117);
  static const darkSurface = Color(0xFF161B22);
  static const darkCard = Color(0xFF21262D);
  static const darkBorder = Color(0xFF30363D);
}

// ─── Fábricas de tema ─────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData build({
    required bool isDark,
    required bool isSuperUser,
  }) {
    final primary = _primary(isDark, isSuperUser);
    final secondary = _secondary(isDark, isSuperUser);
    final onPrimary = isDark && isSuperUser ? Colors.black : Colors.white;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final onSurface =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1A2E);
    final divider = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onPrimary,
        error: isDark ? Colors.redAccent : Colors.red,
        onError: Colors.white,
        background: bgColor,
        onBackground: onSurface,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: bgColor,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkSurface : primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ── Bottom Nav ──────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedItemColor: isSuperUser ? AppColors.gold : primary,
        unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: card,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? BorderSide(color: AppColors.darkBorder, width: 1)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      // ── ElevatedButton ──────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: isDark ? 0 : 2,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      // ── InputDecoration ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        labelStyle:
            TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        hintStyle:
            TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),

      // ── ListTile ────────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: isDark ? Colors.grey[400] : Colors.grey[700],
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),

      // ── Switch ──────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? primary : Colors.grey,
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected)
              ? primary.withOpacity(0.4)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  static Color _primary(bool isDark, bool isSuperUser) {
    if (isSuperUser) return isDark ? AppColors.gold : AppColors.superRed;
    return isDark ? AppColors.lightBlue : AppColors.navy;
  }

  static Color _secondary(bool isDark, bool isSuperUser) {
    if (isSuperUser) return isDark ? AppColors.goldLight : AppColors.gold;
    return isDark ? AppColors.blue : AppColors.blue;
  }

  // Gradiente AppBar — exposto para widgets que precisam
  static List<Color> appBarGradient({
    required bool isDark,
    required bool isSuperUser,
  }) {
    if (isSuperUser) {
      return isDark
          ? [const Color(0xFF3D1800), const Color(0xFF1A0A00)]
          : [const Color(0xFF9E3A00), AppColors.superRed];
    }
    return isDark
        ? [const Color(0xFF1E3A5F), AppColors.darkSurface]
        : [AppColors.lightBlue, AppColors.navy];
  }
}
