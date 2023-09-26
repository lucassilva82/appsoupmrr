import 'package:flutter/material.dart';

import '../widgets/drawer_personalizado.dart';

class Configuracoes extends StatelessWidget {
  const Configuracoes({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracoes'),
      ),
      body: Center(
          child: Container(
        child: Text('TELA DE CONFIGURACOES'),
      )),
      drawer: Drawerpersonalizado(),
    );
  }
}
