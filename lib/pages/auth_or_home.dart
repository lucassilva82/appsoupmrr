import 'dart:io'; // Para detectar iOS/Android
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_model.dart';
import 'auth_page.dart';
import 'biometric_auth_page.dart';
import 'home_page.dart';

class AuthOrHome extends StatefulWidget {
  const AuthOrHome({Key? key}) : super(key: key);

  @override
  State<AuthOrHome> createState() => _AuthOrHomeState();
}

class _AuthOrHomeState extends State<AuthOrHome> {
  late Future<void> _initFuture;
  bool _needsForceUpdate = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);

    debugPrint("[LOG] AuthOrHome initState: Iniciando...");

    // 1) Tenta autoLogin
    // 2) Depois busca min_version no Firestore e compara
    _initFuture = auth.tryAutoLogin().then((_) {
      debugPrint(
          "[LOG] initState: tryAutoLogin finalizado, agora checkVersion...");
      return _checkVersionFromFirestore();
    });
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        } else if (snapshot.hasError) {
          debugPrint(
              "[LOG] FutureBuilder: snapshot.hasError => ${snapshot.error}");
          return const Scaffold(
            body: Center(child: Text('Ocorreu um erro')),
          );
        } else {
          // Se precisamos forçar update
          if (_needsForceUpdate) {
            debugPrint(
                "[LOG] FutureBuilder: _needsForceUpdate=true => ForceUpdateScreen...");
            return _buildForceUpdateScreen();
          }

          // Caso contrário, exibe a lógica normal
          if (auth.isAuth) {
            debugPrint("[LOG] FutureBuilder: auth.isAuth => HomePage");
            return HomePage();
          } else if (auth.useBiometrics) {
            debugPrint(
                "[LOG] FutureBuilder: auth.useBiometrics => BiometricAuthPage");
            return const BiometricAuthPage();
          } else {
            debugPrint("[LOG] FutureBuilder: => AuthPage");
            return const AuthPage();
          }
        }
      },
    );
  }

  /// Tela de "forçar atualização" com:
  /// - Fundo: assets/imagens/entradacapa.png
  /// - Caixa degradê em tons de azul
  /// - Botão "Acessar agora" para redirecionar iOS/Android
  Widget _buildForceUpdateScreen() {
    debugPrint(
        "[LOG] _buildForceUpdateScreen: Exibindo tela de atualização...");

    return Scaffold(
      // Fundo com imagem
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/imagens/entradacapa.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D47A1), // Azul escuro
                  Color(0xFF1976D2), // Azul mais claro
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nova versão disponível!',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Para continuar usando o app, atualize agora para a versão mais recente.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                  ),
                  onPressed: () async {
                    debugPrint("[LOG] Botão 'Acessar agora' clicado...");

                    final storeUrl = Platform.isIOS
                        ? 'https://apps.apple.com/us/app/soupmrr/id6466815434'
                        : 'https://play.google.com/store/apps/details?id=pm.rr.soupmrr';

                    final uri = Uri.parse(storeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      debugPrint(
                          "[ERRO] Não foi possível abrir a URL: $storeUrl");
                    }
                  },
                  child: const Text('Acessar agora'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
