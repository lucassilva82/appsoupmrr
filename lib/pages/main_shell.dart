import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/log/registro_log.dart';
import '../core/rede/api_client.dart';
import '../features/servicos/servicos_page.dart';
import '../models/auth_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/notification_provider.dart';
import '../utils/theme_provider.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import '../core/config/app_config.dart';
import '../core/navegacao/titulos_rota.dart';
import '../features/servicos/busca_page.dart';
import 'configuracoes.dart';
import '../widgets/barra_lateral.dart';
import '../widgets/barra_navegacao.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _currentIndex;

  /// Evita agendar a saída mais de uma vez: `build` roda várias vezes entre
  /// o toque em "Sair" e a troca de tela.
  bool _saindo = false;

  final _navegadores = List.generate(4, (_) => GlobalKey<NavigatorState>());

  // Ordem das abas: Início, Serviços, Avisos, Perfil.
  static const _abaAvisos = 2;
  static const _chavesAba = ['aba.inicio', 'aba.servicos', 'aba.avisos', 'aba.perfil'];

  /// Última leitura do `app_config` pelo shell (§5.3: na volta ao app depois
  /// de 5 minutos, relê).
  DateTime _configLidoEm = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, 3);
    // Conecta o histórico de notificações do militar logado (stream Firestore).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).bindUser();
      // Entra na intranet em segundo plano, para Escalas, SVI e os avisos do
      // SIGE já abrirem com a sessão pronta (sem pedir senha). Só quando o
      // painel liberou Escalas ou SVI: na fase sem intranet (decisão do
      // usuário, 24/10/2026) as duas ficam bloqueadas e a senha do app não
      // vai para a intranet. Liberadas depois, a própria tela entra.
      final config = RepositorioConfig.atual;
      final intranetEmUso = ['op.escalas', 'op.svi'].any((chave) {
        final item = config.item(chave);
        return item != null && !item.bloqueado;
      });
      if (!intranetEmUso) return;
      final auth = Provider.of<Auth>(context, listen: false);
      EscalaService().entrarEmSegundoPlano(
        matricula: auth.matricula,
        senhaApp: auth.password,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_configLidoEm) > const Duration(minutes: 5)) {
      _recarregarConfig();
    }
  }

  /// Relê o `app_config` (volta ao app, ⌘R no iPad). Nunca lança.
  Future<void> _recarregarConfig() async {
    _configLidoEm = DateTime.now();
    final auth = Provider.of<Auth>(context, listen: false);
    await carregarAppConfig(api: ApiClient(), matricula: auth.matricula, senha: auth.password);
  }

  /// Busca na aba atual (⌘F no iPad, Ctrl+F no Android com teclado).
  void _abrirBusca() {
    registrar('tela.abrir', chave: 'busca', dados: {'de': 'teclado'});
    _navegadores[_currentIndex]
        .currentState
        ?.push(MaterialPageRoute(builder: (_) => const BuscaPage()));
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
        Navigator.of(context, rootNavigator: true).pushNamed(nome!, arguments: settings.arguments);
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
          observers: [TitulosRota.novo()],
          onGenerateRoute: (s) => _rota(s, raiz),
          onUnknownRoute: (s) => MaterialPageRoute(settings: s, builder: (_) => raiz),
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

    // Atalhos de teclado (§15.4): ⌘F busca, ⌘1 a ⌘4 abas, ⌘R atualiza.
    // No Android com teclado, Ctrl no lugar do ⌘.
    final atalhos = <ShortcutActivator, VoidCallback>{
      for (final ctrl in [false, true]) ...{
        SingleActivator(LogicalKeyboardKey.keyF, meta: !ctrl, control: ctrl): _abrirBusca,
        SingleActivator(LogicalKeyboardKey.keyR, meta: !ctrl, control: ctrl): _recarregarConfig,
        for (final (i, tecla) in [
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.digit4
        ].indexed)
          SingleActivator(tecla, meta: !ctrl, control: ctrl): () => _irPara(i),
      },
    };

    return CallbackShortcuts(
      bindings: atalhos,
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _voltar();
          },
          child: FundoSuave(
            child: Scaffold(
              // No iOS a barra é solta, de vidro: o conteúdo passa por baixo
              // dela (o MediaQuery já soma a altura da barra no fim das
              // listas).
              extendBody: !lateral && BarraNavegacao.plataformaIos,
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

  /// Início leva saudação e lotação (duas linhas); as outras, o título.
  double get _alturaCab => indice == 0 || indice == _abaAvisos ? 64 : 56;

  @override
  Widget build(BuildContext context) {
    // A raiz da aba dá o nome para o "‹ Serviços" das telas abertas nela.
    TitulosRota.registrar(context, ['Início', 'Serviços', 'Avisos', 'Perfil'][indice]);
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
        // Título grande na raiz de cada aba, sem faixa de fundo (protótipo
        // §15.3: `.cab` e `.ola`). As funções abertas por cima trazem a
        // barra de vidro delas.
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            _alturaCab + MediaQuery.of(context).padding.top,
          ),
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: _alturaCab,
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
    final cor = Theme.of(context).colorScheme.onSurface;
    final linha = Row(
      children: [
        // Título dinâmico por aba
        Expanded(
          child: indice == 0
              ? _titleHome(context, nome, isSuperUser, isAdmin)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ['Início', 'Serviços', 'Avisos', 'Perfil'][indice],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // iOS: título grande (32, negrito); Android: o da
                      // TopAppBar média do Material 3 (24, regular).
                      style: TextStyle(
                        fontSize: _ios ? 32 : 24,
                        fontWeight: _ios ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: _ios ? -0.64 : 0,
                        height: 1.1,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
        ),

        // Ações à direita, como no protótipo: Início com lupa e sino,
        // Serviços com o sino (a busca já fica no topo da tela), Avisos
        // com "Marcar todos" e Perfil com a lupa.
        if (indice == 0 || indice == 3)
          IconButton(
            tooltip: 'Buscar',
            icon: Icon(Icons.search, color: cor),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuscaPage())),
          ),
        if (indice == 0 || indice == 1) _notificationBell(unread, cor),
        if (indice == _abaAvisos && unread > 0)
          TextButton(
            onPressed: () => notifProvider.markAllAsRead(),
            child: Text(
              'Marcar todos',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 6),
      child: indice != _abaAvisos
          ? linha
          // Avisos diz numa linha, na largura toda, o que é a aba (§3.1).
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 42, child: linha),
                Text(
                  'Mensagens do SouPMRR para você'
                  '${unread > 0 ? ' · $unread ${unread == 1 ? 'não lido' : 'não lidos'}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cor.withValues(alpha: 0.62)),
                ),
              ],
            ),
    );
  }

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  /// "Bom dia", "Boa tarde" ou "Boa noite", pela hora do aparelho.
  static String saudacao([DateTime? agora]) {
    final h = (agora ?? DateTime.now()).hour;
    if (h >= 5 && h < 12) return 'Bom dia';
    if (h >= 12 && h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  /// Saudação grande e, embaixo, a lotação em siglas com o selo do nível
  /// (§6.2; protótipo `.ola`).
  Widget _titleHome(BuildContext context, String nome, bool isSuperUserLegado, bool isAdmin) {
    final theme = Theme.of(context);
    final config = RepositorioConfig.atual;
    // Com os níveis ligados no painel, o selo é o nome curto do nível (§6.2);
    // até lá, a regra de hoje.
    final nivel = config.nivel;
    final isSuperUser = nivel != null ? nivel.selo : isSuperUserLegado;
    final label = nivel != null ? nivel.nomeCurto : (isAdmin ? 'Admin' : 'Gestor');
    final lotacao = config.lotacaoCurta;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${saudacao()}, $nome',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (lotacao.isNotEmpty || isSuperUser)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                if (lotacao.isNotEmpty)
                  Flexible(
                    child: Text(
                      lotacao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: mudo),
                    ),
                  ),
                if (isSuperUser) ...[
                  if (lotacao.isNotEmpty) const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _notificationBell(int count, Color cor) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: cor),
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
