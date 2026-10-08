import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CartaoVidro
//
// Superfície translúcida no padrão do iOS: desfoque do que está atrás,
// degradê suave de claro para transparente e borda fininha. Serve de base
// para os cards e botões do app sem alterar o conteúdo deles.
// ─────────────────────────────────────────────────────────────────────────────

class CartaoVidro extends StatelessWidget {
  final Widget child;
  final double raio;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Cor que tinge o vidro (ex.: dourado no item destacado do menu).
  final Color? tingimento;

  /// Intensidade do desfoque do fundo.
  final double desfoque;

  const CartaoVidro({
    Key? key,
    required this.child,
    this.raio = 16,
    this.padding,
    this.onTap,
    this.tingimento,
    this.desfoque = 18,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cor = tingimento;

    // No claro o vidro clareia; no escuro, escurece de leve. Em ambos, a
    // borda é o que dá o contorno — como nas superfícies do iOS.
    final base = cor ?? (isDark ? Colors.white : Colors.white);
    final opacidadeTopo = cor != null
        ? (isDark ? 0.26 : 0.20)
        : (isDark ? 0.10 : 0.72);
    final opacidadeBase = cor != null
        ? (isDark ? 0.14 : 0.10)
        : (isDark ? 0.04 : 0.48);

    final borda = (cor ?? Colors.white)
        .withOpacity(cor != null ? 0.35 : (isDark ? 0.14 : 0.70));

    final conteudo = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withOpacity(opacidadeTopo),
            base.withOpacity(opacidadeBase),
          ],
        ),
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: borda, width: 0.8),
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: desfoque, sigmaY: desfoque),
        child: onTap == null
            ? conteudo
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: (cor ?? theme.colorScheme.primary)
                      .withOpacity(0.10),
                  highlightColor: (cor ?? theme.colorScheme.primary)
                      .withOpacity(0.06),
                  child: conteudo,
                ),
              ),
      ),
    );
  }
}

/// Fundo com manchas de cor suaves, para o vidro ter o que desfocar.
/// Sem isso o efeito some em telas de fundo liso.
class FundoSuave extends StatelessWidget {
  final Widget child;

  const FundoSuave({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;

    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -60,
          child: _Mancha(
            cor: primaria.withOpacity(isDark ? 0.22 : 0.16),
            tamanho: 260,
          ),
        ),
        Positioned(
          top: 180,
          right: -90,
          child: _Mancha(
            cor: AppColors.lightBlue.withOpacity(isDark ? 0.16 : 0.14),
            tamanho: 280,
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: _Mancha(
            cor: AppColors.gold.withOpacity(isDark ? 0.10 : 0.10),
            tamanho: 240,
          ),
        ),
        child,
      ],
    );
  }
}

class _Mancha extends StatelessWidget {
  final Color cor;
  final double tamanho;

  const _Mancha({required this.cor, required this.tamanho});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [cor, cor.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}
