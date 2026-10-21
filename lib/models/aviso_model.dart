// Aviso do SIGE (escala, permuta, SVI) aberto pelo toque no push ou na lista.
//
// O contrato é o do documento da frente SIGE (PARA_O_LUCAS_AVISOS_E_TOQUE.md,
// partes 3 e 4): o push traz `tipo_evento`, `referencia_id` e `notificacao_id`
// no `data`; com o id, `GET /dispositivo/notificacoes/{id}` devolve o texto
// inteiro e o `destino` já resolvido pelo servidor. O app não adivinha o
// destino pelo tipo: tipo ou tela que ele não conhece viram só texto.

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

String? _texto(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// O que o app já tem no instante do toque (push ou item da lista), antes de
/// falar com o servidor. Basta para mostrar o texto do aviso.
class AvisoAberto {
  final int? notificacaoId;
  final String titulo;
  final String corpo;
  final String? tipoEvento;
  final int? referenciaId;
  final DateTime? recebidoEm;

  const AvisoAberto({
    this.notificacaoId,
    required this.titulo,
    required this.corpo,
    this.tipoEvento,
    this.referenciaId,
    this.recebidoEm,
  });

  /// `data` do FCM: tudo chega como texto. Aceita as chaves da Cloud Function
  /// (`titulo`, `mensagem`) e as do sistema (`title`, `body`).
  factory AvisoAberto.doPush(Map<String, dynamic> data,
      {String? tituloSistema, String? corpoSistema}) {
    return AvisoAberto(
      notificacaoId: _int(data['notificacao_id']),
      titulo: _texto(data['titulo']) ?? _texto(tituloSistema) ?? 'Aviso',
      corpo: _texto(data['mensagem']) ?? _texto(corpoSistema) ?? '',
      tipoEvento: _texto(data['tipo_evento']),
      referenciaId: _int(data['referencia_id']),
      recebidoEm: DateTime.tryParse(data['recebido_em']?.toString() ?? ''),
    );
  }

  /// Aviso que pode ser aberto nesta tela: veio do SIGE com o id do aviso ou,
  /// em push antigo, ao menos com o tipo do evento.
  static bool ehDoSige(Map<String, dynamic> data) =>
      _int(data['notificacao_id']) != null ||
      _texto(data['tipo_evento']) != null;
}

/// Telas que o servidor pode mandar em `destino.tela`. Qualquer outra vira
/// [TelaDestino.aviso] (o SIGE pode criar telas novas sem avisar o app).
enum TelaDestino { escala, permuta, sviVagas, sviAdesao, aviso }

TelaDestino telaDestinoDe(String? tela) {
  switch (tela) {
    case 'escala':
      return TelaDestino.escala;
    case 'permuta':
      return TelaDestino.permuta;
    case 'svi_vagas':
      return TelaDestino.sviVagas;
    case 'svi_adesao':
      return TelaDestino.sviAdesao;
    default:
      return TelaDestino.aviso;
  }
}

class AvisoDestino {
  final TelaDestino tela;
  final String telaRaw;
  final int? id;
  final int? escalaId;
  final List<String> acoes;
  final bool somenteLeitura;
  final String? situacaoMilitar;

  const AvisoDestino({
    required this.tela,
    required this.telaRaw,
    this.id,
    this.escalaId,
    this.acoes = const [],
    this.somenteLeitura = true,
    this.situacaoMilitar,
  });

  static const somenteTexto =
      AvisoDestino(tela: TelaDestino.aviso, telaRaw: 'aviso');

  factory AvisoDestino.fromJson(Map<String, dynamic>? j) {
    if (j == null) return somenteTexto;
    var tela = telaDestinoDe(j['tela']?.toString());
    final id = _int(j['id']);
    // Escala e permuta sem id não têm o que carregar: ficam só com o texto.
    if ((tela == TelaDestino.escala || tela == TelaDestino.permuta) &&
        id == null) {
      tela = TelaDestino.aviso;
    }
    return AvisoDestino(
      tela: tela,
      telaRaw: j['tela']?.toString() ?? '',
      id: id,
      escalaId: _int(j['escala_id']),
      acoes: (j['acoes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      somenteLeitura: j['somente_leitura'] != false,
      situacaoMilitar: _texto(j['situacao_militar']),
    );
  }

  /// Push antigo, sem `notificacao_id`: monta o destino pelo tipo, só para
  /// os tipos cujo `referencia_id` é com certeza o id de uma escala diária.
  /// O resto fica só com o texto (o servidor é quem sabe o que abrir).
  factory AvisoDestino.peloTipo(String? tipo, int? referenciaId) {
    const tiposDeEscala = {
      'publicada',
      'escalado',
      'aprovada',
      'ciencia_lembrete',
      'cancelada',
      'removido',
      'svi_inscrito',
    };
    if (referenciaId != null && tiposDeEscala.contains(tipo)) {
      return AvisoDestino(
        tela: TelaDestino.escala,
        telaRaw: 'escala',
        id: referenciaId,
        escalaId: referenciaId,
      );
    }
    return somenteTexto;
  }
}

/// Resposta de `GET /dispositivo/notificacoes/{id}`.
class AvisoDetalhe {
  final int id;
  final String titulo;
  final String corpo;
  final String? tipoEvento;
  final String? criadoEmBr;
  final bool lida;
  final AvisoDestino destino;

  const AvisoDetalhe({
    required this.id,
    required this.titulo,
    required this.corpo,
    this.tipoEvento,
    this.criadoEmBr,
    required this.lida,
    required this.destino,
  });

  factory AvisoDetalhe.fromJson(Map<String, dynamic> j) => AvisoDetalhe(
        id: _int(j['id']) ?? 0,
        titulo: _texto(j['titulo']) ?? '',
        corpo: _texto(j['corpo']) ?? '',
        tipoEvento: _texto(j['tipo_evento']),
        criadoEmBr: _texto(j['criado_em_br']),
        lida: j['lida'] == true,
        destino: AvisoDestino.fromJson(j['destino'] as Map<String, dynamic>?),
      );
}

/// Resposta de `GET /escala/permuta/{id}` (somente leitura: quem decide é o
/// escalante).
class PermutaModel {
  final int permutaId;
  final int? escalaId;
  final String tipo;
  final String situacao;
  final String situacaoTexto;
  final String? meuPapel;
  final String dataServico;
  final String? tipoServico;
  final String? guarnicao;
  final String? horarioIni;
  final String? horarioFim;
  final String? solicitante;
  final String? titular;
  final bool jaNaEscala;
  final String? mensagem;

  const PermutaModel({
    required this.permutaId,
    this.escalaId,
    required this.tipo,
    required this.situacao,
    required this.situacaoTexto,
    this.meuPapel,
    required this.dataServico,
    this.tipoServico,
    this.guarnicao,
    this.horarioIni,
    this.horarioFim,
    this.solicitante,
    this.titular,
    this.jaNaEscala = false,
    this.mensagem,
  });

  bool get ehSubstituicao => tipo.toUpperCase() == 'SUBSTITUICAO';

  factory PermutaModel.fromJson(Map<String, dynamic> j) {
    final turno = j['turno'] as Map<String, dynamic>?;
    return PermutaModel(
      permutaId: _int(j['permuta_id']) ?? 0,
      escalaId: _int(j['escala_id']),
      tipo: j['tipo']?.toString() ?? '',
      situacao: j['situacao']?.toString() ?? '',
      situacaoTexto:
          _texto(j['situacao_texto']) ?? _texto(j['situacao']) ?? '',
      meuPapel: _texto(j['meu_papel']),
      dataServico: j['data_servico']?.toString() ?? '',
      tipoServico: _texto(j['tipo_servico']),
      guarnicao: _texto(j['guarnicao']),
      horarioIni: _texto(turno?['horario_ini']),
      horarioFim: _texto(turno?['horario_fim']),
      solicitante: _texto(j['solicitante']),
      titular: _texto(j['titular']),
      jaNaEscala: j['ja_na_escala'] == true,
      mensagem: _texto(j['mensagem']),
    );
  }
}
