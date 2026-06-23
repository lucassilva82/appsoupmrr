import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_theme.dart';

// ── Model de dados por mês ────────────────────────────────────────────────────
class _MesData {
  final int mesNum;
  final String mesAbrev;
  final double bruto;
  final double descontos;
  final double liquido;

  const _MesData({
    required this.mesNum,
    required this.mesAbrev,
    required this.bruto,
    required this.descontos,
    required this.liquido,
  });
}

// ── Página principal ──────────────────────────────────────────────────────────
class ContrachequeGraficoPage extends StatefulWidget {
  final String cpf;
  final String ano;

  const ContrachequeGraficoPage({
    Key? key,
    required this.cpf,
    required this.ano,
  }) : super(key: key);

  @override
  State<ContrachequeGraficoPage> createState() =>
      _ContrachequeGraficoPageState();
}

class _ContrachequeGraficoPageState extends State<ContrachequeGraficoPage> {
  List<_MesData>? _dados;
  double _progress = 0.0;
  String _statusMsg = 'Preparando análise...';
  bool _hasError = false;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Carga de dados ──────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      _setStatus('Reunindo seus contracheques...', 0.05);

      final dadosSql = DadosSql();
      final lista =
          await dadosSql.listaMesesContracheque(widget.cpf, widget.ano);
      if (!mounted) return;

      if (lista.isEmpty) {
        setState(() => _dados = []);
        return;
      }

      _setStatus('Identificando ${lista.length} folhas...', 0.12);

      // Agrupa TODAS as folhas de cada mês para somar
      final Map<String, List<MesesContracheque>> porMes = {};
      for (final item in lista) {
        porMes.putIfAbsent(item.mes, () => []).add(item);
      }
      final entries = porMes.entries.toList()
        ..sort((a, b) =>
            (int.tryParse(a.key) ?? 0).compareTo(int.tryParse(b.key) ?? 0));

      const msgs = [
        'Calculando proventos...',
        'Analisando descontos...',
        'Somando todas as folhas...',
        'Verificando rubricas...',
        'Montando seu gráfico...',
      ];

      final results = <_MesData>[];
      for (int i = 0; i < entries.length; i++) {
        if (!mounted) return;
        final mesItems = entries[i].value;
        final mesNum = int.tryParse(entries[i].key) ?? (i + 1);
        final mesAbrev = _abrevMes(mesItems.first.mesExtenso);

        _setStatus(msgs[i % msgs.length], 0.15 + 0.75 * (i / entries.length));

        // Busca TODAS as folhas do mês em paralelo e soma
        final raws = await Future.wait(
          mesItems.map((item) => _fetchRaw(dadosSql, item)),
        );
        double bruto = 0, desc = 0;
        for (final r in raws) {
          if (r != null) {
            bruto += r[0];
            desc += r[1];
          }
        }
        if (bruto > 0 || desc > 0) {
          results.add(_MesData(
            mesNum: mesNum,
            mesAbrev: mesAbrev,
            bruto: bruto,
            descontos: desc,
            liquido: bruto - desc,
          ));
        }
      }

      if (!mounted) return;
      _setStatus('Finalizando análise...', 0.97);
      await Future.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;
      setState(() {
        _dados = results..sort((a, b) => a.mesNum.compareTo(b.mesNum));
        _progress = 1.0;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _setStatus(String msg, double progress) {
    if (!mounted) return;
    setState(() {
      _statusMsg = msg;
      _progress = progress;
    });
  }

  Future<List<double>?> _fetchRaw(
      DadosSql dadosSql, MesesContracheque item) async {
    try {
      final c = await dadosSql.buscaContracheque(
        item.cpf,
        item.ano,
        item.mes,
        item.mesExtenso,
        item.matricula,
        item.tipo,
        item.codProvento,
        item.relacaoTrabalho,
        item.folha,
      );
      double bruto = 0, desc = 0;
      for (final tp in c.proventos) {
        if (tp.tipoRubrica == 'P') {
          bruto += double.tryParse(tp.provento) ?? 0;
        } else {
          desc += double.tryParse(tp.desconto) ?? 0;
        }
      }
      return [bruto, desc];
    } catch (_) {
      return null;
    }
  }

  String _abrevMes(String m) {
    const map = {
      'JANEIRO': 'JAN',
      'FEVEREIRO': 'FEV',
      'MARÇO': 'MAR',
      'ABRIL': 'ABR',
      'MAIO': 'MAI',
      'JUNHO': 'JUN',
      'JULHO': 'JUL',
      'AGOSTO': 'AGO',
      'SETEMBRO': 'SET',
      'OUTUBRO': 'OUT',
      'NOVEMBRO': 'NOV',
      'DEZEMBRO': 'DEZ',
    };
    final upper = m.toUpperCase().trim();
    return map[upper] ??
        (m.length >= 3 ? m.substring(0, 3).toUpperCase() : m.toUpperCase());
  }

  String _formatShort(double v) {
    if (v >= 100000) return 'R\$${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) {
      return 'R\$${(v / 1000).toStringAsFixed(1)}'
          .replaceAll('.', ',')
          .concat('k');
    }
    return NumberFormat.currency(
            locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0)
        .format(v);
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_hasError || (_dados != null && _dados!.isEmpty)) {
      return _buildError(isDark);
    }
    if (_dados == null) return _buildLoading(isDark);
    return _buildContent(_dados!, isDark);
  }

