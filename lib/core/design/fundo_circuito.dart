import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_theme.dart';
import '../../widgets/versao_app.dart';

/// Fundo das telas de entrada (login, recuperar senha, primeiro acesso,
/// e-mail, biometria): a arte dos cards em tela cheia, com as trilhas de
/// circuito que se desenham ao abrir e pulsos de luz correndo por elas.
/// Com "Reduzir movimento", aparece pronto e parado.
class FundoCircuito extends StatefulWidget {
  /// Quantas telas de entrada (login, Face ID, primeiro acesso, recuperar
  /// senha) estão montadas. Com alguma, diálogos e avisos curtos abrem no
  /// tema escuro, sobre o fundo de circuito, mesmo com o aparelho no claro.
  /// (Notifica: um diálogo aberto antes da tela montar troca de tema na hora.)
  static final abertos = ValueNotifier<int>(0);
  static bool get ativo => abertos.value > 0;

  /// O tema escuro das telas de entrada.
  static ThemeData get temaEscuro => _escuro ??= AppTheme.build(isDark: true, isSuperUser: false);
  static ThemeData? _escuro;

  const FundoCircuito({super.key});

  static const base = _Fundo.base;

  @override
  State<FundoCircuito> createState() => _FundoCircuitoState();
}

class _FundoCircuitoState extends State<FundoCircuito> with TickerProviderStateMixin {
  bool _contado = false;

  @override
  void initState() {
    super.initState();
    // Depois do quadro: avisar durante o build marcaria outras telas no meio dele.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _contado = true;
      FundoCircuito.abertos.value++;
    });
  }

  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1;
      _pulso.stop();
    } else if (!_pulso.isAnimating) {
      _pulso.repeat();
    }
  }

  @override
  void dispose() {
    // Fora do dispose: avisar aqui marca outras telas com a árvore travada
    // ("widget tree was locked", AP-FATAL no painel em 25/10/2026). A
    // microtarefa roda logo depois do quadro, antes do próximo.
    if (_contado) scheduleMicrotask(() => FundoCircuito.abertos.value--);
    _entrada.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulso, _entrada]),
          builder: (_, __) => CustomPaint(
            painter: _Fundo(pulso: _pulso.value, entrada: Curves.easeOutCubic.transform(_entrada.value)),
          ),
        ),
      );
}

/// Uma tela de entrada inteira: o [FundoCircuito] atrás, o tema escuro (o
/// fundo é sempre escuro) e ícones claros na barra de status. O [child] é
/// um Scaffold com fundo transparente.
class TelaEntrada extends StatelessWidget {
  const TelaEntrada({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF0E1726),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: ColoredBox(
          color: FundoCircuito.base,
          child: Stack(children: [
            const Positioned.fill(child: FundoCircuito()),
            Theme(data: FundoCircuito.temaEscuro, child: child),
          ]),
        ),
      );
}

/// O fundo: a arte dos cards em tela cheia. Degradê azul-marinho, brilho
/// ciano no alto, trilhas de circuito que se desenham na entrada e pulsos de
/// luz correndo por elas, e três ícones grandes quase apagados.
class _Fundo extends CustomPainter {
  _Fundo({required this.pulso, required this.entrada});

  static const base = Color(0xFF020916);
  static const _ciano = Color(0xFF4FD8F0);

  /// 0..1, repetindo: posição dos pulsos de luz.
  final double pulso;

  /// 0..1: quanto das trilhas já foi desenhado.
  final double entrada;

