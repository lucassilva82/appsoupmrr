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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ViaturaQuebrada(origem: falha.origem),
            const SizedBox(height: 12),
            Text(falha.titulo,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(falha.deQuem,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Text(falha.texto, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (aoTentar != null && falha.acao == AcaoFalha.tentarDeNovo) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
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
                      descricaoInicial: '${falha.titulo}.\n\nO que eu estava fazendo: \n\n--- Detalhes técnicos ---\n$detalhes',
                    ),
                  ));
                },
              ),
            ],
            const SizedBox(height: 10),
            SelectableText('Código ${falha.codigo}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('Detalhes técnicos', style: theme.textTheme.bodySmall),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(detalhes, style: theme.textTheme.bodySmall),
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

  static const _azul = Color(0xFF1E3A8A);
  static const _verde = Color(0xFF15803D);
  static const _ambar = Color(0xFFF59E0B);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..isAntiAlias = true;
    final solo = s.height - 18;
    // Chão.
    canvas.drawLine(Offset(8, solo + 12), Offset(s.width - 8, solo + 12), p..color = chao..strokeWidth = 2);

    // Triângulo de sinalização no chão, atrás da viatura.
    final tri = Path()
      ..moveTo(20, solo + 11)
      ..lineTo(32, solo - 10)
      ..lineTo(44, solo + 11)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFFDC2626)..style = PaintingStyle.stroke..strokeWidth = 3);

    canvas.save();
    // Inclinada para a frente: o pneu dianteiro (direita) está murcho.
    canvas.translate(s.width * 0.55, solo);
    canvas.rotate(0.06);
    canvas.translate(-s.width * 0.55, -solo);

    final x0 = 54.0, x1 = s.width - 18;
    final base = solo - 2;
    // Carroceria: parte de baixo branca, de cima azul, faixa verde.
    final corpo = RRect.fromLTRBR(x0, base - 30, x1, base, const Radius.circular(8));
    canvas.drawRRect(corpo, Paint()..color = escuro ? const Color(0xFFE5E7EB) : Colors.white);
    canvas.drawRRect(corpo, Paint()..color = const Color(0xFF94A3B8)..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawRect(Rect.fromLTRB(x0 + 2, base - 18, x1 - 2, base - 13), Paint()..color = _verde);
    final cabine = RRect.fromLTRBR(x0 + 22, base - 50, x1 - 46, base - 28, const Radius.circular(8));
    canvas.drawRRect(cabine, Paint()..color = _azul);
    // Vidros escuros.
    canvas.drawRRect(RRect.fromLTRBR(x0 + 28, base - 46, x0 + 58, base - 32, const Radius.circular(4)),
        Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(RRect.fromLTRBR(x0 + 62, base - 46, x1 - 52, base - 32, const Radius.circular(4)),
        Paint()..color = const Color(0xFF0F172A));
    // Giroflex apagado.
    canvas.drawRRect(RRect.fromLTRBR(x0 + 40, base - 56, x0 + 80, base - 50, const Radius.circular(3)),
        Paint()..color = const Color(0xFF64748B));
    // Pisca-alerta âmbar, piscando.
    final aceso = (t * 4).floor().isEven;
    final pisca = Paint()..color = _ambar.withValues(alpha: aceso ? 1 : 0.25);
    canvas.drawCircle(Offset(x1 - 3, base - 22), 3.5, pisca);
    canvas.drawCircle(Offset(x0 + 3, base - 22), 3.5, pisca);

    // Rodas: a de trás inteira, a da frente murcha (achatada).
    final roda = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(Offset(x0 + 22, base + 2), 11, roda);
    canvas.drawCircle(Offset(x0 + 22, base + 2), 4, Paint()..color = const Color(0xFF9CA3AF));
    canvas.drawOval(Rect.fromCenter(center: Offset(x1 - 26, base + 6), width: 26, height: 14), roda);
    canvas.drawCircle(Offset(x1 - 26, base + 4), 3.5, Paint()..color = const Color(0xFF9CA3AF));
    canvas.restore();

    // Fumaça saindo do capô (sobe e some).
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1;
      final cx = s.width - 46 + math.sin((f + i) * math.pi) * 6;
      final cy = solo - 40 - f * 46;
      canvas.drawCircle(Offset(cx, cy), 6 + f * 10,
          Paint()..color = (escuro ? Colors.white : const Color(0xFF64748B)).withValues(alpha: 0.35 * (1 - f)));
    }
  }

  @override
  bool shouldRepaint(_PintorViatura old) => old.t != t || old.escuro != escuro;
}
