import 'escala_model.dart';

// ── Modelos do módulo SVI (Serviço Voluntário Interno) ────────────────────────

/// Status possíveis da adesão SVI retornados pela API.
enum SviAdesaoStatus {
  semAdesao,
  pendente,
  ativa,
  suspensa,
  cancelada,
  desconhecido,
}

SviAdesaoStatus _parseStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'sem_adesao':
    case 'sem adesao':
      return SviAdesaoStatus.semAdesao;
    case 'pendente':
      return SviAdesaoStatus.pendente;
    case 'ativa':
    case 'ativo':
      return SviAdesaoStatus.ativa;
    case 'suspensa':
    case 'suspenso':
      return SviAdesaoStatus.suspensa;
    case 'cancelada':
    case 'cancelado':
      return SviAdesaoStatus.cancelada;
    default:
      return SviAdesaoStatus.desconhecido;
  }
}

class SviAdesaoModel {
  final SviAdesaoStatus status;
  final String statusRaw;
  final DateTime? dataAssinatura;
  final int horasMes;
  final bool ativa;

  const SviAdesaoModel({
    required this.status,
    required this.statusRaw,
    this.dataAssinatura,
    required this.horasMes,
    required this.ativa,
  });

  factory SviAdesaoModel.fromJson(Map<String, dynamic> j) {
    final rawStatus = j['status']?.toString();
    return SviAdesaoModel(
      status: _parseStatus(rawStatus),
      statusRaw: rawStatus ?? '',
      dataAssinatura: j['data_assinatura'] != null
          ? DateTime.tryParse(j['data_assinatura'].toString())
          : null,
      horasMes: (j['horas_mes'] as num?)?.toInt() ?? 0,
      ativa: j['ativa'] == true,
    );
  }
}

class SviTermoModel {
  final String texto;
  final String versao;

  const SviTermoModel({required this.texto, required this.versao});

  factory SviTermoModel.fromJson(Map<String, dynamic> j) => SviTermoModel(
        texto: j['texto']?.toString() ?? '',
        versao: j['versao']?.toString() ?? '',
      );
}

/// Resposta consolidada de GET /perfil/resumo
class PerfilResumoModel {
  final EscalaModel? proximaEscala;
  final SviAdesaoModel? adesaoSvi;
  final int notificacoesPendentes;
  final int horasSviMes;

  const PerfilResumoModel({
    this.proximaEscala,
    this.adesaoSvi,
    required this.notificacoesPendentes,
    required this.horasSviMes,
  });

  factory PerfilResumoModel.fromJson(Map<String, dynamic> j) =>
      PerfilResumoModel(
        proximaEscala: j['proxima_escala'] is Map<String, dynamic>
            ? EscalaModel.fromJson(j['proxima_escala'] as Map<String, dynamic>)
            : null,
        adesaoSvi: j['adesao_svi'] is Map<String, dynamic>
            ? SviAdesaoModel.fromJson(j['adesao_svi'] as Map<String, dynamic>)
            : null,
        notificacoesPendentes:
            (j['notificacoes_pendentes'] as num?)?.toInt() ?? 0,
        horasSviMes: (j['horas_svi_mes'] as num?)?.toInt() ?? 0,
      );
}

// ── Auto-escalação SVI (vagas para voluntários) ──────────────────────────────

int _sviInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// Um slot/vaga individual de uma escala SVI. Fornecido em detalhe por
/// GET /svi/escalas/{id}/slots (com `guarnicao_id` + `funcao_id`, campo
/// `disponivel` e restrições de posto/graduação e quadro). O parse é defensivo
/// para aceitar variações de chave.
class SviSlotModel {
  final int guarnicaoId;
  final String guarnicaoNome;
  final int funcaoId;
  final String funcaoNome;
  final String? postoPermitido;
  final String? quadroPermitido;
  final bool disponivel;
  final String? motivoIndisponivel;

  const SviSlotModel({
    required this.guarnicaoId,
    required this.guarnicaoNome,
    required this.funcaoId,
    required this.funcaoNome,
    this.postoPermitido,
    this.quadroPermitido,
    this.disponivel = true,
    this.motivoIndisponivel,
  });

