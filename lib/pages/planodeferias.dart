import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

// import '../widgets/drawer_personalizado.dart'; // removido: import não utilizado
import '../widgets/custom_appbar.dart';
import '../models/auth_model.dart';

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

  Widget _buildRow(Map<String, dynamic> r) {
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

    final nome =
        getField(['nome', 'nome_militar', 'nomeMilitar', 'nomeCompleto']);
    final posto = getField(['posto', 'posto_graduacao', 'PostoGraduacao']);
    final comando = getField(['comando', 'orgao', 'lotacao']);
    final unidade = getField(['unidade', 'unidade_sigla']);

    String formatDateStr(String s) {
      if (s.trim().isEmpty) return '';
      final str = s.trim();
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
      final m = iso.firstMatch(str);
      if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
      final iso2 = RegExp(r'^(\d{4})\/(\d{2})\/(\d{2})');
      final m2 = iso2.firstMatch(str);
      if (m2 != null) return '${m2.group(3)}/${m2.group(2)}/${m2.group(1)}';
      final br = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})');
      if (br.hasMatch(str)) return str;
      return str;
    }

    // integral (previsto)
    final integralInicio = getField([
      'prev_feri_inicio',
      'prev_feri_inicio_format',
      'integral_inicio',
      'integral_inicio_format',
      'integra_inicio'
    ]);
    final integralFinal = getField([
      'prev_feri_final',
      'prev_feri_final_format',
      'integral_final',
      'integral_final_format',
      'integra_final'
    ]);

    // parcelas
    final frac1Inicio = getField(['1p_inicio', '1p_inicio_format']);
    final frac1Final = getField(['1p_fim', '1p_fim_format']);
    final frac2Inicio = getField(['2p_inicio', '2p_inicio_format']);
    final frac2Final = getField(['2p_fim', '2p_fim_format']);
    final frac3Inicio = getField(['3p_inicio', '3p_inicio_format']);
    final frac3Final = getField(['3p_fim', '3p_fim_format']);

    final fIntegralInicio =
        integralInicio.isNotEmpty ? formatDateStr(integralInicio) : '';
    final fIntegralFinal =
        integralFinal.isNotEmpty ? formatDateStr(integralFinal) : '';
    final f1i = frac1Inicio.isNotEmpty ? formatDateStr(frac1Inicio) : '';
    final f1f = frac1Final.isNotEmpty ? formatDateStr(frac1Final) : '';
    final f2i = frac2Inicio.isNotEmpty ? formatDateStr(frac2Inicio) : '';
    final f2f = frac2Final.isNotEmpty ? formatDateStr(frac2Final) : '';
    final f3i = frac3Inicio.isNotEmpty ? formatDateStr(frac3Inicio) : '';
    final f3f = frac3Final.isNotEmpty ? formatDateStr(frac3Final) : '';
    // antecipação do 13º
    final prevAnt = getField([
      'prev_feri_antecipado',
      'prev_feri_antecipado_format',
      'prev_feri_antecipado_raw'
    ]);
    String antecipadoLabel = '';
    if (prevAnt.isNotEmpty) {
      final v = prevAnt.toLowerCase();
      if (v == 'a')
        antecipadoLabel = 'O 13º Salário é pago no aniversário.';
      else if (v == 'b')
        antecipadoLabel = 'O 13º Salário é pago parcelado.';
      else
        antecipadoLabel = prevAnt;
    }

    // Decide mode robustly:
    // - if prev_feri_inicio/prev_feri_final exist -> integral
    // - else if any frac fields exist -> parcelado
    // - else fall back to frac_int flag
    final hasPrev = integralInicio.isNotEmpty || integralFinal.isNotEmpty;
    final hasFrac = frac1Inicio.isNotEmpty ||
        frac1Final.isNotEmpty ||
        frac2Inicio.isNotEmpty ||
        frac2Final.isNotEmpty ||
        frac3Inicio.isNotEmpty ||
        frac3Final.isNotEmpty;
    final fracIntRaw = r['frac_int'];
    final bool isIntegral = hasPrev ||
        (!(hasFrac) &&
            fracIntRaw != null &&
            (fracIntRaw.toString() == '1' ||
                fracIntRaw.toString().toLowerCase() == 'true'));

    Widget header() {
      String clean(String s) => s.replaceAll(RegExp(r'[\-\.]+'), '').trim();
      final p = clean(posto);
      final n = clean(nome);
      final subParts = <String>[];
      if (comando.isNotEmpty) subParts.add(comando);
      if (unidade.isNotEmpty) subParts.add(unidade);
      final sub = subParts.join(' • ');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.isNotEmpty)
            Text(p,
                style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          if (n.isNotEmpty)
            Text(n,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (sub.isNotEmpty) SizedBox(height: 6),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(color: Colors.grey.shade700)),
        ],
      );
    }

    // helper: try parse many date formats to DateTime
    DateTime? tryParseDate(String s) {
      if (s.trim().isEmpty) return null;
      final str = s.trim();
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
      final m = iso.firstMatch(str);
      if (m != null)
        return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
            int.parse(m.group(3)!));
      final iso2 = RegExp(r'^(\d{4})\/(\d{2})\/(\d{2})');
      final m2 = iso2.firstMatch(str);
      if (m2 != null)
        return DateTime(int.parse(m2.group(1)!), int.parse(m2.group(2)!),
            int.parse(m2.group(3)!));
      final br = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})');
      final m3 = br.firstMatch(str);
      if (m3 != null)
        return DateTime(int.parse(m3.group(3)!), int.parse(m3.group(2)!),
            int.parse(m3.group(1)!));
      return null;
    }

    // collect candidate start dates (integral or parcel starts)
    final candidatesRaw = <String>[
      integralInicio,
      frac1Inicio,
      frac2Inicio,
      frac3Inicio
    ];
    final now = DateTime.now();
    DateTime? nearest;
    for (final raw in candidatesRaw) {
      if (raw.trim().isEmpty) continue;
      final dt = tryParseDate(raw);
      if (dt == null) continue;
      if (!dt.isBefore(now)) {
        if (nearest == null || dt.isBefore(nearest)) nearest = dt;
      }
    }

    // if no future dates found, do not show badge
    int? daysLeft;
    if (nearest != null) {
      final diff = nearest.difference(now).inDays;
      daysLeft = diff >= 0 ? diff : 0;
    }

    // provide screen width for badge constraints
    final sw = MediaQuery.of(context).size.width;

    // build the card content and include a small trailing badge column so it doesn't overlap the header
    final cardWithOptionalBadge = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.blueAccent.shade200,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.beach_access,
                              color: Colors.blueAccent)),
                      const SizedBox(width: 12),
                      Expanded(child: header()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Integral
                  if (fIntegralInicio.isNotEmpty || fIntegralFinal.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Text('Integral',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800))),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  'Início: ${fIntegralInicio.isEmpty ? '—' : fIntegralInicio}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  'Fim: ${fIntegralFinal.isEmpty ? '—' : fIntegralFinal}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Parcelas (only when not integral)
                  if (!isIntegral) ...[
                    if (f1i.isNotEmpty || f1f.isNotEmpty)
                      _buildParcelaRow('Frac 1P', f1i, f1f),
                    if (f2i.isNotEmpty || f2f.isNotEmpty)
                      _buildParcelaRow('Frac 2P', f2i, f2f),
                    if (f3i.isNotEmpty || f3f.isNotEmpty)
                      _buildParcelaRow('Frac 3P', f3i, f3f),
                  ],
                  // If integral and there are no dates, show a small note
                  if (isIntegral &&
                      fIntegralInicio.isEmpty &&
                      fIntegralFinal.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Plano integral (sem datas previstas)',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),

                  // Exibe info de antecipação do 13º salário (se houver)
                  if (antecipadoLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              antecipadoLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // trailing badge area (keeps space and avoids overlapping header)
          if (daysLeft != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, right: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: sw * 0.36),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border:
                            Border.all(color: Colors.blue.shade600, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            daysLeft == 1
                                ? 'Falta 1 dia'
                                : 'Faltam $daysLeft dias',
                            style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text('para as férias',
                              style: TextStyle(
                                  color: Colors.blue.shade700, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );

    // return the card (let it size itself) — badge constrained to avoid overflow
    return cardWithOptionalBadge;
  }

  Widget _buildParcelaRow(String title, String inicio, String fim) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Início: ${inicio == '-' ? '----' : inicio}'),
              Text('Fim: ${fim == '-' ? '----' : fim}'),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Meu Plano de Ferias'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedYear,
                          hint: const Text('Selecione o ano'),
                          items: _years
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: (v) async {
                            // when user picks a year, update selection and re-fetch
                            setState(() => _selectedYear = v);
                            await _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if ((_filtered.isEmpty))
                Expanded(
                  child: Center(
                    child: Text(
                      _error == null
                          ? 'Você não possui um plano de ferias para o ano selecionado. Procure a administração da sua OM.'
                          : _error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 16),
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildRow(_filtered[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
