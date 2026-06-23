import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/utils/app_theme.dart';

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
      'https://pmrr.net/flutter/sigrh/mapadaforca/listamapa_forca_full.php',
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
    final tipos = {
      'barra': Icons.bar_chart_rounded,
      'pizza': Icons.pie_chart_rounded,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                label: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: active
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                selected: active,
                onSelected: (_) => setState(() => _campo = e.key),
                selectedColor:
                    isDark ? const Color(0xFF2C5B7A) : AppColors.blue,
                checkmarkColor: Colors.white,
                backgroundColor: isDark
                    ? theme.colorScheme.surface
                    : const Color(0xFFF2F6FF),
                side: BorderSide(
                  color: active
                      ? (isDark ? const Color(0xFF2C5B7A) : AppColors.blue)
                      : isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFDDE6F5),
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
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surface
                      : const Color(0xFFF2F6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFDDE6F5),
                  ),
                ),
                child: Row(
                  children: tipos.entries.map((e) {
                    final active = _chart == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _chart = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: active
                              ? (isDark
                                  ? const Color(0xFF2C5B7A)
                                  : AppColors.blue)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          e.value,
                          size: 18,
                          color: active
                              ? Colors.white
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: () => setState(() {
                  _future = _fetch();
                }),
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Map<String, int> mapa, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = mapa.values.fold<int>(0, (s, v) => s + v);
    final top = mapa.entries.isEmpty
        ? null
        : mapa.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final label = {
      'posto_graduacao': 'Posto/Graduação',
      'comando': 'Comando',
      'unidade': 'Unidade',
    }[_campo]!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF203C52), const Color(0xFF1A3246)]
              : [AppColors.blue, AppColors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visão por $label',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  top == null
                      ? 'Total: $total'
                      : 'Maior grupo: ${top.key} (${top.value})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
            tooltipBgColor: AppColors.navy.withValues(alpha: 0.9),
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${keys[group.x]}\n',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: rod.toY.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.lightBlue,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(width: barWidth, height: 280, child: chart),
      ),
    );
  }

  Widget _pieChart(Map<String, int> mapa, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = mapa.values.fold<int>(0, (s, v) => s + v);
    final keys = mapa.keys.toList();

    final touchedKey =
        (_touched != null && _touched! >= 0 && _touched! < keys.length)
            ? keys[_touched!]
            : null;
    final touchedVal = touchedKey != null ? (mapa[touchedKey] ?? 0) : 0;
    final touchedPct = total == 0 ? 0.0 : touchedVal / total * 100;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
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
                            final idx =
                                response?.touchedSection?.touchedSectionIndex;
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.28),
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
                  onTap: () => setState(() => _touched = isSelected ? null : i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
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
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> dados, BuildContext context) {
    final mapa = _contarPor(dados, _campo);
    if (mapa.isEmpty) {
      return const Center(child: Text('Sem valores para esse campo.'));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _summaryCard(mapa, context),
          _chart == 'barra'
              ? _barChart(mapa, context)
              : _pieChart(mapa, context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filterBar(context),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator.adaptive());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar dados.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              final dados = snap.data ?? [];
              if (dados.isEmpty) {
                return const Center(child: Text('Nenhum dado encontrado.'));
              }
              return _buildBody(dados, context);
            },
          ),
        ),
      ],
    );
  }
}
