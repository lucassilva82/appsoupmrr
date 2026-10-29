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
  const MeuServicoOperacao({required this.servicos, this.evento, this.nomeGuerra});

  final List<ServicoOperacao> servicos;

  /// Nome curto da operação (Expoferr, ENEM). Nulo fora do modo evento — na
  /// eleição o Operar manda `evento: null`.
  final String? evento;
  final String? nomeGuerra;

  bool get temServico => servicos.isNotEmpty;

  /// O primeiro serviço da lista: o Operar já a devolve na ordem do dia.
  ServicoOperacao? get proximo => servicos.isEmpty ? null : servicos.first;
}

class MeuServicoApi {
  MeuServicoApi({required this.api, required this.sessao});

  final ApiClient api;
  final SessaoOperar sessao;

  static const prefixo = OperarApi.prefixo;

  /// Lê `/api/meu-servico`. Em 401 o aparelho foi desligado do outro lado:
  /// pede um token novo e tenta uma vez só, para não entrar em laço.
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
