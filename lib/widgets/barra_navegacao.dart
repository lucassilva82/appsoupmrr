import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BarraNavegacao (SOUPM_2_2 §15.3; medidas do protótipo `.ios-barra` e
// `.tabbar` do Android)
//
// iOS: barra solta de vidro. Uma cápsula de 64pt afastada das bordas e acima
// da barra de início, com desfoque e saturação (deixa ver o conteúdo por
// baixo) e uma borda de luz. A aba ativa cresce, ganha uma cápsula clara e
// mostra o nome ao lado do ícone, empurrando as outras, que ficam só com o
// ícone (o nome vai para o leitor de tela). O ícone encolhe ao apertar e dá
// um pulo ao ser escolhido. Com "Reduzir transparência" fica opaca; com
// "Reduzir movimento", sem animação.
//
// Android: a NavigationBar do Material 3. Indicador de 64×32 atrás do ícone
// e o nome embaixo.
//
// O Scaffold que usa a barra no iOS precisa de `extendBody: true`, para o
// conteúdo passar por baixo do vidro.
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

  /// Nulo: decide pela plataforma do aparelho. Os testes passam o valor.
  final bool? ios;

  const BarraNavegacao({
    super.key,
    required this.itens,
    required this.indiceAtual,
    required this.aoSelecionar,
    this.ios,
  });

  static bool get plataformaIos => !Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    void tocar(int i) {
      if (i != indiceAtual) HapticFeedback.selectionClick();
      aoSelecionar(i);
    }

    return (ios ?? plataformaIos)
        ? _BarraIos(itens: itens, indiceAtual: indiceAtual, aoTocar: tocar)
        : _BarraAndroid(itens: itens, indiceAtual: indiceAtual, aoTocar: tocar);
  }
}

// ── iOS ──────────────────────────────────────────────────────────────────────

class _BarraIos extends StatelessWidget {
  const _BarraIos({required this.itens, required this.indiceAtual, required this.aoTocar});

  final List<ItemNavegacao> itens;
  final int indiceAtual;
  final ValueChanged<int> aoTocar;

  static const _altura = 64.0;
  static const _respiro = 6.0;
  static const _vao = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escuro = theme.brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final semMovimento = mq.disableAnimations;
    final semTransparencia = mq.highContrast;
    final base = mq.padding.bottom;

