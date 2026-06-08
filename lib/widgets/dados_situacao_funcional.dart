import 'package:flutter/material.dart';
import '../models/militar.dart';

class DadosSituacaoFuncional extends StatefulWidget {
  final Militar militar;
  const DadosSituacaoFuncional({Key? key, required this.militar})
      : super(key: key);

  @override
  State<DadosSituacaoFuncional> createState() => _DadosSituacaoFuncionalState();
}

class _DadosSituacaoFuncionalState extends State<DadosSituacaoFuncional> {
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    // Ordena pela data de início (mais recente primeiro)
    DateTime _parseDate(String? s) {
      if (s == null) return DateTime.fromMillisecondsSinceEpoch(0);
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    final list = widget.militar.fichaFuncional.alteracoesFuncional;
    list.sort(
        (a, b) => _parseDate(b.dataInicio).compareTo(_parseDate(a.dataInicio)));
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    Widget buildHeader() {
      return Row(
        children: const [
          SizedBox(width: 80, child: Text('Tipo', textAlign: TextAlign.center)),
          SizedBox(
              width: 120, child: Text('Situação', textAlign: TextAlign.center)),
          SizedBox(
              width: 100,
              child: Text('Data Início', textAlign: TextAlign.center)),
          SizedBox(
              width: 100, child: Text('Data Fim', textAlign: TextAlign.center)),
          SizedBox(
              width: 60, child: Text('Ativo', textAlign: TextAlign.center)),
        ].map((w) => DefaultTextStyle(style: headerStyle, child: w)).toList(),
      );
    }

    Widget buildRow(dynamic alt) {
      String _formatBr(String? s) {
        if (s == null || s.isEmpty) return '-';
        try {
          final d = DateTime.parse(s);
          final dd = d.day.toString().padLeft(2, '0');
          final mm = d.month.toString().padLeft(2, '0');
          final yyyy = d.year.toString();
          return '$dd/$mm/$yyyy';
        } catch (_) {
          // tenta reorganizar se vier no padrão YYYY-MM-DD
          final reg = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})$');
          final m = reg.firstMatch(s);
          if (m != null) {
            return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
          }
          // fallback: troca hífens por barras
          return s.replaceAll('-', '/');
        }
      }

      return Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              alt.tipoSituacao,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              alt.situacaoFuncional,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _formatBr(alt.dataInicio),
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _formatBr(alt.dataFim),
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: alt.ativo
                  ? const Icon(Icons.done, color: Colors.green, size: 16)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Container(
        width: double.infinity,
        height: size.height * 0.30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(2, 2)),
          ],
        ),
        child: Column(
          children: [
            // Cabeçalho
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.lightBlue, Colors.blue.shade900],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(5)),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.grey, blurRadius: 4, offset: Offset(2, 2)),
                ],
              ),
              child: const Text(
                'Ficha Funcional',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Tabela com scroll horizontal e vertical
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 80 + 120 + 100 + 100 + 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabeçalho da tabela
                          Container(
                            color: Colors.blue.shade100,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: buildHeader(),
                          ),
                          const Divider(height: 0),
                          // Corpo da tabela
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _verticalController,
                                itemCount: widget.militar.fichaFuncional
                                    .alteracoesFuncional.length,
                                itemBuilder: (context, index) {
                                  final alt = widget.militar.fichaFuncional
                                      .alteracoesFuncional[index];
                                  return Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                    ),
                                    child: buildRow(alt),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
