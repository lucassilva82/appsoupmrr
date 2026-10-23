import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/log/registro_log.dart';
import '../features/servicos/servicos_page.dart';
import '../models/auth_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/notification_provider.dart';
import '../utils/theme_provider.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import '../features/servicos/busca_page.dart';
import 'configuracoes.dart';
import '../widgets/barra_lateral.dart';
import '../widgets/barra_navegacao.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/vidro.dart';

/// Rotas que só existem no navegador raiz (login, abertura, o próprio
/// shell). Pedidas de dentro de uma aba, vão para a raiz.
const _rotasDaRaiz = {
  AppRoutes.AUTH_OR_HOME,
  AppRoutes.AUTH_PAGE,
  AppRoutes.BIOMETRIC_AUTH_PAGE,
  AppRoutes.HOME_PAGE,
};

/// O app logado: 4 abas (docs/SOUPM_2_2.md §3.1), cada uma com o próprio
/// navegador, para a barra de abas não sumir quando uma função abre.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  /// Evita agendar a saída mais de uma vez: `build` roda várias vezes entre
  /// o toque em "Sair" e a troca de tela.
  bool _saindo = false;

  final _navegadores = List.generate(4, (_) => GlobalKey<NavigatorState>());

  // Ordem das abas: Início, Serviços, Avisos, Perfil.
  static const _abaAvisos = 2;
  static const _chavesAba = ['aba.inicio', 'aba.servicos', 'aba.avisos', 'aba.perfil'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    // Conecta o histórico de notificações do militar logado (stream Firestore).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).bindUser();
      // Entra na intranet em segundo plano, para Escalas, SVI e os avisos do
      // SIGE já abrirem com a sessão pronta (sem pedir senha).
      final auth = Provider.of<Auth>(context, listen: false);
      EscalaService().entrarEmSegundoPlano(
        matricula: auth.matricula,
        senhaApp: auth.password,
      );
    });
  }

  void _irPara(int i) {
    if (i == _currentIndex) {
      // Tocar de novo na aba ativa volta ao começo dela (padrão do iOS).
      _navegadores[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    registrar('tela.abrir', chave: _chavesAba[i], dados: {'de': 'aba'});
    setState(() => _currentIndex = i);
  }

  /// Voltar do Android: primeiro dentro da aba, depois para a Início, e só
  /// então sai do app.
  void _voltar() {
    final nav = _navegadores[_currentIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    } else {
      SystemNavigator.pop();
    }
  }

  Route<dynamic>? _rota(RouteSettings settings, Widget raiz) {
    if (settings.name == Navigator.defaultRouteName) {
      return MaterialPageRoute(settings: settings, builder: (_) => raiz);
    }
    final nome = settings.name;
    if (_rotasDaRaiz.contains(nome)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context, rootNavigator: true)
            .pushNamed(nome!, arguments: settings.arguments);
      });
      return null;
    }
    final app = context.findAncestorWidgetOfExactType<MaterialApp>();
    final construtor = app?.routes?[nome];
    if (construtor != null) {
      return MaterialPageRoute(settings: settings, builder: construtor);
    }
    return app?.onGenerateRoute?.call(settings);
  }

  Widget _aba(int i, Widget raiz) => HeroControllerScope(
        controller: MaterialApp.createMaterialHeroController(),
        child: Navigator(
          key: _navegadores[i],
          onGenerateRoute: (s) => _rota(s, raiz),
          onUnknownRoute: (s) => MaterialPageRoute(
              settings: s, builder: (_) => raiz),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);

    // ── Fim de sessão ───────────────────────────────────────────────────
    // O login entra por `pushReplacementNamed(HOME_PAGE)`, então o MainShell
    // é uma **rota** e o AuthOrHome — que é quem observa a autenticação —
    // some da pilha. Sem isto, `logout()` mudava o estado e a tela não se
    // mexia: o militar tocava em Sair, confirmava, e continuava onde estava.
    // Só fechando e reabrindo o app, porque aí o AuthOrHome roda de novo.
    //
    // A guarda fica aqui, e não em cada chamada de `logout()`, porque são
    // quatro lugares hoje — menu, drawer, configurações e biometria — e a
    // quinta que aparecer vai esquecer de navegar.
    //
    // Vale também para a expiração do prazo de sessão, que é o outro jeito
    // de `isAuth` virar falso com a tela aberta.
    if (!auth.isAuth && !_saindo) {
      _saindo = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          AppRoutes.AUTH_PAGE,
          (_) => false,
        );
      });
    }

    final notifProvider = Provider.of<NotificationProvider>(context);
    final unread = notifProvider.notifications.where((n) => !n.clicked).length;

    final abas = IndexedStack(
      index: _currentIndex,
      children: [
        _aba(0, _RaizAba(indice: 0, irPara: _irPara, child: const HomeBody())),
        _aba(1, _RaizAba(indice: 1, irPara: _irPara, child: const ServicosBody())),
        _aba(2, _RaizAba(indice: 2, irPara: _irPara, child: const NotificationsBody())),
        _aba(3, _RaizAba(indice: 3, irPara: _irPara, child: const SettingsBody())),
      ],
    );
    final itens = [
      const ItemNavegacao(
        icone: Icons.home_outlined,
        iconeAtivo: Icons.home_rounded,
        rotulo: 'Início',
      ),
      const ItemNavegacao(
        icone: Icons.apps_outlined,
        iconeAtivo: Icons.apps_rounded,
        rotulo: 'Serviços',
      ),
      ItemNavegacao(
        icone: Icons.notifications_outlined,
        iconeAtivo: Icons.notifications_rounded,
        rotulo: 'Avisos',
        contador: unread,
      ),
      const ItemNavegacao(
        icone: Icons.person_outline,
        iconeAtivo: Icons.person_rounded,
        rotulo: 'Perfil',
      ),
    ];

    // iPad e Android largo (≥ 600): barra lateral no lugar da barra de
    // baixo (§3.1); a partir de 840, com o nome ao lado do ícone.
    final largura = MediaQuery.sizeOf(context).width;
    final lateral = largura >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: FundoSuave(
        child: Scaffold(
          body: lateral
              ? Row(children: [
                  BarraLateral(
                    itens: itens,
                    indice: _currentIndex,
                    aoSelecionar: _irPara,
                    estendida: largura >= 840,
                  ),
                  Expanded(child: abas),
                ])
              : abas,
          bottomNavigationBar: lateral
              ? null
              : BarraNavegacao(
                  indiceAtual: _currentIndex,
                  aoSelecionar: _irPara,
                  itens: itens,
                ),
        ),
      ),
    );
  }
}

