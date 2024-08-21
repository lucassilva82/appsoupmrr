import 'package:flutter/material.dart';

import '../models/militar.dart';

class DadosSituacaoFuncional extends StatefulWidget {
  Militar militar;
  DadosSituacaoFuncional({Key? key, required this.militar}) : super(key: key);

  @override
  State<DadosSituacaoFuncional> createState() => _DadosSituacaoFuncionalState();
}

class _DadosSituacaoFuncionalState extends State<DadosSituacaoFuncional> {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    widget.militar.fichaFuncional.alteracoesFuncional =
        widget.militar.fichaFuncional.alteracoesFuncional.reversed.toList();

    late ScrollController _controllerOne = ScrollController();

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Container(
        width: width * 0.99,
        height: height * 0.26,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 4,
              offset: Offset(2, 2), // Shadow position
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: width * 0.99,
              height: height * 0.04,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.lightBlue,
                    Colors.blue.shade900,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 4,
                    offset: Offset(2, 2), // Shadow position
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    'FIcha Funcional',
                    style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Tipo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: width * 0.10),
                        Text(
                          'Situação',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: width * 0.09),
                        Text(
                          'Data Inicio',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: width * 0.03),
                        Text(
                          'Data Fim',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: width * 0.05),
                        Text(
                          'Ativo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Container(
                      // decoration: BoxDecoration(color: Colors.blue.shade50),
                      width: double.maxFinite,
                      height: height * 0.15,
                      child: Scrollbar(
                        controller: _controllerOne,
                        child: ListView.builder(
                          controller: _controllerOne,
                          shrinkWrap: true,
                          itemCount: widget.militar.fichaFuncional
                              .alteracoesFuncional.length,
                          itemBuilder: ((context, index) {
                            return Padding(
                              padding: const EdgeInsets.all(1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.blue.shade100)),
                                height: height * 0.04,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding:
                                          EdgeInsetsDirectional.only(start: 2),
                                      width: width * 0.10,
                                      child: Text(
                                        widget
                                            .militar
                                            .fichaFuncional
                                            .alteracoesFuncional[index]
                                            .tipoSituacao,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: width * 0.30,
                                      child: Text(
                                        widget
                                            .militar
                                            .fichaFuncional
                                            .alteracoesFuncional[index]
                                            .situacaoFuncional,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: width * 0.17,
                                      child: Text(
                                        widget
                                            .militar
                                            .fichaFuncional
                                            .alteracoesFuncional[index]
                                            .dataInicio,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: width * 0.25,
                                      child: Text(
                                        widget.militar.fichaFuncional
                                            .alteracoesFuncional[index].dataFim,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    widget
                                                .militar
                                                .fichaFuncional
                                                .alteracoesFuncional[index]
                                                .ativo ==
                                            true
                                        ? Icon(
                                            Icons.done,
                                            color: Colors.green,
                                          )
                                        : Text('')
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
