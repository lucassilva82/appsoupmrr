import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/utils/app_theme.dart';
import '../core/design/arte_cartao.dart';
import '../features/mapa_efetivo/mapa_efetivo.dart';
import '../core/erros/falha_de.dart';
import 'cartao_painel.dart';
import 'vidro.dart';

class WidgetGraficos extends StatefulWidget {
  const WidgetGraficos({super.key});

  @override
  State<WidgetGraficos> createState() => _WidgetGraficosState();
}

class _WidgetGraficosState extends State<WidgetGraficos> {
  late Future<List<Map<String, dynamic>>> _future;
  String _campo = 'posto_graduacao';
  String _chart = 'barra';
  int? _touched;

  static const _palette = [
    Color(0xFF1565C0),
    Color(0xFF1976D2),
    Color(0xFF1E88E5),
    Color(0xFF2196F3),
    Color(0xFF42A5F5),
    Color(0xFF64B5F6),
    Color(0xFF0D47A1),
    Color(0xFF0277BD),
    Color(0xFF0288D1),
    Color(0xFF039BE5),
    Color(0xFF29B6F6),
    Color(0xFF4FC3F7),
  ];

  Color _colorFor(int i) => _palette[i % _palette.length];

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final uri = Uri.parse(
      'https://pmrr.online/flutter/sigrh/mapadaforca/listamapa_forca_full.php',
    );
    final r = await http.get(uri);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (d['code'] == 0) return [];
    return (d['result'] as List).cast<Map<String, dynamic>>();
  }

  Map<String, int> _contarPor(List<Map<String, dynamic>> data, String campo) {
    final map = <String, int>{};
    for (final row in data) {
      final key = (row[campo] ?? '—').toString();
      map[key] = (map[key] ?? 0) + 1;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Widget _filterBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final campos = {
      'posto_graduacao': 'Posto/Graduação',
      'comando': 'Comando',
      'unidade': 'Unidade',
    };

    // Mesmos chips das outras abas do Mapa da Força: marcado é texto e borda
    // na primária, sem o azul cheio fixo (AppColors.blue) de antes.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: campos.entries.map((e) {
              final active = _campo == e.key;
              return FilterChip(
                label: Text(e.value),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
                selected: active,
                onSelected: (_) => setState(() => _campo = e.key),
                selectedColor: theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.10 : 0.07),
                backgroundColor: theme.colorScheme.onSurface
                    .withValues(alpha: isDark ? 0.06 : 0.04),
                side: BorderSide(
                  color: active
                      ? theme.colorScheme.primary.withValues(alpha: 0.30)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                showCheckmark: false,
                visualDensity:
                    const VisualDensity(horizontal: -1, vertical: -2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Tipo de gráfico com o controle segmentado do tema.
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -2, vertical: -1),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'barra',
                    tooltip: 'Gráfico de barras',
                    icon: Icon(Icons.bar_chart_rounded, size: AppIconSize.sm),
                  ),
                  ButtonSegment(
                    value: 'pizza',
                    tooltip: 'Gráfico de pizza',
                    icon: Icon(Icons.pie_chart_rounded, size: AppIconSize.sm),
                  ),
                ],
                selected: {_chart},
                onSelectionChanged: (v) => setState(() => _chart = v.first),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: () => setState(() {
                  _future = _fetch();
                }),
                icon: Icon(
                  Icons.refresh_rounded,
                  size: AppIconSize.sm,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Resumo com a arte cheia da área de Gestão (padrão 2.2): o total é o
  // número herói do card.
  Widget _summaryCard(Map<String, int> mapa, BuildContext context) {
    final total = mapa.values.fold<int>(0, (s, v) => s + v);
    final top = mapa.entries.isEmpty
        ? null
        : mapa.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final label = {
      'posto_graduacao': 'Posto/Graduação',
      'comando': 'Comando',
      'unidade': 'Unidade',
    }[_campo]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: CartaoArte(
        arte: Arte.de('gestao'),
        padding: kPaddingCartao,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoCartao(
              icone: Icons.insights_rounded,
              titulo: 'Visão por $label',
              mostrarSeta: false,
            ),
            const SizedBox(height: 12),
            DestaqueCartao(
              rotulo: 'Efetivo',
              valor: '$total',
              complemento: 'militares',
              tamanhoComplemento: 14,
            ),
            ValueListenableBuilder<EfetivoEscopo?>(
              valueListenable: MapaEfetivoRepositorio.pmrr,
              builder: (context, e, __) {
                final o = e?.total;
                // Sem previsão, ou com previsão que não cobre o efetivo, o
                // card não escreve percentual nenhum: ver EfetivoEscopo.
                if (o == null || o.semPrevisao || (e?.fonteSuspeita ?? false)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BarraOcupacao(ocupacao: o, altura: 8),
                      const SizedBox(height: 5),
                      Text(
                        '${o.existente} de ${o.previsto} previstos · '
                        '${o.pct!.toStringAsFixed(0)}% ocupado'
                        '${o.faltam > 0 ? ' · faltam ${o.faltam}' : ''}'
                        '${o.temExcedente ? ' · excedente de ${o.excedente}' : ''}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.88)),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (top != null) ...[
              const SizedBox(height: 8),
              Text(
                'Maior grupo: ${top.key} (${top.value})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.84)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barChart(Map<String, int> mapa, BuildContext context) {
    final theme = Theme.of(context);
    final keys = mapa.keys.toList();
    final maxVal =
        mapa.values.isEmpty ? 0 : mapa.values.reduce((a, b) => a > b ? a : b);

    final bars = List.generate(keys.length, (i) {
      final isTouched = i == _touched;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: mapa[keys[i]]!.toDouble(),
            width: isTouched ? 18 : 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            gradient: LinearGradient(
              colors: [_colorFor(i).withValues(alpha: 0.7), _colorFor(i)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    });

    final chart = BarChart(
      BarChartData(
        maxY: maxVal * 1.25,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent || event is FlPanEndEvent) {
              setState(() => _touched = response?.spot?.touchedBarGroupIndex);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: theme.colorScheme.inverseSurface,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${keys[group.x]}\n',
              TextStyle(
                color: theme.colorScheme.onInverseSurface,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: rod.toY.toInt().toString(),
                  style: TextStyle(
                    color: theme.colorScheme.inversePrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Transform.rotate(
                    angle: -pi / 5,
                    child: SizedBox(
                      width: 58,
                      child: Text(
                        keys[i],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                );
              },
              interval: 1,
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: bars,
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
    );

    final barWidth = (keys.length * 42.0).clamp(200.0, 2000.0);

    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: CartaoVidro(
          arte: Arte.de('gestao'),
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(width: barWidth, height: 280, child: chart),
          ),
        ));
  }

  Widget _pieChart(Map<String, int> mapa, BuildContext context) {
    final theme = Theme.of(context);
    final total = mapa.values.fold<int>(0, (s, v) => s + v);
    final keys = mapa.keys.toList();

    final touchedKey =
        (_touched != null && _touched! >= 0 && _touched! < keys.length)
            ? keys[_touched!]
            : null;
    final touchedVal = touchedKey != null ? (mapa[touchedKey] ?? 0) : 0;
    final touchedPct = total == 0 ? 0.0 : touchedVal / total * 100;

    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: CartaoVidro(
          arte: Arte.de('gestao'),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 50,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent) {
                              setState(() {
                                final idx = response
                                    ?.touchedSection?.touchedSectionIndex;
                                // fl_chart usa -1 quando o toque cai fora de
                                // qualquer fatia; tratar como "deselecionar".
                                if (idx == null || idx < 0) {
                                  _touched = null;
                                } else {
                                  _touched = idx == _touched ? null : idx;
                                }
                              });
                            }
                          },
                        ),
                        sections: List.generate(keys.length, (i) {
                          final val = mapa[keys[i]]!.toDouble();
                          final pct = total == 0 ? 0.0 : (val / total * 100);
                          final isTouched = i == _touched;
                          return PieChartSectionData(
                            value: val,
                            // Mostrar % dentro apenas se fatia >= 6%
                            title: pct < 6 ? '' : '${pct.toStringAsFixed(0)}%',
                            radius: isTouched ? 84 : 68,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            color: _colorFor(i),
                          );
                        }),
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 300),
                    ),
                    // Centro interativo: ao tocar em qualquer fatia (inclusive
                    // pequenas) exibe nome + % + contagem no buraco central.
                    if (touchedKey != null)
                      IgnorePointer(
                        child: Container(
                          width: 90,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                touchedKey,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.85),
                                  fontSize: 8.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${touchedPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _colorFor(_touched!),
                                ),
                              ),
                              Text(
                                '$touchedVal',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Hint quando nada tocado
                      IgnorePointer(
                        child: Text(
                          'Toque\numa fatia',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.28),
                            fontSize: 9,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(keys.length, (i) {
                    final pct = total == 0
                        ? '0%'
                        : '${(mapa[keys[i]]! / total * 100).toStringAsFixed(0)}%';
                    final isSelected = i == _touched;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _touched = isSelected ? null : i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _colorFor(i).withValues(alpha: 0.22)
                              : _colorFor(i).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? _colorFor(i).withValues(alpha: 0.7)
                                : _colorFor(i).withValues(alpha: 0.3),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _colorFor(i),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${keys[i]} · $pct',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildBody(List<Map<String, dynamic>> dados, BuildContext context) {
    final mapa = _contarPor(dados, _campo);
    if (mapa.isEmpty) {
      return _caixaEstado(context, const Text('Sem valores para esse campo.'));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _summaryCard(mapa, context),
          _chart == 'barra'
              ? _barChart(mapa, context)
              : _pieChart(mapa, context),
          _ocupacaoPorGrupo(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Ocupação (previsto x existente) do agrupamento escolhido.
  ///
  /// Só aparece para **Comando** e **Posto/Graduação**, que são os cortes em
  /// que a API devolve a previsão. Para **Unidade** não há dado neste nível, e
  /// a seção some em vez de mostrar uma lista pela metade — meia lista parece
  /// uma lista inteira, e foi assim que uma prévia de 20 nomes quase passou
  /// por 129 (APRENDIZADOS §51).
  Widget _ocupacaoPorGrupo(BuildContext context) {
    if (_campo != 'comando' && _campo != 'posto_graduacao') {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<EfetivoEscopo?>(
      valueListenable: MapaEfetivoRepositorio.pmrr,
      builder: (context, e, __) {
        if (e == null || e.fonteSuspeita) return const SizedBox.shrink();
        final itens = _campo == 'comando' ? e.filhos : e.postos;
        final comPrevisao =
            itens.where((i) => !i.ocupacao.semPrevisao).toList();
        if (comPrevisao.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final semPrevisao = itens.length - comPrevisao.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: CartaoVidro(
            arte: Arte.de('gestao'),
            padding: kPaddingCartao,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CabecalhoCartao(
                  icone: Icons.donut_large_rounded,
                  titulo: _campo == 'comando'
                      ? 'Ocupação por comando'
                      : 'Ocupação por posto e graduação',
                  mostrarSeta: false,
                ),
                const SizedBox(height: 10),
                for (final i in comPrevisao) ...[
                  Text(i.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  BarraOcupacao(ocupacao: i.ocupacao),
                  const SizedBox(height: 4),
                  LinhaOcupacao(ocupacao: i.ocupacao, mostrarPct: true),
                  const SizedBox(height: 11),
                ],
                if (semPrevisao > 0)
                  Text(
                    semPrevisao == 1
                        ? '1 grupo está fora desta conta por não ter previsão cadastrada no SIGRH.'
                        : '$semPrevisao grupos estão fora desta conta por não terem previsão cadastrada no SIGRH.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.68)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Estado parado (vazio, erro): caixa de vidro com a arte da área.
  Widget _caixaEstado(BuildContext context, Widget filho,
          {Color? tingimento}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CartaoVidro(
            arte: tingimento == null ? Arte.de('gestao') : null,
            tingimento: tingimento,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: filho,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filterBar(context),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator.adaptive());
              }
              if (snap.hasError) {
                // Mesma mensagem, com código, das outras abas (antes era
                // "Erro ao carregar dados.", sem código nem o que fazer).
                final tema = Theme.of(context);
                return _caixaEstado(
                  context,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: AppIconSize.xl, color: tema.colorScheme.error),
                      const SizedBox(height: 8),
                      Text('Não foi possível carregar o Mapa da Força.',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          'Tente de novo em instantes. Código ${falhaDe('MF', snap.error, tela: 'gestao.mapa_forca').codigo}.',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodySmall),
                    ],
                  ),
                  tingimento: tema.colorScheme.error,
                );
              }
              final dados = snap.data ?? [];
              if (dados.isEmpty) {
                return _caixaEstado(
                    context, const Text('Nenhum dado encontrado.'));
              }
              return _buildBody(dados, context);
            },
          ),
        ),
      ],
    );
  }
}
