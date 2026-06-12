import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';

class CardTempoServico extends StatelessWidget {
  const CardTempoServico({Key? key, this.diasAgregadosTeste}) : super(key: key);

  final int? diasAgregadosTeste;

  Future<int> _buscarDiasAgregados(String matricula) async {
    if (diasAgregadosTeste != null) return diasAgregadosTeste!;
    final uri = Uri.parse(
      'https://pmrr.net/flutter/sigrh/listar_policial_iper.php?matricula=$matricula',
    );
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return 0;
      final json = jsonDecode(resp.body);
      if (json['code'] != 1) return 0;
      return (json['result'] as List<dynamic>).fold<int>(0, (p, e) {
        final raw = e['poip_total_dias'];
        if (raw is int) return p + raw;
        if (raw is String) return p + (int.tryParse(raw) ?? 0);
        if (raw is num) return p + raw.toInt();
        return p;
      });
    } catch (_) {
      return 0;
    }
  }

  DateTime? _parseDataIncorporacao(String? str) {
    if (str == null || str.isEmpty) return null;
    final iso = DateTime.tryParse(str);
    if (iso != null) return iso;
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(str);
    } catch (_) {
      return null;
    }
  }

  String _extensoDias(int totalDias) {
    const diasAno = 365, diasMes = 30;
    final anos = totalDias ~/ diasAno;
    final meses = (totalDias % diasAno) ~/ diasMes;
    final dias = (totalDias % diasAno) % diasMes;
    final partes = <String>[];
    if (anos > 0) partes.add('$anos ${anos > 1 ? "anos" : "ano"}');
    if (meses > 0) partes.add('$meses ${meses > 1 ? "meses" : "mês"}');
    if (dias > 0 || partes.isEmpty)
      partes.add('$dias ${dias > 1 ? "dias" : "dia"}');
    if (partes.length > 1) {
      final ultimo = partes.removeLast();
      return '${partes.join(", ")} e $ultimo';
    }
    return partes.first;
  }

  String _mesAbrev(int mes) {
    const m = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return m[mes - 1];
  }

  Widget _blob({double w = double.infinity, double h = 12, double r = 6, required bool isDark}) =>
      Container(
        width: w, height: h,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  Widget _quad(Color c) => Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final matricula = auth.matricula ?? '';
    final dataInc = _parseDataIncorporacao(auth.dataIncorporacao);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context);
    const primaryBlue = Color(0xFF1565C0);
    const bgAccent = Color(0xFFE3F2FD);

    int diasNormal = 0;
    if (dataInc != null) diasNormal = DateTime.now().difference(dataInc).inDays;

    return FutureBuilder<int>(
      future: _buscarDiasAgregados(matricula),
      builder: (context, snap) {
        final isLoading = snap.connectionState == ConnectionState.waiting;

        // Skeleton só quando não há nem o tempo normal disponível
        if (isLoading && diasNormal == 0) {
          return Card(
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  _blob(w: 36, h: 36, r: 10, isDark: isDark),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _blob(w: 130, h: 12, isDark: isDark),
                    _blob(w: 80, h: 10, isDark: isDark),
                  ]),
                  const Spacer(),
                  _blob(w: 48, h: 24, r: 20, isDark: isDark),
                ]),
                const SizedBox(height: 14),
                _blob(h: 22, r: 20, isDark: isDark),
                const SizedBox(height: 6),
                _blob(w: 200, h: 10, isDark: isDark),
              ]),
            ),
          );
        }

        final diasAgregados = snap.data ?? 0;
        final diasTotal = diasNormal + diasAgregados;
        const metaDias = 10950;
        final percTotal = (diasTotal / metaDias).clamp(0.0, 1.0);
        final percNormal = (diasNormal / metaDias).clamp(0.0, 1.0);

        const normalA = Color(0xFFBFE2F3);
        const normalB = Color(0xFF004298);
        const agregA  = Color(0xFF0D80C6);
        const agregB  = Color(0xFF00C8D7);

        final LinearGradient gradient;
        if (diasAgregados == 0) {
          gradient = const LinearGradient(colors: [normalA, normalB], begin: Alignment.centerLeft, end: Alignment.centerRight);
        } else {
          final split = percTotal == 0 ? 1.0 : percNormal / percTotal;
          final s0 = (split - 0.02).clamp(0.0, 1.0);
          final s1 = (split + 0.02).clamp(0.0, 1.0);
          gradient = LinearGradient(colors: [normalA, normalB, agregA, agregB], stops: [0.0, s0, s1, 1.0], begin: Alignment.centerLeft, end: Alignment.centerRight);
        }

        // Projeção de aposentadoria (30 anos de serviço)
        String? retirementLabel;
        String? retirementDiff;
        if (dataInc != null) {
          final meta = DateTime(dataInc.year + 30, dataInc.month, dataInc.day);
          final agora = DateTime.now();
          retirementLabel = '${_mesAbrev(meta.month)}/${meta.year}';
          final diff = meta.difference(agora).inDays;
          if (diff > 0) {
            final anosR = diff ~/ 365;
            final mesesR = (diff % 365) ~/ 30;
            retirementDiff = anosR > 0
                ? 'em $anosR ${anosR == 1 ? "ano" : "anos"}${mesesR > 0 ? " e $mesesR ${mesesR == 1 ? "mês" : "meses"}" : ""}'
                : 'em $diff dias';
          } else {
            retirementDiff = 'Meta atingida ✓';
          }
        }

        return Card(
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // ── Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? primaryBlue.withValues(alpha: 0.18) : bgAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.military_tech_rounded, color: primaryBlue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tempo de Serviço', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Fonte: SIGRH', style: t.textTheme.labelSmall?.copyWith(color: Colors.grey[500])),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? primaryBlue.withValues(alpha: 0.18) : bgAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(percTotal * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),

              const SizedBox(height: 10),

              // ── Barra de progresso
              LinearPercentIndicator(
                linearGradient: gradient,
                barRadius: const Radius.circular(20),
                animation: true,
                lineHeight: 18,
                animationDuration: 800,
                percent: percTotal,
                center: AutoSizeText(
                  _extensoDias(diasTotal),
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                  maxLines: 1,
                  minFontSize: 7,
                ),
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: 6),

              // ── Legenda PM / IPER
              if (isLoading)
                Row(children: [
                  _quad(normalB),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('PM: ${_extensoDias(diasNormal)}',
                        style: t.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 6),
                  Text('IPER: carregando…', style: t.textTheme.labelSmall?.copyWith(color: Colors.grey[500])),
                ])
              else if (diasAgregados == 0)
                Text('* Não possui tempo agregado no IPER.',
                    style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[500]))
              else
                Row(children: [
                  _quad(normalB),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('PM: ${_extensoDias(diasNormal)}',
                        style: t.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  _quad(agregA),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('IPER: ${_extensoDias(diasAgregados)}',
                        style: t.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ]),

              // ── Projeção de aposentadoria (30 anos)
              if (retirementLabel != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.flag_outlined, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 6),
                    Text('Meta 30 anos: $retirementLabel',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54)),
                    const Spacer(),
                    Text(retirementDiff ?? '',
                        style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.black38)),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
