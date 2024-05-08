import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

import '../models/militar.dart';
import '../models/telefone.dart';

class DadosContato extends StatefulWidget {
  final Militar militar;
  final Function atualizarDados;
  const DadosContato(
      {Key? key, required this.militar, required this.atualizarDados})
      : super(key: key);

  @override
  State<DadosContato> createState() => _DadosContatoState();
}

class _DadosContatoState extends State<DadosContato> {
  late TextEditingController controllerTextFielContato;

  late ScrollController _controllerOne = ScrollController();

  @override
  void initState() {
    // TODO: implement initState
    controllerTextFielContato = TextEditingController();
    controllerTextFielContato.text = '95';
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controllerTextFielContato.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(2.0),
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
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 4,
                    offset: Offset(2, 2), // Shadow position
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 10),
                      Text(
                        'Contato',
                        style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.all(2),
                    onPressed: () {
                      openDialogAddContato(widget.militar.telefones);
                      widget.militar.alterouDados = true;
                      widget.atualizarDados();
                    },
                    icon: Icon(
                      Icons.add_call,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(3.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NÚMERO',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: width * 0.25),
                        Text(
                          'WHATSAPP',
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
                      height: height * 0.10,
                      child: Scrollbar(
                        controller: _controllerOne,
                        child: ListView.builder(
                          controller: _controllerOne,
                          shrinkWrap: true,
                          itemCount: widget.militar.telefones.length,
                          itemBuilder: ((context, index) {
                            return Padding(
                              padding: const EdgeInsets.all(1.0),
                              child: Container(
                                height: height * 0.04,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey,
                                      blurRadius: 4,
                                      offset: Offset(2, 2), // Shadow position
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: width * 0.45,
                                      child: Text(
                                        widget
                                            .militar.telefones[index].numeroTel,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: width * 0.32,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Checkbox(
                                              value: widget.militar
                                                  .telefones[index].value,
                                              onChanged: ((value) {
                                                //LIMPA TODOS OS TELEFONE, COLOCA TODOS COMO COMUM NOVAMENTE
                                                widget.militar.telefones
                                                    .forEach(
                                                  (element) {
                                                    element.value = false;
                                                    element.tipo = Tipos.comum;
                                                  },
                                                );
                                                if (value == true) {
                                                  widget.militar.telefones
                                                      .elementAt(index)
                                                      .tipo = Tipos.whats;
                                                } else {
                                                  widget.militar.telefones
                                                      .elementAt(index)
                                                      .tipo = Tipos.comum;
                                                }

                                                widget.militar.alterouDados =
                                                    true;

                                                setState(() {
                                                  widget
                                                      .militar
                                                      .telefones[index]
                                                      .value = value!;
                                                });

                                                widget.atualizarDados();
                                              })),
                                          const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 1),
                                              child: Image(
                                                image: AssetImage(
                                                    'assets/imagens/whatsapp.png'),
                                              )),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                        color: Colors.red,
                                        padding: const EdgeInsets.all(2),
                                        onPressed: () {
                                          if (widget.militar.telefones.length <=
                                              1) {
                                            QuickAlert.show(
                                              confirmBtnText: 'OK',
                                              context: context,
                                              type: QuickAlertType.error,
                                              title: 'Opa..',
                                              text:
                                                  'Voce precisa ter ao menos um contato cadastrado',
                                              backgroundColor: Colors.white,
                                              titleColor: Colors.black,
                                              textColor: Colors.black,
                                            );
                                          } else {
                                            openDialogExcluiContato(
                                                widget.militar.telefones,
                                                index);
                                            widget.militar.alterouDados = true;
                                            widget.atualizarDados();
                                          }
                                        },
                                        icon: Icon(Icons.delete)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  // ElevatedButton.icon(
                  //   onPressed: () {
                  //     openDialogAddContato(widget.militar.telefones);
                  //     widget.militar.alterouDados = true;
                  //     widget.atualizarDados();
                  //   },
                  //   icon: Icon(
                  //     Icons.add_call,
                  //     size: 24,
                  //   ),
                  //   label: Text(
                  //     'Novo',
                  //     style: TextStyle(fontSize: 12),
                  //   ),
                  //   style: ElevatedButton.styleFrom(
                  //     primary: Colors.blue,
                  //     onPrimary: Colors.white,
                  //     shadowColor: Colors.grey,
                  //     elevation: 2,
                  //     shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10.0)),
                  //     minimumSize: Size(11, 8), //////// HERE
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Adiciona novo número de telefone
  Future openDialogAddContato(List<Telefone> listaContatos) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue.shade300,
        title: Text('Adicionar novo contato'),
        content: TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            return value!.length != 11
                ? 'o número precisa conter 11 dígitos'
                : '';
          },
          controller: controllerTextFielContato,
          decoration: InputDecoration(hintText: 'Digite o número'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.red, minimumSize: Size(10, 10)),
            onPressed: () {
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
                if (controllerTextFielContato.text.length == 11) {
                  listaContatos.add(Telefone(
                      numeroTel: controllerTextFielContato.text,
                      tipo: Tipos.comum,
                      value: false));
                  controllerTextFielContato.text = '95';
                  setState(() {});
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                'Adiconar',
                style: TextStyle(color: Colors.white),
              ))
        ],
      ),
    );
  }

  //Adiciona novo número de telefone
  Future openDialogExcluiContato(List<Telefone> listaContatos, int index) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Deseja excluir o contato: ${listaContatos.elementAt(index).numeroTel}?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.red, minimumSize: Size(10, 10)),
            onPressed: () {
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
                listaContatos.removeAt(index);
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Text(
                'Excluir',
                style: TextStyle(color: Colors.white),
              ))
        ],
      ),
    );
  }
}
