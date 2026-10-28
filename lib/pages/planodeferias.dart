import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/vidro.dart';

class PlanoDeFeriasPage extends StatefulWidget {
  const PlanoDeFeriasPage({super.key});

  @override
  State<PlanoDeFeriasPage> createState() => _PlanoDeFeriasPageState();
}

class _PlanoDeFeriasPageState extends State<PlanoDeFeriasPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  List<int> _years = [];
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    // populate default years (2025.., at least through 2027 and currentYear+1)
    _years = _defaultYears();
    final now = DateTime.now().year;
    _selectedYear = _years.contains(now) ? now : _years.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  List<int> _defaultYears() {
    final now = DateTime.now().year;
    final start = 2025;
    final end = (now + 1) > 2027 ? (now + 1) : 2027;
    final list = <int>[];
    for (var y = start; y <= end; y++) list.add(y);
    return list;
  }

  Future<void> _loadData({bool force = false}) async {
    final auth = Provider.of<Auth>(context, listen: false);
    final matricula = auth.matricula;
    if (matricula == null || matricula.isEmpty) {
      setState(() {
        _error = 'Matrícula não disponível.';
        _all = [];
        _years = [];
        _selectedYear = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          'https://pmrr.online/flutter/sigrh/buscaplanodeferias.php?matricula=$matricula');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        setState(() {
          _error = 'Erro ao consultar servidor (${resp.statusCode}).';
          _all = [];
          _years = [];
          _selectedYear = null;
        });
        return;
      }

      final Map<String, dynamic> body = jsonDecode(resp.body);
      if (body['code'] == 1 && body['result'] is List) {
        final list = List<Map<String, dynamic>>.from(body['result']);
        // determine years available from API and merge with defaults
        final yearsSet = <int>{};
        for (final row in list) {
          final y = _extractYear(row);
          if (y != null) yearsSet.add(y);
        }
        // merge with default years (ensures at least 2025-2027 + currentYear+1)
        final merged = {..._defaultYears(), ...yearsSet};
        // remove years older than 2025 (e.g., 2021) so dropdown only shows 2025+
        final years = merged.where((y) => y >= 2025).toList()
          ..sort((a, b) => b.compareTo(a));
        setState(() {
          _all = list;
          _years = years;
          // keep previously selected if any, otherwise prefer current year when present
          final now = DateTime.now().year;
          _selectedYear = _selectedYear ??
              (years.contains(now)
                  ? now
                  : (years.isNotEmpty ? years.first : null));
        });
      } else {
        setState(() {
          _all = [];
          _years = [];
          _selectedYear = null;
          _error = body['message'] ?? 'Nenhum plano de férias encontrado.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao buscar plano de férias: $e';
        _all = [];
        _years = [];
        _selectedYear = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _extractYear(Map<String, dynamic> row) {
    // Prefer explicit year fields
    final possibleYearKeys = [
      'ano',
      'year',
      'plano_ano',
      'ano_plano',
      'ano_base_nome',
      'ano_base'
    ];
    for (final k in possibleYearKeys) {
      final v = row[k];
      if (v != null) {
        final s = v.toString();
        final y = int.tryParse(s);
        if (y != null) return y;
      }
    }

    // parse from date-like fields
    for (final entry in row.entries) {
      final val = entry.value;
      if (val is String && RegExp(r'\d{4}').hasMatch(val)) {
        final m = RegExp(r'(20\d{2}|19\d{2})').firstMatch(val);
        if (m != null) return int.tryParse(m.group(0)!);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedYear == null) return _all;
    return _all.where((r) => _extractYear(r) == _selectedYear).toList();
  }

  // ── UI: barra de seleção de ano ─────────────────────────────────────
  // Dentro do TopoArte (padrão 2.2): pílulas de vidro claro sobre a arte,
  // texto branco, a selecionada mais clara e com contorno. Alvo de 44 pt.
  Widget _buildYearBar(bool isDark) {
    if (_years.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final year = _years[i];
          final isSelected = year == _selectedYear;
          return Semantics(
            button: true,
            selected: isSelected,
            label: 'Ano $year',
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _selectedYear = year);
                  _loadData();
                },
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
                    year.toString(),
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

  // ── UI: estado vazio / erro ──────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final isError = _error != null;
    final tema = Theme.of(context);
    final aoFundo = tema.colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CartaoVidro(
              arte: Arte.de('fe'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        isError
                            ? Icons.cloud_off_outlined
                            : Icons.beach_access_outlined,
                        size: AppIconSize.xl,
                        color: isError
                            ? tema.colorScheme.error
                            : tema.colorScheme.primary.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isError
                          ? 'Não foi possível carregar'
                          : 'Nenhum plano encontrado',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ??
                          'Você não possui um plano de férias cadastrado para $_selectedYear.\nProcure a administração da sua OM.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: aoFundo.withValues(alpha: 0.65),
                      ),
                    ),
                    if (isError) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh, size: AppIconSize.sm),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI: chip de status de um período ────────────────────────────────
  Widget _buildStatusChip(DateTime? startDt, DateTime? endDt) {
    final now = DateTime.now();
    Color color;
    IconData icon;
    String label;

    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    if (startDt == null) {
      return const SizedBox.shrink();
    } else if (endDt != null && endDt.isBefore(now)) {
      color = tema.colorScheme.onSurface.withValues(alpha: 0.65);
      icon = Icons.check_circle_outline;
      label = 'Concluído';
    } else if (startDt.isBefore(now) ||
        startDt.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      color = escuro ? AppColors.sucessoEscuro : AppColors.sucesso;
      icon = Icons.play_circle_outline;
      label = 'Em andamento';
    } else {
      final days = startDt.difference(now).inDays + 1;
      color = tema.colorScheme.primary;
      icon = Icons.schedule_outlined;
      label = days == 1 ? 'Amanhã' : 'Em ${days}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xxs, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── UI: linha de período (parcela / integral) ────────────────────────
  Widget _buildPeriodRow({
    required String label,
    required String startRaw,
    required String startFormatted,
    required String endRaw,
    required String endFormatted,
    required bool isDark,
  }) {
    DateTime? tryParse(String s) {
      if (s.trim().isEmpty) return null;
      final str = s.trim();
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
      final m = iso.firstMatch(str);
      if (m != null) {
        return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
            int.parse(m.group(3)!));
      }
      final br = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})');
      final m3 = br.firstMatch(str);
      if (m3 != null) {
        return DateTime(int.parse(m3.group(3)!), int.parse(m3.group(2)!),
            int.parse(m3.group(1)!));
      }
      return null;
    }

    final startDt = tryParse(startRaw);
    final endDt = tryParse(endRaw);

    String duration = '';
    if (startDt != null && endDt != null) {
      final d = endDt.difference(startDt).inDays + 1;
      duration = '$d dias';
    }

    // Seção dentro do cartão: superfície neutra, sem borda (DESIGN §3b).
    final tema = Theme.of(context);
    final aoFundo = tema.colorScheme.onSurface;
    final primaria = tema.colorScheme.primary;
    final fim = isDark ? AppColors.falhaEscuro : AppColors.falha;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: aoFundo.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: aoFundo.withValues(alpha: 0.62),
                ),
              ),
              const Spacer(),
              _buildStatusChip(startDt, endDt),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.flight_takeoff_rounded,
                    size: AppIconSize.xs, color: primaria),
              ),
              const SizedBox(width: 5),
              Text(
                startFormatted.isNotEmpty ? startFormatted : '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: aoFundo,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ExcludeSemantics(
                  child: Icon(Icons.arrow_forward_rounded,
                      size: AppIconSize.xxs,
                      color: aoFundo.withValues(alpha: 0.40)),
                ),
              ),
              ExcludeSemantics(
                child: Icon(Icons.flight_land_rounded,
                    size: AppIconSize.xs, color: fim),
              ),
              const SizedBox(width: 5),
              Text(
                endFormatted.isNotEmpty ? endFormatted : '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: aoFundo,
                ),
              ),
              if (duration.isNotEmpty) ...[
                const Spacer(),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    color: aoFundo.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── UI: card principal de férias ─────────────────────────────────────
  Widget _buildVacationCard(Map<String, dynamic> r, bool isDark) {
    String getField(List<String> keys) {
      for (final k in keys) {
        final v = r[k];
        if (v != null) {
          final s = v.toString();
          if (s.trim().isNotEmpty && s.toLowerCase() != 'null') return s.trim();
        }
      }
      return '';
    }

    String fmtDate(String s) {
      if (s.trim().isEmpty) return '';
      final str = s.trim();
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
      final m = iso.firstMatch(str);
      if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
      final iso2 = RegExp(r'^(\d{4})\/(\d{2})\/(\d{2})');
      final m2 = iso2.firstMatch(str);
      if (m2 != null) return '${m2.group(3)}/${m2.group(2)}/${m2.group(1)}';
      return str;
    }

    final nome =
        getField(['nome', 'nome_militar', 'nomeMilitar', 'nomeCompleto']);
    final posto = getField(['posto', 'posto_graduacao', 'PostoGraduacao']);
    final comando = getField(['comando', 'orgao', 'lotacao']);
    final unidade = getField(['unidade', 'unidade_sigla']);
    final subInfo = [comando, unidade].where((s) => s.isNotEmpty).join(' · ');

    // Períodos
    final integralInicioRaw = getField([
      'prev_feri_inicio',
      'prev_feri_inicio_format',
      'integral_inicio',
      'integral_inicio_format',
      'integra_inicio'
    ]);
    final integralFinalRaw = getField([
      'prev_feri_final',
      'prev_feri_final_format',
      'integral_final',
      'integral_final_format',
      'integra_final'
    ]);
    final frac1InicioRaw = getField(['1p_inicio', '1p_inicio_format']);
    final frac1FinalRaw = getField(['1p_fim', '1p_fim_format']);
    final frac2InicioRaw = getField(['2p_inicio', '2p_inicio_format']);
    final frac2FinalRaw = getField(['2p_fim', '2p_fim_format']);
    final frac3InicioRaw = getField(['3p_inicio', '3p_inicio_format']);
    final frac3FinalRaw = getField(['3p_fim', '3p_fim_format']);

    final fIntI = fmtDate(integralInicioRaw);
    final fIntF = fmtDate(integralFinalRaw);
    final f1i = fmtDate(frac1InicioRaw);
    final f1f = fmtDate(frac1FinalRaw);
    final f2i = fmtDate(frac2InicioRaw);
    final f2f = fmtDate(frac2FinalRaw);
    final f3i = fmtDate(frac3InicioRaw);
    final f3f = fmtDate(frac3FinalRaw);

    // 13º
    final prevAnt = getField([
      'prev_feri_antecipado',
      'prev_feri_antecipado_format',
      'prev_feri_antecipado_raw'
    ]);
    String antecipadoLabel = '';
    if (prevAnt.isNotEmpty) {
      final v = prevAnt.toLowerCase();
      if (v == 'a') {
        antecipadoLabel = '13º Salário pago no aniversário.';
      } else if (v == 'b') {
        antecipadoLabel = '13º Salário pago parcelado.';
      } else {
        antecipadoLabel = prevAnt;
      }
    }

    // Tipo: integral ou parcelada
    final hasPrev = integralInicioRaw.isNotEmpty || integralFinalRaw.isNotEmpty;
    final hasFrac = frac1InicioRaw.isNotEmpty ||
        frac1FinalRaw.isNotEmpty ||
        frac2InicioRaw.isNotEmpty ||
        frac2FinalRaw.isNotEmpty ||
        frac3InicioRaw.isNotEmpty ||
        frac3FinalRaw.isNotEmpty;
    final fracIntRaw = r['frac_int'];
    final isIntegral = hasPrev ||
        (!hasFrac &&
            fracIntRaw != null &&
            (fracIntRaw.toString() == '1' ||
                fracIntRaw.toString().toLowerCase() == 'true'));

    final tema = Theme.of(context);
    final primaria = tema.colorScheme.primary;
    final aoFundo = tema.colorScheme.onSurface;

    // Selo do tipo: verde para integral, âmbar para parcelada, nas versões
    // de cada tema (as de fundo escuro não passam de 4,5:1 no claro).
    final corTipo = isIntegral
        ? (isDark ? AppColors.sucessoEscuro : AppColors.sucesso)
        : (isDark ? Colors.amber.shade300 : Colors.amber.shade900);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CartaoVidro(
      arte: Arte.de('fe'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho: quem e o tipo do plano ─────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: aoFundo.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.beach_access_outlined,
                      color: primaria, size: AppIconSize.md),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (posto.isNotEmpty)
                        Text(posto,
                            style: TextStyle(
                                color: aoFundo.withValues(alpha: 0.60),
                                fontSize: 11,
                                letterSpacing: 0.3)),
                      Text(
                        nome.isNotEmpty ? nome : 'Plano de Férias',
                        style: TextStyle(
                          color: aoFundo,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subInfo.isNotEmpty)
                        Text(subInfo,
                            style: TextStyle(
                                color: aoFundo.withValues(alpha: 0.55),
                                fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Badge tipo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: corTipo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: corTipo.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Text(
                    isIntegral ? 'INTEGRAL' : 'PARCELADA',
                    style: TextStyle(
                      color: corTipo,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Períodos ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Column(
              children: [
                if (isIntegral) ...[
                  if (fIntI.isNotEmpty || fIntF.isNotEmpty)
                    _buildPeriodRow(
                      label: 'Período Integral',
                      startRaw: integralInicioRaw,
                      startFormatted: fIntI,
                      endRaw: integralFinalRaw,
                      endFormatted: fIntF,
                      isDark: isDark,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Plano integral — datas ainda não disponíveis.',
                        style: TextStyle(
                          color: aoFundo.withValues(alpha: 0.60),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ] else ...[
                  if (f1i.isNotEmpty || f1f.isNotEmpty)
                    _buildPeriodRow(
                      label: '1ª Parcela',
                      startRaw: frac1InicioRaw,
                      startFormatted: f1i,
                      endRaw: frac1FinalRaw,
                      endFormatted: f1f,
                      isDark: isDark,
                    ),
                  if (f2i.isNotEmpty || f2f.isNotEmpty)
                    _buildPeriodRow(
                      label: '2ª Parcela',
                      startRaw: frac2InicioRaw,
                      startFormatted: f2i,
                      endRaw: frac2FinalRaw,
                      endFormatted: f2f,
                      isDark: isDark,
                    ),
                  if (f3i.isNotEmpty || f3f.isNotEmpty)
                    _buildPeriodRow(
                      label: '3ª Parcela',
                      startRaw: frac3InicioRaw,
                      startFormatted: f3i,
                      endRaw: frac3FinalRaw,
                      endFormatted: f3f,
                      isDark: isDark,
                    ),
                ],
              ],
            ),
          ),

          // ── Info 13º ─────────────────────────────────────────────
          if (antecipadoLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: aoFundo.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.monetization_on_outlined,
                          size: AppIconSize.xs,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade900),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        antecipadoLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FundoSuave(child: Scaffold(
      appBar: const CustomAppBar(title: 'Plano de Férias'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopoArte(
            arte: Arte.de('fe'),
            icone: Icons.beach_access_outlined,
            titulo: 'Plano de férias',
            subtitulo: 'Seus períodos de férias no ano escolhido, '
                'com a situação de cada um.',
            margem: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            // Seletor de ano dentro do topo, como continuação da arte.
            child: _years.isNotEmpty ? _buildYearBar(isDark) : null,
          ),

          // Conteúdo principal
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildVacationCard(_filtered[i], isDark),
                        ),
                      ),
          ),
        ],
      ),
    ));
  }
}
