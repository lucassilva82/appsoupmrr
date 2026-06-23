import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

class Choice {
  final String title;
  final IconData icon;
  final int id;
  Choice({required this.title, required this.icon, required this.id});
}

class HorizontalMenu extends StatelessWidget {
  HorizontalMenu({Key? key}) : super(key: key);

  final List<Choice> allChoices = <Choice>[
    Choice(
        title: 'Ficha Individual', icon: Icons.account_circle_rounded, id: 1),
    Choice(title: 'Escalas', icon: Icons.assignment_rounded, id: 2),
    Choice(title: 'Plano de Férias', icon: Icons.beach_access_rounded, id: 9),
    Choice(title: 'Declarações', icon: Icons.attach_money_rounded, id: 3),
    Choice(title: 'Contracheques', icon: Icons.request_quote_rounded, id: 4),
    Choice(title: 'Mapa da Força', icon: Icons.groups_2_rounded, id: 5),
    Choice(title: 'Certidões', icon: Icons.edit_document, id: 6),
    Choice(title: 'Legislações', icon: Icons.library_books_rounded, id: 8),
    Choice(title: 'POPS', icon: Icons.gavel_rounded, id: 10),
    Choice(title: 'Sair', icon: Icons.logout_rounded, id: 7),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final theme = Theme.of(context);
    final isSuperUser = auth.isSuperUser;

    // Remove Mapa da Força para usuários comuns
    final choices = allChoices.where((c) => c.id != 5 || isSuperUser).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Acesso Rápido',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: choices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              return _GridMenuItem(
                choice: choices[index],
                isSuperUser: isSuperUser,
              );
            },
          ),
        ],
      ),
    );
  }
}
// end of file

class _GridMenuItem extends StatelessWidget {
  final Choice choice;
  final bool isSuperUser;

  const _GridMenuItem({
    Key? key,
    required this.choice,
    required this.isSuperUser,
  }) : super(key: key);

  Future<void> _onTap(BuildContext context) async {
    switch (choice.id) {
      case 1:
        Navigator.of(context).pushNamed(AppRoutes.PAGE_MILITAR);
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.ESCALAS);
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
        Navigator.of(context).pushNamed(AppRoutes.LEGISLACOES_PAGE);
        break;
      case 10:
        Navigator.of(context).pushNamed(AppRoutes.POP_PAGE);
        break;
      case 7:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Deseja sair?'),
            content: const Text('Sua sessão será encerrada.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sim'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          Provider.of<Auth>(context, listen: false).logout();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores especiais por item
    final isPrivileged = choice.id == 5; // Mapa da Força
    final isLogout = choice.id == 7;

    Color bgColor;
    Color iconColor;
    if (isLogout) {
      bgColor = Colors.red.withOpacity(isDark ? 0.18 : 0.10);
      iconColor = Colors.redAccent;
    } else if (isPrivileged) {
      bgColor = AppColors.gold.withOpacity(isDark ? 0.18 : 0.12);
      iconColor = AppColors.gold;
    } else {
      bgColor =
          theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.35 : 0.55);
      iconColor = theme.colorScheme.primary;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(choice.icon, size: 32, color: iconColor),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      choice.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: isLogout
                            ? Colors.redAccent
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isPrivileged)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.star_rounded,
                    size: 12, color: AppColors.gold.withOpacity(0.7)),
              ),
          ],
        ),
      ),
    );
  }
}