  // Trilhas em coordenadas de 0 a 1 (largura e altura), com curvas de 45°.
  static const _trilhas = <List<Offset>>[
    [Offset(-0.05, 0.08), Offset(0.22, 0.08), Offset(0.30, 0.13), Offset(0.52, 0.13)],
    [Offset(1.05, 0.05), Offset(0.80, 0.05), Offset(0.72, 0.10), Offset(0.60, 0.10)],
    [Offset(-0.05, 0.22), Offset(0.12, 0.22), Offset(0.20, 0.27), Offset(0.34, 0.27)],
    [Offset(1.05, 0.25), Offset(0.88, 0.25), Offset(0.82, 0.30), Offset(0.70, 0.30)],
    [Offset(-0.05, 0.46), Offset(0.06, 0.46), Offset(0.12, 0.50), Offset(0.18, 0.50)],
    [Offset(1.05, 0.52), Offset(0.95, 0.52), Offset(0.90, 0.56), Offset(0.84, 0.56)],
    [Offset(-0.05, 0.70), Offset(0.10, 0.70), Offset(0.16, 0.74), Offset(0.30, 0.74)],
    [Offset(1.05, 0.68), Offset(0.84, 0.68), Offset(0.78, 0.72), Offset(0.66, 0.72)],
    [Offset(-0.05, 0.88), Offset(0.26, 0.88), Offset(0.32, 0.84), Offset(0.48, 0.84)],
    [Offset(1.05, 0.92), Offset(0.70, 0.92), Offset(0.64, 0.87), Offset(0.56, 0.87)],
    [Offset(0.40, -0.05), Offset(0.40, 0.03), Offset(0.45, 0.06)],
    [Offset(0.62, 1.05), Offset(0.62, 0.97), Offset(0.57, 0.94)],
  ];

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF041332), Color(0xFF061B3E), Color(0xFF031026), base],
          stops: [0, .38, .72, 1],
        ).createShader(r),
    );
    // Brilho ciano no canto de cima e um azul mais fundo embaixo.
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, -0.95),
          radius: 0.95,
          colors: [_ciano.withValues(alpha: 0.16), _ciano.withValues(alpha: 0)],
        ).createShader(r),
    );
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1, 0.9),
          radius: 0.9,
          colors: [const Color(0xFF1565C0).withValues(alpha: 0.20), const Color(0x001565C0)],
        ).createShader(r),
    );

    // Ícones grandes e apagados, como a marca d'água dos cards.
    void icone(IconData d, Offset c, double tam, double giro) {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(d.codePoint),
          style: TextStyle(
            fontSize: tam,
            fontFamily: d.fontFamily,
            package: d.fontPackage,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(giro);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    icone(Icons.shield_outlined, Offset(s.width * 0.92, s.height * 0.40), s.width * 0.55, 0.26);
    icone(Icons.local_police_outlined, Offset(s.width * 0.06, s.height * 0.62), s.width * 0.42, -0.2);
    icone(Icons.verified_user_outlined, Offset(s.width * 0.80, s.height * 0.86), s.width * 0.30, 0.18);

    // Trilhas: desenham-se na entrada, do começo ao fim de cada uma.
    final traco = Paint()
      ..color = _ciano.withValues(alpha: 0.34)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final ponto = Paint()..color = _ciano.withValues(alpha: 0.75);
    final luz = Paint()
      ..color = _ciano
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var i = 0; i < _trilhas.length; i++) {
      final pts = [for (final p in _trilhas[i]) Offset(p.dx * s.width, p.dy * s.height)];
      final caminho = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        caminho.lineTo(p.dx, p.dy);
      }
      final metrica = caminho.computeMetrics().first;
      final atraso = (i % 4) * 0.08;
      final t = ((entrada - atraso) / (1 - atraso)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      canvas.drawPath(metrica.extractPath(0, metrica.length * t), traco);
      if (t >= 1) {
        canvas.drawCircle(pts.last, 3.4, ponto);
        // Um pulso por trilha, cada um no seu tempo.
        final f = (pulso + i * 0.137) % 1;
        if (f < 0.6) {
          final pos = metrica.getTangentForOffset(metrica.length * (f / 0.6))!.position;
          final forca = math.sin(f / 0.6 * math.pi);
          canvas.drawCircle(pos, 2.8, luz..color = _ciano.withValues(alpha: forca));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Fundo old) => old.pulso != pulso || old.entrada != entrada;
}

/// O cartão de vidro das telas de entrada (o do login do iPhone, padrão 2.2):
/// desfoque de verdade sobre o fundo de circuito, degradê branco quase
/// transparente e borda de luz. Usado no login (iOS e Android) e na entrada
/// por Face ID ou digital.
class CartaoVidroEntrada extends StatelessWidget {
  const CartaoVidroEntrada({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20),
    this.raio = const BorderRadius.all(Radius.circular(28)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius raio;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: raio,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: raio,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.025)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: child,
          ),
        ),
      );
}

/// O rodapé das telas de entrada: os três brasões (Governo de Roraima, PMRR e
/// DTI), cada um no seu tamanho, e a versão.
class RodapeEntrada extends StatelessWidget {
  const RodapeEntrada({super.key});

  static Widget _marca(String arquivo, double altura, String rotulo) => Semantics(
        image: true,
        label: rotulo,
        child: Image.asset(arquivo, height: altura, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      );

  static Widget _divisor() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.white.withValues(alpha: 0.16),
      );

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _marca('assets/imagens/brasao_governo_rr.png', 42, 'Governo de Roraima'),
          _divisor(),
          _marca('assets/imagens/logo_pmrr.png', 44, 'Polícia Militar de Roraima'),
          _divisor(),
          _marca('assets/imagens/logo_dti_marca.png', 34, 'Departamento de Tecnologia da Informação'),
        ]),
        const SizedBox(height: 10),
        TextoVersao(
          formato: (v) => v.isEmpty ? 'DTI/PMRR' : 'Versão $v · DTI/PMRR',
          estilo: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), letterSpacing: .4),
        ),
      ]);
}
