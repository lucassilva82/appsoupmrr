import 'dart:convert';

import 'package:flutter/material.dart';
import 'cartao_painel.dart';
import 'vidro.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';

/// Um trecho de férias já resolvido em datas, para o card não ficar
/// remexendo em string crua no meio do layout.
class _Periodo {
  const _Periodo(this.rotulo, this.inicio, this.fim);

  final String rotulo;
  final DateTime? inicio;
  final DateTime? fim;

  bool get concluido =>
      fim != null && fim!.isBefore(DateTime.now());

  bool get emAndamento {
    final hoje = DateTime.now();
    if (inicio == null) return false;
    return !inicio!.isAfter(hoje) && (fim == null || !fim!.isBefore(hoje));
  }

  /// Quantos dias o período dura, com as duas pontas incluídas.
  int? get duracao {
    if (inicio == null || fim == null) return null;
    final d = fim!.difference(inicio!).inDays + 1;
    return d > 0 ? d : null;
  }

  /// Dias até começar, contando hoje como zero.
  int? get faltam {
    if (inicio == null) return null;
    final hoje = DateTime.now();
    final d = DateTime(inicio!.year, inicio!.month, inicio!.day)
        .difference(DateTime(hoje.year, hoje.month, hoje.day))
        .inDays;
    return d > 0 ? d : null;
  }
}

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

  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  /// "6 — 20 jul de 2026" quando cabe no mesmo mês, "21 dez — 4 jan" quando
  /// atravessa. O ano sai separado, na linha de apoio, porque repetir
  /// "2026" duas vezes na mesma frase é ruído.
  ({String intervalo, String? anos}) _formatar(DateTime? i, DateTime? f) {
    if (i == null && f == null) return (intervalo: '—', anos: null);
    if (i == null || f == null) {
      final d = (i ?? f)!;
      return (
        intervalo: '${d.day} ${_meses[d.month - 1]}',
        anos: '${d.year}',
      );
    }
    if (i.year == f.year && i.month == f.month) {
      return (
        intervalo: '${i.day} — ${f.day} ${_meses[i.month - 1]}',
        anos: '${i.year}',
      );
    }
    final intervalo =
        '${i.day} ${_meses[i.month - 1]} — ${f.day} ${_meses[f.month - 1]}';
    return (
      intervalo: intervalo,
      anos: i.year == f.year ? '${i.year}' : '${i.year} → ${f.year}',
    );
  }

  // ── Esqueleto ────────────────────────────────────────────────────────
  Widget _buildSkeleton(bool isDark) {
    final base =
        isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade200;
    blob({double w = double.infinity, double h = 12.0, double r = 6.0}) =>
        Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(r)),
        );
    return CartaoVidro(
      raio: 16,
      child: Padding(
        padding: kPaddingCartao,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              blob(w: 160, h: 18),
              const SizedBox(height: 8),
              blob(w: 120, h: 11),
              blob(w: 210, h: 25, r: 10),
              const SizedBox(height: 6),
              blob(w: 180, h: 32, r: 20),
            ]),
      ),
    );
  }

  // ── Linha de um período secundário ───────────────────────────────────
  // Uma linha só: rótulo à esquerda, datas à direita. Antes eram duas
  // linhas mais um círculo de 24px para dizer "1ª parcela, concluída".
  Widget _linhaPeriodo(BuildContext context, _Periodo p) {
    final d = _formatar(p.inicio, p.fim);
    final sufixo = d.anos == null ? '' : ' de ${d.anos}';

    return Row(
      children: [
        MarcadorCartao(concluido: p.concluido),
        const SizedBox(width: 10),
        Text(
          p.rotulo,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: p.concluido ? 0.72 : 0.92),
          ),
        ),
        const Spacer(),
        Text('${d.intervalo}$sufixo',
            style: TextStyle(fontSize: 12.5, color: TomCartao.medio(context))),
      ],
    );
  }

  // ── Card vazio ───────────────────────────────────────────────────────
  Widget _buildVazio(BuildContext context) {
    return CartaoVidro(
      raio: 16,
      onTap: () =>
          Navigator.of(context).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
      child: Padding(
        padding: kPaddingCartao,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CabecalhoCartao(
              icone: Icons.beach_access_outlined,
              titulo: 'Plano de férias',
            ),
            const SizedBox(height: 14),
            Text(
              'Nenhum plano cadastrado para este ano.',
              style: TextStyle(fontSize: 15, color: TomCartao.medio(context)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _futurePlan,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(isDark);
        }

        final r = snap.data;
        if (r == null) return _buildVazio(context);

        final ano = (r['ano_base_nome'] ?? r['ano'] ?? r['year'])?.toString() ??
            '${DateTime.now().year}';
        final integral = _isIntegral(r);

        DateTime? dt(dynamic v) => _tryParse(_fmtDate(v));

        final periodos = <_Periodo>[];
        if (integral) {
          final i = dt(r['prev_feri_inicio']);
          final f = dt(r['prev_feri_final']);
          if (i != null || f != null) {
            periodos.add(_Periodo('Período integral', i, f));
          }
        } else {
          const rotulos = ['1ª parcela', '2ª parcela', '3ª parcela'];
          const chaves = [
            ['1p_inicio', '1p_fim'],
            ['2p_inicio', '2p_fim'],
            ['3p_inicio', '3p_fim'],
          ];
          for (var n = 0; n < chaves.length; n++) {
            final i = dt(r[chaves[n][0]]);
            final f = dt(r[chaves[n][1]]);
            if (i != null || f != null) {
              periodos.add(_Periodo(rotulos[n], i, f));
            }
          }
        }

        if (periodos.isEmpty) return _buildVazio(context);

        periodos.sort((a, b) => (a.inicio ?? DateTime(2100))
            .compareTo(b.inicio ?? DateTime(2100)));

        // O período em destaque é o que ainda vai acontecer — ou o que está
        // acontecendo. Com tudo no passado, destaca-se o último, já concluído.
        final destaque = periodos.firstWhere(
          (p) => !p.concluido,
          orElse: () => periodos.last,
        );
        final outros = periodos.where((p) => p != destaque).toList();

        final d = _formatar(destaque.inicio, destaque.fim);
        final faltam = destaque.faltam;

        // "2ª de 2 parcelas" responde o que "2ª parcela" sozinho deixava no
        // ar: quantas são, e em qual delas o militar está.
        final posicao = periodos.indexOf(destaque) + 1;
        final rotuloDestaque = integral
            ? 'Período integral'
            : '${posicao}ª de ${periodos.length} '
                '${periodos.length == 1 ? 'parcela' : 'parcelas'}';

        // A pílula azul virou frase. Ela ocupava uma faixa inteira do card
        // para dizer uma coisa que cabe numa linha de texto — e frase diz
        // mais: quando começa e quanto dura.
        final String quando;
        if (destaque.concluido) {
          quando = 'Período concluído';
        } else if (destaque.emAndamento) {
          quando = 'Em andamento agora';
        } else if (faltam == null) {
          quando = 'A começar';
        } else if (faltam == 1) {
          quando = 'Começam amanhã';
        } else {
          quando = 'Começam em $faltam dias';
        }

        final duracao = destaque.duracao;

        // 13º antecipado
        final prevAntRaw =
            (r['prev_feri_antecipado'] ?? r['prev_feri_antecipado_format'] ?? '')
                .toString();
        String? antecipado;
        if (prevAntRaw.isNotEmpty) {
          final v = prevAntRaw.toLowerCase();
          antecipado = v == 'a'
              ? '13º pago no aniversário'
              : v == 'b'
                  ? '13º pago parcelado'
                  : prevAntRaw;
        }

        return CartaoVidro(
          raio: 16,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
          child: Stack(
            children: [
              // Marca d'água: dá profundidade ao bloco do destaque sem
              // disputar leitura. Fora da árvore semântica, é decoração.
              Positioned(
                top: 38,
                right: -10,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.calendar_month_outlined,
                    size: 92,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: kPaddingCartao,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CabecalhoCartao(
                      icone: Icons.beach_access_outlined,
                      titulo: 'Plano de férias',
                      // O ano-base é o que diz se estas são as férias do ano
                      // corrente ou um período atrasado sendo gozado agora —
                      // a data sozinha não conta isso.
                      meta: 'Ref. $ano',
                    ),
                    const SizedBox(height: 12),

                    DestaqueCartao(
                      rotulo: rotuloDestaque,
                      valor: d.intervalo,
                      tamanho: AppDisplaySize.heroiMenor,
                    ),

                    const SizedBox(height: 8),

                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: quando,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (duracao != null)
                          TextSpan(
                            text: '  ·  $duracao '
                                '${duracao == 1 ? 'dia' : 'dias'} de férias',
                            style: TextStyle(color: TomCartao.medio(context)),
                          ),
                      ]),
                      style: const TextStyle(fontSize: 13.5),
                    ),

                    for (final p in outros) ...[
                      const DivisorCartao(espaco: 12),
                      _linhaPeriodo(context, p),
                    ],

                    const DivisorCartao(espaco: 12),
                    RodapeCartao(
                      icone: antecipado == null
                          ? null
                          : Icons.info_outline_rounded,
                      texto: antecipado,
                      acaoTexto: 'Ver detalhes',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
