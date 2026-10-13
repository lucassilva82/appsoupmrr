import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abertura do app
//
// Ocupa o tempo entre o primeiro frame do Flutter e o app pronto — autologin
// e checagem de versão. A marca não entra pronta: ela é construída à vista.
//
// A coreografia tem uma lógica só, de circuito energizando:
//
//   1. o nó acende
//   2. a trilha corre a partir dele e vira a moldura
//   3. ao fechar o circuito de volta no nó, sai uma onda
//   4. a corrente dá uma volta na moldura já pronta
//   5. as letras assentam
//
// Não há piscada no fim. Havia um clarão branco sobre a moldura inteira, e
// ele lia como falha de renderização, não como acabamento — luz que acende e
// apaga no mesmo lugar é pisca, não é movimento. No lugar dele a corrente
// **percorre** o traçado: mesma energia, com direção, que é o que o olho
// aceita como intencional.
//
// Por que o logo é redesenhado em vez de exibido:
//
// A marca que existe no projeto está achatada **dentro** de `entradacapa.png`
// e de `iconesoupm.png` — moldura, texto e nó são pixels da mesma imagem,
// sobre uma foto. Não há como animar as partes separadamente a partir dali.
//
// As medidas vêm do ícone do app, para as proporções baterem com o original.
// ─────────────────────────────────────────────────────────────────────────────

// Espaço de coordenadas da composição. A moldura mede 610×245 no ícone; a
// caixa aqui é mais alta porque "SOU" monta **em cima** da aresta de cima e
// precisa de espaço acima dela — sem isso o texto estoura a caixa.
const double _compW = 610;
const double _compH = 360;

const double _molduraTopo = 110;
const double _molduraH = 245;

// Medidos no ícone: "SOU" tem o centro das maiúsculas sobre a aresta de cima,
// e "PMRR" fica no miolo.
const double _souTop = 58;
const double _pmrrTop = 206;

const Color _azulMarca = Color(0xFF2E7FBF);
const Color _cianoCircuito = Color(0xFF4FD8F0);

class AberturaSouPMRR extends StatefulWidget {
  const AberturaSouPMRR({Key? key}) : super(key: key);

  @override
  State<AberturaSouPMRR> createState() => _AberturaSouPMRRState();
}

