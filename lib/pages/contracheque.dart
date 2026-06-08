import 'package:flutter/material.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import '../view/second_screen.dart';
import '../widgets/drawer_personalizado.dart';

class Contracheque extends StatefulWidget {
  Contracheque({Key? key}) : super(key: key);

  @override
  _ContrachequeState createState() => _ContrachequeState();

  // Ano inicialmente selecionado
  String _anoSelecionado = '2025';
  late List<MesesContracheque> mesesContracheque;
}

class _ContrachequeState extends State<Contracheque> {
  final DadosSql dadosSql = DadosSql();
  final ScrollController _controllerOne = ScrollController();

  bool anoSelecionado = true;

  @override
  void initState() {
    super.initState();
    // Se preferir, inicie widget._anoSelecionado como o ano atual:
    widget._anoSelecionado = DateTime.now().year.toString();
  }

  // Gera uma lista de anos do atual até 2019 (ajuste conforme sua necessidade)
  List<int> get listaAnos {
    int anoAtual = DateTime.now().year;
    List<int> anos = [];
    for (int ano = anoAtual; ano >= 2020; ano--) {
      anos.add(ano);
    }
    return anos;
  }

  Future<List<MesesContracheque>> _buscaDadosSql(String ano) async {
    final auth = Provider.of<Auth>(context, listen: false);
    widget.mesesContracheque = await dadosSql.listaMesesContracheque(
      auth.cpf!,
      ano,
    );
    return widget.mesesContracheque;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(title: 'Contracheques'),
      // drawer: Drawerpersonalizado(),
      body: Container(
        width: screenWidth,
        height: screenHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: screenHeight * 0.02),

            // LISTA HORIZONTAL DE ANOS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: listaAnos.map((anoInt) {
                  final anoStr = anoInt.toString();
                  final isSelected = anoStr == widget._anoSelecionado;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        widget._anoSelecionado = anoStr;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.03,
                        vertical: MediaQuery.of(context).size.height * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue // cor pro ano selecionado
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        anoStr,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: screenHeight * 0.03),

            // LISTA DE CONTRACHEQUES (apenas se anoSelecionado == true, mas acho que isso já não é necessário)
            anoSelecionado
                ? Container(
                    width: screenWidth * 0.99,
                    height: screenHeight * 0.70,
                    child: FutureBuilder<List<MesesContracheque>>(
                      future: _buscaDadosSql(widget._anoSelecionado),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator.adaptive(),
                          );
                        }
                        if (snapshot.hasError) {
                          print(snapshot.error);
                          return SecondScreen();
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              '* Nenhum contracheque no período.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        // Se chegou aqui, há dados
                        final lista = snapshot.data!;

                        return Column(
                          children: [
                            Container(
                              height: screenHeight * 0.04,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.lightBlue,
                                    Colors.blue.shade900,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.topRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: screenWidth * 0.20,
                                    child: const Center(
                                      child: Text(
                                        'MÊS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: screenWidth * 0.35,
                                    child: const Center(
                                      child: Text(
                                        'MATRÍCULA',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: screenWidth * 0.35,
                                    child: const Center(
                                      child: Text(
                                        'RELAÇAO TRABALHO',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Scrollbar(
                                controller: _controllerOne,
                                child: ListView.builder(
                                  controller: _controllerOne,
                                  itemCount: lista.length,
                                  itemBuilder: (ctx, index) {
                                    final item = lista[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: InkWell(
                                        onTap: () {
                                          item.cpf = Provider.of<Auth>(context,
                                                  listen: false)
                                              .cpf!;
                                          Navigator.of(context).pushNamed(
                                            AppRoutes.PAGE_VIEW_CONTRACHEQUE,
                                            arguments: item,
                                          );
                                        },
                                        child: Container(
                                          width: screenWidth,
                                          height: screenHeight * 0.05,
                                          decoration: lista[index].tipo == "A"
                                              ? BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.lightBlue.shade100,
                                                      Colors.blue.shade400,
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.topRight,
                                                  ),
                                                )
                                              : BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.lightBlue.shade100,
                                                      Colors
                                                          .blueAccent.shade400,
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.topRight,
                                                  ),
                                                ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: screenWidth * 0.20,
                                                child: Center(
                                                  child: Text(
                                                    item.mesExtenso,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: screenWidth * 0.35,
                                                child: Center(
                                                  child: Text(
                                                    item.matricula,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: screenWidth * 0.35,
                                                child: Center(
                                                  child: item.tipo == "A"
                                                      ? Text(
                                                          item.relacaoTrabalho,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black54,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        )
                                                      : Text(
                                                          "${item.relacaoTrabalho}-${item.folha}",
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                Colors.black54,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  // Se ainda quiser manter alguma lógica para anoSelecionado,
  // você pode usar esta função ou remover se não for mais necessária.
  void _dropDownItemSelected(String novoItem) {
    anoSelecionado = true;
    widget._anoSelecionado = novoItem;
    setState(() {});
  }
}
