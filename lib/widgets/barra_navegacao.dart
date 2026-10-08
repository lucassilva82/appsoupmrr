import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BarraNavegacao
//
// Barra inferior com a pílula deslizante no item ativo, como nas barras do
// iOS. No Android o acabamento é o da plataforma (superfície tonal), mas o
// comportamento é o mesmo.
//
// A área de toque de cada item respeita o mínimo de 44pt (iOS) / 48dp
// (Android), mesmo com o ícone sendo menor.
// ─────────────────────────────────────────────────────────────────────────────

class ItemNavegacao {
  final IconData icone;
  final IconData iconeAtivo;
  final String rotulo;
  final int contador;

  const ItemNavegacao({
    required this.icone,
    required this.iconeAtivo,
    required this.rotulo,
    this.contador = 0,
  });
}

class BarraNavegacao extends StatelessWidget {
  final List<ItemNavegacao> itens;
  final int indiceAtual;
  final ValueChanged<int> aoSelecionar;

  const BarraNavegacao({
    Key? key,
    required this.itens,
    required this.indiceAtual,
    required this.aoSelecionar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAndroid = Platform.isAndroid;

    final fundo = isAndroid
        ? (isDark
            ? Color.alphaBlend(
                theme.colorScheme.primary.withOpacity(0.08), AppColors.darkCard)
            : Colors.white)
        : (isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.72));

    final conteudo = Container(
      decoration: BoxDecoration(
        color: fundo,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final larguraItem = constraints.maxWidth / itens.length;

              // Arrastar o dedo pela barra move a seleção, como no iOS.
              int indicePorPosicao(double x) =>
                  (x ~/ larguraItem).clamp(0, itens.length - 1);

              void selecionarPorPosicao(double x) {
                final novo = indicePorPosicao(x);
                if (novo != indiceAtual) {
                  HapticFeedback.selectionClick();
                  aoSelecionar(novo);
                }
              }

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (d) =>
                    selecionarPorPosicao(d.localPosition.dx),
                onHorizontalDragUpdate: (d) =>
                    selecionarPorPosicao(d.localPosition.dx),
                child: Stack(
                // Sem isto o Stack joga a linha de itens para o topo (padrão
                // topStart) enquanto a pílula fica centralizada — era por isso
                // que o ícone ativo encostava na borda de cima da pílula.
                alignment: Alignment.center,
                children: [
                  // Pílula que desliza até o item ativo.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: larguraItem * indiceAtual,
                    top: 6,
                    bottom: 6,
                    width: larguraItem,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        width: larguraItem - 14,
                        height: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withOpacity(isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withOpacity(isDark ? 0.35 : 0.22),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      for (var i = 0; i < itens.length; i++)
                        Expanded(
                          child: _Item(
                            item: itens[i],
                            ativo: i == indiceAtual,
                            aoTocar: () => aoSelecionar(i),
                          ),
                        ),
                    ],
                  ),
                ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // Vidro só no iOS: no Android a barra segue a superfície do Material.
    if (isAndroid) {
      return Material(
        elevation: isDark ? 0 : 3,
        color: Colors.transparent,
        child: conteudo,
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: conteudo,
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final ItemNavegacao item;
  final bool ativo;
  final VoidCallback aoTocar;

  const _Item({required this.item, required this.ativo, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = ativo
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.62);

    return Semantics(
      selected: ativo,
      button: true,
      label: item.rotulo,
      child: InkResponse(
        onTap: aoTocar,
        radius: 36,
        containedInkWell: false,
        child: SizedBox(
          height: 50, // acima do mínimo de 44pt / 48dp; o conteúdo
          // interno ocupa ~40, então fica dentro da pílula
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Caixa fixa de AppIconSize.md: todos os ícones ocupam
                  // exatamente o mesmo espaço, ativos ou não. Sem isso o item
                  // ativo fica com outra altura e a linha de ícones desalinha.
                  SizedBox(
                    width: AppIconSize.md,
                    height: AppIconSize.md,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Icon(
                          ativo ? item.iconeAtivo : item.icone,
                          key: ValueKey(ativo),
                          size: AppIconSize.md,
                          color: cor,
                        ),
                      ),
                    ),
                  ),
                  if (item.contador > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 1.4,
                          ),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          item.contador > 9 ? '9+' : '${item.contador}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                  color: cor,
                ),
                child: Text(item.rotulo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
