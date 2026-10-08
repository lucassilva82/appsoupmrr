import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CartaoVidro
//
// Superfície adaptativa por plataforma:
//
//  • iOS      — vidro: desfoque do que está atrás, degradê suave e borda
//               fininha, como as superfícies do sistema.
//  • Android  — Material 3: superfície tonal com leve elevação, que é o
//               padrão da plataforma. Blur pesado ali destoa e custa caro
//               em aparelhos mais simples.
//
// Em ambos o conteúdo é o mesmo; muda só o acabamento.
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

    if (Platform.isAndroid) return _materialVersao(context, theme, isDark, cor);

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
/// Sem isso o efeito some: vidro sobre fundo liso vira só um retângulo preto.
/// As manchas ficam presas à viewport (não rolam com o conteúdo), que é o
/// comportamento do iOS, e são posicionadas em fração da tela para cobrir
/// qualquer tamanho de aparelho.
class FundoSuave extends StatelessWidget {
  final Widget child;

  const FundoSuave({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, c) {
        final l = c.maxWidth;
        final a = c.maxHeight;

        return Stack(
          children: [
            // Degradê de base: tira o preto chapado e dá direção à luz.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Color.alphaBlend(
                                  primaria.withOpacity(0.16), AppColors.darkBg),
                              AppColors.darkBg,
                              Color.alphaBlend(
                                  AppColors.navy.withOpacity(0.55),
                                  AppColors.darkBg),
                            ]
                          : [
                              Color.alphaBlend(
                                  primaria.withOpacity(0.10),
                                  AppColors.lightBg),
                              AppColors.lightBg,
                              Color.alphaBlend(
                                  AppColors.lightBlue.withOpacity(0.10),
                                  AppColors.lightBg),
                            ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Manchas espalhadas pela altura toda — antes só havia três perto
            // das bordas e o miolo da tela ficava sem nada para desfocar.
            Positioned(
              top: -a * 0.10,
              left: -l * 0.25,
              child: _Mancha(
                cor: primaria.withOpacity(isDark ? 0.30 : 0.18),
                tamanho: l * 0.95,
              ),
            ),
            Positioned(
              top: a * 0.14,
              right: -l * 0.30,
              child: _Mancha(
                cor: AppColors.lightBlue.withOpacity(isDark ? 0.20 : 0.16),
                tamanho: l * 0.90,
              ),
            ),
            Positioned(
              top: a * 0.42,
              left: -l * 0.20,
              child: _Mancha(
                cor: AppColors.gold.withOpacity(isDark ? 0.10 : 0.10),
                tamanho: l * 0.75,
              ),
            ),
            Positioned(
              top: a * 0.58,
              right: -l * 0.18,
              child: _Mancha(
                cor: primaria.withOpacity(isDark ? 0.22 : 0.14),
                tamanho: l * 0.85,
              ),
            ),
            Positioned(
              bottom: -a * 0.08,
              left: l * 0.05,
              child: _Mancha(
                cor: AppColors.lightBlue.withOpacity(isDark ? 0.16 : 0.12),
                tamanho: l * 0.95,
              ),
            ),

            child,
          ],
        );
      },
    );
  }
}

extension _VersaoMaterial on CartaoVidro {
  /// Android: superfície tonal do Material 3 em vez de vidro.
  Widget _materialVersao(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color? cor,
  ) {
    final superficie = cor != null
        ? Color.alphaBlend(
            cor.withOpacity(isDark ? 0.22 : 0.14),
            theme.colorScheme.surface,
          )
        : (isDark
            ? Color.alphaBlend(
                theme.colorScheme.primary.withOpacity(0.08),
                AppColors.darkCard,
              )
            : Colors.white);

    return Material(
      color: superficie,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withOpacity(0.10),
      borderRadius: BorderRadius.circular(raio),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(raio),
            border: Border.all(
              color: (cor ?? theme.colorScheme.outlineVariant)
                  .withOpacity(cor != null ? 0.45 : (isDark ? 0.35 : 0.55)),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
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
