import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ambiente_app.dart';
import '../../core/config/app_config.dart';
import '../../core/log/registro_log.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/vidro.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titulo = widget.regra?.titulo ?? 'Essa versão já deu baixa';
    final texto = widget.regra?.texto ??
        'A ${widget.instalada} está velha demais para rodar. A $_nova já está na $nomeLoja, revisada e de tanque cheio.';
    return FundoSuave(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Semantics(
                    label: 'Ilustração: uma viatura velha, com a versão ${widget.instalada}, ao lado de uma viatura nova, com a versão $_nova.',
                    excludeSemantics: true,
                    child: SizedBox(
                      height: 170,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_loop, _troca]),
                        builder: (_, __) => CustomPaint(
                          size: const Size(double.infinity, 170),
                          painter: _PintorCena(loop: _loop.value, troca: _troca.value),
                        ),
                      ),
                    ),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _Etiqueta(texto: 'Sua versão · ${widget.instalada}', cor: theme.colorScheme.error),
                    _Etiqueta(texto: 'Nova · $_nova', cor: const Color(0xFF14713B)),
                  ]),
                  const SizedBox(height: 20),
                  Text('ATUALIZAÇÃO OBRIGATÓRIA',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(titulo, textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(texto, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _troca.isAnimating ? null : _atualizar,
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: Text('Atualizar na $nomeLoja'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Código $_codigo · ${AmbienteApp.plataforma}', style: theme.textTheme.bodySmall),
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
  const _Etiqueta({required this.texto, required this.cor});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: cor), borderRadius: BorderRadius.circular(10)),
        child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// Fusca velho (esquerda) e viatura nova (direita), vetoriais e próprios: sem
/// foto, placa ou pessoa real.
class _PintorCena extends CustomPainter {
  _PintorCena({required this.loop, required this.troca});
  final double loop;
  final double troca;

  @override
  void paint(Canvas canvas, Size s) {
    final solo = s.height - 18;
    canvas.drawLine(Offset(0, solo + 14), Offset(s.width, solo + 14),
        Paint()..color = Colors.white24..strokeWidth = 2);
    final meio = s.width / 2;

    // ── Fusca: treme, fumaça atrás; na troca perde a cor e afunda ──────────
    final tremor = math.sin(loop * math.pi * 16) * 1.2 * (1 - troca);
    canvas.save();
    canvas.translate(meio * 0.5 + tremor, solo + troca * 6);
    final apagado = 1 - troca * 0.7;
    final corpo = Path()
      ..moveTo(-62, 0)
      ..cubicTo(-62, -34, -36, -58, 0, -58)
      ..cubicTo(36, -58, 62, -34, 62, 0)
      ..close();
    canvas.drawPath(corpo, Paint()..color = const Color(0xFFD6D3C4).withValues(alpha: apagado));
    // Faixa azul desbotada e ferrugem.
    canvas.drawRect(const Rect.fromLTRB(-60, -20, 60, -13), Paint()..color = const Color(0xFF6B7FA8).withValues(alpha: apagado));
    canvas.drawCircle(const Offset(-38, -8), 5, Paint()..color = const Color(0xFF9A5B2E).withValues(alpha: 0.7 * apagado));
    canvas.drawCircle(const Offset(30, -30), 4, Paint()..color = const Color(0xFF9A5B2E).withValues(alpha: 0.6 * apagado));
    // Vidro trincado.
    canvas.drawRRect(RRect.fromLTRBR(-30, -50, 30, -30, const Radius.circular(10)), Paint()..color = const Color(0xFF334155));
    canvas.drawLine(const Offset(-10, -48), const Offset(4, -34), Paint()..color = Colors.white54..strokeWidth = 1);
    canvas.drawLine(const Offset(4, -34), const Offset(14, -44), Paint()..color = Colors.white54..strokeWidth = 1);
    // Giroflex redondo apagado e antena torta.
    canvas.drawCircle(const Offset(0, -62), 6, Paint()..color = const Color(0xFF64748B));
    canvas.drawLine(const Offset(40, -40), const Offset(58, -64), Paint()..color = Colors.white38..strokeWidth = 1.5);
    // Rodas: a de trás murcha.
    final roda = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(const Offset(36, 2), 12, roda);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-36, 6), width: 28, height: 15), roda);
    canvas.restore();
    // Fumaça do Fusca.
    for (var i = 0; i < 3; i++) {
      final f = (loop + i / 3) % 1;
      canvas.drawCircle(Offset(meio * 0.5 - 70 - f * 24, solo - 8 - f * 26), 6 + f * 9,
          Paint()..color = Colors.white.withValues(alpha: 0.28 * (1 - f) * (1 - troca)));
    }

    // ── Viatura nova: caminhonete com barra de LED; na troca, salto ────────
    final salto = math.sin(troca * math.pi) * 18;
    canvas.save();
    canvas.translate(meio * 1.5, solo - salto);
    const azul = Color(0xFF1E3A8A);
    const verde = Color(0xFF15803D);
    final carroceria = RRect.fromLTRBR(-74, -32, 74, 0, const Radius.circular(8));
    canvas.drawRRect(carroceria, Paint()..color = Colors.white);
    canvas.drawRect(const Rect.fromLTRB(-72, -20, 72, -14), Paint()..color = verde);
    canvas.drawRect(const Rect.fromLTRB(-72, -14, 72, -12), Paint()..color = const Color(0xFFE0A100));
    final cabine = RRect.fromLTRBR(-30, -58, 40, -30, const Radius.circular(9));
    canvas.drawRRect(cabine, Paint()..color = azul);
    canvas.drawRRect(RRect.fromLTRBR(-24, -54, 4, -36, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(RRect.fromLTRBR(8, -54, 34, -36, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));
    // Barra de giroflex em LED, vermelho e azul alternando.
    final fase = (loop * 6).floor().isEven;
    canvas.drawRRect(RRect.fromLTRBR(-20, -66, 0, -59, const Radius.circular(3)),
        Paint()..color = fase ? const Color(0xFFEF4444) : const Color(0xFF7F1D1D));
    canvas.drawRRect(RRect.fromLTRBR(0, -66, 20, -59, const Radius.circular(3)),
        Paint()..color = fase ? const Color(0xFF1E3A8A) : const Color(0xFF60A5FA));
    // Faróis em LED e rodas de liga com pinça vermelha.
    canvas.drawRRect(RRect.fromLTRBR(66, -28, 74, -22, const Radius.circular(2)), Paint()..color = const Color(0xFFFFF7CC));
    for (final x in [-46.0, 46.0]) {
      canvas.save();
      canvas.translate(x, 2);
      canvas.rotate(troca * math.pi * 4);
      canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF111827));
      canvas.drawCircle(Offset.zero, 7, Paint()..color = const Color(0xFFCBD5E1));
      canvas.drawRect(const Rect.fromLTRB(-1.5, -7, 1.5, 7), Paint()..color = const Color(0xFF64748B));
      canvas.restore();
      canvas.drawArc(Rect.fromCircle(center: Offset(x, 2), radius: 9), -2.4, 1.2, false,
          Paint()..color = const Color(0xFFDC2626)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    canvas.restore();

    // Confete no salto.
    if (troca > 0.3 && troca < 1) {
      final r = math.Random(7);
      for (var i = 0; i < 18; i++) {
        final ang = r.nextDouble() * math.pi;
        final d = (troca - 0.3) * 120 * (0.5 + r.nextDouble());
        canvas.drawRect(
          Rect.fromCenter(center: Offset(meio * 1.5 + math.cos(ang) * d, solo - 70 - math.sin(ang) * d), width: 4, height: 7),
          Paint()..color = [const Color(0xFFEF4444), const Color(0xFF60A5FA), const Color(0xFFFACC15), const Color(0xFF22C55E)][i % 4]
              .withValues(alpha: 1 - troca),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorCena old) => old.loop != loop || old.troca != troca;
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
