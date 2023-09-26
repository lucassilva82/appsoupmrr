import 'package:flutter/material.dart';

import '../widgets/drawer_personalizado.dart';

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
        title: const Text('TESTANDOdsfsdfdsf'),
      ),
      drawer: Drawerpersonalizado(),
      body: Container(),
    );
  }
}
