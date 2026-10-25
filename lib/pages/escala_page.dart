import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/escala_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/vidro.dart';
import '../core/design/arte_cartao.dart';
import '../core/design/folha_arte.dart';
import '../widgets/aviso_rapido.dart';

// ── EscalasPage ───────────────────────────────────────────────────────────────
class EscalasPage extends StatefulWidget {
  const EscalasPage({Key? key}) : super(key: key);

  @override
  State<EscalasPage> createState() => _EscalasPageState();
}

class _EscalasPageState extends State<EscalasPage>
    with SingleTickerProviderStateMixin {
  final EscalaService _service = EscalaService();
  late final TabController _tabController;

  EscalaModel? _proxima;
  List<EscalaModel> _escalas = [];
  bool _loading = true;
  String? _error;
  bool _usandoCache = false;
  bool _needs2FA = false;
  bool _needsManualLogin = false;
  bool _needsPasswordMigration = false;
  String? _migrationMessage;
  final _tfCode = TextEditingController();
  final _tfSenha = TextEditingController();
  final _tfMatricula = TextEditingController();
  final _tfNovaSenha = TextEditingController();
  final _tfConfirmarSenha = TextEditingController();
  bool _loginObscure = true;
  bool _novaSenhaObscure = true;
  bool _confirmarSenhaObscure = true;

  void _logUi(String message) {
    debugPrint('[EscalasPage] $message');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tfCode.dispose();
    _tfSenha.dispose();
    _tfMatricula.dispose();
    _tfNovaSenha.dispose();
    _tfConfirmarSenha.dispose();
    super.dispose();
  }

  // ── Carregamento de dados ──────────────────────────────────────────────────
  Future<void> _load({bool forceRelogin = false}) async {
    _logUi('load start forceRelogin=$forceRelogin mounted=$mounted');
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _needsManualLogin = false;
      _needsPasswordMigration = false;
      _migrationMessage = null;
    });

    final auth = Provider.of<Auth>(context, listen: false);

    Future<void> tryLoad() async {
      // Carrega em sequência para evitar duas falhas simultâneas quando
      // o backend responde HTML (ambiente indisponível para JSON).
      _logUi('tryLoad start');
      // A "próxima escala" é informativa: se o backend falhar nela (ex.: 500),
      // não bloqueamos o módulo — ainda carregamos a lista para dar ciência.
      EscalaModel? proxima;
      try {
        proxima = await _service.getProximaEscala();
      } on EscalaServiceException catch (e) {
        if (e.code == 'UNAUTHORIZED' || e.code == 'NOT_AUTHENTICATED') {
          rethrow; // erro de autenticação deve seguir o fluxo de relogin
        }
        _logUi('getProximaEscala falhou code=${e.code} — '
            'derivando próxima a partir da lista');
        proxima = null;
      }
      List<EscalaModel> escalas;
      try {
        escalas = await _service.getMinhasEscalas();
      } on EscalaServiceException catch (e) {
        if (e.code == 'UNAUTHORIZED' || e.code == 'NOT_AUTHENTICATED') {
          rethrow; // erro de autenticação deve seguir o fluxo de relogin
        }
        // Backend indisponível (ex.: 500): usa o último cache local válido
        // para não deixar o militar sem ver suas escalas.
        final cache = await _service.getMinhasEscalasCache();
        if (cache.isEmpty) rethrow; // sem cache → propaga o erro normalmente
        _logUi('getMinhasEscalas falhou code=${e.code} — '
            'usando cache local (${cache.length} escalas)');
        proxima ??= _derivarProxima(cache);
        if (!mounted) return;
        setState(() {
          _proxima = proxima;
          _escalas = cache;
          _loading = false;
          _error = null;
          _usandoCache = true;
        });
        return;
      }
      // Fallback: se o endpoint /escala/proxima falhou, derivamos a próxima
      // escala da lista (a futura mais próxima da data de hoje).
      proxima ??= _derivarProxima(escalas);
      _logUi(
          'tryLoad success proxima=${proxima != null} escalas=${escalas.length}');
      if (!mounted) return;
      setState(() {
        _proxima = proxima;
        _escalas = escalas;
        _loading = false;
        _error = null;
        _usandoCache = false;
      });
    }

    try {
      if (forceRelogin) {
        _logUi('forceRelogin acionado: tentando login com credenciais salvas');
        final loginResult =
            await _service.login(auth.matricula ?? '', auth.password ?? '');
        if (loginResult.precisaMigrarSenha) {
          _logUi('login exigiu migracao de senha');
          if (!mounted) return;
          setState(() {
            _loading = false;
            _needsPasswordMigration = true;
            _migrationMessage = loginResult.mensagemMigracao;
          });
          return;
        }
      }
      await tryLoad();
    } on EscalaServiceException catch (e) {
      _logUi('load falhou code=${e.code} message=${e.message}');
      if ((e.code == 'UNAUTHORIZED' || e.code == 'NOT_AUTHENTICATED') &&
          !forceRelogin) {
        // Entra sozinho: senha da intranet guardada no cofre e, depois, a do
        // app. Só pede a senha se as duas forem recusadas.
        _logUi('tentando auto-login apos erro de autenticacao');
        final r = await _service.entrarSozinho(
          matricula: auth.matricula ?? '',
          senhaApp: auth.password,
        );
        _logUi('auto-login resultado=${r.tipo.name}');
        if (!mounted) return;
        switch (r.tipo) {
          case EntradaIntranet.ok:
            try {
              await tryLoad();
            } on EscalaServiceException catch (e2) {
              if (!mounted) return;
              setState(() {
                _loading = false;
                _error = _mensagemErroAmigavel(e2);
              });
            }
          case EntradaIntranet.precisaMigrar:
            setState(() {
              _loading = false;
              _needsPasswordMigration = true;
              _migrationMessage = r.mensagemMigracao;
            });
          case EntradaIntranet.precisa2fa:
            setState(() {
              _loading = false;
              _needs2FA = true;
            });
          case EntradaIntranet.precisaSenha:
            // Senha do app não vale na intranet → pede a senha uma vez; o
            // login manual guarda no cofre para as próximas vezes.
            _tfMatricula.text =
                (auth.matricula ?? '').replaceAll(RegExp(r'[^0-9]'), '');
            setState(() {
              _loading = false;
              _needsManualLogin = true;
            });
          case EntradaIntranet.falhou:
            final erro = r.erro;
            setState(() {
              _loading = false;
              _error = erro is EscalaServiceException
                  ? _mensagemErroAmigavel(erro)
                  : 'Não foi possível falar com a intranet. Confira a '
                      'internet e tente de novo. (ES-REDE)';
            });
        }
      } else if (e.code == 'REQUIRES_2FA') {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _needs2FA = true;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = _mensagemErroAmigavel(e);
        });
      }
    } catch (e) {
      _logUi('load erro inesperado: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro inesperado. Verifique sua conexão.';
      });
    }
  }

  /// Traduz erros técnicos do backend em mensagens claras para o militar.
  String _mensagemErroAmigavel(EscalaServiceException e) {
    switch (e.code) {
      case 'INTERNAL_ERROR':
      case 'SERVER_ERROR':
        return 'O servidor de escalas está temporariamente indisponível. '
            'Tente novamente em alguns instantes.';
      case 'TIMEOUT':
      case 'NETWORK_ERROR':
        return 'Não foi possível conectar. Verifique sua internet e tente novamente.';
      default:
        return e.message.isNotEmpty
            ? e.message
            : 'Não foi possível carregar as escalas. Tente novamente.';
    }
  }

  Future<void> _confirm2FA() async {
    final auth = Provider.of<Auth>(context, listen: false);
    // Usa matrícula/senha do formulário manual se já preenchidos
    final matricula = _tfMatricula.text.trim().isNotEmpty
        ? _tfMatricula.text.trim()
        : auth.matricula ?? '';
    final senha = _tfSenha.text.trim().isNotEmpty
        ? _tfSenha.text.trim()
        : auth.password ?? '';
    setState(() {
      _loading = true;
      _needs2FA = false;
    });
    try {
      _logUi('confirm2FA enviando codigo para login');
      final loginResult = await _service.login(
        matricula,
        senha,
        codigo2fa: _tfCode.text.trim(),
      );
      _tfCode.clear();
      if (loginResult.precisaMigrarSenha) {
        _logUi('confirm2FA ok mas exige migracao de senha');
        setState(() {
          _loading = false;
          _needsPasswordMigration = true;
          _migrationMessage = loginResult.mensagemMigracao;
        });
        return;
      }
      _logUi('confirm2FA concluido com sucesso');
      await _load();
    } on EscalaServiceException catch (e) {
      _logUi('confirm2FA falhou code=${e.code} message=${e.message}');
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _loginManual() async {
    final matricula = _tfMatricula.text.trim();
    final senha = _tfSenha.text.trim();
    if (matricula.isEmpty || senha.isEmpty) return;

    setState(() {
      _loading = true;
      _needsManualLogin = false;
    });
    try {
      _logUi(
          'loginManual start mat=${matricula.replaceAll(RegExp(r'[^0-9]'), '')}');
      final loginResult = await _service.login(matricula, senha);
      if (loginResult.precisaMigrarSenha) {
        _logUi('loginManual ok mas exige migracao de senha');
        setState(() {
          _loading = false;
          _needsPasswordMigration = true;
          _migrationMessage = loginResult.mensagemMigracao;
        });
        return;
      }
      _logUi('loginManual sucesso, recarregando escalas');
      await _load();
    } on EscalaServiceException catch (e) {
      _logUi('loginManual falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      if (e.code == 'REQUIRES_2FA') {
        setState(() {
          _loading = false;
          _needs2FA = true;
        });
      } else {
        setState(() {
          _loading = false;
          _needsManualLogin = true;
          _error = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(EscalaServiceException e) {
    const map = {
      'unauthenticated': 'Matrícula ou senha incorretos.',
      'INVALID_CREDENTIALS': 'Matrícula ou senha incorretos.',
      'USER_NOT_FOUND': 'Usuário não encontrado ou inativo.',
      'UNAUTHORIZED': 'Sessão expirada. Faça login novamente.',
      'REQUIRES_2FA': 'Código 2FA obrigatório.',
      'NOT_AUTHENTICATED': 'Login necessário.',
      'SERVER_ERROR': 'Erro interno no servidor. Aguarde e tente novamente.',
      // API_HTML_RESPONSE usa a própria mensagem do serviço, que já diz de
      // quem é o problema e traz o código ES-SEM-API-nnn.
    };
    return map[e.code] ?? e.message;
  }

  Future<void> _migrarSenha() async {
    final nova = _tfNovaSenha.text.trim();
    final confirmar = _tfConfirmarSenha.text.trim();
    if (nova.isEmpty || confirmar.isEmpty) {
      setState(() => _error = 'Preencha os campos de nova senha.');
      return;
    }

    final senhaOk = _senhaAtendePolitica(nova);
    if (!senhaOk) {
      setState(() {
        _error = 'A nova senha não atende os critérios mínimos de segurança.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _logUi('migrarSenha enviando requisicao');
      await _service.migrarSenha(nova, confirmar);
      _tfNovaSenha.clear();
      _tfConfirmarSenha.clear();
      if (!mounted) return;
      avisoSucesso(context, 'Senha atualizada');
      _logUi('migrarSenha concluida com sucesso');
      await _load();
    } on EscalaServiceException catch (e) {
      _logUi('migrarSenha falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  bool _senhaAtendePolitica(String s) {
    if (s.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(s)) return false;
    if (!RegExp(r'[a-z]').hasMatch(s)) return false;
    if (!RegExp(r'[0-9]').hasMatch(s)) return false;
    if (!RegExp(r'[!@#\$%^&*()_+\-={}\[\]:;"\\|,.<>\/?]').hasMatch(s)) {
      return false;
    }
    return true;
  }

  // ── Dar Ciência ────────────────────────────────────────────────────────────
  Future<void> _darCiencia(EscalaModel escala) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CienciaBottomSheet(escala: escala),
    );
    if (confirm != true || !mounted) return;

    try {
      final result = await _service.registrarCiencia(escala.escalaId);
      if (!mounted) return;
      setState(() {
        escala.temCiencia = true;
        escala.cienciaEmBr = result['ciencia_em']?.toString();
        if (_proxima?.escalaId == escala.escalaId) {
          _proxima!.temCiencia = true;
          _proxima!.cienciaEmBr = result['ciencia_em']?.toString();
        }
      });
      if (mounted) {
        avisoSucesso(context, 'Ciência registrada');
      }
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      avisoErro(context, 'Não foi possível registrar', texto: e.message);
    }
  }

  // ── Impossibilidade ────────────────────────────────────────────────────────
  Future<void> _declararImpossibilidade(EscalaModel escala) async {
    List<EscalaImpossibilidadeTipo> tipos = [];
    try {
      tipos = await _service.getTiposImpossibilidade();
    } catch (_) {}

    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImpossibilidadeBottomSheet(tipos: tipos),
    );
    if (result == null || !mounted) return;

    try {
      await _service.registrarImpossibilidade(
        escala.escalaId,
        result['tipo_id'] as int,
        result['observacao'] as String?,
      );
      if (!mounted) return;
      setState(() {
        escala.temImpossibilidade = true;
        if (_proxima?.escalaId == escala.escalaId) {
          _proxima!.temImpossibilidade = true;
        }
      });
      if (mounted) {
        avisoAtencao(context, 'Impossibilidade registrada');
      }
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      avisoErro(context, 'Não foi possível registrar', texto: e.message);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FundoSuave(
        child: Scaffold(
      appBar: _buildAppBar(theme),
      body: _buildBody(theme, isDark),
    ));
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    final showTabs = !_loading &&
        _error == null &&
        !_needs2FA &&
        !_needsManualLogin &&
        !_needsPasswordMigration;
    final tabBar = showTabs
        ? TabBar(
            controller: _tabController,
            // Sobre a barra de vidro (sempre escura): texto branco.
            indicatorColor: Theme.of(context).colorScheme.onSurface,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .65),
            dividerColor: Colors.transparent,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Próxima'),
              Tab(text: 'Histórico'),
            ],
          )
        : null;

    return AppBar(
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      automaticallyImplyLeading: !_needsPasswordMigration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      actions: showTabs
          ? [
              IconButton(
                tooltip: 'Vagas SVI',
                icon: Icon(Icons.more_time_rounded, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.SVI_ESCALAS),
              ),
            ]
          : null,
      flexibleSpace: const FundoBarraVidro(),
      title: Text(
        'Escalas de Serviço',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
          letterSpacing: 1.2,
        ),
      ),
      bottom: tabBar,
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) return const _LoadingView();

    if (_needs2FA) return _build2FAView(theme);

    if (_needsManualLogin) return _buildLoginManualView(theme);

    if (_needsPasswordMigration) return _buildMigracaoSenhaView(theme);

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: () => _load(),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildProximaTab(theme, isDark),
        _buildHistoricoTab(theme, isDark),
      ],
    );
  }

  /// Aviso exibido quando os dados estão vindo do cache local (servidor fora
  /// do ar). Mantém o militar informado de que pode haver desatualização.
  Widget _buildCacheBanner(bool isDark) {
    if (!_usandoCache) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CartaoVidro(
        raio: 12,
        tingimento: kCorAtencao,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: const Row(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: AppIconSize.xs, color: kCorAtencao),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Servidor indisponível. Exibindo dados salvos — podem estar desatualizados.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMigracaoSenhaView(ThemeData theme) {
    final checks = [
      ('Mínimo de 8 caracteres', _tfNovaSenha.text.trim().length >= 8),
      (
        'Pelo menos 1 letra maiúscula',
        RegExp(r'[A-Z]').hasMatch(_tfNovaSenha.text.trim())
      ),
      (
        'Pelo menos 1 letra minúscula',
        RegExp(r'[a-z]').hasMatch(_tfNovaSenha.text.trim())
      ),
      (
        'Pelo menos 1 número',
        RegExp(r'[0-9]').hasMatch(_tfNovaSenha.text.trim())
      ),
      (
        'Pelo menos 1 caractere especial',
        RegExp(r'[!@#\$%^&*()_+\-={}\[\]:;"\\|,.<>\/?]')
            .hasMatch(_tfNovaSenha.text.trim())
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopoArte(
            arte: Arte.de('operacional'),
            icone: Icons.password_rounded,
            titulo: 'Definição de nova senha',
            subtitulo: _migrationMessage ??
                'Sua senha atual veio do SIGRH. Por segurança, defina uma senha exclusiva para o app.',
            margem: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _tfNovaSenha,
            obscureText: _novaSenhaObscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nova senha',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _novaSenhaObscure = !_novaSenhaObscure);
                },
                icon: Icon(_novaSenhaObscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tfConfirmarSenha,
            obscureText: _confirmarSenhaObscure,
            decoration: InputDecoration(
              labelText: 'Confirmar senha',
              prefixIcon: const Icon(Icons.verified_user_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(
                      () => _confirmarSenhaObscure = !_confirmarSenhaObscure);
                },
                icon: Icon(_confirmarSenhaObscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...checks.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      c.$2 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 16,
                      color: c.$2
                          ? (theme.brightness == Brightness.dark
                              ? AppColors.sucessoEscuro
                              : AppColors.sucesso)
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(c.$1, style: theme.textTheme.bodySmall),
                  ],
                ),
              )),
          const SizedBox(height: 18),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CartaoVidro(
                raio: 12,
                tingimento: theme.colorScheme.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(_error!),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _migrarSenha,
              child: const Text('Atualizar senha e continuar'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: Próxima ────────────────────────────────────────────────────────────
  Widget _buildProximaTab(ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: () => _load(forceRelogin: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
            _buildCacheBanner(isDark),
            _proxima == null
                ? _EmptyProxima(isDark: isDark)
                : Column(
                    children: [
                      _ProximaEscalaCard(
                        escala: _proxima!,
                        isDark: isDark,
                        theme: theme,
                        onCiencia: () => _darCiencia(_proxima!),
                        onImpossibilidade: () =>
                            _declararImpossibilidade(_proxima!),
                        onDetalhe: () => _abrirDetalhe(_proxima!),
                      ),
                      if (_proxima!.composicao.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _GuarnicaoCard(
                            composicao: _proxima!.composicao,
                            isDark: isDark,
                            theme: theme),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Histórico ──────────────────────────────────────────────────────────
  Widget _buildHistoricoTab(ThemeData theme, bool isDark) {
    // Evita duplicar a escala que já está sendo exibida na aba "Próxima".
    final historico = _proxima == null
        ? _escalas
        : _escalas.where((e) => e.escalaId != _proxima!.escalaId).toList();
    if (historico.isEmpty) {
      return _usandoCache
          ? RefreshIndicator(
              onRefresh: () => _load(forceRelogin: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                children: [
                  _buildCacheBanner(isDark),
                  const _EmptyHistorico(),
                ],
              ),
            )
          : const _EmptyHistorico();
    }
    return RefreshIndicator(
      onRefresh: () => _load(forceRelogin: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: historico.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildCacheBanner(isDark);
          final escala = historico[i - 1];
          return _EscalaListCard(
            escala: escala,
            isDark: isDark,
            theme: theme,
            onTap: () => _abrirDetalhe(escala),
          );
        },
      ),
    );
  }

  // ── Login Manual ────────────────────────────────────────────────────────────
  Widget _buildLoginManualView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopoArte(
            arte: Arte.de('operacional'),
            icone: Icons.lock_person_rounded,
            titulo: 'Acesso à Intranet',
            subtitulo:
                'Use as credenciais do sistema da intranet para acessar suas escalas.',
            margem: EdgeInsets.zero,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            CartaoVidro(
              raio: 12,
              tingimento: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(Icons.error_outline_rounded,
                    color: theme.colorScheme.error, size: AppIconSize.xs),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Text('Matrícula',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _tfMatricula,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Somente números (ex: 015997501)',
              helperText: 'Use apenas os dígitos, sem traços',
              prefixIcon: const Icon(Icons.badge_rounded, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Text('Senha da Intranet',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          StatefulBuilder(
            builder: (_, setS) => TextField(
              controller: _tfSenha,
              obscureText: _loginObscure,
              decoration: InputDecoration(
                hintText: 'Senha de acesso à intranet',
                prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_loginObscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () {
                    setS(() => _loginObscure = !_loginObscure);
                  },
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loginManual,
              child: const Text('Entrar'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2FA ─────────────────────────────────────────────────────────────────────
  Widget _build2FAView(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TopoArte(
              arte: Arte.de('operacional'),
              icone: Icons.security_rounded,
              titulo: 'Verificação em dois fatores',
              subtitulo: 'Digite o código de 6 dígitos do seu autenticador.',
              margem: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tfCode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm2FA,
                child: const Text('Verificar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDetalhe(EscalaModel escala) {
    Navigator.of(context).pushNamed(
      AppRoutes.ESCALA_DETALHE,
      arguments: {
        'escalaId': escala.escalaId,
        'service': _service,
        'escala': escala,
      },
    );
  }

  /// Deriva a "próxima escala" a partir da lista de escalas do militar:
  /// a futura (hoje ou adiante) com a data mais próxima. Usado como fallback
  /// quando o endpoint /escala/proxima falha no backend.
  EscalaModel? _derivarProxima(List<EscalaModel> escalas) {
    final futuras = escalas.where((e) => e.isFuture).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.dataEscalaIso);
        final db = DateTime.tryParse(b.dataEscalaIso);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    if (futuras.isEmpty) return null;
    return futuras.first;
  }
}

// ── Card: Próxima Escala ──────────────────────────────────────────────────────
class _ProximaEscalaCard extends StatelessWidget {
  final EscalaModel escala;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onCiencia;
  final VoidCallback onImpossibilidade;
  final VoidCallback onDetalhe;

  const _ProximaEscalaCard({
    required this.escala,
    required this.isDark,
    required this.theme,
    required this.onCiencia,
    required this.onImpossibilidade,
    required this.onDetalhe,
  });

  @override
  Widget build(BuildContext context) {
    final status = escala.statusVisual;
    final (statusLabel, statusColor, statusIcon) = _statusInfo(status);

    // Card de resumo com a arte operacional (padrão 2.2): o fundo é sempre
    // escuro, por isso o texto branco continua legível nos dois temas.
    return CartaoArte(
      arte: Arte.de('operacional'),
      raio: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRÓXIMA ESCALA',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        escala.dataEscala,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withOpacity(0.5), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Divider(height: 1, color: Colors.white.withOpacity(0.15)),
          ),

          // ── Infos ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _infoItem(Icons.access_time_rounded,
                    '${escala.horarioIni} – ${escala.horarioFim}  (${escala.horas}h)'),
                if (escala.guarnicaoNome.isNotEmpty)
                  _infoItem(Icons.groups_rounded, escala.guarnicaoNome),
                if (escala.vtr != null)
                  _infoItem(Icons.local_police_rounded, escala.vtr!),
                if (escala.localAtuacao != null)
                  _infoItem(Icons.place_rounded, escala.localAtuacao!),
                if (escala.localAssuncao != null)
                  _infoItem(Icons.flag_rounded, escala.localAssuncao!),
                _infoItem(Icons.person_rounded, escala.funcaoNome),
                if (escala.uniforme != null)
                  _infoItem(Icons.military_tech_rounded, escala.uniforme!),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Ações ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              children: [
                if (!escala.temCiencia && !escala.temImpossibilidade)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCiencia,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Dar Ciência',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (escala.temCiencia && escala.cienciaEmBr != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Ciente em ${escala.cienciaEmBr}',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!escala.temImpossibilidade && !escala.temCiencia) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onImpossibilidade,
                          icon: const Icon(Icons.block_rounded, size: 16),
                          label: const Text('Impossibilidade'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFC266),
                            side: BorderSide(
                                color: const Color(0xFFFFC266)
                                    .withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDetalhe,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Ver Detalhes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

// ── Card: Guarnição ───────────────────────────────────────────────────────────
class _GuarnicaoCard extends StatelessWidget {
  final List<EscalaComposicaoModel> composicao;
  final bool isDark;
  final ThemeData theme;

  const _GuarnicaoCard({
    required this.composicao,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final primaria = theme.colorScheme.primary;
    return CartaoVidro(
      arte: Arte.de('operacional'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.groups_rounded,
                    size: AppIconSize.sm, color: primaria),
                const SizedBox(width: 10),
                Text('Composição da Guarnição',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),
          ...composicao.map((m) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: primaria.withValues(alpha: 0.14),
                  child: Text(
                    m.nomeGuerra.isNotEmpty ? m.nomeGuerra[0] : '?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaria),
                  ),
                ),
                title: Text(
                  '${m.postoSigla} ${m.nomeGuerra}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  m.funcao,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.70)),
                ),
                trailing: m.telefone != null
                    ? Icon(Icons.phone_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))
                    : null,
              )),
        ],
      ),
    );
  }
}

// ── Card: Lista de Escalas ────────────────────────────────────────────────────
class _EscalaListCard extends StatelessWidget {
  final EscalaModel escala;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _EscalaListCard({
    required this.escala,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = escala.statusVisual;
    final (statusLabel, statusColor, statusIcon) = _statusInfo(status);

    // Parse data
    String dia = '', mes = '';
    try {
      final dt = DateTime.parse(escala.dataEscalaIso);
      dia = dt.day.toString().padLeft(2, '0');
      const meses = [
        'JAN',
        'FEV',
        'MAR',
        'ABR',
        'MAI',
        'JUN',
        'JUL',
        'AGO',
        'SET',
        'OUT',
        'NOV',
        'DEZ',
      ];
      mes = meses[dt.month - 1];
    } catch (_) {}

    final primaria = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CartaoVidro(
        raio: 14,
        onTap: onTap,
        arte: Arte.de('operacional'),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Data badge ─────────────────────────────────────────
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primaria.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dia,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaria,
                    ),
                  ),
                  Text(
                    mes,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primaria.withValues(alpha: 0.75),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Conteúdo ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          escala.tipoServico,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 10, color: statusColor),
                            const SizedBox(width: 3),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${escala.horarioIni} – ${escala.horarioFim}  ·  ${escala.guarnicaoNome}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.70)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (escala.vtr != null || escala.localAtuacao != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [escala.vtr, escala.localAtuacao]
                            .whereType<String>()
                            .join('  ·  '),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.4)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet: Ciência ─────────────────────────────────────────────────────
class _CienciaBottomSheet extends StatelessWidget {
  final EscalaModel escala;
  const _CienciaBottomSheet({required this.escala});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaria = theme.colorScheme.primary;

    return FolhaArte(
      arte: Arte.de('operacional'),
      icone: Icons.check_circle_rounded,
      titulo: 'Confirmar Ciência',
      subtitulo:
          'Ao confirmar, você declara que tomou conhecimento da escala abaixo:',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CartaoVidro(
            raio: 14,
            arte: Arte.de('operacional'),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Data', escala.dataEscala, primaria),
                _row('Horário', '${escala.horarioIni} – ${escala.horarioFim}',
                    primaria),
                _row('Guarnição', escala.guarnicaoNome, primaria),
                if (escala.vtr != null) _row('Viatura', escala.vtr!, primaria),
                if (escala.localAtuacao != null)
                  _row('Local', escala.localAtuacao!, primaria),
                _row('Função', escala.funcaoNome, primaria),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color cor) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text('$label:',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: cor)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}

// ── Bottom Sheet: Impossibilidade ─────────────────────────────────────────────
class _ImpossibilidadeBottomSheet extends StatefulWidget {
  final List<EscalaImpossibilidadeTipo> tipos;
  const _ImpossibilidadeBottomSheet({required this.tipos});

  @override
  State<_ImpossibilidadeBottomSheet> createState() =>
      _ImpossibilidadeBottomSheetState();
}

class _ImpossibilidadeBottomSheetState
    extends State<_ImpossibilidadeBottomSheet> {
  EscalaImpossibilidadeTipo? _selected;
  final _obsController = TextEditingController();

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FolhaArte(
      arte: Arte.de('operacional'),
      icone: Icons.block_rounded,
      titulo: 'Declarar Impossibilidade',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motivo',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          if (widget.tipos.isEmpty)
            Text('Carregando tipos...',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))
          else
            ...widget.tipos.map((t) => RadioListTile<EscalaImpossibilidadeTipo>(
                  value: t,
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v),
                  title: Text(t.descricao, style: theme.textTheme.bodyMedium),
                  subtitle: t.requerAnexo
                      ? const Text('* Requer anexo',
                          style: TextStyle(color: kCorAtencao, fontSize: 11))
                      : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
          const SizedBox(height: 12),
          Text('Observação (opcional)',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observação',
              hintText: 'Descreva o motivo...',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop({
                        'tipo_id': _selected!.id,
                        'observacao': _obsController.text.trim(),
                      }),
              child: const Text('Registrar Impossibilidade'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Views auxiliares ──────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Carregando escalas...',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Estado vazio ou de erro no padrão 2.2: caixa de vidro com a arte
/// operacional, ícone, título, texto e, se houver, o botão.
class _CaixaEstado extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? texto;
  final Widget? acao;
  final Color? corIcone;
  const _CaixaEstado(
      {required this.icone,
      required this.titulo,
      this.texto,
      this.acao,
      this.corIcone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    return CartaoVidro(
      arte: Arte.de('operacional'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: AppIconSize.xl, color: corIcone ?? mudo),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (texto != null) ...[
            const SizedBox(height: 8),
            Text(texto!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: mudo)),
          ],
          if (acao != null) ...[const SizedBox(height: 20), acao!],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _CaixaEstado(
          icone: Icons.wifi_off_rounded,
          corIcone: Theme.of(context).colorScheme.error,
          titulo: 'Não foi possível carregar',
          texto: message,
          acao: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
            label: const Text('Tentar novamente'),
          ),
        ),
      ),
    );
  }
}

class _EmptyProxima extends StatelessWidget {
  final bool isDark;
  const _EmptyProxima({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return const _CaixaEstado(
      icone: Icons.event_available_rounded,
      titulo: 'Nenhuma escala futura',
      texto: 'Você não possui escalas agendadas no momento.',
    );
  }
}

class _EmptyHistorico extends StatelessWidget {
  const _EmptyHistorico();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: _CaixaEstado(
        icone: Icons.history_rounded,
        titulo: 'Sem histórico de escalas',
      ),
    );
  }
}

// ── Helper de status visual ───────────────────────────────────────────────────
(String label, Color color, IconData icon) _statusInfo(
    EscalaStatusVisual status) {
  return switch (status) {
    EscalaStatusVisual.aguardandoCiencia => (
        'Aguardando Ciência',
        Colors.amber,
        Icons.schedule_rounded
      ),
    EscalaStatusVisual.ciente => (
        'Ciente',
        Colors.green,
        Icons.check_circle_rounded
      ),
    EscalaStatusVisual.impossibilidade => (
        'Impossibilidade',
        Colors.red,
        Icons.block_rounded
      ),
    EscalaStatusVisual.realizada => (
        'Realizada',
        Colors.grey,
        Icons.task_alt_rounded
      ),
    EscalaStatusVisual.semCienciaHistorico => (
        'Sem Ciência',
        Colors.blueGrey,
        Icons.remove_circle_outline_rounded
      ),
  };
}
