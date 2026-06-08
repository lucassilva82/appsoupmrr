// lib/widgets/widget_graficos.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class WidgetGraficos extends StatefulWidget {
  const WidgetGraficos({super.key});
  @override
  State<WidgetGraficos> createState() => _WidgetGraficosState();
}

class _WidgetGraficosState extends State<WidgetGraficos> {
  static const MaterialColor _swatch = Colors.lightBlue;
  static final Color _primary = _swatch.shade400;

  late Future<List<Map<String, dynamic>>> _future;
  String _campo = 'posto_graduacao';
  String _chart = 'barra';

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
    return map;
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(spacing: 16, runSpacing: 8, children: [
        DropdownButton<String>(
          value: _campo,
          items: const [
            DropdownMenuItem(
              value: 'posto_graduacao',
              child: Text('Posto/Graduação'),
            ),
            DropdownMenuItem(
              value: 'comando',
              child: Text('Comando'),
            ),
            DropdownMenuItem(
              value: 'unidade',
              child: Text('Unidade'),
            ),
          ],
          onChanged: (v) => setState(() => _campo = v!),
        ),
        DropdownButton<String>(
          value: _chart,
          items: const [
            DropdownMenuItem(value: 'barra', child: Text('Barras')),
            DropdownMenuItem(value: 'pizza', child: Text('Pizza')),
          ],
          onChanged: (v) => setState(() => _chart = v!),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => setState(() => _future = _fetch()),
          icon: const Icon(Icons.refresh),
        ),
      ]),
    );
  }

  Color _colorFor(int index) => _swatch[(200 + index * 100).clamp(200, 900)]!;

  Widget _buildLegend(Map<String, Color> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: items.entries.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: e.value),
            const SizedBox(width: 4),
            Text(e.key, style: const TextStyle(fontSize: 10)),
          ],
        );
      }).toList(),
    );
  }

  Widget _barChart(Map<String, int> mapa) {
    final keys = mapa.keys.toList();
    final maxVal =
        mapa.values.isEmpty ? 0 : mapa.values.reduce((a, b) => a > b ? a : b);
    final barWidth = keys.length * 40.0;
    final chart = BarChart(
      BarChartData(
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Transform.rotate(
                    angle: -pi / 4,
                    child: SizedBox(
                      width: 60,
                      child: Text(
                        keys[i],
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
              interval: 1,
            ),
          ),
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(keys.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: mapa[keys[i]]!.toDouble(),
                width: 16,
                color: _colorFor(i),
              ),
            ],
          );
        }),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: barWidth, height: 300, child: chart),
    );
  }

  Widget _pieChart(Map<String, int> mapa) {
    final total = mapa.values.fold<int>(0, (s, v) => s + v);
    final keys = mapa.keys.toList();
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(keys.length, (i) {
                final val = mapa[keys[i]]!.toDouble();
                final pct = total == 0 ? 0 : (val / total * 100);
                return PieChartSectionData(
                  value: val,
                  title: pct < 4 ? '' : '${pct.toStringAsFixed(0)}%',
                  radius: 70,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  color: _colorFor(i),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildLegend(
          Map.fromIterables(
            keys,
            List.generate(keys.length, (i) => _colorFor(i)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLandscape
          ? Row(
              children: [
                Expanded(flex: 1, child: _filtros()),
                Expanded(
                  flex: 3,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Erro: \${snap.error}'));
                      }
                      final dados = snap.data ?? [];
                      if (dados.isEmpty) {
                        return const Center(
                            child: Text('Nenhum dado encontrado.'));
                      }
                      final mapa = _contarPor(dados, _campo);
                      if (mapa.isEmpty) {
                        return const Center(
                            child: Text('Sem valores para esse campo.'));
                      }
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: _chart == 'barra'
                            ? _barChart(mapa)
                            : _pieChart(mapa),
                      );
                    },
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _filtros(),
                const Divider(height: 0),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Erro: \${snap.error}'));
                      }
                      final dados = snap.data ?? [];
                      if (dados.isEmpty) {
                        return const Center(
                            child: Text('Nenhum dado encontrado.'));
                      }
                      final mapa = _contarPor(dados, _campo);
                      if (mapa.isEmpty) {
                        return const Center(
                            child: Text('Sem valores para esse campo.'));
                      }
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: _chart == 'barra'
                            ? _barChart(mapa)
                            : _pieChart(mapa),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
