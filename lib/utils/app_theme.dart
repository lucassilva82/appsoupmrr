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
  // Azul premium para modo GESTOR
  static const superBlue = Color(0xFF003087);
  static const superBlueDark = Color(0xFF0A1E3D);

  // Superfícies modo claro
  static const lightBg = Color(0xFFF0F4F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);

  // Superfícies modo escuro
  static const darkBg = Color(0xFF03050A);
  static const darkSurface = Color(0xFF080B11);
  static const darkCard = Color(0xFF0E1219);
  static const darkBorder = Color(0xFF1C222A);
}

// ─── Tamanhos de ícone ───────────────────────────────────────────────────────
// Tokens únicos para todo o app. A regra é usar um destes valores e nunca um
// número solto: tamanhos arbitrários quebram o ritmo visual entre as telas.
class AppIconSize {
  AppIconSize._();

  static const xxs = 12.0; // selos e chips, ao lado de texto pequeno
  static const xs = 16.0; // dentro de texto, listas densas
  static const sm = 20.0; // campos, chips, linhas de lista
  static const md = 24.0; // padrão — barra inferior, app bar, ações
  static const lg = 28.0; // botões do menu principal
  static const xl = 32.0; // ilustrações e destaques
}

// ─── Fábricas de tema ─────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData build({
    required bool isDark,
    required bool isSuperUser,
  }) {
    final primary = _primary(isDark, isSuperUser);
    final corErro = isDark ? Colors.redAccent : Colors.red;
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
      // O fundo é pintado uma vez pelo MaterialApp (ver main.dart), para
      // que as superfícies translúcidas tenham o que deixar transparecer.
      scaffoldBackgroundColor: Colors.transparent,

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
      // Superfície translúcida: o fundo do app (com manchas suaves) aparece
      // por trás, dando o acabamento de vidro em todas as telas sem mexer
      // em cada uma. A borda é o que separa o card do fundo.
      // ── Chips ──────────────────────────────────────────────────────────────
      // Mesma regra do seletor segmentado: selecionado é tingido, não pintado
      // de cor cheia. Vale para os ChoiceChip e FilterChip das cinco telas
      // que usam filtro (férias, mapa da força, comandos…).
      chipTheme: ChipThemeData(
        backgroundColor: onSurface.withOpacity(isDark ? 0.05 : 0.035),
        selectedColor: primary.withOpacity(isDark ? 0.26 : 0.16),
        checkmarkColor: primary,
        showCheckmark: false,
        side: BorderSide(color: onSurface.withOpacity(0.15)),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurface.withOpacity(0.70),
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // ── Seletor segmentado ─────────────────────────────────────────────────
      // O padrão do Material pinta o segmento ativo de cor cheia, que com a
      // base escura vira o elemento mais claro da tela. Aqui ele é tingido,
      // igual aos chips e à pílula da barra inferior.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((estados) {
            if (estados.contains(WidgetState.selected)) {
              return primary.withOpacity(isDark ? 0.26 : 0.16);
            }
            return onSurface.withOpacity(isDark ? 0.05 : 0.035);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((estados) {
            if (estados.contains(WidgetState.selected)) return primary;
            return onSurface.withOpacity(0.62);
          }),
          side: WidgetStateProperty.resolveWith((estados) {
            final selecionado = estados.contains(WidgetState.selected);
            return BorderSide(
              color: selecionado
                  ? primary.withOpacity(0.55)
                  : onSurface.withOpacity(0.15),
            );
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // ── Diálogos e bottom sheets ───────────────────────────────────────────
      // Dezoito AlertDialogs espalhados pelo app herdam daqui; sem isso cada
      // um aparece como um bloco opaco sobre superfícies de vidro.
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? card.withOpacity(0.86)
            : Colors.white.withOpacity(0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.80),
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? card.withOpacity(0.86)
            : Colors.white.withOpacity(0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // cardColor (API antiga) acompanha o cardTheme: dez telas pintam
      // superfícies com theme.cardColor e ficavam opacas no meio do vidro.
      cardColor:
          isDark ? card.withOpacity(0.72) : Colors.white.withOpacity(0.78),

      cardTheme: CardThemeData(
        color: isDark
            ? card.withOpacity(0.72)
            : Colors.white.withOpacity(0.78),
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withOpacity(0.06),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.white.withOpacity(0.80),
            width: 0.8,
          ),
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
      // ── Campos de formulário ───────────────────────────────────────────────
      // Mesmo acabamento das superfícies do app: preenchimento translúcido,
      // borda fininha e anel de foco na cor primária. Um só lugar define
      // todos os campos — telas não devem redefinir borda nem fundo.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.055)
            : Colors.white.withOpacity(0.70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.85),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: corErro, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: corErro, width: 1.6),
        ),

        // O rótulo sobe e some dentro da borda; a cor muda no foco para o
        // usuário ver onde está sem depender só do anel.
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: onSurface.withOpacity(0.60),
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: onSurface.withOpacity(0.38),
          fontSize: 14,
        ),
        helperStyle: TextStyle(
          color: onSurface.withOpacity(0.55),
          fontSize: 11.5,
        ),
        // Erro junto do campo, legível — não um fiapo de 10px.
        errorStyle: TextStyle(
          color: corErro,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        errorMaxLines: 2,
        prefixIconColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.focused)
              ? primary
              : onSurface.withOpacity(0.45),
        ),
        suffixIconColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.focused)
              ? primary
              : onSurface.withOpacity(0.45),
        ),
        // 16/15 deixa a altura do campo acima dos 48dp de alvo de toque.
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
    if (isSuperUser) return isDark ? AppColors.lightBlue : AppColors.superBlue;
    return isDark ? AppColors.lightBlue : AppColors.navy;
  }

  static Color _secondary(bool isDark, bool isSuperUser) {
    if (isSuperUser) return isDark ? AppColors.lightBlue : AppColors.blue;
    return isDark ? AppColors.blue : AppColors.blue;
  }

  // Gradiente AppBar — exposto para widgets que precisam
  static List<Color> appBarGradient({
    required bool isDark,
    required bool isSuperUser,
  }) {
    if (isDark) {
      return isSuperUser
          ? [const Color(0xFF05142A), const Color(0xFF030B18)]
          : [const Color(0xFF0A1726), AppColors.darkSurface];
    }
    // modo claro
    return isSuperUser
        ? [const Color(0xFF003D99), AppColors.superBlue] // azul royal → navy
        : [const Color(0xFF1976D2), AppColors.navy]; // azul médio → navy
  }
}
