import 'dart:convert';

import 'package:flutter/material.dart';
import 'cartao_painel.dart';
import 'marca_dagua_cartao.dart';
import 'vidro.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/inatividade_model.dart';
import '../utils/app_routes.dart';

class CardTempoServico extends StatelessWidget {
  const CardTempoServico({Key? key, this.diasAgregadosTeste}) : super(key: key);

  final int? diasAgregadosTeste;

  Future<int> _buscarDiasAgregados(String matricula) async {
    if (diasAgregadosTeste != null) return diasAgregadosTeste!;
    final uri = Uri.parse(
      'https://pmrr.online/flutter/sigrh/listar_policial_iper.php?matricula=$matricula',
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

  /// Quebra o tempo em "a maior unidade" e "o resto", que é o que dá a
  /// hierarquia do card: "5 anos" grande, "6 meses e 26 dias" logo abaixo.
  ({String heroi, String? resto}) _partes(int totalDias) {
    const diasAno = 365, diasMes = 30;
    final anos = totalDias ~/ diasAno;
    final meses = (totalDias % diasAno) ~/ diasMes;
    final dias = (totalDias % diasAno) % diasMes;

    String plural(int n, String um, String varios) =>
        '$n ${n == 1 ? um : varios}';

    if (anos > 0) {
      final resto = <String>[
        if (meses > 0) plural(meses, 'mês', 'meses'),
        if (dias > 0) plural(dias, 'dia', 'dias'),
      ];
      return (
        heroi: plural(anos, 'ano', 'anos'),
        resto: resto.isEmpty ? null : resto.join(' e '),
      );
    }
    if (meses > 0) {
      return (
        heroi: plural(meses, 'mês', 'meses'),
        resto: dias > 0 ? plural(dias, 'dia', 'dias') : null,
      );
    }
    return (heroi: plural(dias, 'dia', 'dias'), resto: null);
  }

  String _mesAbrev(int mes) {
    const m = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return m[mes - 1];
  }

  Widget _blob(
          {double w = double.infinity,
          double h = 12,
          double r = 6,
          required bool isDark}) =>
      Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final matricula = auth.matricula ?? '';
    final dataInc = _parseDataIncorporacao(auth.dataIncorporacao);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int diasNormal = 0;
    if (dataInc != null) diasNormal = DateTime.now().difference(dataInc).inDays;

    return FutureBuilder<int>(
      future: _buscarDiasAgregados(matricula),
      builder: (context, snap) {
        final isLoading = snap.connectionState == ConnectionState.waiting;

        // Esqueleto só enquanto não há nem o tempo da PM para mostrar.
        if (isLoading && diasNormal == 0) {
          return CartaoVidro(
            raio: 16,
            child: Padding(
              padding: kPaddingCartao,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _blob(w: 160, h: 16, isDark: isDark),
                    const SizedBox(height: 8),
                    _blob(w: 150, h: 28, r: 10, isDark: isDark),
                    _blob(w: 190, h: 17, r: 8, isDark: isDark),
                    const SizedBox(height: 6),
                    _blob(h: 6, r: 3, isDark: isDark),
                    _blob(w: 230, h: 13, isDark: isDark),
                  ]),
            ),
          );
        }

        final diasAgregados = snap.data ?? 0;
        final diasTotal = diasNormal + diasAgregados;
        const metaDias = 10950; // 30 anos
        final percTotal = (diasTotal / metaDias).clamp(0.0, 1.0);
        final percNormal = (diasNormal / metaDias).clamp(0.0, 1.0);

        final partes = _partes(diasTotal);
        final pct = (percTotal * 100).toStringAsFixed(1).replaceAll('.', ',');

        // Projeção dos 30 anos.
        String? previsao;
        String? faltam;
        if (dataInc != null) {
          final meta = DateTime(dataInc.year + 30, dataInc.month, dataInc.day);
          previsao = '${_mesAbrev(meta.month)}/${meta.year}';
          final diff = meta.difference(DateTime.now()).inDays;
          if (diff > 0) {
            final anosR = diff ~/ 365;
            faltam = anosR > 0
                ? 'faltam $anosR ${anosR == 1 ? "ano" : "anos"}'
                : 'faltam $diff dias';
          } else {
            faltam = 'meta atingida';
          }
        }

        // O rodapé é onde o IPER aparece. A legenda de quadradinhos coloridos
        // que havia aqui gastava uma linha inteira para dizer o que cabe numa
        // frase — e o segundo trecho da barra já mostra a proporção.
        final String origem;
        if (isLoading) {
          origem = 'Fonte: SIGRH  •  consultando IPER…';
        } else if (diasAgregados == 0) {
          origem = 'Fonte: SIGRH  •  sem tempo agregado do IPER';
        } else {
          origem = 'Fonte: SIGRH  •  IPER: ${_extensoDias(diasAgregados)}';
        }

        return CartaoVidro(
          raio: 16,
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.CALCULO_INATIVIDADE_PAGE),
          child: Stack(
            children: [
              // O arco da medalha é o mesmo percentual da barra — por isso
              // ele recebe percTotal em vez de um valor bonito fixo.
              Positioned(
                top: 58,
                right: -34,
                child: MarcaDaguaCartao(
                  desenho: DesenhoMarca.medalha,
                  progresso: percTotal,
                ),
              ),
              Padding(
                padding: kPaddingCartao,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CabecalhoCartao(
                        icone: Icons.military_tech_outlined,
                        titulo: 'Tempo de serviço',
                      ),
                      const SizedBox(height: 10),

                      // O percentual ao lado do número, não numa legenda embaixo
                      // da barra: é a mesma informação e economiza uma linha.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DestaqueCartao(
                              valor: partes.heroi,
                              complemento: partes.resto,
                              tamanho: AppDisplaySize.heroi,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '$pct%',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      BarraProgressoCartao(
                        valor: percTotal,
                        valorBase: diasAgregados > 0 ? percNormal : null,
                        semantica: 'Tempo de serviço cumprido',
                      ),

                      // Meta, data e quanto falta numa frase só. Eram três
                      // blocos — par rótulo/valor, pílula e divisor — para
                      // dizer o que cabe aqui.
                      if (previsao != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Meta de 30 anos em $previsao'
                          '${faltam == null ? '' : ' · $faltam'}',
                          style: TextStyle(
                              fontSize: 13, color: TomCartao.medio(context)),
                        ),
                      ],

                      // Explica a parcela de dias quando ela passa de 29.
                      // Mesma nota do cálculo de inatividade, pela mesma
                      // razão: ali o número parece errado e não está.
                      if (TempoFmt.notaResto(diasTotal) != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          TempoFmt.notaResto(diasTotal)!,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: TomCartao.medio(context)),
                        ),
                      ],

                      const SizedBox(height: 6),
                      RodapeCartao(texto: origem),
                    ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
