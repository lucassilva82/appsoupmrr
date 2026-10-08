import 'package:flutter/material.dart';

import '../widgets/drawer_personalizado.dart';
import '../widgets/barra_vidro.dart';

class PlanoDeFerias extends StatefulWidget {
  const PlanoDeFerias({Key? key}) : super(key: key);

  @override
  _PlanoDeFeriasState createState() => _PlanoDeFeriasState();
}

class _PlanoDeFeriasState extends State<PlanoDeFerias> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const FundoBarraVidro(),
        title: const Text('TESTANDOdsfsdfdsf'),
      ),
      drawer: DrawerPersonalizado(),
      body: Container(),
    );
  }
}
