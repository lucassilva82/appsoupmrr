import 'dart:ui';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FundoBarraVidro
//
// Fundo translúcido das app bars: degradê institucional com transparência e
// desfoque do conteúdo que passa por baixo, como nas barras do iOS. Vai no
// `flexibleSpace` de qualquer AppBar; a barra em si fica transparente.
//
// É o mesmo acabamento da CustomAppBar e da barra inferior, para o app não
// ter três tratamentos diferentes de superfície.
// ─────────────────────────────────────────────────────────────────────────────

class FundoBarraVidro extends StatelessWidget {
  /// Cantos arredondados embaixo. O padrão é reto, igual à barra da tela
  /// inicial — era isso que deixava as telas internas com outro desenho.
  final bool arredondado;

  const FundoBarraVidro({Key? key, this.arredondado = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Barra das telas internas do protótipo (`.cab-int`): vidro escuro (ou
    // claro, no tema claro) com desfoque e um fio embaixo. Não pinta mais o
    // degradê institucional, que deixava as telas internas com outra cara.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raio = arredondado
        ? const BorderRadius.vertical(bottom: Radius.circular(20))
        : BorderRadius.zero;

    return ClipRRect(
      borderRadius: raio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xB8080C12) // rgba(8, 12, 18, .72)
                : const Color(0xC7F8FAFD), // rgba(248, 250, 253, .78)
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFF002154).withValues(alpha: 0.10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
