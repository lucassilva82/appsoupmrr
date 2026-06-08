// lib/widgets/widget_grandes_comandos.dart
//
// Lista de Comandos (quantidade de militares)
// • Mesmo layout do WidgetMapaGeral
// • Consome https://pmrr.net/flutter/sigrh/mapadaforca/listacomandos.php
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_comando_page.dart';

class WidgetGrandesComandos extends StatefulWidget {
  const WidgetGrandesComandos({super.key});
  @override
  State<WidgetGrandesComandos> createState() => _WidgetGrandesComandosState();
}

class _WidgetGrandesComandosState extends State<WidgetGrandesComandos> {
  late Future<List<Comando>> _future;

  // mesmas siglas do widget anterior
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
  late Set<String> _sel; // selecionados

  @override
  void initState() {
    super.initState();
    _sel = _siglas.toSet(); // inicia com todos selecionados
    _future = _fetch();
  }

  /* ---------- API ---------- */
  Future<List<Comando>> _fetch() async {
    if (_sel.isEmpty) return [];

    Uri uri;
    if (_sel.length == _siglas.length) {
      uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/mapadaforca/listacomandos.php');
    } else {
      final qs =
          _sel.map((s) => 'posto[]=${Uri.encodeQueryComponent(s)}').join('&');
      uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/mapadaforca/listacomandos.php?$qs');
    }

    final resp = await http.get(uri);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    return (data['result'] as List)
        .map((e) => Comando.fromJson(e))
        .where((e) => e.quantidade > 0)
        .toList();
  }

  /* ---------- helpers ---------- */
  void _refresh() => setState(() => _future = _fetch());

  void _toggleChip(String sig, bool v) {
    setState(() {
      v ? _sel.add(sig) : _sel.remove(sig);
      _future = _fetch();
    });
  }

  void _toggleTodos() {
    setState(() {
      _sel.length == _siglas.length ? _sel.clear() : _sel = _siglas.toSet();
      _future = _fetch();
    });
  }

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
              itemBuilder: (_, i) {
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

  /* ---------- BUILD ---------- */
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
              child: Text('Selecione um posto ou graduação no filtro acima.'),
            ),
          )
        else
          FutureBuilder<List<Comando>>(
            future: _future,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Expanded(
                    child: Center(child: Text('Erro: ${snapshot.error}')));
              }

              final list = snapshot.data ?? [];
              final total = list.fold<int>(0, (sum, e) => sum + e.quantidade);

              final maxBody = MediaQuery.of(context).size.height * 0.53;
              final bodyH = ((list.length * rowH).clamp(0, maxBody)).toDouble();

              return Column(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      // cabeçalho
                      Container(
                        height: headerH,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(children: const [
                          Expanded(
                              child: Text('Comando',
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
                                        builder: (_) =>
                                            DetalhesMapaForcaComandoPage(
                                                dadosBusca:
                                                    MapBuscaDetalhesModel(
                                                        idSituacao:
                                                            d.id.toString(),
                                                        descricao:
                                                            d.nomeComando,
                                                        postoGraduacao:
                                                            _sel.toList(),
                                                        quantidade: d.quantidade
                                                            .toString()))),
                                  );
                                },
                                splashColor: primary.withOpacity(0.15),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(d.nomeComando,
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
              ]);
            },
          ),
      ],
    );
  }
}

/* ---------- Model ---------- */
class Comando {
  final int id;
  final String nomeComando;
  final int quantidade;

  Comando(
      {required this.id, required this.nomeComando, required this.quantidade});

  factory Comando.fromJson(Map<String, dynamic> j) => Comando(
        id: j['id_comando'] as int,
        nomeComando: j['nome_comando'] as String,
        quantidade: j['quantidade'] as int,
      );
}
