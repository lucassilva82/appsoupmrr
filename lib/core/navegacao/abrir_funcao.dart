import 'package:flutter/material.dart';

import '../../app/registro_modulos.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/versao/tela_atualizacao.dart' show abrirLoja;
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/vidro.dart';
import '../design/arte_cartao.dart';
import '../design/folha_arte.dart';
import '../config/app_config.dart';
import '../log/registro_log.dart';

/// Abre uma função do menu, do mesmo jeito em Serviços, na busca, nos
/// atalhos e nos cards (docs/SOUPM_2_2.md §3.3 e §5.2):
/// - bloqueada: folha com o motivo e o código `MD-…`, nunca um aviso genérico;
/// - rota que esta versão não conhece: folha "Atualize o app";
/// - senão, abre dentro da aba atual (a barra de abas não some).
///
/// [origem] vai para o log: menu, busca, atalho, card, push.
Future<void> abrirFuncao(BuildContext context, ItemMenu item,
    {String origem = 'menu'}) async {
  registrar('funcao.tocar',
      chave: item.chave,
      dados: {'origem': origem, 'estado': item.bloqueado ? 'bloqueado' : 'ativo'});

  if (item.bloqueado) {
    final m = item.mensagem ??
        MensagemBloqueio(
            motivo: 'indisponivel',
            titulo: '${item.rotulo} indisponível',
            texto: 'Esta função está temporariamente indisponível.',
            codigo: 'MD-${item.chave.toUpperCase()}-INDISPONIVEL');
    registrar('modulo.bloqueio_visto',
        chave: item.chave, codigo: m.codigo, dados: {'motivo': m.motivo});
    return mostrarFolhaBloqueio(context, m, arte: arteDaChave(item.chave));
  }

  final rota = item.rota;
  if (rota == null || registroModulos.porRota(rota) == null) {
    final codigo = 'MD-${item.chave.toUpperCase()}-ATUALIZAR';
    registrar('modulo.bloqueio_visto',
        chave: item.chave, codigo: codigo, dados: {'motivo': 'atualizar_app'});
    return mostrarFolhaBloqueio(
        context,
        MensagemBloqueio(
            motivo: 'atualizar_app',
            titulo: 'Atualize o app',
            texto: 'Esta versão do SouPMRR ainda não tem "${item.rotulo}". '
                'Atualize o app na loja para usar esta função.',
            codigo: codigo),
        arte: arteDaChave(item.chave));
  }

  try {
    // Rota redirecionada (ex.: plantão → escalas) abre a função nova.
    final destino = registroModulos.porRota(rota)!.rota ?? rota;
    await Navigator.of(context).pushNamed(destino);
  } catch (e) {
    debugPrint('[MENU] não abriu ${item.chave}: $e');
    registrar('funcao.tocar',
        chave: item.chave, resultado: 'falhou', codigo: 'AP-ROTA');
    if (context.mounted) {
      avisoErro(context, 'Não foi possível abrir ${item.rotulo}',
          texto: 'Feche e abra o app de novo. Código AP-ROTA.');
    }
  }
}

/// A arte da área de uma função pela chave (`rh.…`, `op.…`, `atend.…`),
/// para a folha de bloqueio ter a cara da área de onde o militar veio.
Arte arteDaChave(String chave) {
  final prefixo = chave.split('.').first;
  return Arte.de(switch (prefixo) {
    'op' => 'operacional',
    'atend' => 'atendimento',
    'com' || 'inst' => 'institucional',
    'pend' => 'pe',
    _ => prefixo,
  });
}

/// Folha com a mensagem do painel (protótipo, folha "bloqueio"), no desenho
/// da FolhaArte (padrão 2.2): a faixa com a arte da área, o ícone do motivo
/// e o título; embaixo o texto, a previsão de volta, o botão da ação que o
/// painel escolheu e o código à vista para o militar informar.
Future<void> mostrarFolhaBloqueio(BuildContext context, MensagemBloqueio m,
    {Arte? arte}) {
  return showModalBottomSheet<void>(
    context: context,
    // Cobre também a barra de abas, como no protótipo.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => FolhaBloqueio(mensagem: m, arte: arte),
  );
}

class FolhaBloqueio extends StatelessWidget {
  const FolhaBloqueio({super.key, required this.mensagem, this.arte});

  final MensagemBloqueio mensagem;

