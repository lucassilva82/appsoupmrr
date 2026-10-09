// lib/pages/detalhes_mapa_forca_comando_page.dart
//
//  DetalhesMapaForcaComandoPage
//    • Cabeçalho dos filtros aplicados
//    • Campo de busca por nome (tempo-real, Material 3)
//    • Unidade  → Subunidade → Situação Funcional → Tipos → Militares
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/map_busca_detalhes_model.dart';
import '../pages/militar_detalhe_full_page.dart';
import '../widgets/custom_appbar.dart';

class DetalhesMapaForcaComandoPage extends StatefulWidget {
  final MapBuscaDetalhesModel dadosBusca;
  const DetalhesMapaForcaComandoPage({super.key, required this.dadosBusca});

  @override
  State<DetalhesMapaForcaComandoPage> createState() =>
      _DetalhesMapaForcaComandoPageState();
}

class _DetalhesMapaForcaComandoPageState
    extends State<DetalhesMapaForcaComandoPage> {
  late Future<Map<String, Map<String, List<MilitarDetalheModel>>>> _future;
  final TextEditingController _searchCtrl = TextEditingController();

  // ---------- Paleta ----------
  // Antes era azul sólido com texto branco por cima. Agora as superfícies são
  // tingidas e translúcidas, e quem escreve é a cor do tema — o mesmo padrão
  // das demais telas (ver DESIGN.md).
  Color get _primaria => Theme.of(context).colorScheme.primary;
  bool get _escuro => Theme.of(context).brightness == Brightness.dark;

  // Dois tons, não cinco. O nível 1 (unidade) é tingido; do nível 2 para
  // baixo não há superfície nova — a hierarquia é indentação e peso de texto.
  // Cada nível com um cinza ligeiramente diferente deixava a tela com meia
  // dúzia de pretos encavalados.
  Color get _fundoNivel1 => _primaria.withValues(alpha: _escuro ? 0.14 : 0.10);
  Color get _fundoNivel2 => Colors.transparent;
  Gradient get _grad => LinearGradient(
        colors: [
          _primaria.withValues(alpha: _escuro ? 0.22 : 0.14),
          _primaria.withValues(alpha: _escuro ? 0.10 : 0.07),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ---------------- API + AGRUPAMENTO ---------------- */
  Future<Map<String, Map<String, List<MilitarDetalheModel>>>> _fetch() async {
    final idCmd =
        widget.dadosBusca.idSituacao; // id_comando (ajuste se necessário)
    final buf = StringBuffer(
        'https://pmrr.online/flutter/sigrh/mapadaforca/listacomando_detalhes.php?id_comando=$idCmd');

    final siglas = widget.dadosBusca.postoGraduacao;
    if (siglas.isNotEmpty &&
        !(siglas.length == 1 && siglas.first.toUpperCase() == 'TODOS')) {
      buf.write(
          siglas.map((p) => '&posto[]=${Uri.encodeQueryComponent(p)}').join());
    }

    // debug: URL que será chamada
    debugPrint('API URL: ${buf.toString()}');

    final resp = await http.get(Uri.parse(buf.toString()));

    // debug: resposta bruta (use debugPrint para não truncar em release)
    debugPrint('API status: ${resp.statusCode}');
    debugPrint(
        'API body (preview): ${resp.body.length > 2000 ? resp.body.substring(0, 2000) + "..." : resp.body}');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['code'] == 0) return {};

    // debug: checar se o campo id_situacao e tipo_situ_func_descricao existem
    if (data['result'] is List && (data['result'] as List).isNotEmpty) {
      final sample = (data['result'] as List).first as Map<String, dynamic>;
      debugPrint('sample keys: ${sample.keys.toList()}');
      debugPrint('sample id_situacao: ${sample['id_situacao']}');
      debugPrint(
          'sample tipo_situ_func_descricao: ${sample['tipo_situ_func_descricao'] ?? sample['descricao_situacao']}');
      final ids = (data['result'] as List)
          .map((e) => (e as Map<String, dynamic>)['id_situacao'])
          .toSet()
          .where((v) => v != null)
          .toList();
      debugPrint('distinct id_situacao found: $ids');
    } else {
      debugPrint('result vazio ou não é lista');
    }

    final lista = (data['result'] as List)
        .map((e) => MilitarDetalheModel.fromJson(e))
        .toList();

    // Agrupa: Unidade → Subunidade → lista de militares
    final Map<String, Map<String, List<MilitarDetalheModel>>> mapa = {};
    for (final m in lista) {
      mapa.putIfAbsent(m.unidade, () => {});
      mapa[m.unidade]!.putIfAbsent(m.subunidade, () => []);
      mapa[m.unidade]![m.subunidade]!.add(m);
    }

    // debug: contagem final
    debugPrint('militares carregados: ${lista.length}');
    return mapa;
  }

  /* ---------- Normalização p/ busca (mesma lógica da outra página) ---------- */
  final Map<int, String> _accentMap = const {
    225: 'a',
    224: 'a',
    226: 'a',
    227: 'a',
    228: 'a',
    229: 'a',
    231: 'c',
    233: 'e',
    232: 'e',
    234: 'e',
    235: 'e',
    237: 'i',
    236: 'i',
    238: 'i',
    239: 'i',
    241: 'n',
    243: 'o',
    242: 'o',
    244: 'o',
    245: 'o',
    246: 'o',
    250: 'u',
    249: 'u',
    251: 'u',
    252: 'u',
  };

  String _normalize(String s) {
    final sb = StringBuffer();
    for (final cu in s.toLowerCase().codeUnits) {
      sb.write(_accentMap[cu] ?? String.fromCharCode(cu));
    }
    return sb.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }

  /* ---------------- FILTRO LOCAL ---------------- */
  Map<String, Map<String, List<MilitarDetalheModel>>> _filtrar(
      Map<String, Map<String, List<MilitarDetalheModel>>> base) {
    final q = _normalize(_searchCtrl.text.trim());
    if (q.isEmpty) return base;

    final terms = q.split(RegExp(r' +'))..removeWhere((e) => e.isEmpty);

    final Map<String, Map<String, List<MilitarDetalheModel>>> filtrado = {};
    base.forEach((unid, submap) {
      final Map<String, List<MilitarDetalheModel>> subFiltrado = {};
      submap.forEach((sub, lista) {
        final l = lista.where((m) {
          final nomeNorm = _normalize(m.nome);
          return terms.every((t) => nomeNorm.contains(t));
        }).toList();
        if (l.isNotEmpty) subFiltrado[sub] = l;
      });
      if (subFiltrado.isNotEmpty) filtrado[unid] = subFiltrado;
    });
    return filtrado;
  }

  /* ---------------- CARTÃO DE MILITAR ---------------- */
  Widget _militarCard(MilitarDetalheModel m) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: _primaria.withValues(alpha: 0.12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MilitarDetalheFullPage(
                  matricula: m.matricula,
                  preloadedImageUrl: _resolveImgUrl(m.imagemUrl)))),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: _resolveImgUrl(m.imagemUrl) ?? '',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  cacheManager: DefaultCacheManager(),
                  placeholder: (_, __) => Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                    child: Icon(Icons.person,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35),
                        size: 38),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(m.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Posto/Graduação: ${m.postoGraduacao}',
                        style: const TextStyle(fontSize: 12)),
                    // nova linha: Situação
                    if (m.situacaoDescricao != null &&
                        m.situacaoDescricao!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Situação: ${m.situacaoDescricao!}',
                          style: m.situacaoDescricao!.startsWith("PRONTO")
                              ? TextStyle(fontSize: 11, color: Colors.black54)
                              : TextStyle(fontSize: 11, color: Colors.red),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
            ]),
          ),
        ),
      );

  /* ---------------- URL resolver de imagem ---------------- */
  String? _resolveImgUrl(String? raw) {
    final v = (raw ?? '').trim().replaceAll('pmrr.net', 'pmrr.online');
    if (v.isEmpty || v.toLowerCase() == 'null') return null;
    if (v.endsWith('/pix_db/') || v.endsWith('/pix_db')) return null;
    if (v.startsWith('https://')) return v;
    if (v.startsWith('http://')) return 'https://${v.substring(7)}';
    if (v.startsWith('//')) return 'https:$v';
    if (v.startsWith('/')) return 'https://rh.pmrr.online$v';
    if (v.contains('.') && v.contains('/')) return 'https://$v';
    return 'https://rh.pmrr.online/$v';
  }

  /* ---------------- HEADER DE FILTROS ---------------- */
  Widget _filtroHeader() {
    final postos = widget.dadosBusca.postoGraduacao;
    final postosStr = (postos.isEmpty ||
            (postos.length == 1 && postos.first.toUpperCase() == 'TODOS'))
        ? 'Todos'
        : postos.join(', ');
    final comando = widget.dadosBusca.descricao;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: _grad,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_rounded, color: _primaria, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comando,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Filtro: $postosStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.62),
                          fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------- BUILD ---------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: widget.dadosBusca.descricao),
      body: Column(
        children: [
          _filtroHeader(),

          // ---------- CAMPO DE BUSCA ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  hintText: 'Pesquisar por nome...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<
                Map<String, Map<String, List<MilitarDetalheModel>>>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }

                final baseMapa = snap.data ?? {};
                final mapa = _filtrar(baseMapa);

                if (mapa.isEmpty) {
                  return const Center(child: Text('Nenhum resultado.'));
                }

                // agora: adiciona um Expansion "Situação Funcional" para toda a unidade mãe (comando)
                final allMilitares = mapa.values
                    .expand((subMap) => subMap.values)
                    .expand((list) => list)
                    .toList();

                // usa o mesmo padrão de cores do restante (combina com o azul principal)
                final topSituacaoTile = _SituacaoTile(
                  key: const ValueKey('situacao_comando_todo'),
                  militares: allMilitares,
                  start: _fundoNivel1,
                  mid: _fundoNivel2,
                );

                return ListView(
                  key: ValueKey(_searchCtrl.text),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    // Situação do comando inteiro (unidade mãe)
                    if (allMilitares.isNotEmpty) topSituacaoTile,
                    // lista de unidades (ex.: BOPE, GIRO, ...)
                    ...mapa.entries.map((unid) {
                      final totalUnid = unid.value.values
                          .fold<int>(0, (s, l) => s + l.length);

                      // criar tile de situação para a unidade inteira (todos militares da unidade)
                      final unidadeMilitares =
                          unid.value.values.expand((l) => l).toList();
                      final unidadeSituacaoTile = _SituacaoTile(
                        key: ValueKey('situacao_unidade_${unid.key}'),
                        militares: unidadeMilitares,
                        start: _fundoNivel1,
                        mid: _fundoNivel2,
                      );

                      // construir lista de subunidades (cada uma é um _GradientTile)
                      final subTiles = unid.value.entries.map((sub) {
                        final totalSub = sub.value.length;

                        // agrupa militares por id_posto dentro da subunidade
                        final Map<int, List<MilitarDetalheModel>> gruposPosto =
                            {};
                        for (final m in sub.value) {
                          gruposPosto.putIfAbsent(m.idPosto, () => []);
                          gruposPosto[m.idPosto]!.add(m);
                        }
                        final sortedIds = gruposPosto.keys.toList()..sort();

                        final List<Widget> children = [];
                        for (final pid in sortedIds) {
                          final grupo = gruposPosto[pid]!;
                          children.add(_PostoHeader(
                              sigla: grupo.first.postoGraduacao,
                              qtd: grupo.length,
                              grad: _grad));
                          children.addAll(grupo.map(_militarCard));
                        }

                        // inserir Situação Funcional dentro da subunidade (antes dos postos)
                        final situacaoTile = _SituacaoTile(
                          key: ValueKey('situacao_${unid.key}_${sub.key}'),
                          militares: sub.value,
                          start: _fundoNivel1,
                          mid: _fundoNivel2,
                        );

                        return _GradientTile(
                          title: sub.key,
                          total: totalSub,
                          leadingIcon: Icons.account_tree_outlined,
                          isSubLevel: true,
                          primaryStart: _fundoNivel1,
                          primaryMid: _fundoNivel2,
                          grad: _grad,
                          referenceTotal: totalUnid,
                          childTiles: [
                            situacaoTile,
                            ...children,
                          ],
                        );
                      }).toList();

                      // unidade principal: inclui Situacao (unidade) + subunidades
                      final List<Widget> unitChilds = [
                        unidadeSituacaoTile,
                        ...subTiles,
                      ];

                      return _GradientTile(
                        title: unid.key,
                        total: totalUnid,
                        leadingIcon: Icons.domain,
                        isSubLevel: false,
                        primaryStart: _fundoNivel1,
                        primaryMid: _fundoNivel2,
                        grad: _grad,
                        referenceTotal: allMilitares.length,
                        childTiles: unitChilds,
                      );
                    }).toList()
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================================
   EXPANSION TILE COM GRADIENTE E CONTADOR
   ==========================================================================*/
class _GradientTile extends StatelessWidget {
  final String title;
  final int total;
  final IconData leadingIcon;
  final bool isSubLevel;
  final Color primaryStart;
  final Color primaryMid;
  final Gradient grad;
  final int? referenceTotal;
  final List<Widget> childTiles;

  const _GradientTile({
    required this.title,
    required this.total,
    required this.leadingIcon,
    required this.isSubLevel,
    required this.primaryStart,
    required this.primaryMid,
    required this.grad,
    this.referenceTotal,
    required this.childTiles,
  });

  Widget _badge(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Text('$total',
          style: TextStyle(
              color: cor, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aoFundo = tema.colorScheme.onSurface;
    final primaria = tema.colorScheme.primary;
    // primaryStart/primaryMid já chegam translúcidos. Aberto, o fundo some:
    // como os tiles são aninhados, pintar cada nível empilhava translucidez
    // até virar um bloco azul chapado. Fechado é tingido, aberto é o fundo
    // da tela com os filhos por cima.
    final bgCollapsed = isSubLevel ? primaryMid : primaryStart;
    const bgExpanded = Colors.transparent;
    final rawPct = referenceTotal == null || referenceTotal == 0
        ? 0.0
        : total / referenceTotal!;
    final pct = rawPct.clamp(0.0, 1.0);
    final visualPct = total > 0 && pct < 0.05 ? 0.05 : pct;
    final pctText = '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';

    // Nível 1 é a única caixa; do nível 2 para baixo a hierarquia é
    // indentação. A guia à esquerda é desenhada uma vez para o bloco inteiro
    // de filhos (abaixo), não uma por filho — senão vira linha tracejada.
    return Container(
      margin: EdgeInsets.fromLTRB(isSubLevel ? 0 : 8, isSubLevel ? 0 : 4,
          isSubLevel ? 0 : 8, isSubLevel ? 0 : 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSubLevel ? 0 : 14),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          collapsedBackgroundColor: bgCollapsed,
          backgroundColor: bgExpanded,
          leading: Icon(leadingIcon,
              color: primaria, size: isSubLevel ? 18 : 22),
          iconColor: aoFundo.withValues(alpha: 0.65),
          collapsedIconColor: aoFundo.withValues(alpha: 0.65),
          title: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: aoFundo,
                        fontSize: isSubLevel ? 13 : 14,
                        fontWeight:
                            isSubLevel ? FontWeight.w500 : FontWeight.bold)),
              ),
              if (referenceTotal != null) ...[
                Text(
                  pctText,
                  style: TextStyle(
                    color: aoFundo.withValues(alpha: 0.70),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: isSubLevel ? 52 : 64,
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: primaria.withValues(alpha: 0.35), width: .8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                              color: aoFundo.withValues(alpha: 0.08)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: visualPct,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaria.withValues(alpha: 0.75),
                                      primaria,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _badge(context)
            ],
          ),
          childrenPadding: EdgeInsets.zero,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 18, top: 2, bottom: 6),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: primaria.withValues(alpha: 0.22),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: childTiles,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================================
   HEADER DO POSTO / GRADUAÇÃO (mini-card)
   ==========================================================================*/
class _PostoHeader extends StatelessWidget {
  final String sigla;
  final int qtd;
  final Gradient grad;
  const _PostoHeader(
      {required this.sigla, required this.qtd, required this.grad});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          gradient: grad, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.military_tech,
              color: tema.colorScheme.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text('$sigla : $qtd militares',
                  style: TextStyle(
                      color: tema.colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)))
        ],
      ),
    );
  }
}

