import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';
import 'operar_api.dart';

/// O serviço do militar na operação, lido direto do Operar.
///
/// O app fala com ele sem passar pela nossa API: o token de aparelho vai no
/// `Authorization`. Só o que o card da Início precisa — o resto das telas é a
/// WebView que mostra.
class ServicoOperacao {
  const ServicoOperacao({
    required this.data,
    required this.escala,
    this.funcao,
    this.posto,
    this.local,
    this.municipio,
    this.horaInicio,
    this.horaFim,
    this.restrita = false,
  });

  final String data;
  final String escala;
  final String? funcao;
  final String? posto;
  final String? local;
  final String? municipio;
  final String? horaInicio;
  final String? horaFim;

  /// Escala restrita (Assessoria Militar): o Operar não manda o detalhe.
  final bool restrita;

  static ServicoOperacao? deJson(Object? j) {
    if (j is! Map || j['data'] is! String) return null;
    final p = j['posto'];
    final l = j['local'];
    return ServicoOperacao(
      data: j['data'] as String,
      escala: '${j['escala'] ?? 'Serviço'}',
      funcao: j['funcao'] as String?,
      posto: p is Map ? p['descricao'] as String? : null,
      horaInicio: p is Map ? p['hora_inicio'] as String? : null,
      horaFim: p is Map ? p['hora_fim'] as String? : null,
      local: l is Map ? l['nome'] as String? : null,
      municipio: l is Map ? l['municipio'] as String? : null,
      restrita: j['restrita'] == true,
    );
  }
}

/// O que o card desenha: a operação em curso e o serviço mais próximo.
class MeuServicoOperacao {
  const MeuServicoOperacao({
    required this.servicos,
    this.evento,
    this.eventoInicio,
    this.eventoFim,
    this.nomeGuerra,
  });

  final List<ServicoOperacao> servicos;

  /// Nome curto da operação (Expoferr, ENEM). Nulo fora do modo evento — na
  /// eleição o Operar manda `evento: null`.
  final String? evento;

  /// A janela da operação, em ISO. Serve para o card dizer se ela está em
  /// curso ou ainda por vir — "Expoferr" sozinho não diz ao militar o que
  /// aquela palavra é.
  final String? eventoInicio;
  final String? eventoFim;
  final String? nomeGuerra;

  bool get temServico => servicos.isNotEmpty;

  /// O primeiro serviço da lista: o Operar já a devolve na ordem do dia.
  ServicoOperacao? get proximo => servicos.isEmpty ? null : servicos.first;

  /// "Operação em curso" ou "Próxima operação", pela janela do evento. Nulo
  /// quando não há evento (a eleição manda `evento: null`).
  String? get rotuloEvento {
    if (evento == null || evento!.isEmpty) return null;
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final ini = eventoInicio, fim = eventoFim;
    if (ini != null && hoje.compareTo(ini) < 0) return 'Próxima operação';
    if (fim != null && hoje.compareTo(fim) > 0) return 'Última operação';
    return 'Operação em curso';
  }

  /// "03/11 a 08/11", ou nulo se o Operar não mandou a janela.
  String? get periodoEvento {
    final ini = eventoInicio, fim = eventoFim;
    if (ini == null || fim == null || ini.length < 10 || fim.length < 10) return null;
    String d(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}';
    return ini == fim ? d(ini) : '${d(ini)} a ${d(fim)}';
  }
}

class MeuServicoApi {
  MeuServicoApi({required this.api, required this.sessao});

  final ApiClient api;
  final SessaoOperar sessao;

  static const prefixo = OperarApi.prefixo;

  /// Lê `/api/meu-servico`. Em 401 o aparelho foi desligado do outro lado:
  /// pede um token novo e tenta uma vez só, para não entrar em laço.
  ///
  /// Este caminho depende de o 401 chegar com content-type JSON: o
  /// `ApiClient` só devolve status fora do 200 quando a resposta é JSON, e do
  /// contrário lança antes. O Operar é FastAPI e responde `{"detail": ...}`,
  /// então funciona — mas um 401 cuspido pelo Apache à frente dele viria em
  /// HTML, e aí a renovação não aconteceria. Um teste cobre o caso bom
  /// (`test/features/operacoes_test.dart`); o ruim vira falha comum, que a
  /// tela trata abrindo o login do próprio Operar.
  Future<MeuServicoOperacao> ler() async {
    var r = await _pedir(await sessao.token());
    if (r.status == 401) {
      r = await _pedir(await sessao.token(renovar: true));
    }
    if (r.status != 200) throw FalhaApp.httpStatus(prefixo, r.status);
    final j = r.corpo;
    if (j is! Map) {
      throw FalhaApp.respostaInvalida(prefixo, detalhe: 'meu-servico não devolveu objeto');
    }
    final lista = j['servicos'];
    final evento = j['evento'];
    final militar = j['militar'];
    return MeuServicoOperacao(
      servicos: [
        for (final s in (lista is List ? lista : const []))
          if (ServicoOperacao.deJson(s) case final v?) v,
      ],
      evento: evento is Map ? '${evento['curto'] ?? evento['nome'] ?? ''}' : null,
      eventoInicio: evento is Map ? evento['inicio'] as String? : null,
      eventoFim: evento is Map ? evento['fim'] as String? : null,
      nomeGuerra: militar is Map ? militar['nome_guerra'] as String? : null,
    );
  }

  Future<({int status, dynamic corpo})> _pedir(String token) => api.requisicao(
        'GET',
        Uri.parse('$urlOperar/api/meu-servico'),
        prefixo: prefixo,
        cabecalhos: {'Authorization': 'Bearer $token'},
      );
}
