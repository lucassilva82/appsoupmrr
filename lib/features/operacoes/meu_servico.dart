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
    this.publicada,
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

  /// A escala já foi FECHADA pelo comando? Enquanto não for, o lançamento é
  /// montagem e pode mudar — foi o que um militar viu em 05/11/2026: o card
  /// dizia que ele estava escalado em 06/11 e, ao abrir, não estava.
  ///
  /// **Nulo é "não sei", nunca "em planejamento"**: o campo nasceu no Operar
  /// em 05/11/2026, e um Operar mais antigo não o manda. Acusar planejamento
  /// por ausência seria afirmar sobre o mundo o que é falta do instrumento.
  final bool? publicada;

  /// Só quando o Operar disse que a escala ainda não fechou.
  bool get emPlanejamento => publicada == false;

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
      publicada: j['publicada'] is bool ? j['publicada'] as bool : null,
    );
  }
}

/// Uma operação aberta no Operar (`GET /api/eventos`), com o código que vai no
/// cabeçalho `X-Turno` ("1T" Expoferr, "2T" ENEM).
///
/// O Operar corta toda leitura pelo evento do pedido; sem `X-Turno` ele cai no
/// primeiro. Foi por isso que o card só mostrava a Expoferr enquanto o ENEM já
/// tinha escala (usuário, 07/11/2026).
class EventoOperar {
  const EventoOperar({
    required this.codigo,
    required this.nome,
    this.curto,
    this.inicio,
    this.fim,
  });

  final String codigo;
  final String nome;
  final String? curto;
  final String? inicio;
  final String? fim;

  /// "Operação ENEM 2026": o título do card. Sem repetir a palavra quando o
  /// próprio nome já a traz.
  String get titulo =>
      nome.toLowerCase().startsWith('operação') ? nome : 'Operação $nome';

  static EventoOperar? deJson(Object? j) {
    if (j is! Map) return null;
    final codigo = j['codigo'], nome = j['nome'], acesso = j['acesso'];
    if (codigo is! String || codigo.isEmpty || nome is! String || nome.isEmpty) return null;
    // Só a operação ABERTA (o mesmo filtro do app de campo, evtAtuais):
    // consulta, prévia e preparação não têm escala para o card mostrar.
    if (acesso is! Map || acesso['modo'] != 'atual') return null;
    return EventoOperar(
      codigo: codigo,
      nome: nome,
      curto: j['curto'] as String?,
      inicio: j['inicio'] as String?,
      fim: j['fim'] as String?,
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
  ///
  /// Com [evento], o pedido leva `X-Turno` e o Operar responde só daquela
  /// operação; o nome e as datas do card vêm então do próprio [evento], como
  /// o app de campo faz (evtInfo), e não do bloco `evento` da resposta.
  Future<MeuServicoOperacao> ler({EventoOperar? evento}) async {
    final r = await _comRenovacao('/api/meu-servico', turno: evento?.codigo);
    final j = r.corpo;
    if (j is! Map) {
      throw FalhaApp.respostaInvalida(prefixo, detalhe: 'meu-servico não devolveu objeto');
    }
    final lista = j['servicos'];
    final ev = j['evento'];
    final militar = j['militar'];
    return MeuServicoOperacao(
      servicos: [
        for (final s in (lista is List ? lista : const []))
          if (ServicoOperacao.deJson(s) case final v?) v,
      ],
      evento: evento != null
          ? (evento.curto ?? evento.nome)
          : ev is Map ? '${ev['curto'] ?? ev['nome'] ?? ''}' : null,
      eventoInicio: evento != null ? evento.inicio : ev is Map ? ev['inicio'] as String? : null,
      eventoFim: evento != null ? evento.fim : ev is Map ? ev['fim'] as String? : null,
      nomeGuerra: militar is Map ? militar['nome_guerra'] as String? : null,
    );
  }

  /// As operações abertas agora (`GET /api/eventos`). Fora do modo evento (a
  /// eleição) a lista vem vazia, e o card segue com um só, como antes.
  Future<List<EventoOperar>> eventos() async {
    final r = await _comRenovacao('/api/eventos');
    final j = r.corpo;
    if (j is! Map) {
      throw FalhaApp.respostaInvalida(prefixo, detalhe: 'eventos não devolveu objeto');
    }
    final base = j['evento'];
    final lista = j['eventos'];
    if (base is! Map || base['modo_evento'] != true || lista is! List) return const [];
    return [
      for (final e in lista)
        if (EventoOperar.deJson(e) case final v?) v,
    ];
  }

  /// Em 401 o aparelho foi desligado do outro lado: pede um token novo e
  /// tenta uma vez só, para não entrar em laço.
  Future<({int status, dynamic corpo})> _comRenovacao(String caminho, {String? turno}) async {
    var r = await _pedir(caminho, await sessao.token(), turno);
    if (r.status == 401) {
      r = await _pedir(caminho, await sessao.token(renovar: true), turno);
    }
    if (r.status != 200) throw FalhaApp.httpStatus(prefixo, r.status);
    return r;
  }

  Future<({int status, dynamic corpo})> _pedir(String caminho, String token, String? turno) =>
      api.requisicao(
        'GET',
        Uri.parse('$urlOperar$caminho'),
        prefixo: prefixo,
        // X-App-Planejamento: esta versão desenha o aviso de "escala em
        // planejamento" por conta própria (o campo `publicada`). Sem este
        // cabeçalho o Operar embute o aviso no texto do posto, para o app que
        // já está na loja mostrar alguma coisa — e é por ele que o servidor
        // sabe que aqui não precisa, evitando o aviso em dobro.
        cabecalhos: {
          'Authorization': 'Bearer $token',
          'X-App-Planejamento': '1',
          if (turno != null) 'X-Turno': turno,
        },
      );
}
