import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';

import '../core/design/arte_cartao.dart';
import '../models/auth_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import '../view/second_screen.dart';
import '../widgets/vidro.dart';

class Contracheque extends StatefulWidget {
  const Contracheque({Key? key}) : super(key: key);

  @override
  State<Contracheque> createState() => _ContrachequeState();
}

class _ContrachequeState extends State<Contracheque> {
  final DadosSql dadosSql = DadosSql();

  // O ano selecionado morava no widget. Widget é imutável por contrato no
  // Flutter — estado que muda pertence ao State, e guardá-lo no widget faz o
  // valor sobreviver a trocas que deveriam reiniciá-lo.
  String _anoSelecionado = DateTime.now().year.toString();

  // A consulta era montada dentro do build(), então qualquer reconstrução do
  // pai refazia a busca no servidor à toa e devolvia a lista ao estado de
  // carregamento. Agora ela só é refeita quando o ano muda, que é a única
  // coisa capaz de mudar o resultado.
  late Future<List<MesesContracheque>> _dados = _buscaDadosSql(_anoSelecionado);

  void _selecionaAno(String ano) {
    if (ano == _anoSelecionado) return;
    setState(() {
      _anoSelecionado = ano;
      _dados = _buscaDadosSql(ano);
    });
  }

  List<int> get listaAnos {
    final anoAtual = DateTime.now().year;
    return List.generate(anoAtual - 2019, (i) => anoAtual - i);
  }

  Future<List<MesesContracheque>> _buscaDadosSql(String ano) async {
    final auth = Provider.of<Auth>(context, listen: false);
    return dadosSql.listaMesesContracheque(auth.cpf!, ano);
  }

