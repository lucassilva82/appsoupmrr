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
  final formKey = GlobalKey<FormState>();
  @override
  _EdicaoEnderecoPageState createState() => _EdicaoEnderecoPageState();
}

class _EdicaoEnderecoPageState extends State<EdicaoEnderecoPage> {
  DadosSql dadosSql = DadosSql();
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    if (widget.inicio == true) {
      widget.enderecoCompleto = widget.militar.endereco;
      widget.controllerCep.text = widget.enderecoCompleto.cep!;
      widget.controllerMunicipio.text = widget.enderecoCompleto.municipio!.nome;
      widget.controllerRua.text = widget.enderecoCompleto.rua!.nome;
      widget.controllerNumero.text = widget.enderecoCompleto.numero!;
      widget.controllerBairro.text = widget.enderecoCompleto.bairro!.nome;

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
                      Container(
                          child: Text(
                        'Buscar:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      )),
                      SizedBox(width: width * 0.03),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Container(
                          // decoration: BoxDecoration(
                          //     color: Colors.blue.shade200,
                          //     borderRadius: BorderRadius.circular(5)),
                          width: width * 0.63,
                          height: height * 0.06,
                          child: TypeAheadField<Endereco?>(
                            minCharsForSuggestions: 4,
                            noItemsFoundBuilder: (context) {
                              return ListTile(
                                title: Text(
                                  'Nenhum item encontrado',
                                  style: TextStyle(fontSize: 11),
                                ),
                              );
                            },
                            textFieldConfiguration: TextFieldConfiguration(
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(fontSize: 11),
                                  hintText: 'digite o nome da rua ou bairro',
                                ),
                                style: TextStyle(fontSize: 12),
                                controller: widget.controllerEnderecoNovo),
                            suggestionsCallback:
                                widget.dadosSql.listaEnderecoCompleto,
                            itemBuilder: (context, Endereco? suggestion) {
                              final end = suggestion!;
                              return ListTile(
                                title: Text(
                                  end.logradouro!,
                                  style: TextStyle(fontSize: 11),
                                ),
                              );
                            },
                            onSuggestionSelected: (Endereco? suggestion) {
                              alteraEndereco(suggestion!);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                          onPressed: limpaDados,
                          icon: Icon(
                            Icons.delete,
                            color: Colors.blue,
                          ))
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                width: width * 0.99,
                height: height * 0.20,
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
                          SizedBox(
                            width: 10,
                          ),
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
                                  widget.enderecoCompleto.municipio!.nome,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.alterouDados == true
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
                                '${widget.enderecoCompleto.rua!.nome}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: widget.alterouDados == true
                                        ? Colors.green
                                        : Colors.black),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Número: ',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${widget.enderecoCompleto.numero}',
                                style: TextStyle(
                                    color: widget.alterouDados == true
                                        ? Colors.green
                                        : Colors.black),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 10),
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
                                  widget.enderecoCompleto.bairro!.nome,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: widget.alterouDados == true
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
                                Text(
                                  widget.enderecoCompleto.cep!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: widget.alterouDados == true
                                          ? Colors.green
                                          : Colors.black),
                                ),
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
            SizedBox(height: height * 0.47),
            widget.alterouDados == true
                ? Container(
                    child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await dadosSql.atualizaEndereco(
                          widget.enderecoCompleto.municipio!.id,
                          widget.enderecoCompleto.bairro!.id,
                          widget.enderecoCompleto.rua!.id,
                          widget.enderecoCompleto.numero!,
                          widget.enderecoCompleto.cep!,
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
                          // autoCloseDuration: const Duration(seconds: 2),
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
                          // autoCloseDuration: const Duration(seconds: 2),
                        );
                        print('error $error');
                      }
                    },
                    child: Text('Salvar Alterações'),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.blue,
                      onPrimary: Colors.white,
                      shadowColor: Colors.grey,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      minimumSize: Size(15, 25), //////// HERE
                    ),
                  ))
                : Container(),
          ],
        ),
      ),
    );
  }

  alteraEndereco(Endereco end) {
    widget.alterouDados = true;
    widget.enderecoCompleto = end;
    widget.controllerEnderecoNovo.text = end.logradouro!;
    widget.controllerCep.text = '';
    widget.controllerNumero.text = '';
    openDialogAlteraNumeroCep();
  }

  limpaDados() {
    widget.controllerEnderecoNovo.text = '';
    widget.alterouDados = false;
    widget.enderecoCompleto = widget.militar.endereco;
  }

  Future openDialogAlteraNumeroCep() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Complete os dados'),
          ],
        ),
        content: Container(
          height: MediaQuery.of(context).size.height * 0.25,
          child: Form(
            key: widget.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Nº: '),
                      SizedBox(width: 7),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.40,
                        child: TextFormField(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor digite o número';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: widget.controllerNumero,
                          decoration: InputDecoration(
                            hintStyle: TextStyle(fontSize: 11),
                            hintText: 'Digite o número da residencia',
                          ),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('CEP: '),
                      SizedBox(width: 7),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.40,
                        child: TextFormField(
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty ||
                                value.length < 8) {
                              return 'Digite um CEP válido';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: widget.controllerCep,
                          decoration: InputDecoration(
                              hintStyle: TextStyle(fontSize: 11),
                              hintText: 'Digite o CEP da residencia'),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.red, minimumSize: Size(10, 10)),
            onPressed: () {
              limpaDados();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: Colors.green, minimumSize: Size(10, 10)),
              onPressed: () {
                if (widget.formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  widget.enderecoCompleto.cep = widget.controllerCep.text;
                  widget.enderecoCompleto.numero = widget.controllerNumero.text;
                  widget.alterouDados = true;
                  setState(() {});
                }
              },
              child: Text(
                'Salvar',
                style: TextStyle(color: Colors.white),
              ))
        ],
      ),
    );
  }
}
