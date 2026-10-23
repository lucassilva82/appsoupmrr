import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/chamados/chamados_api.dart' show chaveSischamados;
import '../../features/chamados/chamados_page.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../ambiente_app.dart';
import '../design/viatura.dart';
import '../config/app_config.dart';
import '../log/registro_log.dart';
import '../navegacao/abrir_funcao.dart';
import '../../features/servicos/servicos_page.dart' show menuEmUso;
import 'falha_app.dart';

/// Erro no lugar do conteúdo (docs/SOUPM_2_2.md §9.1): a viatura da abertura,
/// quebrada; o que aconteceu, de quem é o problema, o que fazer, os botões e
/// "Detalhes técnicos" (fechado), que vão sozinhos no chamado técnico. Nada
/// sensível nos detalhes: sem senha, CPF nem valores.
class EstadoErro extends StatelessWidget {
  const EstadoErro({super.key, required this.falha, this.aoTentar, this.tela, this.chave});

  final FalhaApp falha;
  final VoidCallback? aoTentar;

  /// Onde o erro aconteceu e a função (para o chamado e o log).
  final String? tela;
  final String? chave;

  String _detalhes(DateTime quando) => [
        'Código: ${falha.codigo}',
        'Data e hora: ${quando.day.toString().padLeft(2, '0')}/${quando.month.toString().padLeft(2, '0')}/${quando.year} '
            '${quando.hour.toString().padLeft(2, '0')}:${quando.minute.toString().padLeft(2, '0')}',
        if (tela != null) 'Tela: $tela',
        if (chave != null) 'Função: $chave',
        'Origem: ${falha.deQuem}',
        'App: SouPMRR ${AmbienteApp.versao} (build ${AmbienteApp.build})',
        'Sistema: ${AmbienteApp.plataforma}${AmbienteApp.aparelho == null ? '' : ' · ${AmbienteApp.aparelho}'}',
        if (RegistroLog.atual != null) 'Sessão: ${RegistroLog.atual!.sessaoId}',
      ].join('\n');

  /// O chamado só aparece com a função liberada e a chave no build.
  static bool _podeAbrirChamado(BuildContext context) {
    if (chaveSischamados.isEmpty) return false;
    final gestor = context.read<Auth>().isSuperUser;
    final item = itemPorChave('atend.chamados', menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
    return item != null && !item.bloqueado;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quando = DateTime.now();
    final detalhes = _detalhes(quando);
    final chamado = _podeAbrirChamado(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final linha = theme.colorScheme.onSurface.withValues(alpha: .10);
    final passos = falha.oQueFazer;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: ViaturaQuebrada(origem: falha.origem)),
            const SizedBox(height: 12),
            Text(falha.titulo,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(falha.texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: mudo)),
            const SizedBox(height: 10),
            // De quem é o problema (protótipo `.quem`).
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: linha), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline_rounded, size: AppIconSize.xs, color: mudo),
                  const SizedBox(width: 6),
                  Flexible(child: Text(falha.deQuem, style: TextStyle(fontSize: 12.5, color: mudo))),
                ]),
              ),
            ),
            if (passos.isNotEmpty) ...[
              const SizedBox(height: 14),
              // O que fazer (protótipo `.oque`).
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: .04),
                  border: Border.all(color: linha),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('O que fazer',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                  const SizedBox(height: 6),
                  for (final p in passos)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('•  ', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                        Expanded(child: Text(p, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface))),
                      ]),
                    ),
                ]),
              ),
            ],
            if (aoTentar != null && falha.acao == AcaoFalha.tentarDeNovo) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: aoTentar,
                icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
                label: const Text('Tentar de novo'),
              ),
            ],
            if (chamado) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.support_agent_outlined),
                label: Text(RepositorioConfig.atual.texto('botao_erro') ?? 'Abrir chamado técnico'),
                onPressed: () {
                  registrar('funcao.tocar', chave: 'atend.chamados', codigo: falha.codigo, dados: {'origem': 'erro'});
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NovoChamadoPage(
                      api: apiChamados(context),
                      tituloInicial: 'Erro ${falha.codigo} no SouPMRR',
                      descricaoInicial:
                          '${falha.titulo}.\n\nO que eu estava fazendo: \n\n--- Detalhes técnicos ---\n$detalhes',
                    ),
                  ));
                },
              ),
            ],
            const SizedBox(height: 12),
            // Detalhes técnicos, fechados, com o código à vista (protótipo).
            Material(
              color: theme.colorScheme.onSurface.withValues(alpha: .04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: linha)),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(Icons.bug_report_outlined, size: AppIconSize.sm, color: mudo),
                  title: Text('Detalhes técnicos',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  trailing: Text(falha.codigo,
                      style: TextStyle(
                          fontFamily: 'Menlo', fontFamilyFallback: const ['monospace'], fontSize: 12, color: mudo)),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(detalhes, style: TextStyle(fontSize: 12.5, height: 1.5, color: mudo)),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: AppIconSize.xs),
                      label: const Text('Copiar detalhes'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: detalhes));
                        if (context.mounted) avisoSucesso(context, 'Detalhes copiados');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A viatura da abertura, quebrada (§9.1): inclinada para a frente com o pneu
