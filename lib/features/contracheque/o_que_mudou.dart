import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/arte_cartao.dart';
import '../../core/design/folha_arte.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../models/contracheque_model.dart';
import '../../models/meses_contracheque_model.dart';
import '../../services/dados_sql.dart';
import '../../utils/app_theme.dart';
import '../../widgets/vidro.dart';

/// "O que mudou no contracheque" (P1, docs/SOUPM_2_2.md §11): as rubricas
/// que entraram, saíram ou mudaram de valor em relação ao mês anterior da
/// mesma folha. Tudo é calculado no aparelho com os mesmos dados que a tela
/// já mostra; nada novo vai para a API.

const _chave = 'rh.contracheques.mudou';
const _prefixo = 'CC';

enum TipoMudanca { entrou, saiu, mudou }

class MudancaRubrica {
  const MudancaRubrica({required this.tipo, required this.descricao, required this.provento, this.antes, this.depois});
  final TipoMudanca tipo;
  final String descricao;
  final bool provento;
  final double? antes;
  final double? depois;

  double get diferenca => (depois ?? 0) - (antes ?? 0);
}

/// Lê "1234.56" (da API) e "1.234,56" (já formatado pela tela).
double valorRubrica(String v) {
  final t = v.trim();
  if (t.isEmpty) return 0;
  final normal = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(normal) ?? 0;
}

double _valor(TipoProvento r) => valorRubrica(r.tipoRubrica == 'P' ? r.provento : r.desconto);

/// Compara rubrica a rubrica (pela natureza e pela descrição; rubricas com o
/// mesmo nome no mesmo mês são somadas). Diferenças de menos de 1 centavo
/// não contam.
List<MudancaRubrica> compararRubricas(List<TipoProvento> atual, List<TipoProvento> anterior) {
  Map<String, double> somar(List<TipoProvento> l) {
    final m = <String, double>{};
    for (final r in l) {
      final k = '${r.tipoRubrica == 'P' ? 'P' : 'D'}|${r.descricaoRubrica.trim()}';
      m[k] = (m[k] ?? 0) + _valor(r);
    }
    return m;
  }

  final a = somar(atual), b = somar(anterior);
  final saida = <MudancaRubrica>[];
  for (final k in {...b.keys, ...a.keys}) {
    final provento = k.startsWith('P|');
    final desc = k.substring(2);
    final antes = b[k], depois = a[k];
    if (antes == null) {
      saida.add(MudancaRubrica(tipo: TipoMudanca.entrou, descricao: desc, provento: provento, depois: depois));
    } else if (depois == null) {
      saida.add(MudancaRubrica(tipo: TipoMudanca.saiu, descricao: desc, provento: provento, antes: antes));
    } else if ((depois - antes).abs() >= 0.01) {
      saida.add(MudancaRubrica(tipo: TipoMudanca.mudou, descricao: desc, provento: provento, antes: antes, depois: depois));
    }
  }
  saida.sort((x, y) => y.diferenca.abs().compareTo(x.diferenca.abs()));
  return saida;
}

int _ordem(MesesContracheque m) => (int.tryParse(m.ano) ?? 0) * 100 + (int.tryParse(m.mes) ?? 0);

/// O mês anterior da mesma folha (tipo, relação de trabalho e folha), na
/// lista do próprio ano ou, em janeiro, do ano anterior.
MesesContracheque? mesAnteriorNaLista(MesesContracheque atual, List<MesesContracheque> lista) {
  bool mesmaFolha(MesesContracheque m) =>
      m.tipo == atual.tipo && m.relacaoTrabalho == atual.relacaoTrabalho && m.folha == atual.folha;
  final candidatos = lista.where((m) => mesmaFolha(m) && _ordem(m) < _ordem(atual)).toList()
    ..sort((x, y) => _ordem(y).compareTo(_ordem(x)));
  return candidatos.isEmpty ? null : candidatos.first;
}

class ComparacaoMes {
  const ComparacaoMes({required this.anterior, required this.mudancas});
  final MesesContracheque? anterior;
  final List<MudancaRubrica> mudancas;
}

/// Busca o mês anterior e compara. [dados] é trocável nos testes.
Future<ComparacaoMes> compararComAnterior(
    MesesContracheque atual, ContrachequeModel doMes, {DadosSql? dados}) async {
  final d = dados ?? DadosSql();
  try {
    final ano = int.tryParse(atual.ano) ?? DateTime.now().year;
    var anterior = mesAnteriorNaLista(atual, await d.listaMesesContracheque(atual.cpf, '$ano'));
    anterior ??= mesAnteriorNaLista(atual, await d.listaMesesContracheque(atual.cpf, '${ano - 1}'));
    if (anterior == null) return const ComparacaoMes(anterior: null, mudancas: []);
    final cc = await d.buscaContracheque(anterior.cpf.isEmpty ? atual.cpf : anterior.cpf, anterior.ano, anterior.mes,
        anterior.mesExtenso, anterior.matricula, anterior.tipo, anterior.codProvento, anterior.relacaoTrabalho, anterior.folha);
    return ComparacaoMes(anterior: anterior, mudancas: compararRubricas(doMes.proventos, cc.proventos));
  } on FalhaApp {
    rethrow;
  } catch (e) {
    throw FalhaApp.inesperada(_prefixo, e);
  }
}