    final ativo = theme.colorScheme.primary;
    final texto = theme.colorScheme.onSurface;
    final estiloRotulo = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ativo);

    final capsula = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_altura / 2),
        color: semTransparencia ? theme.colorScheme.surface : null,
        gradient: semTransparencia
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: escuro ? const [0, .55, 1] : const [0, .6, 1],
                colors: escuro
                    ? [
                        Colors.white.withValues(alpha: .10),
                        Colors.white.withValues(alpha: .03),
                        Colors.white.withValues(alpha: .06),
                      ]
                    : [
                        Colors.white.withValues(alpha: .30),
                        Colors.white.withValues(alpha: .06),
                        Colors.white.withValues(alpha: .16),
                      ],
              ),
      ),
      child: CustomPaint(
        foregroundPainter: _BordaDeLuz(escuro: escuro),
        child: Padding(
          padding: const EdgeInsets.all(_respiro),
          child: LayoutBuilder(builder: (context, c) {
            // A ativa ocupa o que precisa (ícone + nome); as outras dividem
            // o resto, como no protótipo (130 + 3 × 68 num iPhone).
            final rotulo = itens[indiceAtual].rotulo;
            final tp = TextPainter(
              text: TextSpan(text: rotulo, style: estiloRotulo),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
            )..layout();
            final vaos = _vao * (itens.length - 1);
            final larguraAtiva = (20 + 24 + 7 + tp.width + 1)
                .clamp(0.0, c.maxWidth - vaos - 44.0 * (itens.length - 1));
            final larguraOutra = (c.maxWidth - vaos - larguraAtiva) / (itens.length - 1);
            return Row(
              children: [
                for (var i = 0; i < itens.length; i++) ...[
                  if (i > 0) const SizedBox(width: _vao),
                  _AbaIos(
                    item: itens[i],
                    ativa: i == indiceAtual,
                    largura: i == indiceAtual ? larguraAtiva : larguraOutra,
                    corAtiva: ativo,
                    corTexto: texto,
                    escuro: escuro,
                    estiloRotulo: estiloRotulo,
                    semMovimento: semMovimento,
                    aoTocar: () => aoTocar(i),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );

    final sombra = escuro
        ? [
            BoxShadow(
                color: Colors.black.withValues(alpha: .6),
                offset: const Offset(0, 18),
                blurRadius: 40,
                spreadRadius: -14),
            BoxShadow(
                color: Colors.black.withValues(alpha: .2),
                offset: const Offset(0, 3),
                blurRadius: 10),
          ]
        : [
            BoxShadow(
                color: const Color(0xFF002154).withValues(alpha: .38),
                offset: const Offset(0, 18),
                blurRadius: 40,
                spreadRadius: -16),
            BoxShadow(
                color: const Color(0xFF002154).withValues(alpha: .10),
                offset: const Offset(0, 3),
                blurRadius: 10),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, base > 0 ? (base - 12).clamp(8.0, base) : 16),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Abas',
        child: Container(
          height: _altura,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_altura / 2),
            boxShadow: sombra,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_altura / 2),
            child: semTransparencia
                ? capsula
                : BackdropFilter(
                    // Desfoque com saturação, como o vidro do iOS 26.
                    filter: ImageFilter.compose(
                      outer: ColorFilter.matrix(_saturacao(2.2)),
                      inner: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    ),
                    child: capsula,
                  ),
          ),
        ),
      ),
    );
  }

  static List<double> _saturacao(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      i * r + s, i * g, i * b, 0, 0, //
      i * r, i * g + s, i * b, 0, 0, //
      i * r, i * g, i * b + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// A borda de 1pt da cápsula, com a luz entrando pelo canto de cima.
class _BordaDeLuz extends CustomPainter {
  const _BordaDeLuz({required this.escuro});
  final bool escuro;

  @override
  void paint(Canvas canvas, Size size) {
    final r =
        RRect.fromRectAndRadius((Offset.zero & size).deflate(.5), Radius.circular(size.height / 2));
    final cores = escuro
        ? [
            Colors.white.withValues(alpha: .65),
            Colors.white.withValues(alpha: .08),
            Colors.white.withValues(alpha: .02),
            Colors.white.withValues(alpha: .38),
          ]
        : [
            Colors.white.withValues(alpha: .95),
            Colors.white.withValues(alpha: .25),
            const Color(0xFF002154).withValues(alpha: .06),
            Colors.white.withValues(alpha: .7),
          ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: escuro ? const [0, .38, .62, 1] : const [0, .4, .65, 1],
        colors: cores,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r, paint);
  }

  @override
  bool shouldRepaint(_BordaDeLuz old) => old.escuro != escuro;
}

class _AbaIos extends StatefulWidget {
  const _AbaIos({
    required this.item,
    required this.ativa,
    required this.largura,
    required this.corAtiva,
    required this.corTexto,
    required this.escuro,
    required this.estiloRotulo,
    required this.semMovimento,
    required this.aoTocar,
  });

  final ItemNavegacao item;
  final bool ativa;
  final double largura;
  final Color corAtiva;
  final Color corTexto;
  final bool escuro;
  final TextStyle estiloRotulo;
  final bool semMovimento;
  final VoidCallback aoTocar;

  @override
  State<_AbaIos> createState() => _AbaIosState();
}

class _AbaIosState extends State<_AbaIos> with SingleTickerProviderStateMixin {
  // O pulo do ícone quando a aba é escolhida (`.pulso`, 500 ms).
  late final AnimationController _pulo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  bool _apertada = false;

  /// Quique da troca de largura: cubic-bezier(.3, 1.2, .4, 1).
  static const _quique = Cubic(.3, 1.2, .4, 1);

  @override
  void didUpdateWidget(_AbaIos old) {
    super.didUpdateWidget(old);
    if (widget.ativa && !old.ativa && !widget.semMovimento) {
      _pulo.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final cor = w.ativa ? w.corAtiva : w.corTexto;
    final dur = w.semMovimento ? Duration.zero : const Duration(milliseconds: 500);
    final contador = w.item.contador;

    final icone = AnimatedBuilder(
      animation: _pulo,
      builder: (context, child) {
        // Sobe a 1,18 e volta, com o quique da curva do protótipo.
        final t = _pulo.value;
        final escala = _pulo.isAnimating
            ? 1 + .18 * Curves.easeOutBack.transform(t < .5 ? t * 2 : 2 - t * 2)
            : 1.0;
        return Transform.scale(scale: (_apertada ? .8 : 1) * escala, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(w.ativa ? w.item.iconeAtivo : w.item.icone, size: 24, color: cor),
          if (contador > 0)
            Positioned(
              top: -7,
              left: 13,
              child: Container(
                height: 17,
                constraints: const BoxConstraints(minWidth: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  contador > 99 ? '99+' : '$contador',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1),
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: w.ativa,
      label: contador > 0 ? '${w.item.rotulo}, $contador não lidos' : w.item.rotulo,
      excludeSemantics: true,
      // O "apertar" (ícone encolhe) vem do ponteiro, separado do toque: um
      // setState no meio do reconhecimento do toque fazia toques muito
      // curtos se perderem.
      child: Listener(
        onPointerDown: (_) => setState(() => _apertada = true),
        onPointerUp: (_) => setState(() => _apertada = false),
        onPointerCancel: (_) => setState(() => _apertada = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: w.aoTocar,
          child: AnimatedContainer(
            duration: dur,
            curve: _quique,
            width: w.largura,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: w.ativa
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: w.escuro
                          ? [
                              Colors.white.withValues(alpha: .17),
                              Colors.white.withValues(alpha: .06),
                            ]
                          : [
                              const Color(0xFF002154).withValues(alpha: .11),
                              const Color(0xFF002154).withValues(alpha: .05),
                            ],
                    )
                  : null,
              boxShadow: w.ativa && w.escuro
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          offset: const Offset(0, 4),
                          blurRadius: 12),
                    ]
                  : null,
            ),
            child: ClipRect(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icone,
                  // O nome cresce de 0 até a largura dele e acende logo depois.
                  Flexible(
                    child: AnimatedOpacity(
                      duration: w.semMovimento ? Duration.zero : const Duration(milliseconds: 300),
                      opacity: w.ativa ? 1 : 0,
                      child: w.ativa
                          ? Padding(
                              padding: const EdgeInsets.only(left: 7),
                              child: Text(
                                w.item.rotulo,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                textScaler:
                                    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
                                style: w.estiloRotulo,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Android ──────────────────────────────────────────────────────────────────

class _BarraAndroid extends StatelessWidget {
  const _BarraAndroid({required this.itens, required this.indiceAtual, required this.aoTocar});

  final List<ItemNavegacao> itens;
  final int indiceAtual;
  final ValueChanged<int> aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escuro = theme.brightness == Brightness.dark;
    final pri = theme.colorScheme.primary;
    // Superfície tonal: 96% da superfície com 4% da primária.
    final fundo = Color.alphaBlend(
        pri.withValues(alpha: .04), escuro ? AppColors.darkCard : theme.colorScheme.surface);
    final apagado = theme.colorScheme.onSurface.withValues(alpha: .62);

    return Material(
      color: fundo,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Row(
            children: [
              for (var i = 0; i < itens.length; i++)
                Expanded(
                  child: _AbaAndroid(
                    item: itens[i],
                    ativa: i == indiceAtual,
                    corAtiva: theme.colorScheme.onSurface,
                    corApagada: apagado,
                    indicador: pri.withValues(alpha: .2),
                    aoTocar: () => aoTocar(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbaAndroid extends StatelessWidget {
  const _AbaAndroid({
    required this.item,
    required this.ativa,
    required this.corAtiva,
    required this.corApagada,
    required this.indicador,
    required this.aoTocar,
  });

  final ItemNavegacao item;
  final bool ativa;
  final Color corAtiva;
  final Color corApagada;
  final Color indicador;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = ativa ? corAtiva : corApagada;
    final semMovimento = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: ativa,
      label: item.contador > 0 ? '${item.rotulo}, ${item.contador} não lidos' : item.rotulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: semMovimento ? Duration.zero : const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: ativa ? indicador : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(ativa ? item.iconeAtivo : item.icone, size: 24, color: cor),
                    if (item.contador > 0)
                      Positioned(
                        top: -2,
                        left: 36,
                        child: Container(
                          height: 17,
                          constraints: const BoxConstraints(minWidth: 17),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5484D),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            item.contador > 99 ? '99+' : '${item.contador}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                height: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.rotulo,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: ativa ? FontWeight.w700 : FontWeight.w500,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
