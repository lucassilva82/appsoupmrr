import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';
import '../widgets/abertura_soupmrr.dart';
import '../widgets/auth_form.dart';
import '../widgets/versao_app.dart';

/// Tela de login da 2.2 (pedido do usuário, 24/10/2026).
///
/// O fundo é a mesma linguagem dos cards com arte do app (degradê
/// azul-marinho, brilho, trilhas de circuito com pulsos de luz e ícones
/// grandes apagados), no lugar da foto. Cada plataforma no seu padrão:
/// - iOS: marca no alto, cartão de vidro com os campos agrupados;
/// - Android: marca na arte do topo e uma folha do Material 3 que sobe com
///   o formulário.
/// Com o teclado aberto, nada é empurrado de qualquer jeito: a marca encolhe
/// e o rodapé some, e o formulário acompanha o teclado com a mesma curva.
class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  /// Montagem da tela: marca, formulário e rodapé, em sequência.
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  /// Os pulsos de luz que correm pelas trilhas do fundo (contínuo e lento).
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  static const _curvaTeclado = Curves.easeOutCubic;
  static const _tempoTeclado = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _entrada.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quem pediu menos movimento recebe a tela pronta e o fundo parado.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1;
      _pulso.stop();
    } else if (!_pulso.isAnimating) {
      _pulso.repeat();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    super.dispose();
  }

  double _trecho(double inicio, double fim, {Curve curva = Curves.easeOutCubic}) =>
      curva.transform(((_entrada.value - inicio) / (fim - inicio)).clamp(0.0, 1.0));

  /// A peça entra subindo e acendendo no trecho [inicio]–[fim] da entrada.
  Widget _surge(double inicio, double fim, Widget filho, {double deslocamento = 24}) => AnimatedBuilder(
        animation: _entrada,
        builder: (_, f) {
          final t = _trecho(inicio, fim);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, deslocamento * (1 - t)), child: f),
          );
        },
        child: filho,
      );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    if (auth.isAuth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE),
      );
    }
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final aberto = teclado > 0;

    // A tela é sempre escura: ícones claros na barra de status.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0E1726),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: _Fundo.base,
      // O teclado é tratado aqui, com animação própria: sem isto o Scaffold
      // encolhe a tela de uma vez e tudo "pula" para cima.
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulso, _entrada]),
              builder: (_, __) => CustomPaint(
                painter: _Fundo(pulso: _pulso.value, entrada: _trecho(0, 0.55, curva: Curves.easeOutCubic)),
              ),
            ),
          ),
        ),
        Platform.isAndroid ? _android(context, teclado, aberto) : _ios(context, teclado, aberto),
      ]),
      ),
    );
  }

  // ── Marca e rodapé (comuns) ───────────────────────────────────────────────

  Widget _marca(bool aberto, double largura) => AnimatedBuilder(
        animation: _entrada,
        builder: (_, __) => AnimatedContainer(
          duration: _tempoTeclado,
          curve: _curvaTeclado,
          // Com o teclado, a marca encolhe para caber o formulário inteiro.
          width: aberto ? largura * 0.5 : largura,
          child: MarcaSouPMRR(
            largura: aberto ? largura * 0.5 : largura,
            progresso: _trecho(0.0, 0.62, curva: Curves.linear),
            corrente: _trecho(0.62, 0.95, curva: Curves.easeInOutSine),
          ),
        ),
      );

  Widget _lema(bool aberto) => AnimatedSize(
        duration: _tempoTeclado,
        curve: _curvaTeclado,
        child: aberto
            ? const SizedBox(width: double.infinity)
            : _surge(
                0.45,
                0.8,
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'POLÍCIA MILITAR DE RORAIMA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                deslocamento: 10,
              ),
      );

  /// Os três brasões, cada um no seu tamanho, e a versão.
  Widget _rodape(bool aberto) => AnimatedSize(
        duration: _tempoTeclado,
        curve: _curvaTeclado,
        child: aberto
            ? const SizedBox(width: double.infinity)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _surge(0.62, 0.9, const _Marca(arquivo: 'assets/imagens/brasao_governo_rr.png', altura: 42,
                        rotulo: 'Governo de Roraima')),
                    _divisor(),
                    _surge(0.68, 0.94, const _Marca(arquivo: 'assets/imagens/logo_pmrr.png', altura: 44,
                        rotulo: 'Polícia Militar de Roraima')),
                    _divisor(),
                    _surge(0.74, 1.0, const _Marca(arquivo: 'assets/imagens/logo_dti_marca.png', altura: 34,
                        rotulo: 'Departamento de Tecnologia da Informação')),
                  ],
                ),
                const SizedBox(height: 10),
                _surge(
                  0.8,
                  1.0,
                  TextoVersao(
                    formato: (v) => v.isEmpty ? 'DTI/PMRR' : 'Versão $v · DTI/PMRR',
                    estilo: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), letterSpacing: .4),
                  ),
                  deslocamento: 8,
                ),
              ]),
      );

  Widget _divisor() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.white.withValues(alpha: 0.16),
      );

  // ── iOS ───────────────────────────────────────────────────────────────────

  Widget _ios(BuildContext context, double teclado, bool aberto) {
    final larguraMarca = (MediaQuery.sizeOf(context).width * 0.62).clamp(200.0, 300.0);
    return SafeArea(
      child: AnimatedPadding(
        duration: _tempoTeclado,
        curve: _curvaTeclado,
        // Acima do teclado, descontando a área segura que ele já cobre.
        padding: EdgeInsets.only(bottom: math.max(0, teclado - MediaQuery.paddingOf(context).bottom)),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(children: [
                      AnimatedSize(
                        duration: _tempoTeclado,
                        curve: _curvaTeclado,
                        child: SizedBox(height: aberto ? 4 : math.max(12, c.maxHeight * 0.06)),
                      ),
                      _marca(aberto, larguraMarca),
                      _lema(aberto),
                      SizedBox(height: aberto ? 14 : 30),
                      _surge(
                        0.3,
                        0.75,
                        _CartaoVidro(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Entrar',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('Use a matrícula e a senha do SouPMRR.',
                                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.72))),
                            const SizedBox(height: 18),
                            const AuthForm(),
                          ]),
                        ),
                        deslocamento: 36,
                      ),
                      SizedBox(height: aberto ? 8 : 28),
                      _rodape(aberto),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Android ───────────────────────────────────────────────────────────────

  Widget _android(BuildContext context, double teclado, bool aberto) {
    final mq = MediaQuery.of(context);
    final larguraMarca = (mq.size.width * 0.58).clamp(190.0, 280.0);
    return Column(children: [
      // Topo: a marca sobre a arte. Com o teclado, encolhe.
      SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: _tempoTeclado,
          curve: _curvaTeclado,
          height: aberto ? 96 : mq.size.height * 0.30,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _marca(aberto, larguraMarca),
              _lema(aberto),
            ]),
          ),
        ),
      ),
      // A folha do Material 3, que sobe com o formulário.
      Expanded(
        child: _surge(
          0.25,
          0.7,
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1220).withValues(alpha: 0.82),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, -6))],
            ),
            child: AnimatedPadding(
              duration: _tempoTeclado,
              curve: _curvaTeclado,
              padding: EdgeInsets.only(bottom: teclado),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + (aberto ? 0 : mq.padding.bottom)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Alça da folha.
                      Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const Text('Entrar no SouPMRR',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Use a matrícula e a senha do SouPMRR.',
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.72))),
                      const SizedBox(height: 20),
                      const AuthForm(material: true),
                      SizedBox(height: aberto ? 0 : 20),
                      _rodape(aberto),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          deslocamento: 60,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Cartão de vidro do iOS: desfoque de verdade sobre a arte, borda de luz.
class _CartaoVidro extends StatelessWidget {
  const _CartaoVidro({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.02)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: child,
          ),
        ),
      );
}

/// Um brasão do rodapé, com o nome para o leitor de tela.
class _Marca extends StatelessWidget {
  const _Marca({required this.arquivo, required this.altura, required this.rotulo});
  final String arquivo;
  final double altura;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: rotulo,
        child: Image.asset(arquivo, height: altura, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
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
