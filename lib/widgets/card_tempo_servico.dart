import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:projetonovo/core/design/arte_cartao.dart';
import 'cartao_painel.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/inatividade_model.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

class CardTempoServico extends StatefulWidget {
  const CardTempoServico({Key? key, this.diasAgregadosTeste, this.cliente})
      : super(key: key);

  final int? diasAgregadosTeste;

  /// Cliente HTTP dos testes (respostas e falhas simuladas). Nulo = o padrão.
  final http.Client? cliente;

  @override
  State<CardTempoServico> createState() => _CardTempoServicoState();
}

/// Resultado da consulta ao IPER: os dias averbados ou o motivo da falha.
/// "Não tem averbado" (dias 0, sem código) é diferente de "não consegui
/// consultar" (código preenchido): o card nunca pode confundir os dois.
class _ConsultaIper {
  const _ConsultaIper.ok(this.dias) : codigo = null;
  const _ConsultaIper.falha(this.codigo) : dias = 0;

  final int dias;
  final String? codigo;
  bool get falhou => codigo != null;
}

class _CardTempoServicoState extends State<CardTempoServico> {
  // O card era StatelessWidget e montava a consulta dentro do build(). Como o
  // build observa o Auth (`Provider.of<Auth>(context)` sem listen: false),
  // qualquer notificação do Auth reconstruía o card e disparava uma requisição
  // HTTP nova ao listar_policial_iper.php — e o esqueleto de carregamento
  // voltava junto. Agora a consulta é guardada e só refeita se a matrícula
  // mudar, que é a única entrada dela.
  String? _matriculaConsultada;
  Future<_ConsultaIper>? _consulta;

  Future<_ConsultaIper> _futurePara(String matricula) {
    if (_matriculaConsultada != matricula || _consulta == null) {
      _matriculaConsultada = matricula;
      _consulta = _buscarDiasAgregados(matricula);
    }
    return _consulta!;
  }

  void _tentarDeNovo() => setState(() => _consulta = null);

