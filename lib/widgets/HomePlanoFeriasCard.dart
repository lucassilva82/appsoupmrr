import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

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
          'https://pmrr.online/flutter/sigrh/buscaplanodeferias.php?matricula=$matricula');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> body = jsonDecode(resp.body);
      if (body['code'] != 1 || body['result'] is! List) return null;
      final list = List<Map<String, dynamic>>.from(body['result']);
      if (list.isEmpty) return null;
      final now = DateTime.now().year;
      for (final r in list) {
        final a = (r['ano_base_nome'] ?? r['ano'] ?? r['year'])?.toString();
        if (a != null && int.tryParse(a) == now) return r;
      }
      return list.first;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  String _fmtDate(dynamic s) {
    if (s == null) return '';
    final str = s.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str);
    if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(str)) return str;
    return str;
  }

  DateTime? _tryParse(String s) {
    if (s.trim().isEmpty) return null;
    final str = s.trim();
    var m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str);
    if (m != null)
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!));
    m = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})').firstMatch(str);
    if (m != null)
      return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!),
          int.parse(m.group(1)!));
    return null;
  }

  bool _isIntegral(Map<String, dynamic> r) {
    final hasPrev =
        r['prev_feri_inicio'] != null || r['prev_feri_final'] != null;
    final hasFrac = (r['1p_inicio'] ??
            r['1p_fim'] ??
            r['2p_inicio'] ??
            r['2p_fim'] ??
            r['3p_inicio'] ??
            r['3p_fim']) !=
        null;
    final fi = r['frac_int'];
    return hasPrev ||
        (!hasFrac &&
            fi != null &&
            (fi.toString() == '1' || fi.toString().toLowerCase() == 'true'));
  }

  // Retorna {label, color, icon} para o status do período
  ({String label, Color color, IconData icon})? _periodoStatus(
      String startRaw, String endRaw) {
    final startDt = _tryParse(startRaw);
    if (startDt == null) return null;
    final endDt = _tryParse(endRaw);
    final now = DateTime.now();
    if (endDt != null && endDt.isBefore(now)) {
      return (
        label: 'Concluído',
        color: Colors.grey,
        icon: Icons.check_circle_outline
      );
    }
    if (startDt.isBefore(now) ||
        startDt.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return (
        label: 'Em andamento',
        color: const Color(0xFF22C55E),
        icon: Icons.play_circle_outline
      );
    }
    final days = startDt.difference(now).inDays + 1;
    final label = days == 1 ? 'Amanhã' : 'Em ${days}d';
    return (label: label, color: AppColors.blue, icon: Icons.schedule_outlined);
  }

  // ── Skeleton ─────────────────────────────────────────────────────────
  Widget _buildSkeleton(bool isDark) {
    final base =
        isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade200;
    blob({double w = double.infinity, double h = 12.0, double r = 6.0}) =>
        Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(r)),
        );
    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                blob(w: 36, h: 36, r: 10),
                const SizedBox(width: 10),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [blob(w: 110, h: 12), blob(w: 60, h: 10)]),
                const Spacer(),
                blob(w: 52, h: 24, r: 20),
              ]),
              const SizedBox(height: 14),
              blob(h: 44, r: 10),
              const SizedBox(height: 6),
              blob(h: 44, r: 10),
            ]),
      ),
    );
  }

  // ── Linha de período ─────────────────────────────────────────────────
  Widget _buildPeriodRow({
    required String label,
    required String startRaw,
    required String startFmt,
    required String endFmt,
    required bool isDark,
  }) {
    final status =
        _periodoStatus(startRaw, _tryParse(endFmt) != null ? endFmt : '');
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : AppColors.blue.withValues(alpha: 0.04);
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.blue.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(children: [
        Icon(Icons.event_outlined, size: 14, color: AppColors.blue),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 2),
            Text(
              '${startFmt.isNotEmpty ? startFmt : "—"}  →  ${endFmt.isNotEmpty ? endFmt : "—"}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ]),
        ),
        if (status != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(status.icon, size: 10, color: status.color),
              const SizedBox(width: 3),
              Text(status.label,
                  style: TextStyle(
                      fontSize: 9,
                      color: status.color,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context);
    const primaryBlue = Color(0xFF1565C0);
    const bgAccent = Color(0xFFE3F2FD);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _futurePlan,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return _buildSkeleton(isDark);

        final r = snap.data;

        // Estado vazio / erro
        if (r == null) {
          return Card(
            margin: EdgeInsets.zero,
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? primaryBlue.withValues(alpha: 0.18)
                          : bgAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.beach_access_rounded,
                        color: primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Nenhum plano de férias para o ano atual.',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: primaryBlue),
                ]),
              ),
            ),
          );
        }

        // Dados disponíveis
        final ano =
            (r['ano_base_nome'] ?? r['ano'] ?? r['year'])?.toString() ?? '';
        final integral = _isIntegral(r);

        final prevIniRaw = _fmtDate(r['prev_feri_inicio']);
        final prevFimRaw = _fmtDate(r['prev_feri_final']);
        final p1i = _fmtDate(r['1p_inicio']);
        final p1f = _fmtDate(r['1p_fim']);
        final p2i = _fmtDate(r['2p_inicio']);
        final p2f = _fmtDate(r['2p_fim']);
        final p3i = _fmtDate(r['3p_inicio']);
        final p3f = _fmtDate(r['3p_fim']);

        final prevAntRaw = (r['prev_feri_antecipado'] ??
                r['prev_feri_antecipado_format'] ??
                '')
            .toString();
        String? antecipadoLabel;
        if (prevAntRaw.isNotEmpty) {
          final v = prevAntRaw.toLowerCase();
          if (v == 'a')
            antecipadoLabel = '13º pago no aniversário';
          else if (v == 'b')
            antecipadoLabel = '13º pago parcelado';
          else
            antecipadoLabel = prevAntRaw;
        }

        // Próxima data futura (para badge global)
        DateTime? nearest;
        for (final raw in [prevIniRaw, p1i, p2i, p3i]) {
          if (raw.isEmpty) continue;
          final dt = _tryParse(raw);
          if (dt == null) continue;
          if (!dt.isBefore(DateTime.now())) {
            if (nearest == null || dt.isBefore(nearest)) nearest = dt;
          }
        }
        final daysLeft = nearest != null
            ? nearest.difference(DateTime.now()).inDays + 1
            : null;

        return Card(
          margin: EdgeInsets.zero,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? primaryBlue.withValues(alpha: 0.18)
                              : bgAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.beach_access_rounded,
                            color: primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Plano de Férias',
                                  style: t.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              Row(children: [
                                Text(
                                    'Ano ${ano.isNotEmpty ? ano : DateTime.now().year}',
                                    style: t.textTheme.labelSmall
                                        ?.copyWith(color: Colors.grey[500])),
                                if (!integral) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                          alpha: isDark ? 0.18 : 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('PARCELADA',
                                        style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.amber.shade300
                                                : Colors.amber.shade800)),
                                  ),
                                ],
                              ]),
                            ]),
                      ),
                      // Countdown badge
                      if (daysLeft != null && daysLeft > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(
                                alpha: isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            daysLeft == 1 ? 'Amanhã' : 'Em ${daysLeft}d',
                            style: const TextStyle(
                                color: primaryBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ]),

                    const SizedBox(height: 8),

                    // ── Períodos com status ────────────────────────────────
                    if (integral) ...[
                      if (prevIniRaw.isNotEmpty || prevFimRaw.isNotEmpty)
                        _buildPeriodRow(
                          label: 'Período Integral',
                          startRaw: prevIniRaw,
                          startFmt: prevIniRaw,
                          endFmt: prevFimRaw,
                          isDark: isDark,
                        ),
                    ] else ...[
                      if (p1i.isNotEmpty || p1f.isNotEmpty)
                        _buildPeriodRow(
                            label: '1ª Parcela',
                            startRaw: p1i,
                            startFmt: p1i,
                            endFmt: p1f,
                            isDark: isDark),
                      if (p2i.isNotEmpty || p2f.isNotEmpty)
                        _buildPeriodRow(
                            label: '2ª Parcela',
                            startRaw: p2i,
                            startFmt: p2i,
                            endFmt: p2f,
                            isDark: isDark),
                      if (p3i.isNotEmpty || p3f.isNotEmpty)
                        _buildPeriodRow(
                            label: '3ª Parcela',
                            startRaw: p3i,
                            startFmt: p3i,
                            endFmt: p3f,
                            isDark: isDark),
                    ],

                    // ── Footer: 13º + Ver detalhes ───────────────────────
                    Row(children: [
                      if (antecipadoLabel != null) ...[
                        Icon(Icons.monetization_on_outlined,
                            size: 13,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade700),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(antecipadoLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.amber.shade300
                                      : Colors.amber.shade800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ] else
                        const Spacer(),
                      Text('Ver detalhes',
                          style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: primaryBlue),
                    ]),
                  ]),
            ),
          ),
        );
      },
    );
  }
}