  /// Junta uma restrição que pode vir como string ou como lista de strings.
  static String? _joinRestricao(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final parts =
          v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty);
      final joined = parts.join(', ');
      return joined.isEmpty ? null : joined;
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory SviSlotModel.fromJson(Map<String, dynamic> j) => SviSlotModel(
        guarnicaoId: _sviInt(j['guarnicao_id']),
        guarnicaoNome: (j['guarnicao_nome'] ?? j['guarnicao'] ?? '').toString(),
        funcaoId: _sviInt(j['funcao_id']),
        funcaoNome: (j['funcao_nome'] ?? j['funcao'] ?? '').toString(),
        postoPermitido: _joinRestricao(j['postos_permitidos'] ??
            j['posto_permitido'] ??
            j['posto'] ??
            j['restricao_posto']),
        quadroPermitido: _joinRestricao(j['quadros_permitidos'] ??
            j['quadro_permitido'] ??
            j['quadro'] ??
            j['restricao_quadro']),
        disponivel: j['disponivel'] == null ? true : j['disponivel'] == true,
        motivoIndisponivel: (j['motivo_indisponivel'] ??
                j['motivo'] ??
                j['indisponivel_motivo'])
            ?.toString(),
      );
}

/// Resposta de GET /svi/escalas/{id}/slots — slots detalhados de uma escala.
class SviEscalaSlotsResult {
  final int escalaId;
  final bool aberta;
  final bool temAdesao;
  final List<SviSlotModel> slots;
  final String? mensagem;

  const SviEscalaSlotsResult({
    required this.escalaId,
    required this.aberta,
    required this.temAdesao,
    required this.slots,
    this.mensagem,
  });

  factory SviEscalaSlotsResult.fromJson(Map<String, dynamic> j) {
    final rawSlots =
        (j['slots'] ?? j['vagas'] ?? j['guarnicoes']) as List<dynamic>?;
    return SviEscalaSlotsResult(
      escalaId: _sviInt(j['escala_id'] ?? j['id']),
      aberta: j['aberta'] == null ? true : j['aberta'] == true,
      temAdesao: j['tem_adesao'] == null ? true : j['tem_adesao'] == true,
      slots: rawSlots == null
          ? const []
          : rawSlots
              .whereType<Map<String, dynamic>>()
              .map(SviSlotModel.fromJson)
              .toList(),
      mensagem: j['mensagem']?.toString(),
    );
  }
}

/// Uma escala SVI disponível para candidatura (GET /svi/escalas-disponiveis).
class SviEscalaDisponivelModel {
  final int id;
  final String titulo;
  final String dataEscala;
  final String dataInicio;
  final String tipoServico;
  final String tipoServicoSigla;
  final String comandoSigla;
  final String localAssuncao;
  final String horarioInicio;
  final String horarioFim;
  final DateTime? prazoVoluntarios;
  final int slotsDisponiveis;
  final bool jaEscalado;
  final List<SviSlotModel> slots;

  const SviEscalaDisponivelModel({
    required this.id,
    required this.titulo,
    required this.dataEscala,
    required this.dataInicio,
    required this.tipoServico,
    required this.tipoServicoSigla,
    required this.comandoSigla,
    required this.localAssuncao,
    required this.horarioInicio,
    required this.horarioFim,
    this.prazoVoluntarios,
    required this.slotsDisponiveis,
    required this.jaEscalado,
    this.slots = const [],
  });

  factory SviEscalaDisponivelModel.fromJson(Map<String, dynamic> j) {
    final rawSlots =
        (j['slots'] ?? j['vagas'] ?? j['guarnicoes']) as List<dynamic>?;
    return SviEscalaDisponivelModel(
      id: _sviInt(j['id']),
      titulo: j['titulo']?.toString() ?? '',
      dataEscala: j['data_escala']?.toString() ?? '',
      dataInicio: j['data_inicio']?.toString() ?? '',
      tipoServico: j['tipo_servico']?.toString() ?? '',
      tipoServicoSigla: j['tipo_servico_sigla']?.toString() ?? '',
      comandoSigla: j['comando_sigla']?.toString() ?? '',
      localAssuncao: j['local_assuncao']?.toString() ?? '',
      horarioInicio: j['horario_inicio']?.toString() ?? '',
      horarioFim: j['horario_fim']?.toString() ?? '',
      prazoVoluntarios: j['prazo_voluntarios'] != null
          ? DateTime.tryParse(j['prazo_voluntarios'].toString())
          : null,
      slotsDisponiveis: _sviInt(j['slots_disponiveis']),
      jaEscalado: j['ja_escalado'] == true,
      slots: rawSlots == null
          ? const []
          : rawSlots
              .whereType<Map<String, dynamic>>()
              .map(SviSlotModel.fromJson)
              .toList(),
    );
  }

