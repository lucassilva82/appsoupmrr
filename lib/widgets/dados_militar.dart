import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import 'card_image_militar.dart';
import 'dados_contato.dart';
import 'dados_endereco.dart';
import 'dados_principal.dart';

class DadosMilitar extends StatefulWidget {
  final Militar militar;

  const DadosMilitar({Key? key, required this.militar}) : super(key: key);

  @override
  State<DadosMilitar> createState() => _DadosMilitarState();
}

class _DadosMilitarState extends State<DadosMilitar> {
  @override
  Widget build(BuildContext context) {
    print('militares ${widget.militar.telefones}');
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    DadosSql dadosSql = DadosSql();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white),
      //Coluna central da pagina
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                CardImageMilitar(urlImage: widget.militar.imageUrl),
                SizedBox(width: 10),
                DadosPrincipal(militar: widget.militar),
              ],
            ),
          ),
          SizedBox(height: 1),
          DadosEndereco(militar: widget.militar),
          DadosContato(
            militar: widget.militar,
            atualizarDados: atualizarDados,
          ),
          SizedBox(height: 6),
          widget.militar.alterouDados == true
              ? ElevatedButton(
                  onPressed: () async {
                    try {
                      await dadosSql.excluiContatos(widget.militar.matricula);
                      widget.militar.telefones.forEach((element) async {
                        String tipo = element.value == false ? '0' : '1';
                        await dadosSql.adicionaContatos(
                            widget.militar.matricula, element.numeroTel, tipo);
                      });
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
                )
              : Container()
        ],
      ),
    );
  }

  atualizarDados() {
    setState(() {});
  }
}
