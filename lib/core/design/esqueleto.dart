import 'package:flutter/material.dart';

import '../../widgets/vidro.dart';

/// Carregamento com a forma do conteúdo (SOUPM_2_2 §15.2), no lugar do
/// círculo girando: blocos na cor do texto a 8%, pulsando devagar. Com
/// "Reduzir movimento" ligado, fica parado. O leitor de tela ouve só
/// "Carregando".
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, required this.child});
  final Widget child;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      excludeSemantics: true,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.55, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    );
  }
}

/// Um bloco cinza arredondado.
class BlocoEsqueleto extends StatelessWidget {
  const BlocoEsqueleto({super.key, this.largura, this.altura = 12, this.raio = 6});
  final double? largura;
  final double altura;
  final double raio;

  @override
  Widget build(BuildContext context) => Container(
        width: largura,
        height: altura,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(raio),
        ),
      );
}

/// Uma lista em cartão: ícone, título e linha de apoio, [itens] vezes.
class EsqueletoLista extends StatelessWidget {
  const EsqueletoLista({super.key, this.itens = 4, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24)});
  final int itens;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Esqueleto(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        children: [
          const BlocoEsqueleto(largura: 220),
          const SizedBox(height: 16),
          CartaoVidro(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (var i = 0; i < itens; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    const BlocoEsqueleto(largura: 24, altura: 24, raio: 12),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FractionallySizedBox(widthFactor: i.isEven ? 0.8 : 0.6, child: const BlocoEsqueleto(altura: 14)),
                        const SizedBox(height: 8),
                        const FractionallySizedBox(widthFactor: 0.4, child: BlocoEsqueleto(altura: 10)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
