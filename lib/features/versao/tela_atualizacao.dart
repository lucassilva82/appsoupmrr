import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/log/registro_log.dart';
import '../../widgets/aviso_rapido.dart';
import '../../utils/app_theme.dart';
import '../../widgets/vidro.dart';
import '../../core/design/viatura.dart';

/// Link da loja da própria plataforma (cada loja só fala de si, §31).
String get urlLoja => Platform.isIOS
    ? 'https://apps.apple.com/us/app/soupmrr/id6466815434'
    : 'https://play.google.com/store/apps/details?id=pm.rr.soupmrr';
String get nomeLoja => Platform.isIOS ? 'App Store' : 'Google Play';

Future<bool> abrirLoja() async {
  final uri = Uri.parse(urlLoja);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Atualização obrigatória (docs/SOUPM_2_2.md §10.3): o Fusca velho da PMRR
/// com a versão instalada e a viatura nova com a da loja. Ao tocar em
/// Atualizar, a velha apaga, a nova dá um salto e a loja abre. Textos do
/// painel por plataforma (`app_config.versao`), com o padrão do app.
class TelaAtualizacao extends StatefulWidget {
  const TelaAtualizacao({super.key, required this.instalada, this.regra});
  final String instalada;
  final RegraVersao? regra;

  @override
  State<TelaAtualizacao> createState() => _TelaAtualizacaoState();
}

class _TelaAtualizacaoState extends State<TelaAtualizacao> with TickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final _troca = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  String get _codigo => 'CF-VERSAO-${Platform.isIOS ? 'IOS' : 'ANDROID'}';
  String get _nova => widget.regra?.recomendada ?? widget.regra?.minima ?? 'nova';

  @override
  void initState() {
    super.initState();
    registrar('tela.abrir', chave: 'versao.obrigatoria',
        codigo: _codigo, dados: {'instalada': widget.instalada, 'minima': widget.regra?.minima});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _troca.dispose();
    super.dispose();
  }

  Future<void> _atualizar() async {
    registrar('versao.atualizar', codigo: _codigo, dados: {'instalada': widget.instalada});
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _troca.forward(from: 0);
    }
    final ok = await abrirLoja();
    if (!ok && mounted) {
      registrar('versao.atualizar', resultado: 'falhou', codigo: 'CF-LOJA');
      avisoErro(context, 'Não foi possível abrir a $nomeLoja',
          texto: 'Abra a $nomeLoja no aparelho e procure por SouPMRR. Código CF-LOJA.');
    }
  }

  /// Padrão do app quando o painel não escreveu as novidades desta loja.
  static const _novidadesPadrao = [
    (Icons.dashboard_outlined, 'Menu novo, organizado por áreas'),
    (Icons.campaign_outlined, 'Comunicados oficiais na tela inicial'),
    (Icons.shield_outlined, 'Mais segurança para seus dados'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escuro = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final apoio = cs.onSurface.withValues(alpha: 0.68);
    final titulo = widget.regra?.titulo ?? 'Essa versão já deu baixa';
    final artigo = Platform.isIOS ? 'na' : 'no';
    final texto = widget.regra?.texto ??
        'A ${widget.instalada} está velha demais para rodar. A $_nova já está $artigo $nomeLoja, revisada e de tanque cheio.';
    final doPainel = widget.regra?.novidades ?? const <String>[];
    final novidades = doPainel.isEmpty
        ? _novidadesPadrao
        : [for (final t in doPainel) (Icons.check_circle_outline_rounded, t)];
    final erro = escuro ? AppColors.falhaEscuro : AppColors.falha;
    final ok = escuro ? AppColors.sucessoEscuro : AppColors.sucesso;

    return FundoSuave(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Semantics(
                    label: 'Um Fusca velho da polícia, com a versão ${widget.instalada}, e um policial triste ao lado; à direita, uma viatura nova, com a versão $_nova.',
                    excludeSemantics: true,
                    // A cena tem a medida do protótipo (360 × 206) e só encolhe.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: _PintorCena.largura,
                        height: _PintorCena.altura,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_loop, _troca]),
                              builder: (_, __) => CustomPaint(
                                painter: _PintorCena(
                                  loop: _loop.value,
                                  troca: _troca.value,
                                  instalada: widget.instalada,
                                  nova: _nova,
                                  chao: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -4, width: 164, top: 190,
                            child: Center(child: _Etiqueta(texto: 'Sua versão · ${widget.instalada}', cor: erro)),
                          ),
                          Positioned(
                            right: -4, width: 164, top: 190,
                            child: Center(child: _Etiqueta(texto: 'Nova · $_nova', cor: ok, icone: Icons.check_circle_rounded)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text('ATUALIZAÇÃO OBRIGATÓRIA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: escuro ? AppColors.gold : const Color(0xFF8A5A00))),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: apoio)),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: Column(children: [
                      for (final n in novidades)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
                            ),
                            child: Row(children: [
                              ExcludeSemantics(child: Icon(n.$1, size: AppIconSize.sm, color: cs.primary)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(n.$2, style: const TextStyle(fontSize: 14.5))),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _troca.isAnimating ? null : _atualizar,
                      icon: Icon(Platform.isIOS ? Icons.apps_rounded : Icons.shop_rounded, size: AppIconSize.sm),
                      label: Text('Atualizar $artigo $nomeLoja'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text('Leva menos de um minuto ·', style: TextStyle(fontSize: 12, color: apoio)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_codigo,
                            style: TextStyle(fontSize: 11.5, fontFamily: 'Menlo', fontFamilyFallback: const ['monospace'], color: apoio)),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.cor, this.icone});
  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[Icon(icone, size: 14, color: cor), const SizedBox(width: 4)],
          Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ]),
      );
}

/// A cena do protótipo (`telaAtualizar`), em vetor próprio: o Fusca velho da
/// PMRR (esquerda), o policial e a viatura nova (direita). Sem foto, placa ou
/// pessoa real. As medidas são as do protótipo, num quadro de 360 × 206.
class _PintorCena extends CustomPainter {
  _PintorCena({
    required this.loop,
    required this.troca,
    required this.instalada,
    required this.nova,
    required this.chao,
  });
  static const largura = 360.0;
  static const altura = 206.0;

  final double loop;
  final double troca;

  /// As duas vão escritas na lateral, como o número da viatura.
  final String instalada;
  final String nova;
  final Color chao;

  // Os desenhos do protótipo têm 200 × 112 e aparecem com 164 de largura.
  static const _k = 164 / 200;

  @override
  void paint(Canvas canvas, Size s) {
    // Chão: um fio que some nas pontas.
    canvas.drawRect(
      const Rect.fromLTWH(0, altura - 23, largura, 2),
      Paint()
        ..shader = LinearGradient(colors: [
          chao.withValues(alpha: 0),
          chao.withValues(alpha: 0.25),
          chao.withValues(alpha: 0.25),
          chao.withValues(alpha: 0),
        ], stops: const [0, 0.2, 0.8, 1]).createShader(const Rect.fromLTWH(0, 0, largura, 2)),
    );

    // ── Fusca: treme e solta fumaça; na troca perde a cor e afunda ─────────
    final tremor = math.sin(loop * math.pi * 16) * 0.8 * (1 - troca);
    canvas.save();
    canvas.translate(-4 + tremor, altura - 20 - 92 + Curves.easeIn.transform(troca) * 8);
    canvas.scale(_k);
    _fusca(canvas, apagado: troca);
    canvas.restore();

    // ── Viatura nova: o meio dos eixos do desenho fica em (105, 88) ────────
    final salto = troca > 0.75 ? math.sin((troca - 0.75) / 0.25 * math.pi) * 14 : 0.0;
    canvas.save();
    canvas.translate(largura + 4 - 164 + 105 * _k, altura - 20 - 92 + 88 * _k - salto);
    desenharViatura(canvas,
        giroflexAceso: (loop * 6).floor().isEven,
        giroRodas: troca * math.pi * 4,
        versao: nova);
    canvas.restore();

    // ── Policial: triste ao lado do Fusca; na troca, dois pulinhos até a
    // viatura nova e fica feliz.
    final passo = Curves.easeInOut.transform(troca.clamp(0.0, 1.0));
    final px = 142 + 40 * passo;
    final pulo = (math.sin(troca * math.pi * 2).abs()) * 14 * (troca < 1 ? 1 : 0);
    canvas.save();
    canvas.translate(px, altura - 22 - 94 - pulo);
    canvas.scale(52 / 44);
    _policial(canvas, feliz: troca > 0.42);
    canvas.restore();

    // Confete no salto.
    if (troca > 0.75 && troca < 1) {
      final r = math.Random(7);
      final t = (troca - 0.75) / 0.25;
      const cores = [Color(0xFFFFD54F), Color(0xFF22A64A), Color(0xFF1F4FCF), Color(0xFFE5484D), Color(0xFFFFFFFF)];
      for (var i = 0; i < 14; i++) {
        final dx = ((i * 37) % 120 - 60).toDouble();
        canvas.drawRect(
          Rect.fromCenter(center: Offset(282 + dx * t, 70 - 40 * t + 90 * t * t * r.nextDouble()), width: 4, height: 7),
          Paint()..color = cores[i % 5].withValues(alpha: 1 - t),
        );
      }
    }
  }

  /// O Fusca do protótipo (`fusca()`), no quadro de 200 × 112.
  void _fusca(Canvas c, {required double apagado}) {
    final a = 1 - apagado * 0.7;
    Paint cor(int v, [double op = 1]) => Paint()..color = Color(v).withValues(alpha: op * a);
    Paint traco(int v, double w) => Paint()
      ..color = Color(v).withValues(alpha: a)
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Fumaça saindo de trás.
    for (var i = 0; i < 3; i++) {
      final f = (loop + i / 3) % 1;
      c.drawCircle(Offset(10 - f * 16, 80 - f * 30), 6 + f * 6,
          Paint()..color = const Color(0xFFB9BEC6).withValues(alpha: 0.45 * (1 - f) * (1 - apagado)));
    }
    // Antena entortada.
    c.drawPath(Path()..moveTo(150, 30)..lineTo(164, 8)..lineTo(170, 10), traco(0xFF8A8F96, 1.4));
    // Carroceria.
    c.drawPath(
        Path()
          ..moveTo(18, 86)
          ..cubicTo(18, 64, 34, 48, 62, 42)
          ..cubicTo(76, 24, 118, 20, 138, 34)
          ..cubicTo(160, 40, 182, 56, 184, 86)
          ..close(),
        cor(0xFFE4DECF));
    c.drawOval(Rect.fromCenter(center: const Offset(52, 80), width: 54, height: 34), cor(0xFFDCD5C4));
    c.drawOval(Rect.fromCenter(center: const Offset(152, 80), width: 52, height: 32), cor(0xFFDCD5C4));
    // Faixa azul desbotada.
    c.drawPath(
        Path()
          ..moveTo(20, 70)
          ..cubicTo(60, 62, 140, 62, 184, 70)
          ..lineTo(184, 76)
          ..cubicTo(140, 68, 60, 68, 20, 76)
          ..close(),
        cor(0xFF6F86B2));
    // Vidro, com a coluna e a trinca.
    c.drawPath(
        Path()
          ..moveTo(70, 44)
          ..cubicTo(82, 30, 110, 27, 124, 36)
          ..lineTo(126, 54)
          ..lineTo(68, 54)
          ..close(),
        cor(0xFF59616C));
    c.drawLine(const Offset(96, 31), const Offset(96, 54), traco(0xFFE4DECF, 3)..strokeCap = StrokeCap.butt);
    c.drawPath(Path()..moveTo(102, 34)..lineTo(108, 42)..lineTo(103, 44)..lineTo(109, 51), traco(0xFFD5DBE3, 1.1));
    // Giroflex redondo de antigamente, apagado.
    c.drawRRect(RRect.fromLTRBR(92, 18, 102, 23, const Radius.circular(1)), cor(0xFF7E838B));
    c.drawArc(Rect.fromCircle(center: const Offset(97, 18), radius: 4), math.pi, math.pi, true, cor(0xFF9B9FA6));
    // "POLÍCIA" e a versão instalada como número da viatura.
    _texto(c, 'POLÍCIA', const Offset(72, 66), 8, FontWeight.w900, const Color(0xFF5E7098).withValues(alpha: a));
    _texto(c, 'VTR $instalada', const Offset(108, 84), 6, FontWeight.w700, const Color(0xFF5E7098).withValues(alpha: a));
    // Farol, estribo e ferrugem.
    c.drawCircle(const Offset(177, 62), 5, cor(0xFFCFC9A8));
    c.drawCircle(const Offset(177, 62), 5, traco(0xFF9B9FA6, 1));
    c.drawLine(const Offset(60, 86), const Offset(140, 86), traco(0xFF4A4F57, 4));
    c.drawCircle(const Offset(40, 58), 3.2, cor(0xFF9B6B3D, 0.75));
    c.drawCircle(const Offset(132, 78), 2.6, cor(0xFF9B6B3D, 0.75));
    c.drawCircle(const Offset(160, 50), 2, cor(0xFF9B6B3D, 0.7));
    // Para-choques: o da frente torto.
    c.save();
    c.translate(186, 84);
    c.rotate(20 * math.pi / 180);
    c.translate(-186, -84);
    c.drawRRect(RRect.fromLTRBR(182, 80, 192, 84, const Radius.circular(2)), cor(0xFFA7ADB5));
    c.restore();
    c.drawRRect(RRect.fromLTRBR(10, 80, 20, 84, const Radius.circular(2)), cor(0xFFA7ADB5));
    // Rodas: a de trás murcha.
    c.drawOval(Rect.fromCenter(center: const Offset(52, 95), width: 30, height: 16.1), cor(0xFF1A1C20));
    c.drawOval(Rect.fromCenter(center: const Offset(52, 95), width: 13, height: 7.8), cor(0xFF8A8F96));
    c.drawCircle(const Offset(152, 90), 13, cor(0xFF1A1C20));
    c.drawCircle(const Offset(152, 90), 7.15, cor(0xFFB9BEC6));
    c.drawCircle(const Offset(152, 90), 2.86, cor(0xFF7A8089));
  }

  void _texto(Canvas c, String t, Offset base, double tam, FontWeight peso, Color cor) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: tam, height: 1, fontWeight: peso, color: cor)),
      textDirection: TextDirection.ltr,
    )..layout();
    // O SVG posiciona pela linha de base.
    tp.paint(c, base - Offset(0, tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  /// O policial do protótipo (`militar()`), no quadro de 44 × 80: farda e
  /// boina da PMRR, rosto de desenho, sem semelhança com ninguém.
  void _policial(Canvas c, {required bool feliz}) {
    const farda = Color(0xFF2F3D33);
    const tinta = Color(0xFF3B2A1E);
    final linha = Paint()
      ..color = tinta
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawOval(Rect.fromCenter(center: const Offset(22, 78), width: 26, height: 5), Paint()..color = const Color(0x33000000));
    c.drawRRect(RRect.fromLTRBR(14, 54, 21, 76, const Radius.circular(3)), Paint()..color = const Color(0xFF1E2A22));
    c.drawRRect(RRect.fromLTRBR(23, 54, 30, 76, const Radius.circular(3)), Paint()..color = const Color(0xFF1E2A22));
    c.drawPath(
        Path()
          ..moveTo(10, 30)
          ..quadraticBezierTo(22, 25, 34, 30)
          ..lineTo(33, 57)
          ..lineTo(11, 57)
          ..close(),
        Paint()..color = farda);
    c.drawRect(const Rect.fromLTWH(11, 44, 22, 3), Paint()..color = const Color(0xFF1A1A1A));
    c.drawRRect(RRect.fromLTRBR(20, 43, 24, 48, const Radius.circular(1)), Paint()..color = const Color(0xFFC9A227));
    final braco = Paint()
      ..color = farda
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (feliz) {
      c.drawPath(Path()..moveTo(11, 32)..quadraticBezierTo(2, 22, 6, 12), braco);
      c.drawPath(Path()..moveTo(33, 32)..quadraticBezierTo(42, 22, 38, 12), braco);
    } else {
      c.drawPath(Path()..moveTo(11, 32)..quadraticBezierTo(4, 44, 8, 54), braco);
      c.drawPath(Path()..moveTo(33, 32)..quadraticBezierTo(40, 44, 36, 54), braco);
    }
    c.drawCircle(const Offset(22, 19), 10, Paint()..color = const Color(0xFFD9A877));
    c.drawPath(Path()..moveTo(11, 13)..quadraticBezierTo(22, 3, 33, 13)..close(), Paint()..color = const Color(0xFF1F4FCF));
    c.drawRRect(RRect.fromLTRBR(9, 12, 35, 15, const Radius.circular(1.5)), Paint()..color = const Color(0xFF132F80));
    c.drawCircle(const Offset(22, 9), 1.6, Paint()..color = const Color(0xFFC9A227));
    if (feliz) {
      c.drawCircle(const Offset(18.5, 19), 1.2, Paint()..color = tinta);
      c.drawCircle(const Offset(25.5, 19), 1.2, Paint()..color = tinta);
      c.drawPath(Path()..moveTo(17, 23)..quadraticBezierTo(22, 28, 27, 23), linha..strokeWidth = 1.4);
    } else {
      c.drawPath(Path()..moveTo(17, 19)..quadraticBezierTo(18.5, 17.5, 20, 19), linha);
      c.drawPath(Path()..moveTo(24, 19)..quadraticBezierTo(25.5, 17.5, 27, 19), linha);
      c.drawPath(Path()..moveTo(18, 26)..quadraticBezierTo(22, 23, 26, 26), linha);
      // Lágrima, caindo devagar.
      final f = (loop * 2) % 1;
      c.save();
      c.translate(0, f * 6);
      c.drawPath(
          Path()
            ..moveTo(17.5, 21)
            ..quadraticBezierTo(16.5, 23, 17.5, 24)
            ..quadraticBezierTo(18.5, 23, 17.5, 21),
          Paint()..color = const Color(0xFF7CC4FF).withValues(alpha: 1 - f));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorCena old) =>
      old.loop != loop || old.troca != troca || old.nova != nova || old.instalada != instalada || old.chao != chao;
}

/// Cartão da versão recomendada no topo da Início (§10.2): dispensável, uma
/// vez por versão.
class CartaoVersaoRecomendada extends StatefulWidget {
  const CartaoVersaoRecomendada({super.key, required this.recomendada});
  final String recomendada;

  @override
  State<CartaoVersaoRecomendada> createState() => _CartaoVersaoRecomendadaState();
}

class _CartaoVersaoRecomendadaState extends State<CartaoVersaoRecomendada> {
  bool _escondido = true;
  String get _chave => 'versao_recomendada_dispensada_${widget.recomendada}';

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final p = await SharedPreferences.getInstance();
        if (mounted) setState(() => _escondido = p.getBool(_chave) == true);
      } catch (_) {
        if (mounted) setState(() => _escondido = false);
      }
    }();
  }

  Future<void> _dispensar() async {
    setState(() => _escondido = true);
    registrar('versao.recomendada_dispensar', dados: {'recomendada': widget.recomendada});
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_chave, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_escondido) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: CartaoVidro(
        tingimento: theme.colorScheme.primary,
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(children: [
          Icon(Icons.system_update_alt_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('A versão ${widget.recomendada} do SouPMRR já está na $nomeLoja.')),
          TextButton(
            onPressed: () {
              registrar('versao.atualizar', dados: {'de': 'recomendada'});
              unawaited(abrirLoja());
            },
            child: const Text('Atualizar'),
          ),
          IconButton(tooltip: 'Agora não', icon: const Icon(Icons.close), onPressed: _dispensar),
        ]),
      ),
    );
  }
}