/// A tela raiz de cada aba: a barra de vidro com o título da aba e o
/// conteúdo. As funções abertas por cima trazem a própria barra.
class _RaizAba extends StatelessWidget {
  const _RaizAba({required this.indice, required this.irPara, required this.child});

  final int indice;
  final ValueChanged<int> irPara;
  final Widget child;

  static const _abaAvisos = _MainShellState._abaAvisos;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    // Mantém a assinatura do tema: a barra muda de degradê no claro/escuro.
    Provider.of<ThemeProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);
    final unread = notifProvider.notifications.where((n) => !n.clicked).length;

    return FundoSuave(
      child: Scaffold(
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
                    nome: auth.nomeMilitar ?? 'Militar',
                    isSuperUser: auth.isSuperUser,
                    isAdmin: auth.nivel == 1,
                    unread: unread,
                    notifProvider: notifProvider,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: child,
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
            child: indice == 0
                ? _titleHome(nome, isSuperUser, isAdmin)
                : Text(
                    ['Início', 'Serviços', 'Avisos', 'Perfil'][indice],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),

          // Ações à direita. A lupa abre a busca dentro da aba (§7); em
          // Serviços a busca já está no topo da tela.
          if (indice != 1)
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuscaPage())),
            ),
          if (indice == 0) ...[
            _notificationBell(unread),
          ],
          if (indice == 3)
            IconButton(
              tooltip: 'Ficha Individual',
              icon: const Icon(Icons.badge_outlined, color: Colors.white),
              onPressed: () {
                registrar('funcao.tocar',
                    chave: 'perfil.ficha', dados: {'origem': 'perfil'});
                Navigator.of(context).pushNamed(AppRoutes.PAGE_MILITAR);
              },
            ),
          if (indice == _abaAvisos && unread > 0)
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
          tooltip: 'Avisos',
          onPressed: () => irPara(_abaAvisos),
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