  // ── Conteúdo principal ──────────────────────────────────────────────────────
  Widget _buildContent(List<_MesData> dados, bool isDark) {
    final fmt =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
    final fmtY =
        NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 0);

    final totalLiquido = dados.fold(0.0, (s, d) => s + d.liquido);
    final totalBruto = dados.fold(0.0, (s, d) => s + d.bruto);
    final media = totalLiquido / dados.length;
    final melhorMes = dados.reduce((a, b) => a.liquido > b.liquido ? a : b);

    final maxVal =
        dados.fold(0.0, (s, d) => max(s, max(d.bruto, d.liquido))) * 1.15;

    final liquidoSpots = dados
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.liquido))
        .toList();
    final brutoSpots = dados
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.bruto))
        .toList();

    final touchedData = (_touchedIndex != null && _touchedIndex! < dados.length)
        ? dados[_touchedIndex!]
        : null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF4F7FB),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.navy,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              titlePadding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 16),
              title: const Text(
                'Evolução Salarial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.navy, AppColors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Análise Salarial · ${widget.ano}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cards de resumo ─────────────────────────────────────────
                  _SummaryRow(
                    totalLiquido: totalLiquido,
                    totalBruto: totalBruto,
                    media: media,
                    melhorMes: melhorMes,
                    isDark: isDark,
                    formatShort: _formatShort,
                  ),
                  const SizedBox(height: 20),

                  // ── Gráfico de linha ────────────────────────────────────────
                  _buildChartCard(
                    dados: dados,
                    liquidoSpots: liquidoSpots,
                    brutoSpots: brutoSpots,
                    maxVal: maxVal,
                    isDark: isDark,
                    fmtY: fmtY,
                    touchedData: touchedData,
                    fmt: fmt,
                  ),
                  const SizedBox(height: 20),

                  // ── Lista mensal detalhada ───────────────────────────────────
                  _buildMonthList(dados, isDark, fmt, totalLiquido),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card do gráfico ─────────────────────────────────────────────────────────
  Widget _buildChartCard({
    required List<_MesData> dados,
    required List<FlSpot> liquidoSpots,
    required List<FlSpot> brutoSpots,
    required double maxVal,
    required bool isDark,
    required NumberFormat fmtY,
    required _MesData? touchedData,
    required NumberFormat fmt,
  }) {
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do card
            Row(
              children: [
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'Salário Líquido × Bruto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                _LegendDot(
                    color: AppColors.blue, label: 'Líquido', isDark: isDark),
                const SizedBox(width: 12),
                _LegendDot(
                    color: const Color(0xFF2E7D32),
                    label: 'Bruto',
                    isDark: isDark),
              ],
            ),

            // Slot de tooltip: tamanho fixo para não causar salto de layout
            SizedBox(
              height: 62,
              child: touchedData != null
                  ? _buildTooltipRow(touchedData, isDark, fmt)
                  : Center(
                      child: Text(
                        'Toque em um ponto para ver o detalhe',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ),
            ),

            // Gráfico
            SizedBox(
              height: 210,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      setState(() {
                        if (response != null &&
                            response.lineBarSpots != null &&
                            response.lineBarSpots!.isNotEmpty) {
                          _touchedIndex =
                              response.lineBarSpots!.first.spotIndex;
                        }
                      });
                    },
                    // Desabilita o tooltip nativo (usamos o custom acima)
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.transparent,
                      getTooltipItems: (spots) =>
                          spots.map((_) => null).toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: gridColor, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (dados.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxVal,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 ||
                              idx >= dados.length ||
                              val != val.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          final sel = idx == _touchedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dados[idx].mesAbrev,
                              style: TextStyle(
                                fontSize: sel ? 10 : 9,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w400,
                                color: sel
                                    ? AppColors.blue
                                    : (isDark
                                        ? Colors.white38
                                        : Colors.black38),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (val, meta) {
                          if (val == 0 || val == maxVal) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            fmtY.format(val),
                            style: TextStyle(
                              fontSize: 8,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    // Linha Bruto (mais fina, tracejada visual)
                    LineChartBarData(
                      spots: brutoSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.45),
                      barWidth: 1.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Linha Líquido (principal, destaque)
                    LineChartBarData(
                      spots: liquidoSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.blue,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, idx) {
                          final sel = idx == _touchedIndex;
                          return FlDotCirclePainter(
                            radius: sel ? 6.0 : 3.5,
                            color: sel
                                ? AppColors.blue
                                : AppColors.blue.withValues(alpha: 0.75),
                            strokeWidth: sel ? 2.5 : 1.5,
                            strokeColor:
                                isDark ? AppColors.darkCard : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.blue.withValues(alpha: 0.22),
                            AppColors.blue.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tooltip inline (acima do gráfico) ───────────────────────────────────────
  Widget _buildTooltipRow(_MesData d, bool isDark, NumberFormat fmt) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252E3D) : const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFCBDEFF),
        ),
      ),
      child: Row(
        children: [
          Text(
            d.mesAbrev,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.blue,
            ),
          ),
          const Spacer(),
          _TooltipItem(
              label: 'Bruto',
              value: fmt.format(d.bruto),
              color: const Color(0xFF2E7D32)),
          const SizedBox(width: 14),
          _TooltipItem(
              label: 'Descontos',
              value: fmt.format(d.descontos),
              color: const Color(0xFFC62828)),
          const SizedBox(width: 14),
          _TooltipItem(
              label: 'Líquido',
              value: fmt.format(d.liquido),
              color: AppColors.blue,
              bold: true),
        ],
      ),
    );
  }

  // ── Lista mensal ────────────────────────────────────────────────────────────
  Widget _buildMonthList(List<_MesData> dados, bool isDark, NumberFormat fmt,
      double totalLiquido) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Detalhamento por Mês',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06)),
          ...dados.asMap().entries.map((e) {
            final idx = e.key;
            final d = e.value;
            final pct = totalLiquido > 0 ? (d.liquido / totalLiquido) : 0.0;
            final isLast = idx == dados.length - 1;
            return _MonthRow(
              data: d,
              pct: pct,
              isDark: isDark,
              fmt: fmt,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  // ── Estado de carregamento animado ──────────────────────────────────────────
  Widget _buildLoading(bool isDark) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Ícone central
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.5),
                  ),
                  child: const Icon(Icons.show_chart_rounded,
                      color: Colors.white, size: 38),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Análise Salarial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.ano,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 2),
                // Mensagem animada com fade + slide
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _statusMsg,
                    key: ValueKey(_statusMsg),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // Barra de progresso com animação suave
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: _progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  builder: (context, animValue, _) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: animValue,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(animValue * 100).toInt()}%',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white30, size: 14),
                  label: const Text('Voltar',
                      style: TextStyle(color: Colors.white30, fontSize: 12)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Evolução Salarial',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64,
                color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Sem dados disponíveis para ${widget.ano}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final double totalLiquido;
  final double totalBruto;
  final double media;
  final _MesData melhorMes;
  final bool isDark;
  final String Function(double) formatShort;

  const _SummaryRow({
    required this.totalLiquido,
    required this.totalBruto,
    required this.media,
    required this.melhorMes,
    required this.isDark,
    required this.formatShort,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Líquido no Ano',
            value: formatShort(totalLiquido),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.blue,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Média Mensal',
            value: formatShort(media),
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF2E7D32),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Melhor Mês',
            value: melhorMes.mesAbrev,
            icon: Icons.star_rounded,
            color: const Color(0xFFE67E00),
            isDark: isDark,
            subtitle: formatShort(melhorMes.liquido),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final String? subtitle;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendDot(
      {required this.color, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _TooltipItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _TooltipItem({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  final _MesData data;
  final double pct;
  final bool isDark;
  final NumberFormat fmt;
  final bool isLast;

  const _MonthRow({
    required this.data,
    required this.pct,
    required this.isDark,
    required this.fmt,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          child: Row(
            children: [
              // Mês abreviado
              SizedBox(
                width: 34,
                child: Text(
                  data.mesAbrev,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Barra + valores
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bruto ${fmt.format(data.bruto)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        Text(
                          '- ${fmt.format(data.descontos)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.blue),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Líquido
              Text(
                fmt.format(data.liquido),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
      ],
    );
  }
}

// Extensão para concatenar string (evita interpolação repetida)
extension _StringConcat on String {
  String concat(String other) => '$this$other';
}
