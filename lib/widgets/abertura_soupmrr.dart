import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abertura do app
//
// Ocupa o tempo entre o primeiro frame do Flutter e o app pronto — autologin
// e checagem de versão. A marca não entra pronta: ela é construída à vista,
// na ordem em que foi desenhada. O nó de circuito acende, a trilha corre e
// vira a moldura, e então as letras entram uma a uma.
//
// Por que o logo é redesenhado em vez de exibido:
//
// A marca que existe no projeto está **achatada dentro** de `entradacapa.png`
// e de `iconesoupm.png` — moldura, texto e nó são pixels da mesma imagem,
// sobre uma foto. Não há como animar as partes separadamente a partir dali.
// Por isso a moldura é um `Path` traçado por `PathMetrics` e o texto é texto:
// é a única forma de cada pedaço ter o seu próprio tempo.
//
// O fundo é `fundo_abertura.jpg`, uma faixa recortada da mesma `entradacapa`
// — a textura de circuito sem o logo e sem os brasões do rodapé, que apareceriam
// duplicados atrás da marca que estamos desenhando.
//
// A marca é construída num espaço de 610×245, que são as medidas em que ela
// aparece no ícone do app. Trabalhar nessas coordenadas e escalar no fim é o
// que mantém as proporções fiéis ao original.
// ─────────────────────────────────────────────────────────────────────────────

// Espaço de coordenadas da composição, tirado do ícone do app. A moldura
// mede 610×245 lá; a caixa aqui é mais alta porque "SOU" monta **em cima**
// da aresta de cima e precisa de espaço acima dela — sem isso o texto
// estoura a caixa e o Flutter desenha as listras de overflow.
const double _compW = 610;
const double _compH = 360;

const double _molduraTopo = 110;
const double _molduraH = 245;

// Medidos no ícone: "SOU" tem o centro das maiúsculas exatamente sobre a
// aresta de cima, e "PMRR" fica no miolo.
const double _souTop = 58;
const double _pmrrTop = 206;

const Color _azulMarca = Color(0xFF2E7FBF);

class AberturaSouPMRR extends StatefulWidget {
  const AberturaSouPMRR({Key? key}) : super(key: key);

  @override
  State<AberturaSouPMRR> createState() => _AberturaSouPMRRState();
}

