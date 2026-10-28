import 'package:flutter/widgets.dart';

/// Guarda o título de cada tela e qual tela veio antes dela, para a barra do
/// iOS mostrar "‹ Serviços" (o nome de onde se veio), como no protótipo
/// (`.cab-int`). A barra registra o próprio título ao ser desenhada; a raiz
/// de cada aba registra o nome da aba.
class TitulosRota extends NavigatorObserver {
  TitulosRota._();

  /// Um observador por navegador (o Flutter não deixa repetir o mesmo).
  static TitulosRota novo() => TitulosRota._();

  static final _titulo = Expando<String>('titulo');
  static final _anterior = Expando<Route<dynamic>>('anterior');

  static void registrar(BuildContext context, String titulo) {
    final rota = ModalRoute.of(context);
    if (rota != null) _titulo[rota] = titulo;
  }

  /// Título da tela de onde se veio; nulo quando não se sabe.
  static String? anterior(BuildContext context) {
    final rota = ModalRoute.of(context);
    final antes = rota == null ? null : _anterior[rota];
    return antes == null ? null : _titulo[antes];
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _anterior[route] = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null && oldRoute != null) {
      final antes = _anterior[oldRoute];
      if (antes != null) _anterior[newRoute] = antes;
    }
  }
}