/// dianteiro murcho, fumaça no capô, giroflex apagado, pisca-alerta âmbar e o
/// triângulo no chão, com o selo do tipo de erro. Parada com "Reduzir movimento".
class ViaturaQuebrada extends StatefulWidget {
  const ViaturaQuebrada({super.key, required this.origem});
  final OrigemFalha origem;

  @override
  State<ViaturaQuebrada> createState() => _ViaturaQuebradaState();
}

class _ViaturaQuebradaState extends State<ViaturaQuebrada> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.3;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  IconData get _selo => switch (widget.origem) {
        OrigemFalha.rede || OrigemFalha.aparelho => Icons.wifi_off_rounded,
        OrigemFalha.servidor => Icons.dns_outlined,
        OrigemFalha.conta => Icons.person_off_outlined,
        OrigemFalha.dado => Icons.storage_outlined,
        OrigemFalha.app => Icons.build_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Ilustração: uma viatura parada com o pneu furado e fumaça no capô.',
      excludeSemantics: true,
      child: SizedBox(
        width: 220,
        height: 130,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _PintorViatura(
                  t: _c.value,
                  escuro: theme.brightness == Brightness.dark,
                  chao: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 0,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
              child: Icon(_selo, size: AppIconSize.sm, color: theme.colorScheme.onError),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PintorViatura extends CustomPainter {
  _PintorViatura({required this.t, required this.escuro, required this.chao});
  final double t;
  final bool escuro;
  final Color chao;

  static const _ambar = Color(0xFFF59E0B);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..isAntiAlias = true;
    final solo = s.height - 18;
    // Chão.
    canvas.drawLine(
        Offset(8, solo + 12),
        Offset(s.width - 8, solo + 12),
        p
          ..color = chao
          ..strokeWidth = 2);

    // Triângulo de sinalização no chão, atrás da viatura.
    final tri = Path()
      ..moveTo(20, solo + 11)
      ..lineTo(32, solo - 10)
      ..lineTo(44, solo + 11)
      ..close();
    canvas.drawPath(
        tri,
        Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    // A viatura nova da abertura (o mesmo desenho, giroflex apagado),
    // inclinada para a frente: o pneu dianteiro está murcho.
    final centro = Offset(s.width * 0.55, solo - viaturaRaioRoda + 4);
    canvas.save();
    canvas.translate(centro.dx + viaturaEixoDianteiro, centro.dy);
    canvas.rotate(0.07);
    canvas.translate(-viaturaEixoDianteiro, 0);
    desenharViatura(canvas, giroflexLigado: false);
    // Pisca-alerta âmbar nas lanternas, piscando.
    final aceso = (t * 4).floor().isEven;
    final pisca = Paint()..color = _ambar.withValues(alpha: aceso ? 1 : 0.25);
    canvas.drawCircle(Offset(viaturaLargura / 2 - 6, -viaturaRaioRoda - 4), 3.5, pisca);
    canvas.drawCircle(Offset(-viaturaLargura / 2 + 6, -viaturaRaioRoda - 4), 3.5, pisca);
    // Pneu dianteiro murcho: a borracha amassada no chão.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(viaturaEixoDianteiro, viaturaRaioRoda - 1), width: viaturaRaioRoda * 2.4, height: 7),
        Paint()..color = const Color(0xFF111827));
    canvas.restore();

    // Fumaça saindo do capô (sobe e some).
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1;
      final cx = centro.dx + viaturaEixoDianteiro + 6 + math.sin((f + i) * math.pi) * 6;
      final cy = centro.dy - 34 - f * 46;
      canvas.drawCircle(Offset(cx, cy), 6 + f * 10,
          Paint()..color = (escuro ? Colors.white : const Color(0xFF64748B)).withValues(alpha: 0.35 * (1 - f)));
    }
  }

  @override
  bool shouldRepaint(_PintorViatura old) => old.t != t || old.escuro != escuro;
}
