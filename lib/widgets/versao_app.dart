import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Versão do app lida do próprio pacote instalado, em vez de texto fixo.
// Antes a tela mostrava "2.0" mesmo depois de publicarmos 2.0.7.
// ─────────────────────────────────────────────────────────────────────────────

class VersaoApp {
  VersaoApp._();

  static PackageInfo? _cache;

  /// Ex.: "2.0.7" — e "2.0.7 (47)" quando [comBuild] é true.
  /// No iOS o build costuma repetir a versão; nesse caso ele é omitido.
  static Future<String> texto({bool comBuild = false}) async {
    _cache ??= await PackageInfo.fromPlatform();
    final v = _cache!.version;
    final build = _cache!.buildNumber;
    if (!comBuild || build.isEmpty || build == v) return v;
    return '$v ($build)';
  }
}

/// Exibe a versão assim que ela é lida, sem piscar na tela.
class TextoVersao extends StatelessWidget {
  final String Function(String versao) formato;
  final TextStyle? estilo;
  final TextAlign? alinhamento;
  final bool comBuild;

  const TextoVersao({
    Key? key,
    required this.formato,
    this.estilo,
    this.alinhamento,
    this.comBuild = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: VersaoApp.texto(comBuild: comBuild),
      builder: (context, snap) => Text(
        formato(snap.data ?? ''),
        style: estilo,
        textAlign: alinhamento,
      ),
    );
  }
}
