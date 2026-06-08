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
          if (dataInicio.isEmpty && dataFim.isEmpty) return SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$parcela:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: subtitleFontSize + 1,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dataInicio.isEmpty ? '—' : dataInicio} à ${dataFim.isEmpty ? '—' : dataFim}',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
          child: Center(
            child: Card(
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: cardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // header
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.045,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade800
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Plano de Férias | ${ano.isNotEmpty ? ano : DateTime.now().year}',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (integral)
                            _buildParcelaRow('Período Integral', prevIni,
                                prevFim, Colors.blue.shade700)
                          else ...[
                            _buildParcelaRow(
                                '1ª Parcela', p1i, p1f, Colors.blue.shade500),
                            _buildParcelaRow(
                                '2ª Parcela', p2i, p2f, Colors.green.shade500),
                            _buildParcelaRow(
                                '3ª Parcela', p3i, p3f, Colors.orange.shade500),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (antecipadoLabel.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: antecipadoColor.withOpacity(0.16),
                                    border: Border.all(
                                        color: Colors.blue.shade600, width: 1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.monetization_on,
                                          size: 16,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 8),
                                      Text(antecipadoLabel,
                                          style: TextStyle(
                                              color: Colors.blue.shade900,
                                              fontWeight: FontWeight.w700,
                                              fontSize: subtitleFontSize - 2)),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                'Toque para ver detalhes',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: subtitleFontSize - 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (daysLeft != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                border: Border.all(
                                    color: Colors.blue.shade600, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    daysLeft == 1
                                        ? 'Falta 1 dia para as férias'
                                        : 'Faltam $daysLeft dias para as férias',
                                    style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w700,
                                        fontSize: subtitleFontSize - 1),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