final _real = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);

/// Botão "O que mudou" da tela do contracheque: abre a folha com a
/// comparação. Os valores obedecem ao olho da tela ([valoresVisiveis]).
class BotaoOQueMudou extends StatelessWidget {
  const BotaoOQueMudou({super.key, required this.mes, required this.contracheque, required this.valoresVisiveis, this.dados});
  final MesesContracheque mes;
  final ContrachequeModel contracheque;
  final bool valoresVisiveis;
  final DadosSql? dados;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _abrir(context),
      icon: const Icon(Icons.compare_arrows_rounded, size: AppIconSize.sm),
      label: const Text('O que mudou em relação ao mês anterior'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    registrar('contracheque.mudou_ver', chave: _chave, dados: {'mes': mes.mes, 'ano': mes.ano});
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      // Folha no padrão 2.2 (FolhaArte): o fundo e a alça vêm do cabeçalho
      // com a arte, desenhado em _FolhaMudancas.
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, rolagem) => _FolhaMudancas(
          futuro: compararComAnterior(mes, contracheque, dados: dados),
          rolagem: rolagem,
          valoresVisiveis: valoresVisiveis,
          mes: mes,
        ),
      ),
    );
  }
}

class _FolhaMudancas extends StatelessWidget {
  const _FolhaMudancas({required this.futuro, required this.rolagem, required this.valoresVisiveis, required this.mes});
  final Future<ComparacaoMes> futuro;
  final ScrollController rolagem;
  final bool valoresVisiveis;
  final MesesContracheque mes;

  String _v(double? v) => v == null ? '—' : (valoresVisiveis ? _real.format(v) : '••••••');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apagado = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final escuro = theme.brightness == Brightness.dark;
    final verde = escuro ? AppColors.sucessoEscuro : AppColors.sucesso;
    final vermelho = escuro ? AppColors.falhaEscuro : AppColors.falha;
    // Recados (erro, sem mês anterior, nada mudou) num cartão com a arte
    // discreta do contracheque, para não ficarem soltos na folha.
    Widget recado(String texto) => CartaoVidro(
          arte: Arte.de('cc'),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: SizedBox(
            width: double.infinity,
            child: Text(texto, style: theme.textTheme.bodyMedium),
          ),
        );
    return FutureBuilder<ComparacaoMes>(
      future: futuro,
      builder: (context, s) {
        Widget corpo;
        if (s.connectionState != ConnectionState.done) {
          corpo = const Padding(
              padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator.adaptive()));
        } else if (s.hasError) {
          final f = s.error is FalhaApp ? s.error as FalhaApp : FalhaApp.inesperada(_prefixo, s.error!);
          registrarErro(f, tela: _chave);
          corpo = recado('${f.titulo}. ${f.texto} Código ${f.codigo}.');
        } else if (s.data!.anterior == null) {
          corpo = recado('Não há mês anterior desta folha para comparar.');
        } else if (s.data!.mudancas.isEmpty) {
          corpo = recado(
              'Nenhuma rubrica mudou em relação a ${s.data!.anterior!.mesExtenso}/${s.data!.anterior!.ano}.');
        } else {
          final ant = s.data!.anterior!;
          corpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Comparado com ${ant.mesExtenso}/${ant.ano}.', style: theme.textTheme.bodySmall?.copyWith(color: apagado)),
            const SizedBox(height: 8),
            CartaoVidro(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, m) in s.data!.mudancas.indexed) ...[
              if (i > 0) Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
              Semantics(
                container: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Icon(
                        switch (m.tipo) {
                          TipoMudanca.entrou => Icons.add_circle_outline_rounded,
                          TipoMudanca.saiu => Icons.remove_circle_outline_rounded,
                          TipoMudanca.mudou => Icons.swap_vert_rounded,
                        },
                        size: AppIconSize.sm,
                        color: m.provento ? verde : vermelho),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.descricao, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            [
                              m.provento ? 'Provento' : 'Desconto',
                              switch (m.tipo) {
                                TipoMudanca.entrou => 'entrou neste mês',
                                TipoMudanca.saiu => 'saiu neste mês',
                                TipoMudanca.mudou => '${_v(m.antes)} → ${_v(m.depois)}',
                              },
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: apagado)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      valoresVisiveis
                          ? '${m.diferenca >= 0 ? '+' : '−'}${_real.format(m.diferenca.abs())}'
                          : '••••••',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
            ],
              ]),
            ),
          ]);
        }
        // Mesmo desenho da FolhaArte (faixa com a arte no topo, alça, ícone
        // e título); a lista embaixo usa o controle da folha arrastável.
        return Material(
          color: escuro ? const Color(0xFF10161F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CabecalhoFolhaArte(
              arte: Arte.de('cc'),
              icone: Icons.compare_arrows_rounded,
              titulo: 'O que mudou em ${mes.mesExtenso}/${mes.ano}',
              subtitulo: 'Rubricas que entraram, saíram ou mudaram de valor '
                  'em relação ao mês anterior da mesma folha.',
            ),
            Expanded(
              child: ListView(
                controller: rolagem,
                padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
                children: [corpo],
              ),
            ),
          ]),
        );
      },
    );
  }
}