class _AberturaSouPMRRState extends State<AberturaSouPMRR>
    with TickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _trecho(double inicio, double fim, {Curve curva = Curves.easeOut}) {
    final t = ((_c.value - inicio) / (fim - inicio)).clamp(0.0, 1.0);
    return curva.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final larguraMarca =
        (MediaQuery.of(context).size.width * 0.76).clamp(230.0, 340.0);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final entrouFundo = _trecho(0.0, 0.22);
            final no = _trecho(0.08, 0.22, curva: Curves.easeOutBack);
            final trilha = _trecho(0.16, 0.54, curva: Curves.easeInOutCubic);
            final assentou = _trecho(0.84, 1.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Fundo: textura de circuito com recuo lento de câmera ──
                Opacity(
                  opacity: entrouFundo,
                  child: Transform.scale(
                    // Começa fechado e abre: dá a sensação de câmera recuando
                    // enquanto a marca se monta, em vez de um fundo parado.
                    scale:
                        1.16 - 0.16 * Curves.easeOutCubic.transform(_c.value),
                    child: Image.asset(
                      'assets/imagens/fundo_abertura.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Escurece o fundo para a marca ter contraste, e fecha nas
                // bordas — sem isto a textura compete com o logo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xE6000810),
                        Color(0x99001A33),
                        Color(0xE6000810),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [Colors.transparent, Color(0xCC000508)],
                      stops: [0.45, 1.0],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),

                // ── A marca ───────────────────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: larguraMarca,
                        height: larguraMarca * _compH / _compW,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _compW,
                            height: _compH,
                            child: _Marca(
                              no: no,
                              trilha: trilha,
                              assentou: assentou,
                              letra: _trecho,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 34),

                      // ── Assinatura ────────────────────────────────────────
                      // O espaçamento fecha de 9 para 3: o texto "assenta",
                      // que é o gesto das cartelas de abertura de cinema.
                      Opacity(
                        opacity: _trecho(0.86, 1.0),
                        child: Text(
                          'POLÍCIA MILITAR DE RORAIMA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 9 -
                                6 *
                                    _trecho(0.86, 1.0,
                                        curva: Curves.easeOutCubic),
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Carregamento ──────────────────────────────────────────
                Positioned(
                  bottom: 64,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: _trecho(0.9, 1.0),
                      child: const _LinhaCarregando(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A marca: moldura traçada + letras entrando
// ─────────────────────────────────────────────────────────────────────────────

class _Marca extends StatelessWidget {
  const _Marca({
    Key? key,
    required this.no,
    required this.trilha,
    required this.assentou,
    required this.letra,
  }) : super(key: key);

  final double no;
  final double trilha;
  final double assentou;

  /// Mesma função de janela do pai, para as letras entrarem em sequência.
  final double Function(double, double, {Curve curva}) letra;

  static const _sou = ['S', 'O', 'U'];
  static const _pmrr = ['P', 'M', 'R', 'R'];

  /// Uma letra: entra caindo de leve e encolhendo até o tamanho certo —
  /// o movimento de carimbo das cartelas de abertura.
  Widget _caractere(String c, double t, double tamanho) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, -10 * (1 - t)),
        child: Transform.scale(
          scale: 1 + 0.28 * (1 - t),
          child: Text(
            c,
            style: TextStyle(
              fontSize: tamanho,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: Colors.white,
              shadows: const [
                Shadow(
                    color: Color(0x99000A14),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _palavra(
      List<String> letras, double inicio, double fim, double tamanho) {
    final passo = (fim - inicio) / letras.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var n = 0; n < letras.length; n++)
          _caractere(
            letras[n],
            letra(inicio + n * passo, inicio + n * passo + passo * 1.9,
                curva: Curves.easeOutCubic),
            tamanho,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _PinturaMoldura(
              no: no,
              trilha: trilha,
              brilho: assentou,
            ),
          ),
        ),

        // "SOU" monta em cima da aresta superior, como no logo original.
        Positioned(
          left: 0,
          right: 0,
          top: _souTop,
          child: Center(child: _palavra(_sou, 0.46, 0.70, 132)),
        ),

        // "PMRR" no miolo.
        Positioned(
          left: 0,
          right: 0,
          top: _pmrrTop,
          child: Center(child: _palavra(_pmrr, 0.62, 0.88, 150)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Moldura
// ─────────────────────────────────────────────────────────────────────────────

class _PinturaMoldura extends CustomPainter {
  const _PinturaMoldura({
    required this.no,
    required this.trilha,
    required this.brilho,
  });

  /// 0..1 — o nó de circuito acendendo.
  final double no;

  /// 0..1 — quanto da moldura já foi traçado.
  final double trilha;

  /// 0..1 — o realce final, quando a marca assenta.
  final double brilho;

  static const double _raio = 62;
  static const double _traco = 14;

  /// Centro do nó, na aresta de cima à esquerda — onde a trilha nasce.
  static const Offset _centroNo = Offset(95, _molduraTopo);

  /// A moldura, no sentido horário, começando logo depois do nó e parando
  /// antes dele: é a falha onde o nó se encaixa, como no logo original.
  Path _caminho(Size s) {
    final w = s.width;
    const t = _molduraTopo;
    final b = t + _molduraH;
    const r = _raio;
    return Path()
      ..moveTo(120, t)
      ..lineTo(w - r, t)
      ..arcToPoint(Offset(w, t + r), radius: const Radius.circular(r))
      ..lineTo(w, b - r)
      ..arcToPoint(Offset(w - r, b), radius: const Radius.circular(r))
      ..lineTo(r, b)
      ..arcToPoint(Offset(0, b - r), radius: const Radius.circular(r))
      ..lineTo(0, t + r)
      ..arcToPoint(Offset(r, t), radius: const Radius.circular(r))
      ..lineTo(72, t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Azul em cima, branco embaixo — a leitura do logo original.
    final tinta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _traco
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_azulMarca, _azulMarca, Colors.white],
        stops: [0.0, 0.38, 0.82],
      ).createShader(Rect.fromLTWH(0, _molduraTopo, size.width, _molduraH));

    // ── Trilha ──────────────────────────────────────────────────────────
    if (trilha > 0) {
      final caminho = _caminho(size);
      final metricas = caminho.computeMetrics().toList();
      final total = metricas.fold<double>(0, (t, m) => t + m.length);
      final alvo = total * trilha;

      var percorrido = 0.0;
      for (final m in metricas) {
        if (percorrido >= alvo) break;
        final pedaco = (alvo - percorrido).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(0, pedaco), tinta);
        percorrido += m.length;
      }

      // Ponta acesa, só enquanto está correndo. Parada, viraria um ponto
      // solto grudado na moldura.
      if (trilha < 1) {
        var antes = 0.0;
        for (final m in metricas) {
          if (alvo <= antes + m.length) {
            final tg = m.getTangentForOffset(alvo - antes);
            if (tg != null) {
              canvas.drawCircle(
                tg.position,
                16,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.55)
                  ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 12),
              );
              canvas.drawCircle(
                tg.position,
                6,
                Paint()..color = Colors.white,
              );
            }
            break;
          }
          antes += m.length;
        }
      }
    }

    // ── Nó de circuito ──────────────────────────────────────────────────
    if (no > 0) {
      canvas.save();
      canvas.translate(_centroNo.dx, _centroNo.dy);
      canvas.scale(no.clamp(0.0, 1.2));
      canvas.drawCircle(
        Offset.zero,
        26,
        Paint()
          ..color = _azulMarca.withValues(alpha: 0.45 * no)
          ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        Offset.zero,
        19,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _traco
          ..color = _azulMarca,
      );
      canvas.restore();
    }

    // ── Realce de assentamento ──────────────────────────────────────────
    // Um sopro de luz quando a marca termina de se montar, e some.
    if (brilho > 0 && brilho < 1) {
      final forca = (1 - (brilho - 0.35).abs() * 2.4).clamp(0.0, 1.0);
      if (forca > 0) {
        canvas.drawPath(
          _caminho(size),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _traco
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.5 * forca)
            ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 10),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PinturaMoldura antiga) =>
      antiga.no != no || antiga.trilha != trilha || antiga.brilho != brilho;
}

// ─────────────────────────────────────────────────────────────────────────────

class _LinhaCarregando extends StatefulWidget {
  const _LinhaCarregando({Key? key}) : super(key: key);

  @override
  State<_LinhaCarregando> createState() => _LinhaCarregandoState();
}

class _LinhaCarregandoState extends State<_LinhaCarregando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.12)),
              Align(
                alignment: Alignment(-1 + 2 * _c.value, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.42,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.acaoClara,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