  /// Horário formatado sem os segundos (07:00:00 → 07:00).
  String _hm(String h) => h.length >= 5 ? h.substring(0, 5) : h;
  String get horarioInicioFmt => _hm(horarioInicio);
  String get horarioFimFmt => _hm(horarioFim);

  bool get prazoEncerrado =>
      prazoVoluntarios != null && prazoVoluntarios!.isBefore(DateTime.now());

  bool get semVagas => slotsDisponiveis <= 0;

  /// Se o app pode oferecer o botão "Quero este serviço" para esta escala.
  bool get podeCandidatar => !jaEscalado && !prazoEncerrado && !semVagas;
}

/// Resposta consolidada de GET /svi/escalas-disponiveis.
class SviEscalasDisponiveisResult {
  final bool temAdesao;
  final List<SviEscalaDisponivelModel> escalas;
  final String? mensagem;

  const SviEscalasDisponiveisResult({
    required this.temAdesao,
    required this.escalas,
    this.mensagem,
  });

  factory SviEscalasDisponiveisResult.fromJson(Map<String, dynamic> j) =>
      SviEscalasDisponiveisResult(
        temAdesao: j['tem_adesao'] == true,
        escalas: (j['escalas'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SviEscalaDisponivelModel.fromJson)
            .toList(),
        mensagem: j['mensagem']?.toString(),
      );
}

/// Um serviço no qual o militar se candidatou (GET /svi/meus-voluntarios).
class SviVoluntarioModel {
  final int militarId;
  final int escalaId;
  final String dataEscala;
  final String dataInicio;
  final String titulo;
  final String tipoServico;
  final String tipoServicoSigla;
  final String comandoSigla;
  final String localAssuncao;
  final String horarioInicio;
  final String horarioFim;
  final int horas;
  final String guarnicaoNome;
  final String funcao;
  final String situacao;
  final DateTime? voluntarioEm;
  final String statusEscala;

  const SviVoluntarioModel({
    required this.militarId,
    required this.escalaId,
    required this.dataEscala,
    required this.dataInicio,
    required this.titulo,
    required this.tipoServico,
    required this.tipoServicoSigla,
    required this.comandoSigla,
    required this.localAssuncao,
    required this.horarioInicio,
    required this.horarioFim,
    required this.horas,
    required this.guarnicaoNome,
    required this.funcao,
    required this.situacao,
    this.voluntarioEm,
    required this.statusEscala,
  });

  factory SviVoluntarioModel.fromJson(Map<String, dynamic> j) =>
      SviVoluntarioModel(
        militarId: _sviInt(j['militar_id']),
        escalaId: _sviInt(j['escala_id']),
        dataEscala: j['data_escala']?.toString() ?? '',
        dataInicio: j['data_inicio']?.toString() ?? '',
        titulo: j['titulo']?.toString() ?? '',
        tipoServico: j['tipo_servico']?.toString() ?? '',
        tipoServicoSigla: j['tipo_servico_sigla']?.toString() ?? '',
        comandoSigla: j['comando_sigla']?.toString() ?? '',
        localAssuncao: j['local_assuncao']?.toString() ?? '',
        horarioInicio: j['horario_inicio']?.toString() ?? '',
        horarioFim: j['horario_fim']?.toString() ?? '',
        horas: _sviInt(j['horas']),
        guarnicaoNome: j['guarnicao_nome']?.toString() ?? '',
        funcao: j['funcao']?.toString() ?? '',
        situacao: j['situacao']?.toString() ?? '',
        voluntarioEm: j['voluntario_em'] != null
            ? DateTime.tryParse(j['voluntario_em'].toString())
            : null,
        statusEscala: j['status_escala']?.toString() ?? '',
      );

  String _hm(String h) => h.length >= 5 ? h.substring(0, 5) : h;
  String get horarioInicioFmt => _hm(horarioInicio);
  String get horarioFimFmt => _hm(horarioFim);
}
