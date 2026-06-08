import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';

class Choice {
  final String title;
  final IconData icon;
  final int id;
  Choice({required this.title, required this.icon, required this.id});
}

class HorizontalMenu extends StatelessWidget {
  HorizontalMenu({Key? key}) : super(key: key);

  final List<Choice> allChoices = <Choice>[
    Choice(title: 'Ficha Individual', icon: Icons.account_circle, id: 1),
    Choice(title: 'Meu Plantão', icon: Icons.car_crash, id: 2),
    Choice(title: 'Plano de Férias', icon: Icons.beach_access, id: 9),
    Choice(title: 'Declarações', icon: Icons.attach_money, id: 3),
    Choice(title: 'Contracheques', icon: Icons.request_quote, id: 4),
    Choice(title: 'Mapa da Força', icon: Icons.groups_2, id: 5),
    Choice(title: 'Certidões', icon: Icons.edit_document, id: 6),
    // Novo atalho para a página de Legislações
    Choice(title: 'Legislações', icon: Icons.library_books, id: 8),
    Choice(title: 'POPS', icon: Icons.gavel, id: 10),
    Choice(title: 'Sair', icon: Icons.logout_rounded, id: 7),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);

    final isUser = auth.isSuperUser;
    // Remove Mapa da Força para usuários comuns
    final choices = allChoices.where((c) => c.id != 5 || isUser).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final menuHeight = screenHeight * 0.20;
    final itemWidth = screenWidth * 0.25;
    final itemHeight = menuHeight * 0.6;

    return Container(
      // color: Colors.amber,
      width: screenWidth,
      height: menuHeight,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
            child: Row(
              children: choices.map((choice) {
                return _MenuItem(
                  choice: choice,
                  itemWidth: itemWidth,
                  itemHeight: itemHeight,
                  isPrivileged: choice.id == 5,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final Choice choice;
  final double itemWidth;
  final double itemHeight;
  final bool isPrivileged;

  const _MenuItem(
      {Key? key,
      required this.choice,
      required this.itemWidth,
      required this.itemHeight,
      this.isPrivileged = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Auth não é utilizado diretamente neste widget

    // Gradiente padrão:
    // - Mapa da Força (privileged): branco → azul → preto
    // - Plano de Férias (id 6): cinza → cinza escuro
    // - Demais (usuários e outros): azul claro → azul escuro
    final gradientColors = isPrivileged
        ? [Colors.white, const Color.fromARGB(255, 58, 95, 112), Colors.black87]
        : [Colors.lightBlue, Colors.blue.shade900];

    return InkWell(
      onTap: () {
        switch (choice.id) {
          case 1:
            Navigator.of(context).pushNamed(AppRoutes.PAGE_MILITAR);
            break;
          case 2:
            Navigator.of(context).pushNamed(AppRoutes.PLANTAO);
            break;
          case 9:
            Navigator.of(context).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE);
            break;
          case 3:
            Navigator.of(context).pushNamed(AppRoutes.DECLARACOES_PAGE);
            break;
          case 4:
            Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE);
            break;
          case 5:
            Navigator.of(context).pushNamed(AppRoutes.MAPA_DA_FORCA);
            break;
          case 6:
            Navigator.of(context).pushNamed(AppRoutes.CERTIDOES_PAGE);
            break;
          case 8:
            // Navega para a página de Legislações
            Navigator.of(context).pushNamed(AppRoutes.LEGISLACOES_PAGE);
            break;
          case 10:
            Navigator.of(context).pushNamed(AppRoutes.POP_PAGE);
            break;
          case 7:
            QuickAlert.show(
              context: context,
              type: QuickAlertType.confirm,
              title: 'Deseja sair?',
              text: 'Sua sessão será encerrada',
              confirmBtnText: 'Sim',
              cancelBtnText: 'Cancelar',
              confirmBtnColor: Colors.redAccent,
              onConfirmBtnTap: () {
                Provider.of<Auth>(context, listen: false).logout();
                Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.AUTH_OR_HOME,
                );
              },
            );
            break;
        }
      },
      child: Stack(
        children: [
          Container(
            width: itemWidth,
            height: itemHeight,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(2, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(choice.icon, size: itemHeight * 0.5, color: Colors.white),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    choice.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: itemHeight * 0.10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (isPrivileged)
            Positioned(
              top: 8,
              right: 12,
              child: Icon(
                Icons.supervisor_account,
                size: 16,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}
