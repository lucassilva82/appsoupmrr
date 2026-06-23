import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';

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
          'https://pmrr.net/flutter/sigrh/buscaplanodeferias.php?matricula=$matricula');
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
  Widget _buildYearBar(bool isDark) {
    if (_years.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _years.map((year) {
          final isSelected = year == _selectedYear;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(year.toString()),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedYear = year);
                _loadData();
              },
              selectedColor: AppColors.blue,
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AppColors.blue
                    : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── UI: estado vazio / erro ──────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final isError = _error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.blue)
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.cloud_off_outlined
                    : Icons.beach_access_outlined,
                size: 40,
                color: isDark
                    ? Colors.white24
                    : AppColors.blue.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isError ? 'Não foi possível carregar' : 'Nenhum plano encontrado',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ??
                  'Você não possui um plano de férias cadastrado para $_selectedYear.\nProcure a administração da sua OM.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            if (isError) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                ),
              ),
            ],
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

    if (startDt == null) {
      return const SizedBox.shrink();
    } else if (endDt != null && endDt.isBefore(now)) {
      color = Colors.grey;
      icon = Icons.check_circle_outline;
      label = 'Concluído';
    } else if (startDt.isBefore(now) ||
        startDt.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      color = const Color(0xFF22C55E);
      icon = Icons.play_circle_outline;
      label = 'Em andamento';
    } else {
      final days = startDt.difference(now).inDays + 1;
      color = AppColors.blue;
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
          Icon(icon, size: 11, color: color),
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

    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.blue.withValues(alpha: 0.15);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : AppColors.blue.withValues(alpha: 0.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.8),
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
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              _buildStatusChip(startDt, endDt),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.flight_takeoff_rounded,
                  size: 14, color: AppColors.blue),
              const SizedBox(width: 5),
              Text(
                startFormatted.isNotEmpty ? startFormatted : '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 13, color: isDark ? Colors.white38 : Colors.black26),
              ),
              Icon(Icons.flight_land_rounded,
                  size: 14, color: Colors.red.shade400),
              const SizedBox(width: 5),
              Text(
                endFormatted.isNotEmpty ? endFormatted : '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              if (duration.isNotEmpty) ...[
                const Spacer(),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header gradient ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.blue, AppColors.navy],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.beach_access_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (posto.isNotEmpty)
                        Text(posto,
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                letterSpacing: 0.3)),
                      Text(
                        nome.isNotEmpty ? nome : 'Plano de Férias',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subInfo.isNotEmpty)
                        Text(subInfo,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Badge tipo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isIntegral
                        ? const Color(0xFF1DE9B6).withValues(alpha: 0.18)
                        : Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isIntegral
                          ? const Color(0xFF1DE9B6)
                          : Colors.amber.shade400,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isIntegral ? 'INTEGRAL' : 'PARCELADA',
                    style: TextStyle(
                      color: isIntegral
                          ? const Color(0xFF1DE9B6)
                          : Colors.amber.shade300,
                      fontSize: 9.5,
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
                          color: isDark ? Colors.white38 : Colors.black38,
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
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.08)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.shade300.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.monetization_on_outlined,
                        size: 16,
                        color: isDark
                            ? Colors.amber.shade300
                            : Colors.amber.shade800),
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
    );
  }

  // ── build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: const CustomAppBar(title: 'Plano de Férias'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Seletor de ano (chips)
          if (_years.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildYearBar(isDark),
            const SizedBox(height: 4),
          ],

          // Conteúdo principal
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.blue))
                : _filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        color: AppColors.blue,
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
    );
  }
}
