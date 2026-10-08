import 'dart:ui';
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
import '../widgets/barra_navegacao.dart';
import '../widgets/barra_vidro.dart';

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
    // Conecta o histórico de notificações do militar logado (stream Firestore).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).bindUser();
    });
  }

  // Ordem das abas: Início, Perfil, Avisos, Config.
  static const _abaAvisos = 2;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    // Mantém a assinatura do tema: a barra muda de degradê no claro/escuro.
    Provider.of<ThemeProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);

    final isSuperUser = auth.isSuperUser;
    final isAdmin = auth.nivel == 1;
    final unread = notifProvider.notifications.where((n) => !n.clicked).length;
    final nome = auth.nomeMilitar ?? 'Militar';

    return Scaffold(
      // ── AppBar dinâmico ─────────────────────────────────────────────────────
      // ── AppBar dinâmico ─────────────────────────────────────────────────────
      // A altura precisa somar o recorte do topo (ilha/notch). Sem isso o
      // PreferredSize ficava com 56pt no total, o SafeArea empurrava o
      // conteúdo para baixo e o título encostava na borda inferior.
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          kToolbarHeight + MediaQuery.of(context).padding.top,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: FundoBarraVidro()),
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: _buildAppBarContent(
                  context,
                  nome: nome,
                  isSuperUser: isSuperUser,
                  isAdmin: isAdmin,
                  unread: unread,
                  notifProvider: notifProvider,
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Corpo com IndexedStack (preserva estado entre abas) ──────────────
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeBody(),
          PageMilitarBody(),
          NotificationsBody(),
          SettingsBody(),
        ],
      ),

      // ── Barra inferior ───────────────────────────────────────────────────
      bottomNavigationBar: BarraNavegacao(
        indiceAtual: _currentIndex,
        aoSelecionar: (i) => setState(() => _currentIndex = i),
        itens: [
          const ItemNavegacao(
            icone: Icons.home_outlined,
            iconeAtivo: Icons.home_rounded,
            rotulo: 'Início',
          ),
          const ItemNavegacao(
            icone: Icons.person_outline,
            iconeAtivo: Icons.person_rounded,
            rotulo: 'Perfil',
          ),
          ItemNavegacao(
            icone: Icons.notifications_outlined,
            iconeAtivo: Icons.notifications_rounded,
            rotulo: 'Avisos',
            contador: unread,
          ),
          const ItemNavegacao(
            icone: Icons.settings_outlined,
            iconeAtivo: Icons.settings_rounded,
            rotulo: 'Config.',
          ),
        ],
      ),
    );
  }

  // ── AppBar content ────────────────────────────────────────────────────────
  Widget _buildAppBarContent(
    BuildContext context, {
    required String nome,
    required bool isSuperUser,
    required bool isAdmin,
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
                ? _titleHome(nome, isSuperUser, isAdmin)
                : Text(
                    [
                      'Início',
                      'Ficha Individual',
                      'Notificações',
                      'Configurações'
                    ][_currentIndex],
                    textAlign: TextAlign.center,
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
          if (_currentIndex == _abaAvisos && unread > 0)
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

  Widget _titleHome(String nome, bool isSuperUser, bool isAdmin) {
    final label = isAdmin ? 'Admin' : 'GESTOR';
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
            child: Text(
              label,
              style: const TextStyle(
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
          onPressed: () => setState(() => _currentIndex = _abaAvisos),
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

}
