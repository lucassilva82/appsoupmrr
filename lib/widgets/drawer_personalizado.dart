import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';

class Drawerpersonalizado extends StatelessWidget {
  const Drawerpersonalizado({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Auth auth = Provider.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.70,
      child: ListView(
        children: <Widget>[
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
                color: Colors.lightBlue.shade600,
                image: DecorationImage(
                    opacity: 80.0,
                    fit: BoxFit.fill,
                    image: AssetImage(
                      'assets/imagens/fotocapa.jpeg',
                    ))),
            accountName: Text('${auth.nomeMilitar}'),
            accountEmail: Text('Matrícula: ${auth.matricula}'),
            currentAccountPicture: CircleAvatar(
              radius: 40.0,
              backgroundImage: NetworkImage(auth.image ?? ''),
              backgroundColor: Colors.transparent,
            ),
          ),
          ListTile(
              leading: Icon(Icons.home),
              title: Text("Home"),
              // subtitle: Text("atualize seus dados..."),
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE);
              }),
          ListTile(
              leading: Icon(Icons.account_circle),
              title: Text("Ficha Individual"),
              // subtitle: Text("atualize seus dados..."),
              onTap: () {
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.PAGE_MILITAR);
              }),
          ListTile(
              leading: Icon(Icons.car_crash),
              title: Text("Meu Plantao"),
              // subtitle: Text("atualize seus dados..."),
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.PLANTAO);
              }),
          // ListTile(
          //   leading: Icon(Icons.attach_money),
          //   title: Text("Meu Patrimonio"),
          //   // subtitle: Text("atualize seus dados..."),

          //   // onTap: () {
          //   //   Navigator.of(context)
          //   //       .pushReplacementNamed(AppRoutes.DECLARACOES_IRPF_PAGE);
          //   // },
          // ),
          ListTile(
              leading: Icon(Icons.request_quote),
              title: Text("Contracheques"),
              // subtitle: Text("atualize seus dados..."),
              onTap: () {
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.CONTRACHEQUE_PAGE);
              }),
          // ListTile(
          //     leading: Icon(Icons.settings),
          //     title: Text("Configurações"),
          //     // subtitle: Text("atualize seus dados..."),
          //     onTap: () {
          //       Navigator.of(context)
          //           .pushReplacementNamed(AppRoutes.CONFIGURACOES);
          //     }),
          ListTile(
              leading: Icon(Icons.help_center_rounded),
              title: Text("Ajuda"),
              // subtitle: Text("atualize seus dados..."),
              onTap: () {
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.AJUDA_PAGE);
              }),
          ListTile(
              leading: Icon(Icons.logout_rounded),
              title: Text("Sair"),
              onTap: () {
                auth.logout();
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.AUTH_OR_HOME);
              }),
        ],
      ),
    );
  }
}
