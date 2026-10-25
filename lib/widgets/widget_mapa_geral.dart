// lib/widgets/widget_mapa_geral.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/utils/app_theme.dart';
import '../core/erros/falha_de.dart';
import '../core/design/arte_cartao.dart';
import 'cartao_painel.dart';
import 'vidro.dart';

class WidgetMapaGeral extends StatefulWidget {
  const WidgetMapaGeral({super.key});
  @override
  State<WidgetMapaGeral> createState() => _WidgetMapaGeralState();
}

class _WidgetMapaGeralState extends State<WidgetMapaGeral> {
  late Future<List<Situacao>> _future;

  final List<String> _siglas = [
    'CEL',
    'TC',
    'MAJ',
    'CAP',
    '1º TEN',
    '2º TEN',
    'ASP',
    'CHO-CAD IV',
    'SUB TEN',
    '1º SGT',
    '2º SGT',
    '3º SGT',
    'AL SGT',
    'CB',
    'AL CB',
    'SD',
    'AL SD',
  ];
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = _siglas.toSet();
    _future = _fetch();
  }

  Future<List<Situacao>> _fetch() async {
    if (_sel.isEmpty) return [];
    Uri uri;
    if (_sel.length == _siglas.length) {
      uri = Uri.parse(
          'https://pmrr.online/flutter/sigrh/mapadaforca/listarsituacao.php');
    } else {
      final qs =
          _sel.map((s) => 'posto[]=${Uri.encodeQueryComponent(s)}').join('&');
      uri = Uri.parse(
          'https://pmrr.online/flutter/sigrh/mapadaforca/listarsituacao.php?$qs');
    }
    final r = await http.get(uri);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['result'] as List)
        .map((e) => Situacao.fromJson(e))
        .where((e) => e.quantidade > 0)
        .toList();
  }

  void _toggleChip(String sig, bool v) {
    setState(() {
      v ? _sel.add(sig) : _sel.remove(sig);
      _future = _fetch();
    });
  }

  void _toggleTodos() {
    setState(() {
      _sel.length == _siglas.length ? _sel.clear() : _sel = _siglas.toSet();
      _future = _fetch();
    });
  }

  Widget _filterSection(ThemeData theme, bool isDark) {
    final allSel = _sel.length == _siglas.length;
    final split = (_siglas.length / 2).ceil();
    final row1 = _siglas.take(split).toList();
    final row2 = _siglas.skip(split).toList();

    Widget chip(String sig) {
      final selected = _sel.contains(sig);
      return FilterChip(
        label: Text(sig),
        selected: selected,
        onSelected: (v) => _toggleChip(sig, v),
        // Com os quinze postos marcados — que é o estado padrão — a faixa
        // virava um bloco azul do tamanho de dois terços da tela. Marcado
        // passou a ser texto e borda; o preenchimento quase não tinge.
        selectedColor:
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.07),
        backgroundColor:
            theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.30)
              : theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggleTodos,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: allSel
                        ? theme.colorScheme.primary
                            .withValues(alpha: isDark ? 0.10 : 0.07)
                        : theme.colorScheme.onSurface
                            .withValues(alpha: isDark ? 0.06 : 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: allSel
                          ? theme.colorScheme.primary.withValues(alpha: 0.30)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allSel
                            ? Icons.clear_all_rounded
                            : Icons.select_all_rounded,
                        size: AppIconSize.xxs,
                        color: allSel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        allSel ? 'Limpar' : 'Todos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: allSel
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Filtros',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: row1
                  .map((sig) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: chip(sig)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: row2
                  .map((sig) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: chip(sig)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listItem(Situacao d, int i, int total, ThemeData theme, bool isDark) {
    final rawPct = total <= 0 ? 0.0 : d.quantidade / total;
    final pct = rawPct.clamp(0.0, 1.0);
    final visualPct = d.quantidade > 0 && pct < 0.05 ? 0.05 : pct;
    final pctText = '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalhesMapaForcaPage(
              dadosBusca: MapBuscaDetalhesModel(
                idSituacao: d.id.toString(),
                descricao: d.descricao,
                postoGraduacao: _sel.toList(),
                quantidade: d.quantidade.toString(),
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  d.descricao,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pctText,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
              // A barra do painel (DESIGN §2b), no lugar do azul fixo que
              // não vinha do tema.
              SizedBox(
                width: 56,
                child: BarraProgressoCartao(valor: visualPct),
              ),
              const SizedBox(width: 10),
              // Número sem a pílula azul que havia atrás. Eram quinze
              // pílulas numa lista de quinze linhas: o acento deixa de
              // acentuar quando está em tudo. A barra ao lado já carrega
              // o azul, e ela é quem compara as linhas entre si.
              SizedBox(
                width: 34,
                child: Text(
                  d.quantidade.toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: AppIconSize.xs,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final arte = Arte.de('gestao');
    final apoio = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    // Estado parado (vazio, erro): caixa de vidro com a arte da área.
    Widget caixaEstado(Widget filho, {Color? tingimento}) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CartaoVidro(
              arte: tingimento == null ? arte : null,
              tingimento: tingimento,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: filho,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterSection(theme, isDark),
        if (_sel.isEmpty)
          Expanded(
            child: caixaEstado(Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_off_rounded,
                    size: AppIconSize.xl, color: apoio),
                const SizedBox(height: 10),
                Text('Selecione um posto ou graduação.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: apoio)),
              ],
            )),
          )
        else
          Expanded(
            child: FutureBuilder<List<Situacao>>(
              future: _future,
              builder: (c, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                }
                if (s.hasError) {
                  return caixaEstado(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: AppIconSize.xl,
                            color: theme.colorScheme.error),
                        const SizedBox(height: 8),
                        Text('Não foi possível carregar o Mapa da Força.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Tente de novo em instantes. Código ${falhaDe('MF', s.error, tela: 'gestao.mapa_forca').codigo}.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    tingimento: theme.colorScheme.error,
                  );
                }
                final list = s.data ?? [];
                if (list.isEmpty) {
                  return caixaEstado(Text('Nenhum resultado.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: apoio)));
                }
                final total = list.fold<int>(0, (t, e) => t + e.quantidade);
                return Column(
                  children: [
                    // Tabela numa caixa de vidro só, com a arte discreta da
                    // área (nível 1, DESIGN §3b); as linhas não têm
                    // superfície própria, só o divisor.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: CartaoVidro(
                          arte: arte,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 12, 16, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text('SITUAÇÃO FUNCIONAL',
                                          style: estiloRotulo(context)),
                                    ),
                                    Text('EFETIVO',
                                        style: estiloRotulo(context)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: theme.dividerColor
                                        .withValues(alpha: 0.2),
                                  ),
                                  itemBuilder: (_, i) => _listItem(
                                      list[i], i, total, theme, isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Rodapé total: o número é o destaque (DESIGN §2b).
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: CartaoVidro(
                          raio: 14,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text('TOTAL',
                                    style: estiloRotulo(context)),
                              ),
                              DestaqueCartao(
                                valor: total.toString(),
                                tamanho: AppDisplaySize.heroiMenor,
                                corValor: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class Situacao {
  final int id;
  final String descricao;
  final int quantidade;
  Situacao(
      {required this.id, required this.descricao, required this.quantidade});
  factory Situacao.fromJson(Map<String, dynamic> j) => Situacao(
        id: j['id_situacao'] as int,
        descricao: j['descricao_situacao'] as String,
        quantidade: j['quantidade'] as int,
      );
}
