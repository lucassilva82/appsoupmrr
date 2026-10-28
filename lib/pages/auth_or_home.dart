import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/ambiente_app.dart';
import '../core/config/app_config.dart';
import '../core/erros/estado_erro.dart';
import '../core/erros/falha_app.dart';
import '../core/log/registro_log.dart';
import '../features/versao/tela_atualizacao.dart';
import '../core/rede/api_client.dart';
import '../models/auth_model.dart';
import '../widgets/abertura_soupmrr.dart';
import 'auth_page.dart';
import 'biometric_auth_page.dart';
import 'main_shell.dart';
import '../widgets/vidro.dart';

class AuthOrHome extends StatefulWidget {
  const AuthOrHome({Key? key}) : super(key: key);

  @override
  State<AuthOrHome> createState() => _AuthOrHomeState();
}

class _AuthOrHomeState extends State<AuthOrHome> {
  late Future<void> _initFuture;

  /// Um toque na abertura encerra o piso de tempo (§15.6); o trabalho de
  /// verdade (login, versão) continua sendo esperado.
  final _piso = Completer<void>();
  bool _needsForceUpdate = false;
  String _instalada = '';
  RegraVersao? _regra;

  /// A tela de entrada (login ou Face ID) mostrada aqui, se houve. Abrir o
  /// app já logado vai direto à Início, sem animação.
  Widget? _entrada;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);

    debugPrint("[LOG] AuthOrHome initState: Iniciando...");

    // 1) Tenta autoLogin
    // 2) Depois busca min_version no Firestore e compara
    // Piso de tempo para a abertura: os 2,5s da animação mais ~1,1s de
    // permanência com a marca pronta. Sem a permanência a assinatura entrava
    // e o app abria no quadro seguinte — ninguém via o conjunto montado.
    //
    // E sem piso nenhum, numa sessão já autenticada o carregamento termina em
    // ~300ms e a animação vira um tremor, pior do que não ter animação.
    _initFuture = () async {
      final trabalho = auth.tryAutoLogin().then((_) async {
        debugPrint(
            "[LOG] initState: tryAutoLogin finalizado, agora checkVersion...");
        // Abre com a cópia guardada e, sem esperar, busca a ficha de novo no
        // SIGRH (nome de guerra, posto, foto trocados lá).
        unawaited(auth.atualizarPerfilEmSegundoPlano());
        // O que o app desenha vem da API (fase 1 da 2.2). A versão mínima
        // por plataforma também (§10.2): espera até 3 s; sem resposta, vale a
        // cópia guardada e, sem regra nenhuma, a do Firestore (2.1.x).
        final config = carregarAppConfig(
            api: ApiClient(),
            matricula: auth.isAuth ? auth.matricula : null,
            senha: auth.isAuth ? auth.password : null);
        try {
          await config.timeout(const Duration(seconds: 3));
        } catch (_) {}
        if (!await _checarVersaoPorPlataforma()) {
          await _checkVersionFromFirestore();
        }
      });
      await Future.wait([
        trabalho,
        Future.any([
          Future<void>.delayed(const Duration(milliseconds: 4200)),
          _piso.future
        ]),
      ]);
    }();
  }

  /// Regra da plataforma vinda do `app_config` (§10.2). Devolve falso quando
  /// não há regra (sem rede e sem cópia), para cair no Firestore.
  Future<bool> _checarVersaoPorPlataforma() async {
    final config = RepositorioConfig.atual;
    final regra = config.versoes[AmbienteApp.plataforma];
    if (regra == null) return false;
    try {
      _instalada = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      _instalada = AmbienteApp.versao;
    }
    _regra = regra;
    if (config.situacaoVersao(AmbienteApp.plataforma, _instalada) ==
        SituacaoVersao.obrigatoria) {
      _needsForceUpdate = true;
    }
    return true;
  }

  /// Busca a `min_version` no Firestore (coleção 'appConfig', doc 'versions')
  /// e compara com a versão do app. Se a versão atual for menor, _needsForceUpdate = true.
  Future<void> _checkVersionFromFirestore() async {
    debugPrint("[LOG] _checkVersionFromFirestore: Iniciando...");

    try {
      debugPrint(
          "[LOG] _checkVersionFromFirestore: Antes de buscar doc 'versions' em 'appConfig'...");
      final docSnap = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('versions')
          .get();

      if (!docSnap.exists) {
        debugPrint(
            "[LOG] _checkVersionFromFirestore: doc 'versions' não existe. Sem forçar update.");
        return;
      }

      final data = docSnap.data();
      if (data == null || !data.containsKey('min_version')) {
        debugPrint(
            "[LOG] _checkVersionFromFirestore: Campo 'min_version' não encontrado. Sem forçar update.");
        return;
      }

      final minVersion = data['min_version'] as String?;
      debugPrint("[LOG] _checkVersionFromFirestore: min_version: $minVersion");

      if (minVersion == null) {
        debugPrint(
            "[LOG] _checkVersionFromFirestore: minVersion=null. Sem forçar update.");
        return;
      }

      // Versão atual do app
      debugPrint(
          "[LOG] _checkVersionFromFirestore: Antes de obter PackageInfo...");
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      _instalada = currentVersion;
      debugPrint(
          "[LOG] _checkVersionFromFirestore: currentVersion do app: $currentVersion");

      // Compara
      if (_compareVersions(currentVersion, minVersion) < 0) {
        debugPrint(
            "[LOG] _checkVersionFromFirestore: currentVersion < minVersion => Force update!");
        _needsForceUpdate = true;
      } else {
        debugPrint(
            "[LOG] _checkVersionFromFirestore: currentVersion >= minVersion => Sem force update.");
      }
    } catch (e) {
      debugPrint("[ERRO] _checkVersionFromFirestore => $e");
    }

    debugPrint("[LOG] _checkVersionFromFirestore: Término do método.");
  }

  /// Compara strings de versão (ex.: "1.0.15" vs "1.0.16").
  /// Retorna 1 se v1 > v2, 0 se iguais, -1 se v1 < v2
  int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.tryParse).toList();
    final v2Parts = v2.split('.').map(int.tryParse).toList();

    // Garante 3 partes (Major, Minor, Patch)
    while (v1Parts.length < 3) {
      v1Parts.add(0);
    }
    while (v2Parts.length < 3) {
      v2Parts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      final a = v1Parts[i] ?? 0;
      final b = v2Parts[i] ?? 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }

  /// Leva à Início depois da entrada. Se houver uma janela do app por cima
  /// (a rota não é a do topo), espera ela fechar: trocar a rota agora
  /// trocaria a janela, não a entrada. Quando a própria tela de entrada já
  /// abriu a Início, esta tela sai e não faz nada.
  Future<void> _irParaInicio() async {
    for (var i = 0; i < 100 && mounted; i++) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        abrirInicioDepoisDoLogin(context);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[LOG] AuthOrHome build()...");
    final auth = Provider.of<Auth>(context);

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (ctx, snapshot) {
        debugPrint(
            "[LOG] FutureBuilder: connectionState=${snapshot.connectionState}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint("[LOG] FutureBuilder: Loading...");
          return AberturaSouPMRR(aoPular: () {
            if (!_piso.isCompleted) _piso.complete();
          });
        } else if (snapshot.hasError) {
          debugPrint(
              "[LOG] FutureBuilder: snapshot.hasError => ${snapshot.error}");
          final falha = FalhaApp(
            codigo: 'AP-ABERTURA',
            origem: OrigemFalha.app,
            titulo: 'O app não conseguiu abrir',
            texto:
                'Algo falhou ao preparar o app. Feche e abra de novo; se continuar, abra um chamado técnico com o código.',
            detalhe: '${snapshot.error}',
          );
          registrarErro(falha, tela: 'abertura');
          return FundoSuave(
              child: Scaffold(
                  body: SafeArea(
                      child: EstadoErro(falha: falha, tela: 'abertura'))));
        } else {
          // Se precisamos forçar update
          if (_needsForceUpdate) {
            debugPrint(
                "[LOG] FutureBuilder: _needsForceUpdate=true => ForceUpdateScreen...");
            return TelaAtualizacao(instalada: _instalada, regra: _regra);
          }

          // Caso contrário, exibe a lógica normal
          if (auth.isAuth && _entrada != null) {
            // Acabou de entrar pela senha ou pelo Face ID: a tela de entrada
            // fica até a Início chegar por cima, com esmaecimento e os blocos
            // em cascata. Montar outra Início aqui embaixo era montar duas: a
            // de baixo desligava a cascata da de cima, e tudo aparecia de uma
            // vez. Só uma das entradas leva à Início (a primeira que rodar).
            debugPrint("[LOG] FutureBuilder: auth.isAuth => Início pela rota de entrada");
            WidgetsBinding.instance.addPostFrameCallback((_) => _irParaInicio());
            return _entrada!;
          }
          if (auth.isAuth) {
            debugPrint("[LOG] FutureBuilder: auth.isAuth => MainShell");
            return const MainShell();
          } else if (auth.useBiometrics) {
            debugPrint(
                "[LOG] FutureBuilder: auth.useBiometrics => BiometricAuthPage");
            return _entrada = const BiometricAuthPage();
          } else {
            debugPrint("[LOG] FutureBuilder: => AuthPage");
            return _entrada = const AuthPage();
          }
        }
      },
    );
  }
}
