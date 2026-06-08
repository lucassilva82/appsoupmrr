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
import '../models/militar_detalhe_model.dart';
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

  // ---------- Paleta (mesma do CustomAppBar) ----------
  static const MaterialColor _swatch = Colors.lightBlue;
  static final Color _primaryStart = _swatch.shade400;
  static final Color _primaryMid = _swatch.shade200;
  static final Color _primaryEnd = _swatch.shade700;
  static final Gradient _grad = LinearGradient(
    colors: [_primaryStart, _primaryEnd],
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
        'https://pmrr.net/flutter/sigrh/mapadaforca/listacomando_detalhes.php?id_comando=$idCmd');

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

  /* ---------------- BADGE DE CONTADOR ---------------- */
  Widget _badge(int qtd, {Gradient? grad}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: grad ?? _grad,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: _primaryEnd.withOpacity(.25),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Text('$qtd',
            style: const TextStyle(fontSize: 11, color: Colors.white)),
      );

  /* ---------------- CARTÃO DE MILITAR ---------------- */
  Widget _militarCard(MilitarDetalheModel m) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: _primaryStart.withOpacity(.20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MilitarDetalheFullPage(matricula: m.matricula))),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: m.imagemUrl ?? '',
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
                    color: Colors.grey.shade300,
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 38),
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

  /* ---------------- HEADER DE FILTROS ---------------- */
  Widget _filtroHeader() {
    final postos = widget.dadosBusca.postoGraduacao;
    final postosStr = (postos.isEmpty ||
            (postos.length == 1 && postos.first.toUpperCase() == 'TODOS'))
        ? 'Todos'
        : postos.join(', ');
    final comando = widget.dadosBusca.descricao;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            gradient: _grad,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _primaryEnd.withOpacity(.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.filter_alt, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Filtros aplicados',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4))
            ]),
            const SizedBox(height: 6),
            Text('Comando: $comando',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(height: 2),
            Text('Postos/Graduações: $postosStr',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Pesquisar militar por nome...',
              leading: const Icon(Icons.search),
              elevation: const MaterialStatePropertyAll(0),
              onTap: () => _searchCtrl.selection = TextSelection(
                  baseOffset: 0, extentOffset: _searchCtrl.text.length),
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
                  start: _primaryStart,
                  mid: _primaryMid,
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
                        start: _primaryStart,
                        mid: _primaryMid,
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
                          start: _primaryStart,
                          mid: _primaryMid,
                        );

                        return _GradientTile(
                          title: sub.key,
                          total: totalSub,
                          leadingIcon: Icons.account_tree_outlined,
                          isSubLevel: true,
                          primaryStart: _primaryStart,
                          primaryMid: _primaryMid,
                          grad: _grad,
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
                        primaryStart: _primaryStart,
                        primaryMid: _primaryMid,
                        grad: _grad,
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
  final List<Widget> childTiles;

  const _GradientTile({
    required this.title,
    required this.total,
    required this.leadingIcon,
    required this.isSubLevel,
    required this.primaryStart,
    required this.primaryMid,
    required this.grad,
    required this.childTiles,
  });

  Widget _badge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: grad,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$total',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );

  @override
  Widget build(BuildContext context) {
    final bgCollapsed =
        isSubLevel ? primaryStart.withOpacity(.25) : primaryStart;
    final bgExpanded = isSubLevel ? primaryStart.withOpacity(.15) : primaryMid;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isSubLevel ? 12 : 8, vertical: isSubLevel ? 2 : 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          collapsedBackgroundColor: bgCollapsed,
          backgroundColor: bgExpanded,
          leading: Icon(leadingIcon,
              color: Colors.white, size: isSubLevel ? 18 : 22),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isSubLevel ? 13 : 14,
                        fontWeight:
                            isSubLevel ? FontWeight.w500 : FontWeight.bold)),
              ),
              _badge()
            ],
          ),
          childrenPadding: EdgeInsets.only(bottom: isSubLevel ? 2 : 4, top: 2),
          children: childTiles,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          gradient: grad, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.military_tech, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text('$sigla : $qtd militares',
                  style: const TextStyle(color: Colors.white, fontSize: 12)))
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
    const double scale = 0.8; // 20% menor que padrão

    // agrupa por situacaoDescricao (fallback 'Sem Situação')
    final Map<String, List<MilitarDetalheModel>> porSituacao = {};
    for (final m in militares) {
      final s = (m.situacaoDescricao ?? '').trim();
      final key = s.isEmpty ? 'Sem Situação' : s;
      porSituacao.putIfAbsent(key, () => []);
      porSituacao[key]!.add(m);
    }

    final situacoes = porSituacao.keys.toList()..sort();

    // badge teal vibrante
    final Gradient pillGrad =
        LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade600]);

    // tamanhos base (20% menores)
    final double rootTitleSize = 14 * scale;
    final double rootBadgeSize = 11 * scale;
    final double itemTitleSize = 13 * scale;
    final double itemBadgeSize = 11 * scale;
    final double listNameSize = 12 * scale;
    final double listSubSize = 11 * scale;

    // borda discreta quase imperceptível
    final Color subtleBorder = Colors.black.withOpacity(0.06);
    const double subtleWidth = 0.5;

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // fundo branco puro
          // agora usa mesmo arredondamento dos outros blocos (16)
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: subtleBorder, width: subtleWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6 * scale,
              offset: Offset(0, 3 * scale),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ExpansionTile(
            key: PageStorageKey('situacao_root_${militares.hashCode}'),
            tilePadding: EdgeInsets.symmetric(
                horizontal: 12 * scale, vertical: 8 * scale),
            collapsedBackgroundColor: Colors.white,
            backgroundColor: Colors.white,
            leading: Icon(Icons.flag_outlined,
                color: Colors.grey.shade800, size: 18 * scale),
            iconColor: Colors.grey.shade800,
            collapsedIconColor: Colors.grey.shade800,
            title: Row(
              children: [
                Expanded(
                  child: Text('Situação Funcional',
                      style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: rootTitleSize)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 8 * scale, vertical: 4 * scale),
                  decoration: BoxDecoration(
                      gradient: pillGrad,
                      borderRadius: BorderRadius.circular(20 * scale)),
                  child: Text('${militares.length}',
                      style: TextStyle(
                          color: Colors.white, fontSize: rootBadgeSize)),
                )
              ],
            ),
            childrenPadding: EdgeInsets.only(bottom: 6 * scale, top: 4 * scale),
            children: situacoes.map((sit) {
              final lista = porSituacao[sit]!;
              return Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale, vertical: 6 * scale),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // sub-bloco com radius levemente menor, mas alinhado visualmente
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: subtleBorder, width: subtleWidth),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 5 * scale,
                        offset: Offset(0, 2 * scale),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ExpansionTile(
                      key: PageStorageKey(
                          'situacao_item_${militares.hashCode}_$sit'),
                      tilePadding: EdgeInsets.symmetric(
                          horizontal: 12 * scale, vertical: 8 * scale),
                      collapsedBackgroundColor: Colors.white,
                      backgroundColor: Colors.white,
                      leading: Icon(Icons.work_outline,
                          color: Colors.grey.shade800, size: 16 * scale),
                      iconColor: Colors.grey.shade800,
                      collapsedIconColor: Colors.grey.shade800,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(sit,
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: itemTitleSize,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8 * scale, vertical: 4 * scale),
                            decoration: BoxDecoration(
                                gradient: pillGrad,
                                borderRadius:
                                    BorderRadius.circular(20 * scale)),
                            child: Text('${lista.length}',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: itemBadgeSize)),
                          )
                        ],
                      ),
                      childrenPadding:
                          EdgeInsets.only(bottom: 6 * scale, top: 4 * scale),
                      children: lista
                          .map((m) => _situacaoListItem(context, m, pillGrad,
                              listNameSize, listSubSize, scale))
                          .toList(),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // item estilizado para lista dentro da situação (agora texto escuro sobre branco)
  Widget _situacaoListItem(BuildContext context, MilitarDetalheModel m,
      Gradient pillGrad, double nameSize, double subSize, double scale) {
    // detecta situação e escolhe cor
    final situ = (m.situacaoDescricao ?? '').trim().toUpperCase();

    final Color mainColor = Colors.black87;
    final Color subColor = Colors.black54;

    final nameStyle = TextStyle(
        fontSize: nameSize, fontWeight: FontWeight.w600, color: mainColor);
    final subStyle =
        TextStyle(fontSize: subSize, color: subColor, height: 1.05);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MilitarDetalheFullPage(matricula: m.matricula)));
      },
      child: Container(
        margin:
            EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
        padding:
            EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: Colors.black.withOpacity(0.04), width: 0.4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4 * scale,
                offset: Offset(0, 1 * scale))
          ],
        ),
        child: Row(
          children: [
            // avatar com recorte superior (alignment topCenter)
            ClipRRect(
              borderRadius: BorderRadius.circular(6 * scale),
              child: CachedNetworkImage(
                imageUrl: m.imagemUrl ?? '',
                width: 44 * scale,
                height: 44 * scale,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                cacheManager: DefaultCacheManager(),
                placeholder: (_, __) => Container(
                  width: 44 * scale,
                  height: 44 * scale,
                  color: Colors.grey.shade200,
                  child: const Center(
                      child: Icon(Icons.person, size: 18, color: Colors.grey)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 44 * scale,
                  height: 44 * scale,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.person, color: Colors.grey, size: 18),
                ),
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle),
                  SizedBox(height: 4 * scale),
                  Text(m.postoGraduacao, style: subStyle, maxLines: 1),
                ],
              ),
            ),
            SizedBox(width: 8 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale, vertical: 6 * scale),
              decoration: BoxDecoration(
                  gradient: pillGrad,
                  borderRadius: BorderRadius.circular(16 * scale)),
              child: Icon(Icons.arrow_forward_ios,
                  size: 14 * scale, color: Colors.white),
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
