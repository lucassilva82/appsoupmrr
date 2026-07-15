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
    Choice(title: 'SVI', icon: Icons.more_time_rounded, id: 11),
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

  // Recursos ainda em desenvolvimento — indisponíveis para o usuário final.
  static const Set<int> _emDesenvolvimento = {2, 11}; // Escalas e SVI

  bool get _isEmDesenvolvimento => _emDesenvolvimento.contains(choice.id);

  Future<void> _onTap(BuildContext context) async {
    if (_isEmDesenvolvimento) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final amber = const Color(0xFFC77800); // âmbar suave
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            elevation: 2,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor:
                isDark ? const Color(0xFF2A2620) : const Color(0xFFFFF6E9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: amber.withOpacity(0.25)),
            ),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: amber.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.hourglass_top_rounded, color: amber, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Em desenvolvimento',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark
                              ? const Color(0xFFF3E6CE)
                              : const Color(0xFF5A4416),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Este recurso estará disponível em breve.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: isDark
                              ? const Color(0xFFB9AD97)
                              : const Color(0xFF8A7350),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      return;
    }
    switch (choice.id) {
      case 1:
        Navigator.of(context).pushNamed(AppRoutes.PAGE_MILITAR);
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.ESCALAS);
        break;
      case 11:
        Navigator.of(context).pushNamed(AppRoutes.SVI_ESCALAS);
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
            Opacity(
              opacity: _isEmDesenvolvimento ? 0.45 : 1.0,
              child: Center(
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
            ),
            if (isPrivileged)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.star_rounded,
                    size: 12, color: AppColors.gold.withOpacity(0.7)),
              ),
            if (_isEmDesenvolvimento)
              Positioned(
                top: 6,
                left: 6,
                right: 6,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC77800)
                          .withOpacity(isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFC77800).withOpacity(0.30),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC77800),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Em breve',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFE9C68A)
                                  : const Color(0xFF9A5E00),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