/* ============================================================================
   TILE DE SITUAÇÃO FUNCIONAL (bordas discretas/invisíveis, radius alinhado)
   ==========================================================================*/
class _SituacaoTile extends StatelessWidget {
  final List<MilitarDetalheModel> militares;
  final Color start;
  final Color mid;

  const _SituacaoTile({
    Key? key,
    required this.militares,
    required this.start,
    required this.mid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.72);
    final onCard = theme.colorScheme.onSurface;
    final subtleBorder = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    // O fator 0.82 multiplicava tudo e gerava tamanhos como 10,66 e 9,43 —
    // exatamente o que a skill chama de valor arbitrário. Agora são números
    // da escala do app.
    const double scale = 1.0;

    final Map<String, List<MilitarDetalheModel>> porSituacao = {};
    for (final m in militares) {
      final s = (m.situacaoDescricao ?? '').trim();
      final key = s.isEmpty ? 'Sem Situação' : s;
      porSituacao.putIfAbsent(key, () => []);
      porSituacao[key]!.add(m);
    }

    final situacoes = porSituacao.keys.toList()..sort();
    // Selo tingido com a primária; o número usa a própria primária.
    final LinearGradient pillGrad = LinearGradient(colors: [
      primaria.withValues(alpha: isDark ? 0.22 : 0.16),
      primaria.withValues(alpha: isDark ? 0.14 : 0.10),
    ]);

    const double rootTitleSize = 12;
    const double rootBadgeSize = 10;
    const double itemTitleSize = 12;
    const double itemBadgeSize = 10;
    const double listNameSize = 12;
    const double listSubSize = 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: subtleBorder, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            key: PageStorageKey('situacao_root_${militares.hashCode}'),
            tilePadding: EdgeInsets.symmetric(
                horizontal: 10.0 * scale, vertical: 4.0 * scale),
            collapsedBackgroundColor: cardBg,
            backgroundColor: cardBg,
            leading: Icon(Icons.flag_outlined,
                color: onCard.withOpacity(0.7), size: 16.0 * scale),
            iconColor: onCard.withOpacity(0.6),
            collapsedIconColor: onCard.withOpacity(0.6),
            title: Row(
              children: [
                Expanded(
                  child: Text('Situação Funcional',
                      style: TextStyle(
                          color: onCard,
                          fontWeight: FontWeight.w700,
                          fontSize: rootTitleSize)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 7.0 * scale, vertical: 3.0 * scale),
                  decoration: BoxDecoration(
                      gradient: pillGrad,
                      borderRadius: BorderRadius.circular(20.0 * scale)),
                  child: Text('${militares.length}',
                      style: TextStyle(
                          color: primaria,
                          fontSize: rootBadgeSize,
                          fontWeight: FontWeight.w700)),
                )
              ],
            ),
            childrenPadding:
                EdgeInsets.only(bottom: 5.0 * scale, top: 2.0 * scale),
            children: situacoes.map((sit) {
              final lista = porSituacao[sit]!;
              final rawPct =
                  militares.isEmpty ? 0.0 : lista.length / militares.length;
              final pct = rawPct.clamp(0.0, 1.0);
              final visualPct = lista.isNotEmpty && pct < 0.05 ? 0.05 : pct;
              final pctText =
                  '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 1),
                child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      key: PageStorageKey(
                          'situacao_item_${militares.hashCode}_$sit'),
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.symmetric(
                          horizontal: 8.0 * scale, vertical: 3.0 * scale),
                      collapsedBackgroundColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      leading: Icon(Icons.work_outline,
                          color: onCard.withOpacity(0.6), size: 13.0 * scale),
                      iconColor: onCard.withOpacity(0.6),
                      collapsedIconColor: onCard.withOpacity(0.6),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(sit,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: onCard,
                                    fontSize: itemTitleSize,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            pctText,
                            style: TextStyle(
                              color: onCard.withOpacity(0.65),
                              fontSize: 9.0 * scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 5.0 * scale),
                          SizedBox(
                            width: 50.0 * scale,
                            height: 5.0 * scale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.2)
                                      : const Color(0xFF1976D2)
                                          .withOpacity(0.3),
                                  width: .7,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: const Color(0xFF1976D2)
                                          .withOpacity(isDark ? 0.12 : 0.08),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: visualPct,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF64B5F6),
                                                Color(0xFF1976D2),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 5.0 * scale),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.0 * scale, vertical: 2.0 * scale),
                            decoration: BoxDecoration(
                                gradient: pillGrad,
                                borderRadius:
                                    BorderRadius.circular(20.0 * scale)),
                            child: Text('${lista.length}',
                                style: TextStyle(
                                    color: primaria,
                                    fontSize: itemBadgeSize,
                                    fontWeight: FontWeight.w700)),
                          )
                        ],
                      ),
                      childrenPadding:
                          const EdgeInsets.only(bottom: 4, top: 2),
                      children: lista
                          .map((m) => _situacaoListItem(context, m, pillGrad,
                              listNameSize, listSubSize, scale, isDark, onCard))
                          .toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _situacaoListItem(
      BuildContext context,
      MilitarDetalheModel m,
      LinearGradient pillGrad,
      double nameSize,
      double subSize,
      double scale,
      bool isDark,
      Color onCard) {
    final nameStyle = TextStyle(
        fontSize: nameSize, fontWeight: FontWeight.w600, color: onCard);
    final subStyle = TextStyle(
        fontSize: subSize, color: onCard.withOpacity(0.55), height: 1.05);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80);
    // Mesmo tom do cartão de situação: um só preto na tela toda.
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.72);

    String? resolveUrl(String? raw) {
      final v = (raw ?? '').trim().replaceAll('pmrr.net', 'pmrr.online');
      if (v.isEmpty || v.toLowerCase() == 'null') return null;
      if (v.endsWith('/pix_db/') || v.endsWith('/pix_db')) return null;
      if (v.startsWith('https://')) return v;
      if (v.startsWith('http://')) return 'https://${v.substring(7)}';
      if (v.startsWith('//')) return 'https:$v';
      if (v.startsWith('/')) return 'https://rh.pmrr.online$v';
      if (v.contains('.') && v.contains('/')) return 'https://$v';
      return 'https://rh.pmrr.online/$v';
    }

    final resolvedUrl = resolveUrl(m.imagemUrl);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MilitarDetalheFullPage(
                matricula: m.matricula,
                preloadedImageUrl: resolveUrl(m.imagemUrl))));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0 * scale),
              child: resolvedUrl != null
                  ? CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      width: 40.0 * scale,
                      height: 40.0 * scale,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      cacheManager: DefaultCacheManager(),
                      placeholder: (_, __) => Container(
                        width: 40.0 * scale,
                        height: 40.0 * scale,
                        color: Colors.white.withValues(alpha: 0.06),
                        child: const Center(
                            child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5))),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 40.0 * scale,
                        height: 40.0 * scale,
                        color: Colors.white.withValues(alpha: 0.06),
                        child: Icon(Icons.person,
                            color: onCard.withValues(alpha: 0.35), size: 16),
                      ),
                    )
                  : Container(
                      width: 40.0 * scale,
                      height: 40.0 * scale,
                      decoration: BoxDecoration(
                        color: onCard.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6.0 * scale),
                      ),
                      child: Icon(Icons.person,
                          color: onCard.withValues(alpha: 0.35), size: 16),
                    ),
            ),
            SizedBox(width: 8.0 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle),
                  SizedBox(height: 3.0 * scale),
                  Text(m.postoGraduacao, style: subStyle, maxLines: 1),
                ],
              ),
            ),
            SizedBox(width: 6.0 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 7.0 * scale, vertical: 5.0 * scale),
              decoration: BoxDecoration(
                  gradient: pillGrad,
                  borderRadius: BorderRadius.circular(12.0 * scale)),
              child: Icon(Icons.arrow_forward_ios,
                  size: 10.0 * scale,
                  color: Theme.of(context).colorScheme.primary),
            )
          ],
        ),
      ),
    );
  }
}

