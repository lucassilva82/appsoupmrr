import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── Paleta de cores PMRR ────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Azul das ações. É a base do degradê do botão de login, e o único tom da
  // família que passa nos 3:1 de contorno de controle sobre o fundo escuro —
  // o navy fica em 1,24:1, ou seja, o botão não se delimita do fundo.
  static const acao = Color(0xFF0565B5);
  static const acaoClara = Color(0xFF087BCC);

  // Identidade visual PMRR
  static const navy = Color(0xFF002154);

  /// Cor das telas nativas de abertura: `LaunchScreen.storyboard`,
  /// `launch_background.xml` e a splash do Android 12.
  ///
  /// É o topo do degradê da app bar no modo escuro (ver
  /// `AppTheme.appBarGradient`). O app abre na mesma cor da barra que o
  /// militar vai ver em todas as telas — e a abertura do Flutter continua
  /// esse degradê, então a emenda entre nativo e Flutter não aparece.
  ///
  /// Precisa acompanhar o degradê da app bar se ele mudar. Tem de ser cor
  /// chapada: a splash do Android 12 não aceita degradê, só uma cor.
  static const aberturaFundo = Color(0xFF0A1726);
  static const blue = Color(0xFF1565C0);
  static const lightBlue = Color(0xFF42A5F5);
  static const gold = Color(0xFFFFB300);
  static const goldLight = Color(0xFFFFD54F);

  /// Dourado como texto ou ícone (selo do nível, aba ativa do gestor). O
  /// FFB300 só tem contraste no tema escuro: no claro dá 1,5:1 e o selo
  /// "some". No claro, este tom (6:1 sobre o fundo e sobre o selo tingido).
  /// DESIGN §6. O dourado claro continua bom como tinta de fundo (alfa).
  static const douradoEscuro = Color(0xFF7A4F00);
  static Color douradoTexto(Brightness b) => b == Brightness.dark ? gold : douradoEscuro;

  /// Âmbar de atenção no tema claro (o C77800 dá 2,9:1 sobre o fundo claro).
  static const atencaoEscura = Color(0xFF8A5A00);
  // Azul premium para modo GESTOR
  static const superBlue = Color(0xFF003087);
  static const superBlueDark = Color(0xFF0A1E3D);

  // Superfícies modo claro
  static const lightBg = Color(0xFFF0F4F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);

  // Verde e vermelho semânticos, por modo. O par escuro do Material
  // (#2E7D32 / #C62828) fica em 3,7:1 e 3,4:1 sobre a base nova — reprova nos
  // 4.5:1 de texto. Em fundo escuro usa-se a versão clara.
  static const sucesso = Color(0xFF14713B);
  static const sucessoEscuro = Color(0xFF6EE7A0);
  static const falha = Color(0xFFB3261E);
  static const falhaEscuro = Color(0xFFFF9E9E);

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
    final onPrimary = Colors.white;

    // Botões cheios: degradê na cor de ação, o mesmo do botão de login
    // (_botaoPrincipal, no fim do arquivo). Medido sobre o fundo escuro:
    // 3,25:1 de contorno (o navy dava 1,24:1) e 5,94:1 de branco por cima.
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
      // Barras internas do protótipo (`.cab-int`): o fundo é o vidro do
      // FundoBarraVidro; o texto e os ícones seguem o tema.
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xB8080C12) : const Color(0xC7F8FAFD),
        foregroundColor: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: defaultTargetPlatform == TargetPlatform.iOS,
        titleTextStyle: TextStyle(
          fontSize: defaultTargetPlatform == TargetPlatform.iOS ? 17 : 22,
          fontWeight: defaultTargetPlatform == TargetPlatform.iOS ? FontWeight.w600 : FontWeight.w400,
          color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1A2E),
        ),
        iconTheme: IconThemeData(color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1A2E)),
      ),

      // ── Bottom Nav ──────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedItemColor: isSuperUser ? AppColors.douradoTexto(isDark ? Brightness.dark : Brightness.light) : primary,
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

      // Folha opaca: a 86% o texto da tela de trás aparecia no meio do
      // texto da folha (visto no "O que mudou" do contracheque, 2.2).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? card : Colors.white,
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
      elevatedButtonTheme: ElevatedButtonThemeData(style: _botaoPrincipal(isDark)),

      // ── FilledButton ───────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(style: _botaoPrincipal(isDark)),

      // ── OutlinedButton ─────────────────────────────────────────────────────
      // Secundário (DESIGN §5): vidro leve, contorno fino na primária e o
      // mesmo raio e altura do principal, para os dois lado a lado casarem.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: isDark ? Colors.white.withValues(alpha: .04) : Colors.white.withValues(alpha: .55),
          side: BorderSide(color: primary.withValues(alpha: .55), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: .2),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
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
          color: onSurface.withOpacity(0.62),
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: onSurface.withOpacity(0.38),
          fontSize: 14,
        ),
        helperStyle: TextStyle(
          color: onSurface.withOpacity(0.62),
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

/// Botão principal do app (DESIGN §5 e §11): o mesmo acabamento do botão
/// Entrar do login, para todos os botões cheios. Degradê na cor de ação
/// (mais clara em cima), um fio de luz no alto, sombra azul suave e, ao
/// apertar, escurece e a sombra recolhe. Desabilitado: chapado e apagado.
/// O contraste do branco sobre o tom mais claro do degradê passa de 4,5:1.
ButtonStyle _botaoPrincipal(bool isDark) => estiloBotaoCor(AppColors.acao, clara: AppColors.acaoClara, escuro: isDark);

/// O mesmo acabamento em outra cor (verde de concluir, vermelho de excluir).
/// [clara] é o tom de cima do degradê; sem ele, a própria cor clareada.
/// Com [cheioDesligado], o botão desabilitado continua cheio (botão ocupado,
/// com o indicador de carregamento dentro).
ButtonStyle estiloBotaoCor(Color cor, {Color? clara, bool escuro = true, bool cheioDesligado = false}) {
  final topo = clara ?? Color.lerp(cor, Colors.white, .16)!;
  final textoClaro = ThemeData.estimateBrightnessForColor(cor) == Brightness.dark;
  final texto = textoClaro ? Colors.white : const Color(0xFF14171F);
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) && !cheioDesligado ? texto.withValues(alpha: .7) : texto),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed)
        ? Colors.black.withValues(alpha: .14)
        : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
            ? Colors.white.withValues(alpha: .08)
            : null),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    // 52 de altura mínima: com 48 o indicador de carregamento ficava
    // espremido dentro do botão.
    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
    textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: .2)),
    backgroundBuilder: (context, estados, filho) {
      final desligado = estados.contains(WidgetState.disabled) && !cheioDesligado;
      final apertado = estados.contains(WidgetState.pressed);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: desligado
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topo, cor],
                ),
          color: desligado ? cor.withValues(alpha: .40) : null,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: desligado ? 0 : .22), width: 1),
          ),
          boxShadow: desligado
              ? null
              : [
                  BoxShadow(
                    color: cor.withValues(alpha: escuro ? (apertado ? .25 : .45) : (apertado ? .18 : .32)),
                    blurRadius: apertado ? 6 : 16,
                    offset: Offset(0, apertado ? 2 : 6),
                    spreadRadius: -4,
                  ),
                ],
        ),
        child: filho,
      );
    },
  );
}
