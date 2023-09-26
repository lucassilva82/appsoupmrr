import 'package:currency_formatter/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:money_formatter/money_formatter.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/contracheque_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../view/second_screen.dart';

class PageContracheque extends StatelessWidget {
  MesesContracheque mesSelecionado;
  PageContracheque({Key? key, required this.mesSelecionado}) : super(key: key);
  late ContrachequeModel contracheque;
  late ScrollController _controllerOne = ScrollController();
  late double proventos;
  late double descontos;
  late double totalLiquido;

  @override
  Widget build(BuildContext context) {
    Auth auth = Provider.of(context);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    DadosSql dadosSql = DadosSql();
    TextStyle estiloCabecalho = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Colors.blue,
    );
    TextStyle estiloCabecalho2 = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: Colors.white,
    );
    TextStyle estiloSubtitulo = TextStyle(
      // fontWeight: FontWeight.bold,
      fontSize: 14,
      color: Colors.black54,
    );
    TextStyle contrachequeTexto = TextStyle(
      fontSize: 14,
      color: Colors.black54,
    );

    Future<ContrachequeModel> _buscaDadosSql() async {
      contracheque = await dadosSql.buscaContracheque(mesSelecionado.cpf,
          mesSelecionado.ano, mesSelecionado.mes, mesSelecionado.codProvento);

      proventos = 0.0;
      descontos = 0.0;
      totalLiquido = 0.0;

      contracheque.proventos.forEach((element) {
        if (element.dp == 'P') {
          proventos += double.parse(element.valor);
        } else {
          descontos += double.parse(element.valor);
        }
      });

      totalLiquido = proventos - descontos;
      return contracheque;
    }

    CurrencyFormatterSettings realSettings = CurrencyFormatterSettings(
      symbol: '',
      symbolSide: SymbolSide.right,
      thousandSeparator: '.',
      decimalSeparator: ',',
      symbolSeparator: ' ',
    );

    return FutureBuilder<ContrachequeModel>(
      future: _buscaDadosSql(),
      builder: ((context, snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                  'Contracheque - ${mesSelecionado.mes}/${mesSelecionado.ano}'),
            ),
            body: SafeArea(
              child: Container(
                decoration: BoxDecoration(),
                child: Column(
                  children: [
                    //Cabecalho contracheque
                    Container(
                      decoration: const BoxDecoration(
                          image: DecorationImage(
                        opacity: 220,
                        image: AssetImage("assets/imagens/previa.png"),
                      )),
                      width: width,
                      height: height * 0.25,
                      child: Column(
                        children: [
                          Container(
                            height: height * 0.08,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        'LOTAÇÃO',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.10),
                                      child: Text(
                                        'MÊS/ANO',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        mesSelecionado.lotacao,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.10),
                                      child: Text(
                                        '${mesSelecionado.mes}/${mesSelecionado.ano}',
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: height * 0.08,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        'CARGO / TIPO',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.10),
                                      child: Text(
                                        'MATRÍCULA',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        mesSelecionado.lotacao!,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.15),
                                      child: Text(
                                        auth.matricula!,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: height * 0.08,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        'NOME',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        // auth.nomeCompleto!,
                                        auth.nomeCompleto!,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    //dados de provento
                    Container(
                      // decoration: BoxDecoration(color: Colors.green),
                      width: width,
                      height: height * 0.40,
                      child: Column(
                        children: [
                          Container(
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
                            width: width,
                            height: height * 0.045,
                            child: Row(
                              children: [
                                Container(
                                  width: width * 0.25,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 20.0),
                                    child: Text(
                                      'TIPO',
                                      style: estiloCabecalho2,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: width * 0.50,
                                  child: Text(
                                    'DESCRIÇÃO',
                                    style: estiloCabecalho2,
                                  ),
                                ),
                                Container(
                                  width: width * 0.20,
                                  child: Text(
                                    'VALOR',
                                    style: estiloCabecalho2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Container(
                                width: double.maxFinite,
                                height: height * 0.35,
                                child: Scrollbar(
                                  controller: _controllerOne,
                                  child: ListView.builder(
                                    controller: _controllerOne,
                                    itemCount: contracheque.proventos.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        padding:
                                            const EdgeInsets.only(left: 20.0),
                                        decoration: BoxDecoration(
                                          gradient: contracheque
                                                      .proventos[index].dp ==
                                                  'P'
                                              ? LinearGradient(
                                                  colors: [
                                                    Colors.lightBlue.shade100,
                                                    const Color.fromARGB(
                                                        255, 89, 173, 241),
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.topRight,
                                                )
                                              : LinearGradient(
                                                  colors: [
                                                    Color.fromARGB(
                                                        255, 231, 209, 209),
                                                    Color.fromARGB(
                                                        255, 252, 156, 159),
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.topRight,
                                                ),
                                        ),
                                        width: width,
                                        height: height * 0.04,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: width * 0.20,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  contracheque
                                                      .proventos[index].dp,
                                                  style: contrachequeTexto,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: width * 0.50,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 10),
                                                child: Text(
                                                  contracheque.proventos[index]
                                                      .descricao,
                                                  style: contrachequeTexto,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: width * 0.20,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 1),
                                                child: Text(
                                                  'R\$ ${CurrencyFormatter.format(contracheque.proventos[index].valor, realSettings)}',
                                                  style: contrachequeTexto,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )),
                          ),
                        ],
                      ),
                    ),
                    //soma dos valores
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                      ),
                      width: width,
                      height: height * 0.04,
                      child: Container(
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
                        width: width,
                        height: height * 0.04,
                        child: Row(
                          children: [
                            Container(
                              width: width * 0.35,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20.0),
                                child: Text(
                                  'PROVENTOS',
                                  style: estiloCabecalho2,
                                ),
                              ),
                            ),
                            Container(
                              width: width * 0.30,
                              child: Text(
                                'DESCONTOS',
                                style: estiloCabecalho2,
                              ),
                            ),
                            Container(
                              width: width * 0.30,
                              child: Text(
                                'TOTAL LíQUIDO',
                                style: estiloCabecalho2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: height * 0.01),
                    Row(
                      children: [
                        Container(
                          width: width * 0.35,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: Text(
                              'R\$ ${CurrencyFormatter.format(proventos, realSettings)}',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Container(
                          width: width * 0.30,
                          child: Text(
                            'R\$ ${CurrencyFormatter.format(descontos, realSettings)}',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                        Container(
                          width: width * 0.28,
                          child: Text(
                            'R\$ ${CurrencyFormatter.format(totalLiquido, realSettings)}',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: height * 0.01),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            // decoration: BoxDecoration(color: Colors.red),
                            width: width * 0.95,
                            height: height * 0.05,
                            child: Text(
                              '* Dados somente para visualização, nao valido para fins de comprovação, acesse o site do servidor para imprimir seu contracheque oficial',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          print(snapshot.error);
          return SecondScreen();
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      }),
    );
  }
}