/* ============================================================================
   Modelo (adicionado campos de situação)
   ==========================================================================*/
class MilitarDetalheModel {
  final String matricula;
  final int idPosto;
  final String postoGraduacao;
  final String nome;
  final String unidade;
  final String subunidade;
  final String? imagemUrl;
  final int? idSituacao; // novo
  final String? situacaoDescricao; // novo

  MilitarDetalheModel({
    required this.matricula,
    required this.idPosto,
    required this.postoGraduacao,
    required this.nome,
    required this.unidade,
    required this.subunidade,
    this.imagemUrl,
    this.idSituacao,
    this.situacaoDescricao,
  });

  factory MilitarDetalheModel.fromJson(Map<String, dynamic> j) =>
      MilitarDetalheModel(
        matricula: j['matricula'].toString(),
        idPosto: int.tryParse(j['id_posto'].toString()) ?? 999,
        postoGraduacao: j['posto_graduacao'] ?? '',
        nome: j['nome'] ?? '',
        unidade: j['unidade'] ?? '',
        subunidade: j['subunidade'] ?? '',
        imagemUrl: j['imagemurl'],
        idSituacao: j['id_situacao'] != null
            ? int.tryParse(j['id_situacao'].toString())
            : null,
        // tenta diferentes chaves que sua API pode retornar
        situacaoDescricao: ((j['tipo_situ_func_descricao'] ??
                    j['descricao_situacao'] ??
                    j['descricao'] ??
                    j['situacao']) ??
                '')
            .toString()
            .trim(),
      );
}
