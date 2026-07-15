import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/escala_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

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
        // tenta auto-login com credenciais salvas
        try {
          _logUi('tentando auto-login apos erro de autenticacao');
          final loginResult =
              await _service.login(auth.matricula ?? '', auth.password ?? '');
          if (loginResult.precisaMigrarSenha) {
            _logUi('auto-login exigiu migracao de senha');
            if (!mounted) return;
            setState(() {
              _loading = false;
              _needsPasswordMigration = true;
              _migrationMessage = loginResult.mensagemMigracao;
            });
            return;
          }
          _logUi('auto-login ok, recarregando escalas');
          await tryLoad();
        } on EscalaServiceException catch (e2) {
          _logUi('auto-login falhou code=${e2.code} message=${e2.message}');
          if (!mounted) return;
          if (e2.code == 'REQUIRES_2FA') {
            setState(() {
              _loading = false;
              _needs2FA = true;
            });
          } else {
            // Credenciais do app não funcionam na intranet → pede login manual
            final auth = Provider.of<Auth>(context, listen: false);
            _tfMatricula.text =
                (auth.matricula ?? '').replaceAll(RegExp(r'[^0-9]'), '');
            setState(() {
              _loading = false;
              _needsManualLogin = true;
            });
          }
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
      'API_HTML_RESPONSE':
          'A API respondeu HTML em vez de JSON. Verifique se a URL base e o roteamento da intranet estão corretos no ambiente atual.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Senha atualizada com sucesso.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Ciência registrada com sucesso!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Impossibilidade registrada.'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: _buildBody(theme, isDark),
    );
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
            indicatorColor: AppColors.blue,
            labelColor: AppColors.blue,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Próxima'),
              Tab(text: 'Histórico'),
            ],
          )
        : null;

    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: !_needsPasswordMigration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      actions: showTabs
          ? [
              IconButton(
                tooltip: 'Vagas SVI',
                icon: const Icon(Icons.more_time_rounded, color: Colors.white),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.SVI_ESCALAS),
              ),
            ]
          : null,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      shape: tabBar == null
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)))
          : null,
      title: const Text(
        'Escalas de Serviço',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Servidor indisponível. Exibindo dados salvos — podem estar desatualizados.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Definição de nova senha',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _migrationMessage ??
                'Sua senha atual veio do SIGRH. Por segurança, defina uma senha exclusiva para o app.',
            style: theme.textTheme.bodyMedium,
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      color: c.$2 ? Colors.green : Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(c.$1, style: theme.textTheme.bodySmall),
                  ],
                ),
              )),
          const SizedBox(height: 18),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _migrarSenha,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Atualizar senha e continuar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
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
      color: AppColors.blue,
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
              color: AppColors.blue,
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
      color: AppColors.blue,
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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded,
                  size: 48, color: AppColors.blue),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('Acesso à Intranet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Use as credenciais do sistema da intranet\npara acessar suas escalas.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13))),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Entrar',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_rounded,
                  size: 48, color: AppColors.blue),
            ),
            const SizedBox(height: 20),
            Text('Verificação em dois fatores',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Digite o código de 6 dígitos do seu autenticador.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm2FA,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verificar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D2B5A), const Color(0xFF1565C0)]
              : [AppColors.blue, const Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
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
                            foregroundColor: Colors.orange.shade300,
                            side: BorderSide(
                                color: Colors.orange.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
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
                          foregroundColor: Colors.white70,
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE8EFFA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.groups_rounded,
                      size: 15, color: AppColors.blue),
                ),
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
                  backgroundColor: AppColors.blue.withOpacity(0.12),
                  child: Text(
                    m.nomeGuerra.isNotEmpty ? m.nomeGuerra[0] : '?',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.55)),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE8EFFA),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // ── Data badge ─────────────────────────────────────────
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dia,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  Text(
                    mes,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue.withOpacity(0.7),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.55)),
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 40, color: Colors.green),
          ),
          const SizedBox(height: 16),
          Text('Confirmar Ciência',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Ao confirmar, você declara que tomou conhecimento da escala abaixo:',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.blue.withOpacity(0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Data', escala.dataEscala),
                _row('Horário', '${escala.horarioIni} – ${escala.horarioFim}'),
                _row('Guarnição', escala.guarnicaoNome),
                if (escala.vtr != null) _row('Viatura', escala.vtr!),
                if (escala.localAtuacao != null)
                  _row('Local', escala.localAtuacao!),
                _row('Função', escala.funcaoNome),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirmar',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text('$label:',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue)),
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Declarar Impossibilidade',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Motivo',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            if (widget.tipos.isEmpty)
              const Text('Carregando tipos...',
                  style: TextStyle(color: Colors.grey))
            else
              ...widget.tipos.map((t) =>
                  RadioListTile<EscalaImpossibilidadeTipo>(
                    value: t,
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v),
                    title: Text(t.descricao, style: theme.textTheme.bodyMedium),
                    subtitle: t.requerAnexo
                        ? const Text('* Requer anexo',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 11))
                        : null,
                    dense: true,
                    activeColor: AppColors.blue,
                    contentPadding: EdgeInsets.zero,
                  )),
            const SizedBox(height: 12),
            Text('Observação (opcional)',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            TextField(
              controller: _obsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Descreva o motivo...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Registrar Impossibilidade',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
          const CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Carregando escalas...',
              style: Theme.of(context).textTheme.bodySmall),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Não foi possível carregar',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_rounded,
              size: 72, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Nenhuma escala futura',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Você não possui escalas agendadas no momento.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _EmptyHistorico extends StatelessWidget {
  const _EmptyHistorico();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Sem histórico de escalas',
              style: Theme.of(context).textTheme.titleMedium),
        ],
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
