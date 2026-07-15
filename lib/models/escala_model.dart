// ── Modelos do módulo Escalas de Serviço ─────────────────────────────────────

/// Conversão defensiva para int (backend pode enviar int, num ou string).
int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

enum EscalaStatusVisual {
  aguardandoCiencia, // 🟡 futura, sem ciência
  ciente, // 🟢 futura, com ciência
  impossibilidade, // 🔴 impossibilidade declarada
  realizada, // ⚪ passada, com ciência
  semCienciaHistorico, // ⚫ passada, sem ciência
}

class EscalaComposicaoModel {
  final String matricula;
  final String funcao;
  final String postoSigla;
  final String quadroSigla;
  final String nomeGuerra;
  final String? telefone;

  const EscalaComposicaoModel({
    required this.matricula,
    required this.funcao,
    required this.postoSigla,
    required this.quadroSigla,
    required this.nomeGuerra,
    this.telefone,
  });

  factory EscalaComposicaoModel.fromJson(Map<String, dynamic> j) =>
      EscalaComposicaoModel(
        matricula: j['matricula']?.toString() ?? '',
        funcao: j['funcao']?.toString() ?? '',
        postoSigla: j['posto_sigla']?.toString() ?? '',
        quadroSigla: j['quadro_sigla']?.toString() ?? '',
        nomeGuerra: j['nome_guerra']?.toString() ?? '',
        telefone: j['telefone']?.toString(),
      );
}

class EscalaImpossibilidadeTipo {
  final int id;
  final String codigo;
  final String descricao;
  final bool requerAnexo;

  const EscalaImpossibilidadeTipo({
    required this.id,
    required this.codigo,
    required this.descricao,
    required this.requerAnexo,
  });

  factory EscalaImpossibilidadeTipo.fromJson(Map<String, dynamic> j) =>
      EscalaImpossibilidadeTipo(
        id: _asInt(j['id']),
        codigo: j['codigo']?.toString() ?? '',
        descricao: j['descricao']?.toString() ?? '',
        requerAnexo: j['requer_anexo'] == true,
      );
}

class EscalaModel {
  final int escalaId;
  final String escalaStatus;
  final String dataEscala;
  final String dataEscalaIso;
  final String tipoServico;
  final String guarnicaoNome;
  final String? vtr;
  final String? localAtuacao;
  final String horarioIni;
  final String horarioFim;
  final String funcaoNome;
  final String horas;
  final String? localAssuncao;
  final String? uniforme;
  final String? observacoesGerais;
  bool temCiencia;
  String? cienciaEmBr;
  bool temImpossibilidade;
  final List<EscalaComposicaoModel> composicao;
  final String? corpoNotificacao;
  final String? policialNomeGuerra;
  final String? policialPostoSigla;
  final String? policialNomeCompleto;
  final String? policialTelefone;

  EscalaModel({
    required this.escalaId,
    required this.escalaStatus,
    required this.dataEscala,
    required this.dataEscalaIso,
    required this.tipoServico,
    required this.guarnicaoNome,
    this.vtr,
    this.localAtuacao,
    required this.horarioIni,
    required this.horarioFim,
    required this.funcaoNome,
    required this.horas,
    this.localAssuncao,
    this.uniforme,
    this.observacoesGerais,
    required this.temCiencia,
    this.cienciaEmBr,
    required this.temImpossibilidade,
    this.composicao = const [],
    this.corpoNotificacao,
    this.policialNomeGuerra,
    this.policialPostoSigla,
    this.policialNomeCompleto,
    this.policialTelefone,
  });

  factory EscalaModel.fromJson(Map<String, dynamic> j) {
    final composicaoList = (j['composicao'] as List<dynamic>? ?? [])
        .map((e) => EscalaComposicaoModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final policial = j['policial'] as Map<String, dynamic>?;

    return EscalaModel(
      escalaId: _asInt(j['escala_id']),
      escalaStatus: j['escala_status']?.toString() ?? '',
      dataEscala: j['data_escala']?.toString() ?? '',
      dataEscalaIso: j['data_escala_iso']?.toString() ?? '',
      tipoServico: j['tipo_servico']?.toString() ?? '',
      guarnicaoNome: j['guarnicao_nome']?.toString() ?? '',
      vtr: j['vtr']?.toString(),
      localAtuacao: j['local_atuacao']?.toString(),
      horarioIni: j['horario_ini']?.toString() ?? '',
      horarioFim: j['horario_fim']?.toString() ?? '',
      funcaoNome: j['funcao_nome']?.toString() ?? '',
      horas: j['horas']?.toString() ?? '',
      localAssuncao: j['local_assuncao']?.toString(),
      uniforme: j['uniforme']?.toString(),
      observacoesGerais: j['observacoes_gerais']?.toString(),
      temCiencia: j['tem_ciencia'] == true,
      cienciaEmBr: j['ciencia_em_br']?.toString(),
      temImpossibilidade: j['tem_impossibilidade'] == true,
      composicao: composicaoList,
      corpoNotificacao: j['corpo_notificacao']?.toString(),
      policialNomeGuerra: policial?['nome_guerra']?.toString(),
      policialPostoSigla: policial?['posto_sigla']?.toString(),
      policialNomeCompleto: policial?['nome_completo']?.toString(),
      policialTelefone: policial?['telefone']?.toString(),
    );
  }

  bool get isFuture {
    try {
      final date = DateTime.parse(dataEscalaIso);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      return !date.isBefore(todayStart);
    } catch (_) {
      return false;
    }
  }

  EscalaStatusVisual get statusVisual {
    if (temImpossibilidade) return EscalaStatusVisual.impossibilidade;
    if (!isFuture && temCiencia) return EscalaStatusVisual.realizada;
    if (!isFuture && !temCiencia) return EscalaStatusVisual.semCienciaHistorico;
    if (temCiencia) return EscalaStatusVisual.ciente;
    return EscalaStatusVisual.aguardandoCiencia;
  }
}
