class CertidaoModel {
  final int soceCod;
  final DateTime? soceData;
  final int soceAtivo;
  final int fkPoliMiliMatricula;
  final int? fkTiceCod;
  final DateTime? soceDataVencimento;
  int? fkStceCod;
  final String? soceArquivo;
  // Novo: arquivo em base64 quando vindo do backend
  final String? soceArquivoBase64;
  final String? soceObs;
  final String? soceJustificativa;

  CertidaoModel({
    required this.soceCod,
    this.soceData,
    required this.soceAtivo,
    required this.fkPoliMiliMatricula,
    this.fkTiceCod,
    this.soceDataVencimento,
    this.fkStceCod,
    this.soceArquivo,
    this.soceArquivoBase64,
    this.soceObs,
    this.soceJustificativa,
  });

  // getter que retorna o nome do tipo conforme soceCod
  String get nomeTipoCertidao {
    switch (fkTiceCod) {
      case 1:
        return 'Certidão de Tempo de Serviço';
      case 2:
        return 'Ficha Funcional';
      default:
        return 'error';
    }
  }

  bool get ativo => soceAtivo == 1;

  factory CertidaoModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    return CertidaoModel(
      soceCod: parseInt(json['soce_cod'] ?? json['soceCod'] ?? json['soceCod']),
      soceData: parseDate(json['soce_data'] ?? json['soceData']),
      soceAtivo: parseInt(json['soce_ativo'] ?? json['soceAtivo']),
      fkPoliMiliMatricula: parseInt(
          json['fk_poli_mili_matricula'] ?? json['fkPoliMiliMatricula']),
      fkTiceCod: json['fk_tice_cod'] != null || json['fkTiceCod'] != null
          ? parseInt(json['fk_tice_cod'] ?? json['fkTiceCod'])
          : null,
      soceDataVencimento:
          parseDate(json['soce_data_vencimento'] ?? json['soceDataVencimento']),
      fkStceCod: json['fk_stce_cod'] != null || json['fkStceCod'] != null
          ? parseInt(json['fk_stce_cod'] ?? json['fkStceCod'])
          : null,
      soceArquivo: (json['soce_arquivo'] ?? json['soceArquivo'])?.toString(),
      soceArquivoBase64:
          (json['soce_arquivo_base64'] ?? json['soceArquivoBase64'])
              ?.toString(),
      soceObs: (json['soce_obs'] ?? json['soceObs'])?.toString(),
      soceJustificativa:
          (json['soce_justificativa'] ?? json['soceJustificativa'])?.toString(),
    );
  }

  static List<CertidaoModel> listFromJson(dynamic list) {
    if (list is! List) return [];
    return list
        .map((e) => e is Map<String, dynamic>
            ? CertidaoModel.fromJson(e)
            : CertidaoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