class _AberturaSouPMRRState extends State<AberturaSouPMRR>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _ambiente;
  late final AnimationController _camera;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    // Separado: a vida do fundo não termina junto com a montagem da marca.
    _ambiente = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    // O recuo de câmera é mais longo que a montagem de propósito. Depois que
    // a marca fica pronta, a tela ainda permanece cerca de um segundo para
    // dar tempo de ver o conjunto — e nesse intervalo a imagem não pode
    // congelar. Amarrado ao controlador da marca, ela paralisava no último
    // quadro e a permanência virava tela travada.
    _camera = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
      _camera.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
      _ambiente.repeat();
      _camera.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _ambiente.dispose();
    _camera.dispose();
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
          animation: Listenable.merge([_c, _ambiente, _camera]),
          builder: (context, _) {
            final entrouFundo = _trecho(0.0, 0.22);

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Fundo: textura de circuito com recuo lento de câmera ──
                Opacity(
                  opacity: entrouFundo,
                  child: Transform.scale(
                    scale: 1.16 -
                        0.16 * Curves.easeOutCubic.transform(_camera.value),
                    child: Image.asset(
                      'assets/imagens/fundo_abertura.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Escurece para a marca ter contraste.
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

                // ── Trilhas vivas ─────────────────────────────────────────
                // Desenhadas por cima da foto, na mesma linguagem dela, para
                // o circuito do fundo parecer energizado. Correr um pulso nas
                // linhas da própria foto seria impossível: lá são pixels
                // chapados, sem geometria para percorrer.
                Opacity(
                  opacity: entrouFundo * 0.9,
                  child: CustomPaint(
                    painter: _PinturaAmbiente(t: _ambiente.value),
                    size: Size.infinite,
                  ),
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
                              no: _trecho(0.08, 0.22,
                                  curva: Curves.easeOutBack),
                              trilha: _trecho(0.16, 0.56,
                                  curva: Curves.easeInOutCubic),
                              onda: _trecho(0.54, 0.95,
                                  curva: Curves.easeOutQuart),
                              corrente: _trecho(0.56, 0.90,
                                  curva: Curves.easeInOutSine),
                              letra: _trecho,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
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
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trilhas do fundo
// ─────────────────────────────────────────────────────────────────────────────

/// Uma trilha em coordenadas normalizadas (0..1 da tela), no traçado
/// ortogonal-e-45° das placas de circuito — o mesmo desenho da foto.
class _Trilha {
  const _Trilha(this.pontos, this.fase, this.velocidade);

  final List<Offset> pontos;

  /// Desencontra os pulsos. Com todos em fase a tela pisca junta.
  final double fase;

  /// Quantas voltas por ciclo do controlador.
  final double velocidade;
}

const List<_Trilha> _trilhas = [
  _Trilha([
    Offset(-0.05, 0.14),
    Offset(0.22, 0.14),
    Offset(0.34, 0.22),
    Offset(0.62, 0.22)
  ], 0.00, 1.0),
  _Trilha([
    Offset(1.05, 0.30),
    Offset(0.78, 0.30),
    Offset(0.68, 0.38),
    Offset(0.40, 0.38)
  ], 0.37, 0.8),
  _Trilha([
    Offset(-0.05, 0.47),
    Offset(0.14, 0.47),
    Offset(0.24, 0.56),
    Offset(0.24, 0.74)
  ], 0.62, 1.15),
  _Trilha([
    Offset(1.05, 0.62),
    Offset(0.82, 0.62),
    Offset(0.72, 0.71),
    Offset(0.72, 0.90)
  ], 0.18, 0.9),
  _Trilha([
    Offset(0.08, 0.86),
    Offset(0.36, 0.86),
    Offset(0.47, 0.95),
    Offset(0.90, 0.95)
  ], 0.80, 0.7),
  _Trilha(
      [Offset(1.05, 0.08), Offset(0.88, 0.08), Offset(0.80, 0.15)], 0.50, 1.3),
];

class _PinturaAmbiente extends CustomPainter {
  const _PinturaAmbiente({required this.t});

  /// 0..1, cíclico.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final linha = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = _cianoCircuito.withValues(alpha: 0.11);

    for (final tr in _trilhas) {
      final caminho = Path();
      for (var n = 0; n < tr.pontos.length; n++) {
        final p = Offset(
          tr.pontos[n].dx * size.width,
          tr.pontos[n].dy * size.height,
        );
        n == 0 ? caminho.moveTo(p.dx, p.dy) : caminho.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(caminho, linha);

      // Terminal: o pontinho que o desenho de placa sempre tem na ponta.
      final fim = Offset(
        tr.pontos.last.dx * size.width,
        tr.pontos.last.dy * size.height,
      );
      canvas.drawCircle(
          fim, 2.6, Paint()..color = _cianoCircuito.withValues(alpha: 0.18));

      // ── O pulso ─────────────────────────────────────────────────────────
      final metrica = caminho.computeMetrics().first;
      final avanco = (t * tr.velocidade + tr.fase) % 1.0;

      // Nasce e morre nas pontas, não no meio da linha.
      final presenca = math.sin(avanco * math.pi);
      if (presenca <= 0.02) continue;

      final cabecaEm = metrica.length * avanco;
      final rastro = metrica.length * 0.22;

      canvas.drawPath(
        metrica.extractPath(math.max(0, cabecaEm - rastro), cabecaEm),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = _cianoCircuito.withValues(alpha: 0.38 * presenca),
      );

      final cabeca = metrica.getTangentForOffset(cabecaEm)?.position;
      if (cabeca != null) {
        canvas.drawCircle(
          cabeca,
          7,
          Paint()
            ..color = _cianoCircuito.withValues(alpha: 0.30 * presenca)
            ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 6),
        );
        canvas.drawCircle(
          cabeca,
          1.8,
          Paint()..color = Colors.white.withValues(alpha: 0.70 * presenca),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PinturaAmbiente antiga) => antiga.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// A marca: moldura traçada + letras entrando
// ─────────────────────────────────────────────────────────────────────────────

class _Marca extends StatelessWidget {
  const _Marca({
    Key? key,
    required this.no,
    required this.trilha,
    required this.onda,
    required this.corrente,
    required this.letra,
  }) : super(key: key);

  final double no;
  final double trilha;
  final double onda;
  final double corrente;

  /// Mesma função de janela do pai, para as letras entrarem em sequência.
  final double Function(double, double, {Curve curva}) letra;

  static const _sou = ['S', 'O', 'U'];
  static const _pmrr = ['P', 'M', 'R', 'R'];

  /// Uma letra: entra caindo de leve e encolhendo até o tamanho certo — o
  /// movimento de carimbo das cartelas de abertura. Entra e fica; não pisca.
  Widget _caractere(String c, double t, double tamanho) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, -10 * (1 - t)),
        child: Transform.scale(
          scale: 1 + 0.26 * (1 - t),
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
              onda: onda,
              corrente: corrente,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _souTop,
          child: Center(child: _palavra(_sou, 0.44, 0.70, 132)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _pmrrTop,
          child: Center(child: _palavra(_pmrr, 0.60, 0.88, 150)),
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
    required this.onda,
    required this.corrente,
  });

  /// 0..1 — o nó de circuito acendendo.
  final double no;

  /// 0..1 — quanto da moldura já foi traçado.
  final double trilha;

  /// 0..1 — a onda que sai do nó quando a trilha fecha o circuito nele.
  final double onda;

  /// 0..1 — a corrente dando uma volta na moldura já pronta.
  final double corrente;

  static const double _raio = 62;
  static const double _traco = 14;

  /// Centro do nó, na aresta de cima à esquerda — de onde a trilha nasce e
  /// para onde ela volta.
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
    final caminho = _caminho(size);
    final metricas = caminho.computeMetrics().toList();
    final total = metricas.fold<double>(0, (t, m) => t + m.length);

    // O caminho vem partido em várias métricas por causa dos arcos, então
    // recortar por comprimento acumulado precisa atravessar todas elas.
    Path recorte(double de, double ate) {
      final saida = Path();
      var antes = 0.0;
      for (final m in metricas) {
        final i = (de - antes).clamp(0.0, m.length);
        final f = (ate - antes).clamp(0.0, m.length);
        if (f > i) saida.addPath(m.extractPath(i, f), Offset.zero);
        antes += m.length;
      }
      return saida;
    }

    Offset? pontoEm(double d) {
      var antes = 0.0;
      for (final m in metricas) {
        if (d <= antes + m.length) {
          return m.getTangentForOffset(d - antes)?.position;
        }
        antes += m.length;
      }
      return null;
    }

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
      canvas.drawPath(recorte(0, total * trilha), tinta);

      if (trilha < 1) {
        final p = pontoEm(total * trilha);
        if (p != null) {
          canvas.drawCircle(
            p,
            16,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.55)
              ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 12),
          );
          canvas.drawCircle(p, 6, Paint()..color = Colors.white);
        }
      }
    }

    // ── Corrente ────────────────────────────────────────────────────────
    // Um trecho claro percorre a moldura pronta, uma vez só.
    if (corrente > 0 && corrente < 1) {
      final presenca = math.sin(corrente * math.pi);
      final cabeca = total * corrente;
      canvas.drawPath(
        recorte(math.max(0, cabeca - total * 0.18), cabeca),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _traco
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.5 * presenca)
          ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 7),
      );
    }

    // ── Nó de circuito ──────────────────────────────────────────────────
    if (no > 0) {
      canvas.save();
      canvas.translate(_centroNo.dx, _centroNo.dy);
      canvas.scale(no.clamp(0.0, 1.2));

      // A onda: dois anéis saindo do nó quando a trilha volta nele. É o
      // fecho do circuito, e o único momento em que o nó se mexe.
      if (onda > 0 && onda < 1) {
        // Três anéis escalonados. Um só lê como glitch; escalonados leem
        // como a onda de um impacto, que é o que acabou de acontecer ali.
        for (final atraso in [0.0, 0.16, 0.32]) {
          final o = ((onda - atraso) / (1 - atraso)).clamp(0.0, 1.0);
          if (o <= 0 || o >= 1) continue;
          canvas.drawCircle(
            Offset.zero,
            19 + 78 * o,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5.0 * (1 - o) + 0.9
              ..color = _cianoCircuito.withValues(alpha: 0.70 * (1 - o)),
          );
        }
      }

      // O nó ganha um sopro de luz no instante da onda e volta ao normal.
      final acende =
          onda > 0 && onda < 0.5 ? math.sin(onda / 0.5 * math.pi) : 0.0;

      canvas.drawCircle(
        Offset.zero,
        26 + 8 * acende,
        Paint()
          ..color = _azulMarca.withValues(alpha: (0.45 + 0.35 * acende) * no)
          ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        Offset.zero,
        19,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _traco
          ..color = Color.lerp(_azulMarca, Colors.white, 0.6 * acende)!,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PinturaMoldura antiga) =>
      antiga.no != no ||
      antiga.trilha != trilha ||
      antiga.onda != onda ||
      antiga.corrente != corrente;
}
