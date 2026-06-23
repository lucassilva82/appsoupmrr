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