  /// Agrupa a lista por mês (chave = "mes_ano"), preservando a ordem
  List<MapEntry<String, List<MesesContracheque>>> _groupByMonth(
      List<MesesContracheque> lista) {
    final Map<String, List<MesesContracheque>> map = {};
    for (final item in lista) {
      final key = '${item.mes}_${item.ano}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map.entries.toList();
  }

  /// Verifica se o item é do mês/ano atual (para exibir o badge NOVO).
  bool _isThisMonth(MesesContracheque item) {
    final now = DateTime.now();
    return item.mes == now.month.toString() && item.ano == now.year.toString();
  }

  String _capitalizeFolha(String folha) {
    return folha
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FundoSuave(child: Scaffold(
      appBar: CustomAppBar(title: 'Contracheques'),
      // Ação principal da tela: botão cheio do tema (AppColors.acao), sem o
      // degradê com brilho passando que o FAB antigo tinha (DESIGN §7: nada
      // se move sem motivo).
      floatingActionButton: FilledButton.icon(
        style: FilledButton.styleFrom(
          elevation: 4,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        onPressed: () {
          final auth = Provider.of<Auth>(context, listen: false);
          Navigator.of(context).pushNamed(
            AppRoutes.CONTRACHEQUE_GRAFICO_PAGE,
            arguments: {
              'cpf': auth.cpf!,
              'ano': _anoSelecionado,
            },
          );
        },
        icon: const Icon(Icons.insights_rounded, size: AppIconSize.sm),
        label: const Text('Análise salarial'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Topo com a arte da área; o seletor de ano mora dentro dele, como
          // continuação do cartão (antes era uma faixa de pílulas solta).
          TopoArte(
            arte: Arte.de('cc'),
            icone: Icons.receipt_long_outlined,
            titulo: 'Contracheques',
            subtitulo: 'Escolha o ano e toque no mês para ver o '
                'contracheque e baixar o PDF.',
            margem: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _buildYearBar(),
          ),

          // ── Lista agrupada ────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<MesesContracheque>>(
              future: _dados,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                if (snapshot.hasError) return SecondScreen();
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isDark);
                }
                return _buildGroupedList(snapshot.data!, isDark);
              },
            ),
          ),
        ],
      ),
    ));
  }

  // ── Seletor de anos ───────────────────────────────────────────────────
  // Dentro do TopoArte: pílulas de vidro claro sobre a arte (texto branco),
  // a selecionada mais clara e com contorno. Alvo de 44 pt de altura.
  Widget _buildYearBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: listaAnos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final anoStr = listaAnos[i].toString();
          final isSelected = anoStr == _anoSelecionado;
          return Semantics(
            button: true,
            selected: isSelected,
            label: 'Ano $anoStr',
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _selecionaAno(anoStr),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: isSelected ? 0.24 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: isSelected ? 0.55 : 0.16),
                    ),
                  ),
                  child: Text(
                    anoStr,
                    style: TextStyle(
                      color: Colors.white
                          .withValues(alpha: isSelected ? 1 : 0.80),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Lista agrupada por mês ────────────────────────────────────────────
  Widget _buildGroupedList(List<MesesContracheque> lista, bool isDark) {
    final groups = _groupByMonth(lista);
    return ListView.builder(
      // Embaixo, espaço para o botão "Análise salarial" não cobrir o último.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final entry = groups[i];
        final items = entry.value;
        final mesExtenso = items.first.mesExtenso;
        return _buildMonthGroup(mesExtenso, items, isDark, ctx);
      },
    );
  }

  // ── Grupo de um mês ───────────────────────────────────────────────────
  // Lista agrupada no padrão do app (como a central de comunicados): rótulo
  // do mês em cima e as folhas daquele mês juntas numa caixa de vidro, uma
  // linha por folha, separadas por divisor.
  Widget _buildMonthGroup(String mesExtenso, List<MesesContracheque> items,
      bool isDark, BuildContext ctx) {
    final theme = Theme.of(ctx);
    final aoFundo = theme.colorScheme.onSurface;
    final primaria = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      mesExtenso.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: primaria,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                if (items.length > 1) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· ${items.length} folhas',
                    style: TextStyle(
                      fontSize: 11,
                      color: aoFundo.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          CartaoVidro(
            raio: 14,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var j = 0; j < items.length; j++) ...[
                  if (j > 0)
                    Divider(
                      height: 1,
                      indent: 46,
                      color: aoFundo.withValues(alpha: 0.08),
                    ),
                  _buildPayslipCard(items[j], isDark, ctx),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Linha de cada contracheque ────────────────────────────────────────
  // A cor do tipo de folha fica só no ícone e no selo.
  Widget _buildPayslipCard(
      MesesContracheque item, bool isDark, BuildContext ctx) {
    final theme = Theme.of(ctx);
    final aoFundo = theme.colorScheme.onSurface;
    final isAtivo = item.tipo == 'A';
    final accentColor = isAtivo
        ? theme.colorScheme.primary
        : (isDark ? Colors.amber.shade300 : Colors.amber.shade900);

    final primaryText = item.tipo == 'A'
        ? _capitalizeFolha(item.relacaoTrabalho)
        : _capitalizeFolha(
            item.folha.isNotEmpty ? item.folha : item.relacaoTrabalho);

    final badgeLabel = isAtivo ? 'Ativo' : item.tipo;

    return InkWell(
      onTap: () {
        item.cpf = Provider.of<Auth>(ctx, listen: false).cpf!;
        Navigator.of(ctx)
            .pushNamed(AppRoutes.PAGE_VIEW_CONTRACHEQUE, arguments: item);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Ícone do tipo de folha (sem quadradinho tingido, DESIGN §2b)
              ExcludeSemantics(
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: AppIconSize.sm,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),

              // Texto principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            primaryText,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: aoFundo,
                            ),
                          ),
                        ),
                        if (_isThisMonth(item)) ...[
                          const SizedBox(width: 6),
                          const _NovoBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mat. ${item.matricula}',
                      style: TextStyle(
                        fontSize: 12,
                        color: aoFundo.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ),
              ),

              // Selo do tipo
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.sm,
                  color: aoFundo.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final theme = Theme.of(context);
    final aoFundo = theme.colorScheme.onSurface;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        CartaoVidro(
          arte: Arte.de('cc'),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.receipt_long_outlined,
                    size: AppIconSize.xl,
                    color: theme.colorScheme.primary.withValues(alpha: 0.70)),
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhum contracheque em $_anoSelecionado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: aoFundo,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha outro ano no topo da tela.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: aoFundo.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Selo "NOVO" ──────────────────────────────────────────────────────────────
// Parado: selo não pisca (DESIGN §2b). Verde do tema de proventos (§3).
class _NovoBadge extends StatelessWidget {
  const _NovoBadge();

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final cor = escuro ? const Color(0xFF6EE7A0) : const Color(0xFF14713B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.40)),
      ),
      child: Text(
        'NOVO',
        style: TextStyle(
          color: cor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
