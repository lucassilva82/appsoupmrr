import 'package:flutter/foundation.dart';

import '../../core/ambiente_app.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';

/// Uma pendência de algum sistema (docs/SOUPM_2_2.md §4.3). Quando a fonte
/// não respondeu, [erro] traz o código (PD-<SISTEMA>-...) e o item aparece
/// assim mesmo: "não consegui conferir" nunca vira "não tem".
class Pendencia {
  const Pendencia({
    required this.tipo,
    required this.sistema,
    required this.titulo,
    required this.referencia,
    this.texto,
    this.obrigatoria = false,
    this.dispensavel = false,
    this.destino,
    this.prazo,
    this.icone,
    this.erro,
  });

  final String tipo;
  final String sistema;
  final String titulo;
  final String referencia;
  final String? texto;
  final bool obrigatoria;
  final bool dispensavel;
  final String? destino;
  final DateTime? prazo;
  final String? icone;
  final String? erro;

  static Pendencia? deJson(Object? j) {
    if (j is! Map || j['tipo'] is! String || j['titulo'] is! String) return null;
    return Pendencia(
      tipo: j['tipo'] as String,
      sistema: '${j['sistema'] ?? ''}',
      titulo: j['titulo'] as String,
      referencia: '${j['referencia'] ?? ''}',
      texto: j['texto'] as String?,
      obrigatoria: j['obrigatoria'] == true,
      dispensavel: j['dispensavel'] == true,
      destino: j['destino'] as String?,
      prazo: DateTime.tryParse('${j['prazo'] ?? ''}'),
      icone: j['icone'] as String?,
      erro: j['erro'] as String?,
    );
  }
}

/// Resposta do `pendencias.php`: [ligados] = tipos ligados no painel. Com 0,
/// o bloco nem aparece; com algum ligado e nada pendente, "Sem pendências".
class SituacaoPendencias {
  const SituacaoPendencias({required this.ligados, required this.itens});
  final int ligados;
  final List<Pendencia> itens;
}

/// Fala com `sigrh/pendencias.php`. Falha sai como [FalhaApp] com o prefixo PD.
class PendenciasRepositorio {
  PendenciasRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/pendencias.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'PD';

  /// Última resposta, para a Início e a lista mostrarem o mesmo.
  static final emUso = ValueNotifier<SituacaoPendencias?>(null);

  /// Sobe quando algo pode ter resolvido uma pendência (ciência dada,
  /// resposta enviada): quem mostra a lista relê.
  static final revisao = ValueNotifier<int>(0);
  static void algoMudou() => revisao.value++;

  Future<Map> _pedir(Map<String, String> campos) async {
    final j = await api.postJson(url, prefixo: prefixo, campos: {'matricula': matricula, 'senha': senhaMd5, ...campos});
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'pendencias.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    return j;
  }

  Future<SituacaoPendencias> listar() async {
    final j = await _pedir({
      'acao': 'listar',
      'plataforma': AmbienteApp.plataforma,
      'app_versao': AmbienteApp.versao,
    });
    final s = SituacaoPendencias(
      ligados: (j['ligados'] as num?)?.toInt() ?? 0,
      itens: [
        for (final i in (j['itens'] as List? ?? const []))
          if (Pendencia.deJson(i) case final p?) p,
      ],
    );
    emUso.value = s;
    return s;
  }

  Future<void> dispensar(Pendencia p) async {
    await _pedir({'acao': 'dispensar', 'tipo': p.tipo, 'referencia': p.referencia});
    final atual = emUso.value;
    if (atual != null) {
      emUso.value = SituacaoPendencias(
          ligados: atual.ligados,
          itens: [for (final i in atual.itens) if (!(i.tipo == p.tipo && i.referencia == p.referencia)) i]);
    }
  }
}
