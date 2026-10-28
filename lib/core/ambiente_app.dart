import 'dart:io';

/// O que o app sabe de si mesmo e manda em todo pedido e em todo log
/// (docs/SOUPM_2_2.md §9.2): versão, build e plataforma.
///
/// Começa com valores de reserva e é preenchido por [preencher] logo depois
/// do primeiro quadro (o `PackageInfo` é assíncrono e não pode segurar a
/// abertura, APRENDIZADOS §2).
class AmbienteApp {
  AmbienteApp._();

  /// Quando o processo começou (o `main` toca neste campo primeiro), para o
  /// tempo de abertura do `app.abrir`.
  static final DateTime inicio = DateTime.now();

  static String versao = '0.0.0';
  static String build = '0';
  static String plataforma = _plataforma();

  /// Modelo e sistema do aparelho, quando já lidos ("iPhone17,1 · iOS 27.1").
  static String? aparelho;

  static void preencher({
    required String versao,
    required String build,
    String? aparelho,
  }) {
    AmbienteApp.versao = versao;
    AmbienteApp.build = build;
    AmbienteApp.aparelho = aparelho;
  }

  static String _plataforma() {
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return Platform.operatingSystem;
    } catch (_) {
      return 'desconhecida';
    }
  }
}
