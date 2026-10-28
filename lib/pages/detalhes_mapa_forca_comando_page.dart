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
import '../widgets/vidro.dart';
import '../core/erros/falha_de.dart';
import '../core/erros/estado_erro.dart';
import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';
import '../widgets/cartao_painel.dart';

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
  // Item de militar: vidro simples, sem arte (a arte fica no topo da tela).
  Widget _militarCard(MilitarDetalheModel m) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: CartaoVidro(
          raio: 14,
          padding: const EdgeInsets.all(8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MilitarDetalheFullPage(
                  matricula: m.matricula,
                  preloadedImageUrl: _resolveImgUrl(m.imagemUrl)))),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
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
                  child: Icon(Icons.person_outline_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                      size: AppIconSize.xl),
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
                        style: TextStyle(
                            fontSize: 11,
                            color: m.situacaoDescricao!.startsWith("PRONTO")
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.62)
                                : Theme.of(context).colorScheme.error),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
                size: AppIconSize.sm)
          ]),
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

    // Topo com a arte da área de Gestão (padrão 2.2): o comando escolhido e
    // o filtro de postos aplicado.
    return TopoArte(
      arte: Arte.de('gestao'),
      icone: Icons.account_balance_outlined,
      titulo: comando,
      subtitulo:
          'Efetivo por unidade, subunidade e situação. Filtro: $postosStr',
      margem: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    );
  }

  /* ---------------- BUILD ---------------- */
  @override
  Widget build(BuildContext context) {
    return FundoSuave(
        child: Scaffold(
      appBar: CustomAppBar(title: widget.dadosBusca.descricao),
      body: Column(
        children: [
          _filtroHeader(),

          // ---------- CAMPO DE BUSCA ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Pesquisar por nome',
                prefixIcon: Icon(Icons.search_rounded, size: AppIconSize.sm),
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
                  return EstadoErro(
                      falha:
                          falhaDe('MF', snap.error, tela: 'gestao.mapa_forca'),
                      tela: 'gestao.mapa_forca');
                }

                final baseMapa = snap.data ?? {};
                final mapa = _filtrar(baseMapa);

                if (mapa.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CartaoVidro(
                        arte: Arte.de('gestao'),
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined,
                                size: AppIconSize.xl,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6)),
                            const SizedBox(height: 10),
                            const Text('Nenhum resultado.'),
                          ],
                        ),
                      ),
                    ),
                  );
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
                              qtd: grupo.length));
                          children.addAll(grupo.map(_militarCard));
                        }

                        // inserir Situação Funcional dentro da subunidade (antes dos postos)
                        final situacaoTile = _SituacaoTile(
                          key: ValueKey('situacao_${unid.key}_${sub.key}'),
                          militares: sub.value,
                        );

                        return _GradientTile(
                          title: sub.key,
                          total: totalSub,
                          leadingIcon: Icons.account_tree_outlined,
                          isSubLevel: true,
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
    ));
  }
}

/* ============================================================================
   UNIDADE / SUBUNIDADE (DESIGN §3b)
   Nível 1 (unidade) é a única caixa: CartaoVidro com a arte discreta da
   área. Do nível 2 para baixo não há superfície; a hierarquia é indentação
   com uma guia de 2px desenhada uma vez para o bloco inteiro de filhos.
   ==========================================================================*/
class _GradientTile extends StatelessWidget {
  final String title;
  final int total;
  final IconData leadingIcon;
  final bool isSubLevel;
  final int? referenceTotal;
  final List<Widget> childTiles;

  const _GradientTile({
    required this.title,
    required this.total,
    required this.leadingIcon,
    required this.isSubLevel,
    this.referenceTotal,
    required this.childTiles,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aoFundo = tema.colorScheme.onSurface;
    final primaria = tema.colorScheme.primary;
    final rawPct = referenceTotal == null || referenceTotal == 0
        ? 0.0
        : total / referenceTotal!;
    final pct = rawPct.clamp(0.0, 1.0);
    final visualPct = total > 0 && pct < 0.05 ? 0.05 : pct;
    final pctText = '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';

    final tile = ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      leading: Icon(leadingIcon,
          color: primaria, size: isSubLevel ? AppIconSize.sm : AppIconSize.md),
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
                        isSubLevel ? FontWeight.w600 : FontWeight.w700)),
          ),
          if (referenceTotal != null) ...[
            Text(
              pctText,
              style: TextStyle(
                color: aoFundo.withValues(alpha: 0.70),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: isSubLevel ? 48 : 60,
              child: BarraProgressoCartao(valor: visualPct),
            ),
            const SizedBox(width: 8),
          ],
          _Contagem(total),
        ],
      ),
      childrenPadding: EdgeInsets.zero,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 18, top: 2, bottom: 8),
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
    );

    if (isSubLevel) return tile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: CartaoVidro(
        raio: 14,
        arte: Arte.de('gestao'),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: tile,
        ),
      ),
    );
  }
}

