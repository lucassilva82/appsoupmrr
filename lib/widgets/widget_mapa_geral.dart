// lib/widgets/widget_mapa_geral.dart
//
// Mapa Geral compacto
// • Grid de chips (máx. 2 linhas) — ActionChip alterna Selecionar/Limpar todos
// • Lista máx. 40 % da tela, linhas clicáveis (ripple + chevron)
// • TOTAL fixo, botão PDF fora da borda
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/utils/app_routes.dart';
import '../models/situacao.dart';

class WidgetMapaGeral extends StatefulWidget {
  const WidgetMapaGeral({super.key});
  @override
  State<WidgetMapaGeral> createState() => _WidgetMapaGeralState();
}

class _WidgetMapaGeralState extends State<WidgetMapaGeral> {
  late Future<List<Situacao>> _future;

  final List<String> _siglas = [
    'CEL',
    'TC',
    'MAJ',
    'CAP',
    '1º TEN',
    '2º TEN',
    'ASP',
    'CHO-CAD IV',
    'SUB TEN',
    '1º SGT',
    '2º SGT',
    '3º SGT',
    'AL SGT',
    'CB',
    'AL CB',
    'SD',
    'AL SD',
  ];
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = _siglas.toSet(); // inicia “todos”
    _future = _fetch();
  }

  Future<List<Situacao>> _fetch() async {
    if (_sel.isEmpty) return []; // nada selecionado → lista vazia

    Uri uri;
    if (_sel.length == _siglas.length) {
      uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/mapadaforca/listarsituacao.php');
    } else {
      final qs =
          _sel.map((s) => 'posto[]=${Uri.encodeQueryComponent(s)}').join('&');
      uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/mapadaforca/listarsituacao.php?$qs');
    }

    final r = await http.get(uri);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['result'] as List)
        .map((e) => Situacao.fromJson(e))
        .where((e) => e.quantidade > 0)
        .toList();
  }
/* ------------- dentro _WidgetMapaGeralState ------------- */

// substitua estes métodos:

  void _refresh() {
    setState(() {
      _future = _fetch(); // agora o callback retorna void
    });
  }

  void _toggleChip(String sig, bool v) {
    setState(() {
      v ? _sel.add(sig) : _sel.remove(sig);
      _future = _fetch(); // já atualiza futuro aqui
    });
  }

  void _toggleTodos() {
    setState(() {
      _sel.length == _siglas.length ? _sel.clear() : _sel = _siglas.toSet();
      _future = _fetch();
    });
  }

  // ---------- Grid compacto de chips ----------
  Widget _filterGrid() => LayoutBuilder(
        builder: (ctx, cons) {
          const chipW = 60.0;
          final cols = (cons.maxWidth / chipW).floor().clamp(3, 7);
          final rows = ((_siglas.length + 1) / cols).ceil();
          final gridH = rows * 30.0;
          final items = ['__toggle__', ..._siglas];

          return SizedBox(
            height: gridH,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 30,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: items.length,
              itemBuilder: (c, i) {
                if (items[i] == '__toggle__') {
                  final all = _sel.length == _siglas.length;
                  return _iconChip(
                    all ? Icons.clear_all : Icons.select_all,
                    _toggleTodos,
                  );
                }
                final sig = items[i];
                return ChoiceChip(
                  label: Text(sig, style: const TextStyle(fontSize: 8)),
                  selected: _sel.contains(sig),
                  selectedColor: Colors.lightBlue,
                  visualDensity:
                      const VisualDensity(horizontal: -4, vertical: -4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  onSelected: (v) => _toggleChip(sig, v),
                );
              },
            ),
          );
        },
      );

  Widget _iconChip(IconData ic, VoidCallback tap) => ActionChip(
        avatar: Icon(ic, size: 11, color: Colors.white),
        label: const SizedBox.shrink(),
        backgroundColor: Colors.grey.shade600,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: tap,
      );

  // --------------------------- BUILD ---------------------------
  @override
  Widget build(BuildContext context) {
    const primary = Colors.lightBlue;
    const headerH = 36.0, rowH = 34.0, totalH = 36.0;

    return Column(
      children: [
        _filterGrid(),
        const SizedBox(height: 6),
        if (_sel.isEmpty)
          const Expanded(
              child: Center(
                  child:
                      Text('Selecione um posto ou graduação no filtro acima.')))
        else
          FutureBuilder<List<Situacao>>(
            future: _future,
            builder: (c, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Expanded(
                    child: Center(child: CircularProgressIndicator()));
              }
              if (s.hasError) {
                return Expanded(child: Center(child: Text('Erro: ${s.error}')));
              }

              final list = s.data ?? [];
              final total = list.fold<int>(0, (t, e) => t + e.quantidade);

              final maxBody = MediaQuery.of(context).size.height * 0.49;
              final bodyH = ((list.length * rowH).clamp(0, maxBody)).toDouble();

              return Column(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: primary),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      // cabeçalho
                      Container(
                        height: headerH,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12)),
                        ),
                        child: Row(children: const [
                          Expanded(
                              child: Text('Situação',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))),
                          Text('Quantidade',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      // corpo
                      SizedBox(
                        height: bodyH,
                        child: ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final d = list[i];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => DetalhesMapaForcaPage(
                                            dadosBusca: MapBuscaDetalhesModel(
                                                idSituacao: d.id.toString(),
                                                descricao: d.descricao,
                                                postoGraduacao: _sel.toList(),
                                                quantidade:
                                                    d.quantidade.toString()))),
                                  );
                                }, // ação detalhada
                                splashColor: primary.withOpacity(0.15),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(d.descricao,
                                            style:
                                                const TextStyle(fontSize: 11))),
                                    Text(d.quantidade.toString(),
                                        style: const TextStyle(fontSize: 11)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right,
                                        size: 18, color: Colors.grey),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // total
                      Container(
                        height: totalH,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: primary,
                        child: Row(children: [
                          const Expanded(
                              child: Text('TOTAL',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))),
                          Text(total.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                // ElevatedButton.icon(
                //   style: ElevatedButton.styleFrom(backgroundColor: primary),
                //   onPressed: () {/* TODO PDF */},
                //   icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                //   label:
                //       const Text('PDF', style: TextStyle(color: Colors.white)),
                // ),
              ]);
            },
          ),
      ],
    );
  }
}

// ---------------- Model ----------------
class Situacao {
  final int id;
  final String descricao;
  final int quantidade;

  Situacao(
      {required this.id, required this.descricao, required this.quantidade});

  factory Situacao.fromJson(Map<String, dynamic> j) => Situacao(
        id: j['id_situacao'] as int,
        descricao: j['descricao_situacao'] as String,
        quantidade: j['quantidade'] as int,
      );
}
