import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/log/registro_log.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../models/auth_model.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/vidro.dart';
import '../comunicados/comunicados_page.dart';
import '../servicos/servicos_page.dart';

/// Card criado no painel (docs/SOUPM_2_2.md §4.6): `home.livre.<chave>` com
/// um dos modelos que o app sabe desenhar. Modelo desconhecido, ou "Número"
/// sem o valor pronto, não desenha nada: versão antiga nunca quebra.
class CardPainel extends StatelessWidget {
  const CardPainel({super.key, required this.bloco});

  final BlocoInicio bloco;

  static const modelos = {'campanha', 'atalho', 'lista', 'numero'};

  /// O card desenha alguma coisa? A Início usa para não deixar espaço vazio.
  static bool desenha(BlocoInicio b) {
    final modelo = b.bruto['modelo'];
    if (!modelos.contains(modelo)) return false;
    final d = b.bruto['dados'];
    if (d is! Map || '${d['titulo'] ?? ''}'.trim().isEmpty) return false;
    if (modelo == 'numero' && d['valor'] == null) return false;
    return true;
  }

  Map<String, dynamic> get _dados => Map<String, dynamic>.from(bloco.bruto['dados'] as Map);
  Map<String, dynamic>? get _acao =>
      bloco.bruto['acao'] is Map ? Map<String, dynamic>.from(bloco.bruto['acao'] as Map) : null;

  Future<void> _agir(BuildContext context, Map<String, dynamic>? acao) async {
    if (acao == null) return;
    final tipo = '${acao['tipo']}';
    final destino = '${acao['destino'] ?? ''}';
    registrar('inicio.card_tocar', chave: bloco.chave, dados: {'acao': tipo});
    switch (tipo) {
      case 'funcao':
      case 'chamado':
        final gestor = context.read<Auth>().isSuperUser;
        final item = itemPorChave(tipo == 'chamado' ? 'atend.chamados' : destino,
            menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
        if (item != null) {
          await abrirFuncao(context, item, origem: 'card');
        } else {
          avisoAtencao(context, 'Função indisponível',
              texto: 'Esta função não está disponível para você agora. Código MD-CARD-DESTINO.');
        }
      case 'comunicado':
        await abrirCentral(context, origem: 'card');
      case 'link':
        final uri = Uri.tryParse(destino);
        final ok = uri != null && uri.scheme == 'https' &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          registrar('inicio.card_tocar', chave: bloco.chave, resultado: 'falhou', codigo: 'AP-LINK');
          avisoErro(context, 'Não foi possível abrir o link',
              texto: 'O aparelho não abriu o endereço deste card. Tente de novo mais tarde. Código AP-LINK.');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!desenha(bloco)) return const SizedBox.shrink();
    final d = _dados;
    final acao = _acao;
    final titulo = '${d['titulo']}'.trim();
    final texto = '${d['texto'] ?? ''}'.trim();
    final arte = Arte.de(bloco.arte);
    final modelo = bloco.bruto['modelo'];

    final Widget conteudo;
    if (modelo == 'lista') {
      final theme = Theme.of(context);
      final linhas = [
        for (final l in (d['linhas'] is List ? d['linhas'] as List : const []))
          if (l is Map && '${l['texto'] ?? ''}'.trim().isNotEmpty) Map<String, dynamic>.from(l),
      ].take(3).toList();
      conteudo = CartaoVidro(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final l in linhas)
            InkWell(
              onTap: l['destino'] == null ? null : () => _agir(context, {'tipo': l['tipo'] ?? 'funcao', 'destino': l['destino']}),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  Expanded(child: Text('${l['texto']}', style: theme.textTheme.bodyMedium)),
                  if (l['destino'] != null)
                    Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
        ]),
      );
    } else {
      const branco = Colors.white;
      // Medidas do protótipo `.card-livre`: raio 18, 16 de respiro, selo
      // de vidro, título 19, texto 13,5 e o botão em pílula contornada.
      conteudo = CartaoArte(
        arte: arte,
        padding: const EdgeInsets.all(16),
        onTap: acao == null ? null : () => _agir(context, acao),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if ('${d['selo'] ?? ''}'.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${d['selo']}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: branco)),
                  ),
                Row(children: [
                  if (modelo == 'atalho') ...[
                    Icon(iconePorNome('${d['icone']}') ?? arte.icones.first, color: branco, size: 28),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.19, color: branco, height: 1.35)),
                  ),
                ]),
                if (modelo == 'numero')
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${d['valor']}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: branco)),
                  ),
                if (texto.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  FractionallySizedBox(
                    widthFactor: 0.68,
                    child: Text(texto,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, height: 1.35, color: branco)),
                  ),
                ],
                if (acao != null && '${acao['rotulo'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${acao['rotulo']}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: branco)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: branco),
                    ]),
                  ),
                ],
              ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(container: true, label: '$titulo. $texto', child: conteudo),
    );
  }
}