  /// Consulta o tempo averbado. Toda falha volta com um código curto, que
  /// também vai para o log, em vez de virar "0 dias" (regra do CLAUDE.md:
  /// erro sempre explicado).
  Future<_ConsultaIper> _buscarDiasAgregados(String matricula) async {
    if (widget.diasAgregadosTeste != null) {
      return _ConsultaIper.ok(widget.diasAgregadosTeste!);
    }
    _ConsultaIper falha(String codigo, Object detalhe) {
      debugPrint('[IPER] $codigo matricula=$matricula: $detalhe');
      return _ConsultaIper.falha(codigo);
    }

    if (matricula.trim().isEmpty) return falha('TS-IPER-MATR', 'sessão sem matrícula');
    final uri = Uri.parse(
      'https://pmrr.online/flutter/sigrh/listar_policial_iper.php?matricula=$matricula',
    );
    final http.Response resp;
    try {
      resp = await (widget.cliente ?? http.Client())
          .get(uri)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (e) {
      return falha('TS-IPER-LENTO', e);
    } on SocketException catch (e) {
      return falha('TS-IPER-REDE', e);
    } on http.ClientException catch (e) {
      return falha('TS-IPER-REDE', e);
    } on HandshakeException catch (e) {
      return falha('TS-IPER-SSL', e);
    }
    if (resp.statusCode != 200) {
      return falha('TS-IPER-SRV-${resp.statusCode}', resp.body);
    }
    final Object? json;
    try {
      json = jsonDecode(resp.body);
    } on FormatException catch (e) {
      return falha('TS-IPER-RESP', e);
    }
    if (json is! Map) return falha('TS-IPER-RESP', resp.body);
    if (json['code'] != 1) {
      final msg = (json['message'] ?? '').toString();
      // A API responde code 0 também quando a matrícula não tem registro no
      // IPER: aí é "não tem averbado", não erro.
      if (msg.toLowerCase().contains('nenhum dado')) return const _ConsultaIper.ok(0);
      return falha('TS-IPER-API', msg);
    }
    final lista = json['result'];
    if (lista is! List) return falha('TS-IPER-RESP', resp.body);
    return _ConsultaIper.ok(lista.fold<int>(0, (p, e) {
      final raw = e is Map ? e['poip_total_dias'] : null;
      if (raw is int) return p + raw;
      if (raw is String) return p + (int.tryParse(raw) ?? 0);
      if (raw is num) return p + raw.toInt();
      return p;
    }));
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

    return FutureBuilder<_ConsultaIper>(
      future: _futurePara(matricula),
      builder: (context, snap) {
        final isLoading = snap.connectionState == ConnectionState.waiting;

        // Esqueleto só enquanto não há nem o tempo da PM para mostrar.
        if (isLoading && diasNormal == 0) {
          return CartaoArte(
            arte: Arte.de('ts'),
            padding: EdgeInsets.zero,
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

        final consulta = snap.data;
        final falhaIper = !isLoading && consulta != null && consulta.falhou;
        final diasAgregados = consulta?.dias ?? 0;
        final diasTotal = diasNormal + diasAgregados;
        const metaDias = 10950; // 30 anos
        final percTotal = (diasTotal / metaDias).clamp(0.0, 1.0);
        final percNormal = (diasNormal / metaDias).clamp(0.0, 1.0);

        final partes = _partes(diasTotal);
        final pct = (percTotal * 100).toStringAsFixed(1).replaceAll('.', ',');

        // Rodapé (protótipo): a incorporação e o IPER numa frase só.
        final inc = dataInc == null
            ? ''
            : 'Incorporação em ${dataInc.day.toString().padLeft(2, '0')}/'
                '${dataInc.month.toString().padLeft(2, '0')}/${dataInc.year} · ';
        final String origem;
        if (isLoading) {
          origem = '${inc}consultando IPER…';
        } else if (diasAgregados == 0) {
          origem = '${inc}sem tempo agregado do IPER';
        } else {
          origem = '${inc}IPER: ${_extensoDias(diasAgregados)}';
        }

        return CartaoArte(
          arte: Arte.de('ts'),
          padding: EdgeInsets.zero,
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.CALCULO_INATIVIDADE_PAGE),
          child: Stack(
            children: [
              Padding(
                padding: kPaddingCartao,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // O percentual no cabeçalho, como no protótipo.
                      CabecalhoCartao(
                        icone: Icons.military_tech_outlined,
                        titulo: 'Tempo de serviço',
                        mostrarSeta: false,
                        acao: Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DestaqueCartao(
                        valor: partes.heroi,
                        complemento: partes.resto,
                        tamanho: AppDisplaySize.heroi,
                      ),
                      const SizedBox(height: 12),

                      BarraProgressoCartao(
                        valor: percTotal,
                        valorBase: diasAgregados > 0 ? percNormal : null,
                        semantica: 'Tempo de serviço cumprido',
                      ),

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
                      if (falhaIper)
                        _FalhaIper(
                          codigo: consulta.codigo!,
                          aoTentarDeNovo: _tentarDeNovo,
                        )
                      else
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

/// Uma linha no lugar do rodapé quando o IPER não respondeu: diz que o
/// averbado ficou de fora e o código (que também foi para o log, com o
/// detalhe), com o botão de tentar de novo.
class _FalhaIper extends StatelessWidget {
  const _FalhaIper({required this.codigo, required this.aoTentarDeNovo});

  final String codigo;
  final VoidCallback aoTentarDeNovo;

  String get _motivo => switch (codigo) {
        'TS-IPER-REDE' => 'sem conexão',
        'TS-IPER-LENTO' => 'servidor lento',
        'TS-IPER-SSL' => 'conexão recusada',
        'TS-IPER-MATR' => 'saia e entre de novo',
        _ => 'erro no servidor',
      };

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(Icons.error_outline, size: AppIconSize.xs, color: cor),
        const SizedBox(width: 6),
        // Uma linha só: em tela estreita a frase encolhe em vez de quebrar
        // (o código partido em duas linhas ficava ilegível). O motivo vai
        // para o leitor de tela.
        Expanded(
          child: Semantics(
            label: 'Tempo averbado não consultado: $_motivo. Código $codigo',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Averbado indisponível · $codigo',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 12, color: cor),
              ),
            ),
          ),
        ),
        // Alvo de 44 pt, desenho pequeno (DESIGN §6).
        IconButton(
          onPressed: aoTentarDeNovo,
          tooltip: 'Tentar de novo',
          icon: Icon(Icons.refresh_rounded, size: AppIconSize.sm, color: cor),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
