import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:quickalert/quickalert.dart';

import '../models/endereco.dart';
import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';

// ignore: must_be_immutable
class EdicaoEnderecoPage extends StatefulWidget {
  Militar militar;
  EdicaoEnderecoPage({
    Key? key,
    required this.militar,
  }) : super(key: key);
  late Endereco enderecoCompleto;
  bool inicio = true;
  bool alterouDados = false;
  DadosSql dadosSql = DadosSql();
  TextEditingController controllerMunicipio = TextEditingController();
  TextEditingController controllerEnderecoNovo = TextEditingController();
  TextEditingController controllerRua = TextEditingController();
  TextEditingController controllerNumero = TextEditingController();
  TextEditingController controllerCep = TextEditingController();
  TextEditingController controllerBairro = TextEditingController();

  @override
  _EdicaoEnderecoPageState createState() => _EdicaoEnderecoPageState();
}

class _EdicaoEnderecoPageState extends State<EdicaoEnderecoPage> {
  DadosSql dadosSql = DadosSql();

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    if (widget.inicio) {
      widget.enderecoCompleto = widget.militar.endereco;
      widget.controllerCep.text = widget.enderecoCompleto.cep ?? '';
      widget.controllerMunicipio.text =
          widget.enderecoCompleto.municipio?.nome ?? '';
      widget.controllerRua.text = widget.enderecoCompleto.rua?.nome ?? '';
      widget.controllerNumero.text = widget.enderecoCompleto.numero ?? '';
      widget.controllerBairro.text = widget.enderecoCompleto.bairro?.nome ?? '';
      widget.inicio = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atualizar Endereço'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            //Buscar Endereco
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                    color: Color.fromARGB(255, 191, 215, 235),
                    borderRadius: BorderRadius.circular(5)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'Buscar:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: width * 0.03),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Container(
                          width: width * 0.60,
                          height: height * 0.06,
                          child: TypeAheadField<Endereco?>(
                            controller: widget.controllerEnderecoNovo,
                            errorBuilder: (context, error) =>
                                const Text('Error!'),
                            loadingBuilder: (context) =>
                                const Text('Loading...'),
                            emptyBuilder: (context) {
                              return ListTile(
                                title: Text(
                                  'Nenhum item encontrado',
                                  style: TextStyle(fontSize: 11),
                                ),
                              );
                            },
                            builder: (context, controller, focusNode) {
                              return TextField(
                                controller: widget.controllerEnderecoNovo,
                                focusNode: focusNode,
                                obscureText: false,
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(fontSize: 11),
                                  hintText: 'digite o nome da rua ou bairro',
                                ),
                                style: TextStyle(fontSize: 12),
                              );
                            },
                            suggestionsCallback:
                                widget.dadosSql.listaEnderecoCompleto,
                            itemBuilder: (context, Endereco? suggestion) {
                              if (suggestion == null)
                                return const SizedBox.shrink();
                              return ListTile(
                                title: Text(
                                  suggestion.logradouro ?? '',
                                  style: TextStyle(fontSize: 11),
                                ),
                              );
                            },
                            onSelected: (end) {
                              atualizaDados();
                              if (end != null) {
                                alteraEndereco(end);
                              }
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: limpaDados,
                        icon: Icon(
                          Icons.delete,
                          color: Colors.blue,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                width: width * 0.99,
                height: height * 0.25,
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
                            topLeft: Radius.circular(5),
                            topRight: Radius.circular(5)),
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
                          SizedBox(width: 10),
                          Text(
                            'Endereço',
                            style: TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Município: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.enderecoCompleto.municipio?.nome ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.alterouDados
                                        ? Colors.green
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: width * 0.99,
                            height: height * 0.04,
                            child: Row(children: [
                              Text(
                                'Rua: ',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.enderecoCompleto.rua?.nome ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: widget.alterouDados
                                        ? Colors.green
                                        : Colors.black),
                              ),

                              // Text(
                              //   widget.enderecoCompleto.numero ?? '',
                              //   style: TextStyle(
                              //       color: widget.alterouDados
                              //           ? Colors.green
                              //           : Colors.black),
                              // ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Número: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  width: width * 0.32,
                                  height: 13,
                                  child: TextField(
                                    readOnly: widget.alterouDados == true
                                        ? false
                                        : true,
                                    expands: false,
                                    controller: widget.controllerNumero,
                                    decoration: InputDecoration(
                                      border: widget.alterouDados == true
                                          ? null
                                          : InputBorder.none,
                                      hintStyle: TextStyle(
                                          fontSize: 12, color: Colors.red),
                                      hintText: 'número da residencia',
                                    ),
                                    keyboardType: TextInputType.number,
                                    autofocus: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 17),
                          Container(
                            child: Row(
                              children: [
                                Text(
                                  'Bairro: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  widget.enderecoCompleto.bairro?.nome ?? '',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: widget.alterouDados
                                          ? Colors.green
                                          : Colors.black),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'CEP: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  width: width * 0.30,
                                  height: 13,
                                  child: TextField(
                                    readOnly: widget.alterouDados == true
                                        ? false
                                        : true,
                                    controller: widget.controllerCep,
                                    decoration: InputDecoration(
                                      border: widget.alterouDados == true
                                          ? null
                                          : InputBorder.none,
                                      hintStyle: TextStyle(
                                          fontSize: 12, color: Colors.red),
                                      hintText: 'cep da residencia',
                                    ),
                                    keyboardType: TextInputType.number,
                                    autofocus: true,
                                  ),
                                ),
                                // Text(
                                //   widget.enderecoCompleto.cep ?? '',
                                //   style: TextStyle(
                                //       fontSize: 12,
                                //       color: widget.alterouDados
                                //           ? Colors.green
                                //           : Colors.black),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: height * 0.30),
            widget.alterouDados
                ? Container(
                    child: ElevatedButton(
                    onPressed: () async {
                      if (widget.controllerNumero.text.isEmpty ||
                          widget.controllerCep.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('Por favor preencha todos os campos')));
                      } else {
                        widget.enderecoCompleto.cep = widget.controllerCep.text;
                        widget.enderecoCompleto.numero =
                            widget.controllerNumero.text;
                        try {
                          await dadosSql.atualizaEndereco(
                            widget.enderecoCompleto.municipio?.id ?? '',
                            widget.enderecoCompleto.bairro?.id ?? '',
                            widget.enderecoCompleto.rua?.id ?? '',
                            widget.enderecoCompleto.numero ?? '',
                            widget.enderecoCompleto.cep ?? '',
                            widget.militar.matricula,
                          );
                          QuickAlert.show(
                            onConfirmBtnTap: () {
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.PAGE_MILITAR);
                            },
                            context: context,
                            title: 'Sucesso',
                            confirmBtnText: 'OK',
                            type: QuickAlertType.success,
                            text: 'Dados Atualizados, Obrigado',
                          );
                        } catch (error) {
                          QuickAlert.show(
                            onConfirmBtnTap: () {
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.PAGE_MILITAR);
                            },
                            context: context,
                            title: 'Error',
                            confirmBtnText: 'OK',
                            type: QuickAlertType.error,
                            text: 'Erro ao enviar os dados, tente novamente',
                          );
                          print('error $error');
                        }
                      }
                    },
                    child: Text('Salvar Alterações',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shadowColor: Colors.grey,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      minimumSize: Size(15, 25),
                    ),
                  ))
                : Container(),
          ],
        ),
      ),
    );
  }

  alteraEndereco(Endereco end) {
    setState(() {
      widget.alterouDados = true;
      widget.enderecoCompleto = end;
      widget.controllerEnderecoNovo.text = end.logradouro ?? '';
      widget.controllerCep.text = '';
      widget.controllerNumero.text = '';
    });
    // openDialogAlteraNumeroCep();
  }

  limpaDados() {
    setState(() {
      widget.controllerEnderecoNovo.text = '';
      widget.alterouDados = false;
      widget.enderecoCompleto = widget.militar.endereco;
    });
  }

  atualizaDados() {
    setState(() {
      widget.alterouDados = true;
    });
  }
}