  /// Arte da área da função; sem ela, a de `rh`.
  final Arte? arte;

  static IconData iconeDoMotivo(String motivo) => switch (motivo) {
        'manutencao' => Icons.construction_rounded,
        'em_breve' => Icons.schedule_rounded,
        'restrito' => Icons.lock_outline_rounded,
        'atualizar_app' => Icons.system_update_rounded,
        _ => Icons.block_rounded,
      };

  static String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  /// "Volta hoje às 18h", "Volta amanhã às 7h30", "Volta em 30/10 às 18h".
  static String previsaoTexto(DateTime p, [DateTime? agora]) {
    final hoje = agora ?? DateTime.now();
    final dia = DateTime(p.year, p.month, p.day);
    final d0 = DateTime(hoje.year, hoje.month, hoje.day);
    final hora = '${p.hour}h${p.minute == 0 ? '' : _doisDigitos(p.minute)}';
    final dif = dia.difference(d0).inDays;
    if (dif == 0) return 'Volta hoje às $hora';
    if (dif == 1) return 'Volta amanhã às $hora';
    return 'Volta em ${_doisDigitos(p.day)}/${_doisDigitos(p.month)} às $hora';
  }

  /// Rótulo e ícone do botão da ação (§3.2); nulo = só "Entendi".
  ({String rotulo, IconData icone})? _acao() => switch (mensagem.acao) {
        'avisar_quando_voltar' => (
            rotulo: mensagem.motivo == 'em_breve' ? 'Avisar quando chegar' : 'Avisar quando voltar',
            icone: Icons.notifications_active_outlined,
          ),
        'atualizar_app' => (rotulo: 'Atualizar o app', icone: Icons.system_update_rounded),
        'abrir_link' when (mensagem.acaoDestino ?? '').startsWith('https://') =>
          (rotulo: 'Saiba mais', icone: Icons.open_in_new_rounded),
        _ => null,
      };

  Future<void> _executar(BuildContext context) async {
    final nav = Navigator.of(context);
    switch (mensagem.acao) {
      case 'avisar_quando_voltar':
        registrar('modulo.avisar_quando_voltar', codigo: mensagem.codigo);
        nav.pop();
        avisoSucesso(context, 'Pedido registrado',
            texto: 'Você recebe uma notificação quando a função estiver disponível.');
      case 'atualizar_app':
        nav.pop();
        await abrirLoja();
      case 'abrir_link':
        nav.pop();
        await launchUrl(Uri.parse(mensagem.acaoDestino!), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = switch (mensagem.motivo) {
      'manutencao' || 'restrito' => theme.colorScheme.error,
      'atualizar_app' => theme.colorScheme.primary,
      _ => kCorAtencao,
    };
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final p = mensagem.previsao?.toLocal();
    final acao = _acao();
    return FolhaArte(
      arte: arte ?? Arte.de('rh'),
      icone: iconeDoMotivo(mensagem.motivo),
      titulo: mensagem.titulo,
      paddingCorpo: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mensagem.texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: mudo)),
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CartaoVidro(
                raio: 12,
                tingimento: cor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_outlined, size: AppIconSize.xs, color: cor),
                  const SizedBox(width: 8),
                  Text(previsaoTexto(p), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          const SizedBox(height: 18),
          if (acao != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _executar(context),
                icon: Icon(acao.icone, size: AppIconSize.sm),
                label: Text(acao.rotulo),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendi')),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendi')),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText('Código ${mensagem.codigo}',
                style: TextStyle(fontFamily: 'Menlo', fontFamilyFallback: const ['monospace'], fontSize: 12, color: mudo)),
          ),
        ],
      ),
    );
  }
}

/// A função pela chave (ou apelido): primeiro no menu em uso, depois no
/// menu de reserva e, por fim, no registro de módulos (funções fora do
/// menu, como as de Perfil). Nula se esta versão não a conhece.
ItemMenu? itemPorChave(String chave, {required List<ItemMenu> menu}) {
  for (final area in menu) {
    for (final f in area.filhos) {
      if (f.chave == chave || f.apelidos.contains(chave)) return f;
    }
  }
  final m = registroModulos.porChave(chave);
  if (m == null) return null;
  return ItemMenu(
      chave: m.chave,
      tipo: 'funcao',
      rotulo: m.rotuloPadrao,
      icone: m.icone,
      rota: m.rota);
}
