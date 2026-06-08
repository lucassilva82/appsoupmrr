// card_tempo_servico.dart
//
// Agora o texto DENTRO da barra (e também na legenda) aparece por extenso:
// “4 anos, 2 meses e 8 dias”, mantendo todo o layout e as cores.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/auth_model.dart';

class CardTempoServico extends StatelessWidget {
  const CardTempoServico({
    Key? key,
    this.diasAgregadosTeste,
  }) : super(key: key);

  final int? diasAgregadosTeste;

  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  /// Converte total de dias para “X anos, Y meses e Z dias”
  String _extensoDias(int totalDias) {
    const diasAno = 365, diasMes = 30;
    final anos = totalDias ~/ diasAno;
    final meses = (totalDias % diasAno) ~/ diasMes;
    final dias = (totalDias % diasAno) % diasMes;

    final partes = <String>[];
    if (anos > 0) partes.add('$anos ${anos > 1 ? "anos" : "ano"}');
    if (meses > 0) partes.add('$meses ${meses > 1 ? "meses" : "mês"}');
    if (dias > 0 || partes.isEmpty) {
      partes.add('$dias ${dias > 1 ? "dias" : "dia"}');
    }
    if (partes.length > 1) {
      final ultimo = partes.removeLast();
      return '${partes.join(", ")} e $ultimo';
    }
    return partes.first;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final matricula = auth.matricula ?? '';
    final dataInc = _parseDataIncorporacao(auth.dataIncorporacao);

    return FutureBuilder<int>(
      future: _buscarDiasAgregados(matricula),
      builder: (context, snap) {
        final diasAgregados = snap.data ?? 0;

        // ---------- cálculo dias normal / total ---------------------------
        int diasNormal = 0, diasTotal = 0;
        if (dataInc != null) {
          diasNormal = DateTime.now().difference(dataInc).inDays;
          diasTotal = diasNormal + diasAgregados;
        }

        // meta 30 anos => 10 950 d
        const metaDias = 10950;
        final percTotal = (diasTotal / metaDias).clamp(0.0, 1.0);
        final percNormal = (diasNormal / metaDias).clamp(0.0, 1.0);

        // ---------- Cores --------------------------------------------------
        const normalA = Color(0xFFBFE2F3);
        const normalB = Color(0xFF004298);
        const agregA = Color(0xFF0D80C6);
        const agregB = Color(0xFF00C8D7);

        late LinearGradient gradient;
        if (diasAgregados == 0) {
          gradient = const LinearGradient(
            colors: [normalA, normalB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );
        } else {
          final split = percTotal == 0 ? 1.0 : percNormal / percTotal;
          final s0 = (split - 0.02).clamp(0.0, 1.0);
          final s1 = (split + 0.02).clamp(0.0, 1.0);
          gradient = LinearGradient(
            colors: [normalA, normalB, agregA, agregB],
            stops: [0.0, s0, s1, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );
        }

        // ---------- UI -----------------------------------------------------
        final h = MediaQuery.of(context).size.height;
        final w = MediaQuery.of(context).size.width;
        final t = Theme.of(context);

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          child: Center(
            child: SizedBox(
              width: w,
              height: h * 0.21,
              child: Column(
                children: [
                  // cabeçalho
                  Container(
                    width: w * 0.99,
                    height: h * 0.0335,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.lightBlue, Color(0xFF004298)],
                        begin: Alignment.centerLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(5),
                          topRight: Radius.circular(5)),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB(255, 77, 138, 229),
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.only(left: 10),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Seu tempo de serviço - SIGRH',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // barra percentuada
                  Padding(
                    padding: const EdgeInsets.only(top: 11.0),
                    child: LinearPercentIndicator(
                      linearGradient: gradient,
                      barRadius: const Radius.circular(20),
                      animation: true,
                      lineHeight: 24,
                      animationDuration: 800,
                      percent: percTotal,
                      center: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 30),
                          Text(
                            '${_extensoDias(diasTotal)} de serviço',
                            style: t.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.surfing_sharp,
                              size: 22,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // legenda (vertical)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: diasAgregados == 0
                        ? Text(
                            '* Não possui tempo agregado no IPER.',
                            style: t.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          )
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _quad(normalB),
                                  const SizedBox(width: 4),
                                  Text('Tempo de serviço na PM: ',
                                      style: t.textTheme.bodySmall),
                                  Text(_extensoDias(diasNormal),
                                      style: t.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _quad(agregA),
                                  const SizedBox(width: 4),
                                  Text('Tempo agregado: ',
                                      style: t.textTheme.bodySmall),
                                  Text(_extensoDias(diasAgregados),
                                      style: t.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _quad(Color c) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