/// Contagem ao lado do título: selo pequeno na primária (DESIGN §3, raio 10).
class _Contagem extends StatelessWidget {
  const _Contagem(this.valor);
  final int valor;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$valor',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/* ============================================================================
   CABEÇALHO DO POSTO / GRADUAÇÃO (nível 2+: sem superfície, só rótulo)
   ==========================================================================*/
class _PostoHeader extends StatelessWidget {
  final String sigla;
  final int qtd;
  const _PostoHeader({required this.sigla, required this.qtd});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Row(
        children: [
          Icon(Icons.military_tech_outlined,
              color: tema.colorScheme.primary, size: AppIconSize.xs),
          const SizedBox(width: 6),
          Expanded(
              child: Text('$sigla : $qtd militares',
                  style: TextStyle(
                      color: tema.colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)))
        ],
      ),
    );
  }
}

/* ============================================================================
   SITUAÇÃO FUNCIONAL (seção neutra dentro da entidade, DESIGN §3b)
   ==========================================================================*/
class _SituacaoTile extends StatelessWidget {
  final List<MilitarDetalheModel> militares;

  const _SituacaoTile({
    Key? key,
    required this.militares,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCard = theme.colorScheme.onSurface;
    final primaria = theme.colorScheme.primary;
    // Seção neutra: um tom só, sem borda (antes branco a 72% com a borda
    // feita à mão e um azul fixo nas barras).
    final secao = onCard.withValues(alpha: 0.055);

    final Map<String, List<MilitarDetalheModel>> porSituacao = {};
    for (final m in militares) {
      final s = (m.situacaoDescricao ?? '').trim();
      final key = s.isEmpty ? 'Sem Situação' : s;
      porSituacao.putIfAbsent(key, () => []);
      porSituacao[key]!.add(m);
    }

    final situacoes = porSituacao.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          key: PageStorageKey('situacao_root_${militares.hashCode}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          collapsedBackgroundColor: secao,
          backgroundColor: secao,
          leading: Icon(Icons.flag_outlined,
              color: onCard.withValues(alpha: 0.7), size: AppIconSize.xs),
          iconColor: onCard.withValues(alpha: 0.6),
          collapsedIconColor: onCard.withValues(alpha: 0.6),
          title: Row(
            children: [
              Expanded(
                child: Text('Situação Funcional',
                    style: TextStyle(
                        color: onCard,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              _Contagem(militares.length),
            ],
          ),
          childrenPadding: const EdgeInsets.only(bottom: 6, top: 2),
          children: situacoes.map((sit) {
            final lista = porSituacao[sit]!;
            final rawPct =
                militares.isEmpty ? 0.0 : lista.length / militares.length;
            final pct = rawPct.clamp(0.0, 1.0);
            final visualPct = lista.isNotEmpty && pct < 0.05 ? 0.05 : pct;
            final pctText =
                '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';

            return ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              key: PageStorageKey('situacao_item_${militares.hashCode}_$sit'),
              initiallyExpanded: false,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              leading: Icon(Icons.work_outline,
                  color: onCard.withValues(alpha: 0.6),
                  size: AppIconSize.xxs),
              iconColor: onCard.withValues(alpha: 0.6),
              collapsedIconColor: onCard.withValues(alpha: 0.6),
              title: Row(
                children: [
                  Expanded(
                    child: Text(sit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: onCard,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    pctText,
                    style: TextStyle(
                      color: onCard.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 48,
                    child: BarraProgressoCartao(valor: visualPct, altura: 5),
                  ),
                  const SizedBox(width: 6),
                  _Contagem(lista.length),
                ],
              ),
              childrenPadding: const EdgeInsets.only(bottom: 4, top: 2),
              children: [
                // Nível 2+: sem superfície; guia única para o bloco.
                Container(
                  margin: const EdgeInsets.only(left: 18),
                  padding: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: primaria.withValues(alpha: 0.22), width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: lista
                        .map((m) => _situacaoListItem(context, m, onCard))
                        .toList(),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _situacaoListItem(
      BuildContext context, MilitarDetalheModel m, Color onCard) {
    final nameStyle =
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onCard);
    final subStyle = TextStyle(
        fontSize: 11, color: onCard.withValues(alpha: 0.6), height: 1.1);
    final vazio = onCard.withValues(alpha: 0.08);

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
    final semFoto = Container(
      width: 40,
      height: 40,
      color: vazio,
      child: Icon(Icons.person_outline_rounded,
          color: onCard.withValues(alpha: 0.4), size: AppIconSize.xs),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MilitarDetalheFullPage(
                matricula: m.matricula,
                preloadedImageUrl: resolveUrl(m.imagemUrl))));
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: resolvedUrl != null
                    ? CachedNetworkImage(
                        imageUrl: resolvedUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        cacheManager: DefaultCacheManager(),
                        placeholder: (_, __) => Container(
                          width: 40,
                          height: 40,
                          color: vazio,
                          child: const Center(
                              child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5))),
                        ),
                        errorWidget: (_, __, ___) => semFoto,
                      )
                    : semFoto,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle),
                    const SizedBox(height: 3),
                    Text(m.postoGraduacao, style: subStyle, maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: AppIconSize.sm, color: onCard.withValues(alpha: 0.4)),
            ],
          ),
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
