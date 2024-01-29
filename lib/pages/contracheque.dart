import 'package:flutter/material.dart';
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
  String _anoSelecionado = '2024';
  late List<MesesContracheque> mesesContracheque;
}

class _ContrachequeState extends State<Contracheque> {
  late ScrollController _controllerOne = ScrollController();
  DadosSql dadosSql = DadosSql();

  bool anoSelecionado = true;

  final _anos = ['2024', '2023', '2022', '2021', '2020', '2019'];

  @override
  Widget build(BuildContext context) {
    double hieght = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.height;
    Auth auth = Provider.of(context);
    widget.mesesContracheque = [];
    Future<List<MesesContracheque>> _buscaDadosSql() async {
      widget.mesesContracheque = await dadosSql.listaMesesContracheque(
          auth.cpf!, widget._anoSelecionado);

      return widget.mesesContracheque;
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
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
        ),
        title: Text('Contracheques'),
      ),
      body: Container(
        width: width,
        height: hieght,
        // decoration: BoxDecoration(color: Colors.black),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: hieght * 0.02),
            Container(
              child: DropdownButton<String>(
                  hint: const Text("Selecione"),
                  style: const TextStyle(color: Colors.blue, fontSize: 16),
                  alignment: AlignmentDirectional.center,
                  items: _anos.map((String dropDownStringItem) {
                    return DropdownMenuItem<String>(
                      value: dropDownStringItem,
                      alignment: AlignmentDirectional.center,
                      child: Container(
                          width: width * 0.08,
                          child: Text(
                            dropDownStringItem,
                            style: TextStyle(fontSize: 16),
                          )),
                    );
                  }).toList(),
                  onChanged: ((novoItemSelecionado) {
                    _dropDownItemSelected(novoItemSelecionado!);
                  }),
                  value: widget._anoSelecionado),
            ),
            SizedBox(height: hieght * 0.03),
            anoSelecionado == true //teste
                ? Container(
                    width: width * 0.99,
                    height: hieght * 0.70,
                    child: FutureBuilder<List<MesesContracheque>>(
                      future: _buscaDadosSql(),
                      builder: ((context, snapshot) {
                        if (snapshot.hasData) {
                          if (widget.mesesContracheque.isEmpty) {
                            return Center(
                                child: Text(
                              '* Nenhum contracheque no periodo.',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ));
                          } else {
                            return Column(
                              children: [
                                Container(
                                  height: hieght * 0.04,
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
                                        // padding: EdgeInsets.symmetric(
                                        //     horizontal: 10),
                                        width: width * 0.10,
                                        child: Center(
                                          child: Text(
                                            'MÊS',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: width * 0.18,
                                        // padding:
                                        //     EdgeInsets.symmetric(horizontal: 8),
                                        child: Center(
                                          child: Text(
                                            'LOTAÇÃO',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: width * 0.18,
                                        // padding:
                                        //     EdgeInsets.symmetric(horizontal: 8),
                                        child: Center(
                                          child: Text(
                                            'PROVENTO',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Container(
                                      // decoration:
                                      //     BoxDecoration(color: Colors.blue),
                                      width: double.maxFinite,
                                      height: hieght * 0.65,
                                      child: Scrollbar(
                                        controller: _controllerOne,
                                        child: ListView.builder(
                                          controller: _controllerOne,
                                          itemCount:
                                              widget.mesesContracheque.length,
                                          itemBuilder: (context, index) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 1),
                                              child: InkWell(
                                                onTap: () {
                                                  widget
                                                      .mesesContracheque[index]
                                                      .cpf = auth.cpf!;
                                                  Navigator.of(context).pushNamed(
                                                      AppRoutes
                                                          .PAGE_VIEW_CONTRACHEQUE,
                                                      arguments: widget
                                                              .mesesContracheque[
                                                          index]);
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors
                                                            .lightBlue.shade100,
                                                        Colors.blue.shade400,
                                                      ],
                                                      begin:
                                                          Alignment.centerLeft,
                                                      end: Alignment.topRight,
                                                    ),
                                                  ),
                                                  width: width,
                                                  height: hieght * 0.05,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: width * 0.10,
                                                        child: Center(
                                                          child: Text(
                                                            '${widget.mesesContracheque[index].mes}',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: width * 0.18,
                                                        child: Center(
                                                          child: Text(
                                                            '${widget.mesesContracheque[index].lotacao}',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: width * 0.18,
                                                        child: Center(
                                                          child: Text(
                                                            '${widget.mesesContracheque[index].tipoProvento}',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ),
                                                      ),
                                                      // Container(
                                                      //   width: width * 0.06,
                                                      //   child: IconButton(
                                                      //       padding:
                                                      //           EdgeInsets.only(
                                                      //               bottom: 10,
                                                      //               left: 20),
                                                      //       onPressed: () {
                                                      //         widget
                                                      //             .mesesContracheque[
                                                      //                 index]
                                                      //             .cpf = auth.cpf!;
                                                      //         Navigator.of(
                                                      //                 context)
                                                      //             .pushNamed(
                                                      //                 AppRoutes
                                                      //                     .PAGE_VIEW_CONTRACHEQUE,
                                                      //                 arguments:
                                                      //                     widget
                                                      //                         .mesesContracheque[index]);
                                                      //       },
                                                      //       icon: Icon(
                                                      //         Icons.search,
                                                      //         color: Colors
                                                      //             .black54,
                                                      //         size: 28,
                                                      //       )),
                                                      // )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )),
                                ),
                              ],
                            );
                          }
                        } else if (snapshot.hasError) {
                          print(snapshot.error);
                          return SecondScreen();
                        }
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
      drawer: Drawerpersonalizado(),
    );
  }

  void _dropDownItemSelected(String novoItem) {
    anoSelecionado = true;
    widget._anoSelecionado = novoItem;
    setState(() {});
  }
}
