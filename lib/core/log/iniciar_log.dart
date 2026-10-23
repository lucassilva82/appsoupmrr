import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ambiente_app.dart';
import '../enderecos.dart';
import '../erros/falha_app.dart';
import '../rede/api_client.dart';
import 'registro_log.dart';

/// Liga o log do app: lê versão e aparelho, cria a fila, registra a abertura
/// e passa a mandar os lotes para `log.php` (docs/SOUPM_2_2.md §9.2).
///
/// Roda depois do primeiro quadro, dentro do `_prepararServicos` do `main`.
Future<void> iniciarLog({
  required ApiClient api,
  required String? Function() matricula,
}) async {
  final info = await PackageInfo.fromPlatform();
  AmbienteApp.preencher(
    versao: info.version,
    build: info.buildNumber,
    aparelho: _sistema(),
  );

  final log = RegistroLog(
    armazem: ArmazemLogPreferencias(),
    enviar: (itens) => _enviarLote(api, itens),
    matricula: matricula,
    aparelhoId: await aparelhoIdApp(),
  );
  RegistroLog.atual = log;

  WidgetsBinding.instance.addObserver(_CicloDoApp(log));
  // O que o Painel mostra em "Tempo de abertura" e "Aparelhos e ambiente".
  // A rede fica de fora: o app não tem como saber sem um pacote nativo novo.
  final tela = PlatformDispatcher.instance;
  await log.evento('app.abrir', dados: {
    'abertura': 'fria',
    'ms': DateTime.now().difference(AmbienteApp.inicio).inMilliseconds,
    'tema': tela.platformBrightness == Brightness.dark ? 'escuro' : 'claro',
    'fonte_escala': double.parse(tela.textScaleFactor.toStringAsFixed(2)),
    if (await _modelo() case final m?) 'modelo': m,
  });
  log.iniciarRelogio();
  unawaited(log.enviar());
}

Future<void> _enviarLote(ApiClient api, List<Map<String, Object?>> itens) async {
  final r = await api.postCorpoJson(Uri.parse('$urlSigrh/log.php'), prefixo: 'LOG', corpo: {'itens': itens});
  if (r is! Map || r['code'] != 1) {
    throw FalhaApp.respostaInvalida('LOG', detalhe: 'log.php: $r');
  }
}

/// Id aleatório gerado na instalação. Não identifica a pessoa nem o aparelho
/// fora do SouPMRR; serve para juntar os registros do mesmo aparelho.
Future<String> aparelhoIdApp() async {
  const chave = 'soupm_aparelho_id';
  final prefs = await SharedPreferences.getInstance();
  final atual = prefs.getString(chave);
  if (atual != null) return atual;
  final r = Random.secure();
  final novo = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  await prefs.setString(chave, novo);
  return novo;
}

/// Modelo do aparelho ("iPhone17,1", "Pixel 9"); nulo se não der para ler.
Future<String?> _modelo() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isIOS) return (await info.iosInfo).utsname.machine;
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return '${a.manufacturer} ${a.model}'.trim();
    }
  } catch (_) {}
  return null;
}

String? _sistema() {
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {
    return null;
  }
}

/// Fundo e volta do app: registra e aproveita para mandar a fila.
class _CicloDoApp with WidgetsBindingObserver {
  _CicloDoApp(this._log);
  final RegistroLog _log;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.paused:
        unawaited(_log.evento('app.fundo').then((_) => _log.enviar()));
        _log.pararRelogio();
      case AppLifecycleState.resumed:
        unawaited(_log.evento('app.voltar').then((_) => _log.enviar()));
        _log.iniciarRelogio();
      default:
        break;
    }
  }
}
