import 'package:flutter/material.dart';

import '../../app/registro_modulos.dart';
import '../../widgets/aviso_rapido.dart';
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
    return mostrarFolhaBloqueio(context, m);
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
            codigo: codigo));
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

/// Folha com a mensagem do painel (iOS: altura média com alça; Android:
/// bottom sheet modal). O código fica à vista para o militar informar.
Future<void> mostrarFolhaBloqueio(BuildContext context, MensagemBloqueio m) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => FolhaBloqueio(mensagem: m),
  );
}

class FolhaBloqueio extends StatelessWidget {
  const FolhaBloqueio({super.key, required this.mensagem});

  final MensagemBloqueio mensagem;

  static IconData iconeDoMotivo(String motivo) => switch (motivo) {
        'manutencao' => Icons.construction_rounded,
        'em_breve' => Icons.schedule_rounded,
        'restrito' => Icons.lock_outline_rounded,
        'atualizar_app' => Icons.system_update_rounded,
        _ => Icons.block_rounded,
      };

  static String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = mensagem.motivo == 'restrito'
        ? theme.colorScheme.error
        : kCorAtencao;
    final p = mensagem.previsao?.toLocal();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 26,
                backgroundColor: cor.withValues(alpha: 0.14),
                child: Icon(iconeDoMotivo(mensagem.motivo), color: cor, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(mensagem.titulo,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(mensagem.texto, style: theme.textTheme.bodyLarge),
            if (p != null) ...[
              const SizedBox(height: 10),
              Text(
                  'Volta em ${_doisDigitos(p.day)}/${_doisDigitos(p.month)} '
                  'às ${_doisDigitos(p.hour)}h${p.minute == 0 ? '' : _doisDigitos(p.minute)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: SelectableText('Código ${mensagem.codigo}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
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
