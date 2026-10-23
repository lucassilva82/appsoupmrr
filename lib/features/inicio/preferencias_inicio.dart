import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';

/// A tela inicial de um militar (docs/SOUPM_2_2.md §4.5): a ordem dos blocos,
/// os que ele escondeu e os atalhos. Nulo em [atalhos] = o padrão do painel.
class PreferenciasInicio {
  const PreferenciasInicio({this.blocos = const [], this.atalhos});

  final List<({String chave, bool visivel})> blocos;
  final List<String>? atalhos;

  static PreferenciasInicio? deJson(Object? j) {
    if (j is! Map) return null;
    return PreferenciasInicio(
      blocos: [
        for (final b in (j['blocos'] is List ? j['blocos'] as List : const []))
          if (b is Map && b['chave'] is String) (chave: b['chave'] as String, visivel: b['visivel'] != false),
      ],
      atalhos: j['atalhos'] is List ? [for (final a in j['atalhos'] as List) '$a'] : null,
    );
  }

  Map<String, Object?> paraJson() => {
        'blocos': [for (final b in blocos) {'chave': b.chave, 'visivel': b.visivel}],
        if (atalhos != null) 'atalhos': atalhos,
      };
}

/// Junta os blocos do painel com a escolha do militar:
/// - a ordem é a do militar; bloco que ele ainda não conhece (novo no
///   painel) entra logo depois do vizinho de cima que o painel definiu;
/// - o que ele escondeu continua escondido, menos bloco fixo (`escondivel`
///   falso), que nunca some;
/// - bloco que o painel desligou não aparece, e volta para onde estava se o
///   painel religar (a escolha dele fica guardada).
/// Devolve as chaves visíveis, na ordem.
List<String> ordenarBlocos(List<BlocoInicio> doPainel, PreferenciasInicio? pref) {
  final painel = [...doPainel]..sort((a, b) => a.ordem.compareTo(b.ordem));
  if (pref == null || pref.blocos.isEmpty) return [for (final b in painel) b.chave];
  final porChave = {for (final b in painel) b.chave: b};
  final ordem = [for (final b in pref.blocos) if (porChave.containsKey(b.chave)) b.chave];
  for (var i = 0; i < painel.length; i++) {
    final chave = painel[i].chave;
    if (ordem.contains(chave)) continue;
    // Depois do bloco que vem antes dele no painel e já está na lista.
    var pos = 0;
    for (var j = i - 1; j >= 0; j--) {
      final k = ordem.indexOf(painel[j].chave);
      if (k >= 0) {
        pos = k + 1;
        break;
      }
    }
    ordem.insert(pos, chave);
  }
  final escondidos = {for (final b in pref.blocos) if (!b.visivel) b.chave};
  return [for (final c in ordem) if (!escondidos.contains(c) || !porChave[c]!.escondivel) c];
}

/// Guarda a escolha no aparelho (por matrícula) e no servidor
/// (`inicio_preferencias.php`). O aparelho vale na hora; o servidor serve
/// para outro aparelho. Falha do servidor não desfaz nada no aparelho.
class InicioPreferenciasRepositorio {
  InicioPreferenciasRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/inicio_preferencias.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'IN';

  /// A escolha em uso; a Início e os atalhos redesenham quando muda.
  static final emUso = ValueNotifier<PreferenciasInicio?>(null);

  String get _chave => 'inicio_preferencias_$matricula';

  /// Na abertura: a do servidor (vinda no app_config) vence; sem ela, a do aparelho.
  Future<void> carregar(PreferenciasInicio? doServidor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (doServidor != null) {
        emUso.value = doServidor;
        await prefs.setString(_chave, jsonEncode(doServidor.paraJson()));
        return;
      }
      final local = prefs.getString(_chave);
      emUso.value = local == null ? null : PreferenciasInicio.deJson(jsonDecode(local));
    } catch (_) {
      // Sem preferências no aparelho: vale o padrão do painel.
    }
  }

  Future<void> salvar(PreferenciasInicio p) async {
    emUso.value = p;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode(p.paraJson()));
    } catch (_) {}
    final j = await api.postJson(url, prefixo: prefixo, campos: {
      'matricula': matricula,
      'senha': senhaMd5,
      'acao': 'gravar',
      'blocos': jsonEncode(p.paraJson()['blocos']),
      'atalhos': p.atalhos == null ? '' : jsonEncode(p.atalhos),
    });
    _conferir(j);
  }

  Future<void> restaurar() async {
    emUso.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chave);
    } catch (_) {}
    _conferir(await api.postJson(url, prefixo: prefixo,
        campos: {'matricula': matricula, 'senha': senhaMd5, 'acao': 'restaurar'}));
  }

  void _conferir(Object? j) {
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'inicio_preferencias.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
  }
}
