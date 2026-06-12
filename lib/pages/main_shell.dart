import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';
import '../utils/notification_provider.dart';
import '../utils/theme_provider.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import 'page_militar.dart';
import 'configuracoes.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Carrega notificações ao entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .loadNotifications();
    });
  }

  static const _labels = ['Início', 'Avisos', 'Perfil', 'Config.'];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);

    final isSuperUser = auth.isSuperUser;
    final isDark = themeProvider.isDark;
    final unread = notifProvider.notifications.where((n) => !n.clicked).length;
    final nome = auth.nomeMilitar ?? 'Militar';

    final gradColors =
        AppTheme.appBarGradient(isDark: isDark, isSuperUser: isSuperUser);

    return Scaffold(
      // ── AppBar dinâmico ─────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _buildAppBarContent(
              context,
              nome: nome,
              isSuperUser: isSuperUser,
              unread: unread,
              notifProvider: notifProvider,
            ),
          ),
        ),
      ),

      // ── Corpo com IndexedStack (preserva estado entre abas) ──────────────
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeBody(),
          NotificationsBody(),
          PageMilitarBody(),
          SettingsBody(),
        ],
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: _labels[0],
            ),
            BottomNavigationBarItem(
              icon: _badgedIcon(Icons.notifications_outlined, unread),
              activeIcon: _badgedIcon(Icons.notifications_rounded, unread),
              label: _labels[1],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: _labels[2],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings_rounded),
              label: _labels[3],
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar content ────────────────────────────────────────────────────────
  Widget _buildAppBarContent(
    BuildContext context, {
    required String nome,
    required bool isSuperUser,
    required int unread,
    required NotificationProvider notifProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 8),

          // Título dinâmico por aba
          Expanded(
            child: _currentIndex == 0
                ? _titleHome(nome, isSuperUser)
                : Text(
                    [
                      'Início',
                      'Notificações',
                      'Ficha Individual',
                      'Configurações'
                    ][_currentIndex],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),

          // Ações à direita
          if (_currentIndex == 0) ...[
            _notificationBell(unread),
          ],
          if (_currentIndex == 1 && unread > 0)
            TextButton(
              onPressed: () => notifProvider.markAllAsRead(),
              child: const Text(
                'Limpar tudo',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _titleHome(String nome, bool isSuperUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSuperUser) ...[
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            'Olá, $nome',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (isSuperUser) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'GESTOR',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _notificationBell(int count) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => setState(() => _currentIndex = 1),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _badgedIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
