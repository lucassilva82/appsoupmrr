import 'package:flutter/material.dart';

import '../widgets/drawer_personalizado.dart';

class MeuPatrimonioPage extends StatefulWidget {
  const MeuPatrimonioPage({Key? key}) : super(key: key);

  @override
  _MeuPatrimonioPageState createState() => _MeuPatrimonioPageState();
}

class _MeuPatrimonioPageState extends State<MeuPatrimonioPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Patrimonio'),
      ),
      body: Container(
        child: Text('Dados Financeiros'),
      ),
      drawer: Drawerpersonalizado(),
    );
  }
}
