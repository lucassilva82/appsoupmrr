import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/design/arte_cartao.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_theme.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/vidro.dart';

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

/// Cores das séries, nos pares do DESIGN §3: a versão clara no fundo
/// escuro e a escura no claro, para o texto passar de 4,5:1 nos dois temas.
class _Cores {
  _Cores(ThemeData t)
      : liquido = t.colorScheme.primary,
        bruto = t.brightness == Brightness.dark
            ? AppColors.sucessoEscuro
            : AppColors.sucesso,
        desconto = t.brightness == Brightness.dark
            ? AppColors.falhaEscuro
            : AppColors.falha,
        destaque = t.brightness == Brightness.dark
            ? Colors.amber.shade300
            : Colors.amber.shade900,
        texto = t.colorScheme.onSurface;
  final Color liquido, bruto, desconto, destaque, texto;
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

    return FundoSuave(child: Scaffold(
      backgroundColor: Colors.transparent,
          // fundo global (FundoSuave) aparece por baixo
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────────
          const SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FundoBarraVidro(),
            title: Text('Evolução Salarial'),
          ),

          // ── Topo com a arte do contracheque (padrão 2.2) ───────────────────
          SliverToBoxAdapter(
            child: TopoArte(
              arte: Arte.de('cc'),
              icone: Icons.show_chart_rounded,
              titulo: 'Análise salarial · ${widget.ano}',
              subtitulo: 'Quanto você recebeu mês a mês no ano: '
                  'líquido, bruto e descontos.',
              margem: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
    ));
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
    final cores = _Cores(Theme.of(context));
    final gridColor = cores.texto.withValues(alpha: 0.06);

    return CartaoVidro(
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
                    'Salário líquido × bruto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cores.texto,
                    ),
                  ),
                ),
                _LegendDot(
                    color: cores.liquido, label: 'Líquido', isDark: isDark),
                const SizedBox(width: 12),
                _LegendDot(color: cores.bruto, label: 'Bruto', isDark: isDark),
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
                          fontSize: 11,
                          color: cores.texto.withValues(alpha: 0.55),
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
                                    ? cores.liquido
                                    : cores.texto.withValues(alpha: 0.55),
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
                              color: cores.texto.withValues(alpha: 0.45),
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
                      color: cores.bruto.withValues(alpha: 0.55),
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
                      color: cores.liquido,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, idx) {
                          final sel = idx == _touchedIndex;
                          return FlDotCirclePainter(
                            radius: sel ? 6.0 : 3.5,
                            color: sel
                                ? cores.liquido
                                : cores.liquido.withValues(alpha: 0.75),
                            strokeWidth: sel ? 2.5 : 1.5,
                            strokeColor: Theme.of(context).colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            cores.liquido.withValues(alpha: 0.22),
                            cores.liquido.withValues(alpha: 0.0),
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
    final cores = _Cores(Theme.of(context));
    // Seção dentro do cartão: superfície neutra, sem borda (DESIGN §3b).
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cores.texto.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            d.mesAbrev,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cores.liquido,
            ),
          ),
          const Spacer(),
          _TooltipItem(
              label: 'Bruto',
              value: fmt.format(d.bruto),
              color: cores.bruto),
          const SizedBox(width: 14),
          _TooltipItem(
              label: 'Descontos',
              value: fmt.format(d.descontos),
              color: cores.desconto),
          const SizedBox(width: 14),
          _TooltipItem(
              label: 'Líquido',
              value: fmt.format(d.liquido),
              color: cores.liquido,
              bold: true),
        ],
      ),
    );
  }

  // ── Lista mensal ────────────────────────────────────────────────────────────
  Widget _buildMonthList(List<_MesData> dados, bool isDark, NumberFormat fmt,
      double totalLiquido) {
    final texto = Theme.of(context).colorScheme.onSurface;
    return CartaoVidro(
      arte: Arte.de('cc'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Detalhamento por mês',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: texto,
              ),
            ),
          ),
          Divider(height: 1, color: texto.withValues(alpha: 0.08)),
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
  // O texto branco fica sobre a arte do contracheque (fundo sempre escuro):
  // direto no fundo da tela ele sumia no tema claro.
  Widget _buildLoading(bool isDark) {
    return FundoSuave(child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const FundoBarraVidro(),
        title: const Text('Evolução Salarial'),
      ),
      body: ListView(
        children: [
          TopoArte(
            arte: Arte.de('cc'),
            icone: Icons.show_chart_rounded,
            titulo: 'Análise salarial · ${widget.ano}',
            subtitulo: 'Juntando os contracheques do ano.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Barra de progresso com animação suave
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: _progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  builder: (context, animValue, _) => Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: animValue,
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(animValue * 100).toInt()}%',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildError(bool isDark) {
    return FundoSuave(child: Scaffold(
      backgroundColor: Colors.transparent,
          // fundo global (FundoSuave) aparece por baixo
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const FundoBarraVidro(),
        title: const Text('Evolução Salarial'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TopoArte(
            arte: Arte.de('cc'),
            icone: Icons.show_chart_rounded,
            titulo: 'Análise salarial · ${widget.ano}',
            subtitulo: 'Quanto você recebeu mês a mês no ano: '
                'líquido, bruto e descontos.',
            margem: const EdgeInsets.only(bottom: 16),
          ),
          Builder(builder: (context) {
            final texto = Theme.of(context).colorScheme.onSurface;
            return CartaoVidro(
              arte: Arte.de('cc'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.bar_chart_outlined,
                        size: AppIconSize.xl,
                        color: texto.withValues(alpha: 0.45)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sem dados disponíveis para ${widget.ano}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: texto.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ));
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
    final cores = _Cores(Theme.of(context));
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Líquido no Ano',
            value: formatShort(totalLiquido),
            icon: Icons.account_balance_wallet_outlined,
            color: cores.liquido,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Média Mensal',
            value: formatShort(media),
            icon: Icons.trending_up_rounded,
            color: cores.bruto,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Melhor Mês',
            value: melhorMes.mesAbrev,
            icon: Icons.star_rounded,
            color: cores.destaque,
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
    final texto = Theme.of(context).colorScheme.onSurface;
    return CartaoVidro(
      raio: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sem quadradinho tingido atrás do ícone (DESIGN §2b).
          ExcludeSemantics(
            child: Icon(icon, size: AppIconSize.sm, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: texto.withValues(alpha: 0.60),
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
                color: texto,
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
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.62),
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
            fontSize: 10,
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
    final cores = _Cores(Theme.of(context));
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
                    color: cores.texto.withValues(alpha: 0.75),
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
                            fontSize: 10,
                            color: cores.texto.withValues(alpha: 0.60),
                          ),
                        ),
                        Text(
                          '- ${fmt.format(data.descontos)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: cores.desconto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: cores.texto.withValues(alpha: 0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(cores.liquido),
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
                  color: cores.texto,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: cores.texto.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

// Extensão para concatenar string (evita interpolação repetida)
extension _StringConcat on String {
  String concat(String other) => '$this$other';
}
