/// Uma função do app, como o menu, a busca, o push, o log e o painel a
/// conhecem (docs/SOUPM_2_2.md §2 e §14.1).
///
/// A [chave] é estável: nunca muda depois de publicada e é a mesma em
/// `soupm_menu_item`, no `app_config`, no log e na ACL. Os [apelidos] são as
/// chaves da primeira versão do plano, aceitas durante a 2.2 (§3.2).
class ModuloApp {
  const ModuloApp({
    required this.chave,
    required this.rotuloPadrao,
    required this.icone,
    required this.prefixoErro,
    this.rota,
    this.apelidos = const [],
    this.sinonimosPadrao = const [],
    this.redirecionaPara,
  });

  final String chave;

  /// Nome de reserva, para quando o `app_config` não vier.
  final String rotuloPadrao;

  /// Chave do mapa de ícones do app (nunca um nome de ícone solto).
  final String icone;

  /// Prefixo dos códigos de erro do módulo (§9.1): `CC`, `CT`, `FE`…
  final String prefixoErro;

  /// Rota de hoje (`AppRoutes`); nula para o que ainda não tem tela.
  final String? rota;
  final List<String> apelidos;
  final List<String> sinonimosPadrao;

  /// Função que fica fora do menu e manda para outra (ex.: `op.plantao`
  /// abre `op.escalas`, §3.2).
  final String? redirecionaPara;
}

/// O registro de todos os módulos. Módulo novo = uma linha na lista do
/// `registro_modulos.dart` + uma linha em `soupm_menu_item`.
class RegistroModulos {
  RegistroModulos(List<ModuloApp> modulos)
      : _porChave = {for (final m in modulos) m.chave: m},
        _porApelido = {
          for (final m in modulos)
            for (final a in m.apelidos) a: m,
        },
        _porRota = {
          for (final m in modulos)
            if (m.rota != null) m.rota!: m,
        };

  final Map<String, ModuloApp> _porChave;
  final Map<String, ModuloApp> _porApelido;
  final Map<String, ModuloApp> _porRota;

  Iterable<ModuloApp> get todos => _porChave.values;

  /// Acha pela chave nova ou pela antiga, já seguindo o redirecionamento.
  ModuloApp? porChave(String chave) {
    final m = _porChave[chave] ?? _porApelido[chave];
    if (m?.redirecionaPara != null) return _porChave[m!.redirecionaPara!];
    return m;
  }

  /// Rota que um push ou link pediu. Rota desconhecida devolve nulo: o app
  /// mostra "Atualize o app para usar esta função" (`MD-<CHAVE>-ATUALIZAR`).
  ModuloApp? porRota(String rota) {
    final m = _porRota[rota];
    if (m?.redirecionaPara != null) return _porChave[m!.redirecionaPara!];
    return m;
  }
}
