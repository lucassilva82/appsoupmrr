import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';

class HomePlanoFeriasCard extends StatefulWidget {
  const HomePlanoFeriasCard({Key? key}) : super(key: key);

  @override
  State<HomePlanoFeriasCard> createState() => _HomePlanoFeriasCardState();
}

class _HomePlanoFeriasCardState extends State<HomePlanoFeriasCard> {
  late Future<Map<String, dynamic>?> _futurePlan;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);
    _futurePlan = _fetchPlan(auth.matricula);
  }

  Future<Map<String, dynamic>?> _fetchPlan(String? matricula) async {
    if (matricula == null || matricula.isEmpty) return null;
    try {
      final uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/buscaplanodeferias.php?matricula=$matricula');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> body = jsonDecode(resp.body);
      if (body['code'] != 1 || body['result'] is! List) return null;
      final list = List<Map<String, dynamic>>.from(body['result']);
      if (list.isEmpty) return null;

      final now = DateTime.now().year;
      for (final r in list) {
        final ano = (r['ano_base_nome'] ?? r['ano'] ?? r['year'])?.toString();
        if (ano != null && ano.isNotEmpty && int.tryParse(ano) == now) return r;
      }
      return list.first;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(dynamic s) {
    if (s == null) return '';
    final str = s.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '';
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final m = iso.firstMatch(str);
    if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
    final br = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})');
    if (br.hasMatch(str)) return str;
    return str;
  }

  bool _isIntegral(Map<String, dynamic> r) {
    final prevIni = r['prev_feri_inicio'];
    final prevFim = r['prev_feri_final'];
    final hasPrev = prevIni != null || prevFim != null;
    final hasFrac = (r['1p_inicio'] != null ||
        r['1p_fim'] != null ||
        r['2p_inicio'] != null ||
        r['2p_fim'] != null ||
        r['3p_inicio'] != null ||
        r['3p_fim'] != null);
    final fracInt = r['frac_int'];
    return hasPrev ||
        (!(hasFrac) &&
            fracInt != null &&
            (fracInt.toString() == '1' ||
                fracInt.toString().toLowerCase() == 'true'));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth * 0.99;
    final cardPadding = screenWidth * 0.03;
    final titleFontSize = screenWidth * 0.035;
    final subtitleFontSize = screenWidth * 0.025;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _futurePlan,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: screenHeight * 0.12,
            child: Center(
                child: Card(
                    elevation: 2,
                    child: SizedBox(
                        width: cardWidth,
                        height: 60,
                        child: Center(
                            child: CircularProgressIndicator.adaptive())))),
          );
        }
        final r = snap.data;
        if (r == null) {
          return SizedBox(
            height: screenHeight * 0.12,
            child: Center(
              child: Card(
                elevation: 2,
                child: SizedBox(
                  width: cardWidth,
                  height: screenHeight * 0.10,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                        'Plano de Férias: sem informações para o ano atual',
                        style: TextStyle(color: Colors.grey.shade700)),
                  ),
                ),
              ),
            ),
          );
        }

        final ano =
            (r['ano_base_nome'] ?? r['ano'] ?? r['year'])?.toString() ?? '';
        final integral = _isIntegral(r);
        final prevIni = _formatDate(r['prev_feri_inicio']);
        final prevFim = _formatDate(r['prev_feri_final']);
        final p1i = _formatDate(r['1p_inicio']);
        final p1f = _formatDate(r['1p_fim']);
        final p2i = _formatDate(r['2p_inicio']);
        final p2f = _formatDate(r['2p_fim']);
        final p3i = _formatDate(r['3p_inicio']);
        final p3f = _formatDate(r['3p_fim']);
        final prevAntRaw = (r['prev_feri_antecipado'] ??
                r['prev_feri_antecipado_format'] ??
                '')
            .toString();
        String antecipadoLabel = '';
        Color antecipadoColor = Colors.transparent;
        if (prevAntRaw.isNotEmpty) {
          final v = prevAntRaw.toLowerCase();
          if (v == 'a') {
            antecipadoLabel = '13º Sal.: Pago no Aniversário';
            antecipadoColor = Colors.blue.shade200;
          } else if (v == 'b') {
            antecipadoLabel = '13º Sal.: Pago Parcelado';
            antecipadoColor = Colors.blue.shade100;
          } else {
            antecipadoLabel = prevAntRaw;
            antecipadoColor = Colors.blue.shade50;
          }
        }

        // --- compute days left until next start (integral or parcelas) ---
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

        final candidatesRaw = <String>[prevIni, p1i, p2i, p3i];
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

        int? daysLeft;
        if (nearest != null) {
          final diff = nearest.difference(now).inDays;
          daysLeft = diff >= 0 ? diff : 0;
        }

        Widget _buildParcelaRow(
            String parcela, String dataInicio, String dataFim, Color cor) {
          if (dataInicio.isEmpty && dataFim.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text('$parcela:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${dataInicio.isEmpty ? '—' : dataInicio} à ${dataFim.isEmpty ? '—' : dataFim}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        const primaryBlue = Color(0xFF1565C0);
        const bgAccent = Color(0xFFE3F2FD);

        return GestureDetector(
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
          child: Card(
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFE0E7F0),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? primaryBlue.withOpacity(0.18)
                              : bgAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.beach_access_rounded,
                            color: primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plano de Férias',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                              'Ano ${ano.isNotEmpty ? ano : DateTime.now().year}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.grey[500])),
                        ],
                      ),
                      const Spacer(),
                      if (daysLeft != null && daysLeft! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${daysLeft}d',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Parcelas ─────────────────────────────────────────────
                  if (integral)
                    _buildParcelaRow(
                        'Período Integral', prevIni, prevFim, primaryBlue)
                  else ...[
                    _buildParcelaRow('1ª Parcela', p1i, p1f,
                        const Color(0xFF1565C0)),
                    _buildParcelaRow('2ª Parcela', p2i, p2f,
                        const Color(0xFF2E7D32)),
                    _buildParcelaRow('3ª Parcela', p3i, p3f,
                        const Color(0xFFE65100)),
                  ],

                  // ── Footer ────────────────────────────────────────────────
                  Row(
                    children: [
                      if (antecipadoLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? primaryBlue.withOpacity(0.15)
                                : bgAccent,
                            border: Border.all(
                                color: primaryBlue.withOpacity(0.3), width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  size: 14, color: primaryBlue),
                              const SizedBox(width: 6),
                              Text(antecipadoLabel,
                                  style: const TextStyle(
                                      color: primaryBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Text('Ver detalhes',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 11)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
