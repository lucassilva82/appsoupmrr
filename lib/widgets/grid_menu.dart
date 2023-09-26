import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';

class Choice {
  final String title;
  final IconData icon;
  Color color;
  final int id;
  Choice(
      {required this.title,
      required this.icon,
      required this.id,
      required this.color});
}

// ignore: must_be_immutable
class GridMenu extends StatelessWidget {
  GridMenu({Key? key}) : super(key: key);

  List<Choice> choices = <Choice>[
    Choice(
        title: 'Ficha Individual',
        icon: Icons.account_circle,
        id: 1,
        color: Colors.blue),
    Choice(
        title: 'Meu Plantao', icon: Icons.car_crash, id: 2, color: Colors.blue),
    Choice(
        title: 'Meu Patrimonio',
        icon: Icons.attach_money,
        id: 3,
        color: Colors.grey),
    Choice(
        title: 'Contracheques',
        icon: Icons.request_quote,
        id: 4,
        color: Colors.blue),
    Choice(
        title: 'Plano de Férias',
        icon: Icons.surfing,
        id: 5,
        color: Colors.grey),
    Choice(
        title: 'Sair', icon: Icons.logout_rounded, id: 6, color: Colors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Container(
      // decoration: BoxDecoration(color: Colors.red),
      width: width * 0.99,
      height: height * 0.40,
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 8.0,
        children: List.generate(choices.length, (index) {
          return Center(
            child: SelectCard(choice: choices[index]),
          );
        }),
      ),
    );
  }
}

class SelectCard extends StatelessWidget {
  SelectCard({required this.choice});
  final Choice choice;

  @override
  Widget build(BuildContext context) {
    final snackBar = SnackBar(
      content: const Text('Módulo em desenvolvimento - DTIPMRR'),
      // action: SnackBarAction(
      //   label: 'Undo',
      //   onPressed: () {
      //     // Some code to undo the change.
      //   },
      // ),
    );
    Auth auth = Provider.of(context);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return InkWell(
      onTap: () {
        if (choice.id == 1) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.PAGE_MILITAR);
        }
        if (choice.id == 2) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.PLANTAO);
        }
        if (choice.id == 3) {
          // Navigator.of(context)
          //     .pushReplacementNamed(AppRoutes.DECLARACOES_IRPF_PAGE);
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
        if (choice.id == 4) {
          Navigator.of(context)
              .pushReplacementNamed(AppRoutes.CONTRACHEQUE_PAGE);
        }
        if (choice.id == 5) {
          // Navigator.of(context).pushReplacementNamed(AppRoutes.PLANODEFERIAS);
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
        if (choice.id == 6) {
          auth.logout();
          Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_OR_HOME);
        }
      },
      child: Container(
        width: width * 0.35,
        height: height * 0.20,
        child: Card(
            color: choice.color,
            child: Center(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                        child:
                            Icon(choice.icon, size: 50.0, color: Colors.white)),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        choice.title,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ]),
            )),
      ),
    );
  }
}
