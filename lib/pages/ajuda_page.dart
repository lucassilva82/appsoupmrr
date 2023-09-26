import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/drawer_personalizado.dart';

class AjudaPage extends StatelessWidget {
  const AjudaPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuda DTI'),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(
        //     colors: [
        //       Color.fromARGB(255, 176, 186, 232),
        //       Color.fromARGB(255, 148, 191, 255),
        //     ],
        //     begin: Alignment.centerLeft,
        //     end: Alignment.topRight,
        //   ),
        // ),
        child: Column(
          children: [
            Image(image: AssetImage('assets/imagens/help.png')),
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            Container(
              width: MediaQuery.of(context).size.width * 0.80,
              child: Text(
                'Caso tenha alguma dúvida ou sugestão, entre em contato com o DTIPMRR',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.10),
            Container(
              child: InkWell(
                onTap: () {
                  final snackBar = SnackBar(
                    content:
                        const Text('Em breve poderá solicitar ajuda - DTIPMRR'),
                    // action: SnackBarAction(
                    //   label: 'Undo',
                    //   onPressed: () {
                    //     // Some code to undo the change.
                    //   },
                    // ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  // abrirWhatsApp(
                  //     context: context,
                  //     text:
                  //         'Olá, tudo bem, gostaria de me cadastrar no aplicativo Escala PMRR?',
                  //     number: '95991298238');
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.20,
                  decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      // border: Border.all(width: 0.5),
                      borderRadius: BorderRadius.all(Radius.circular(6))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Text(
                      //   'Solicitar Ajuda',
                      //   style: TextStyle(color: Colors.black, fontSize: 16),
                      // ),
                      IconButton(
                        onPressed: null,
                        icon: Image.asset('assets/imagens/whatsapp.png'),
                        // color: Colors.orange,
                        tooltip: 'Abrir Whatsapp',
                        iconSize: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawerpersonalizado(),
    );
  }

  void abrirWhatsApp(
      {required BuildContext context,
      required String text,
      required String number}) async {
    var whatsapp = '+55' + number; //+92xx enter like this
    var whatsappURlAndroid =
        "whatsapp://send?phone=" + whatsapp + "&text=$text";
    var whatsappURLIos = "https://wa.me/$whatsapp?text=${Uri.tryParse(text)}";
    print(whatsapp);
    if (Platform.isIOS) {
      // for iOS phone only
      if (await canLaunchUrl(Uri.parse(whatsappURLIos))) {
        await launchUrl(Uri.parse(
          whatsappURLIos,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Whatsapp not installed")));
      }
    } else {
      // android , web
      if (await canLaunchUrl(Uri.parse(whatsappURlAndroid))) {
        await launchUrl(Uri.parse(whatsappURlAndroid));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Whatsapp not installed")));
      }
    }
  }
}
