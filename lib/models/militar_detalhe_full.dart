// lib/models/militar_detalhe_full.dart
class MilitarDetalheFull {
  final String cpf;
  final String matricula;
  final String postoGraduacao;
  final String quadro;
  final String qra;
  final String nomeCompleto;
  final String incorporacao;
  final String telefone;
  final bool whats;
  final String? imagemUrl;
  final String unidadeSigla; // NOVO
  final String subunidade;
  final String municipio;
  final String bairro;
  final String rua;
  final String numero;
  final String matRhNova; // NOVO
  final String cep;

  MilitarDetalheFull({
    required this.cpf,
    required this.matRhNova,
    required this.matricula,
    required this.postoGraduacao,
    required this.quadro,
    required this.qra,
    required this.nomeCompleto,
    required this.incorporacao,
    required this.telefone,
    required this.whats,
    required this.imagemUrl,
    required this.unidadeSigla,
    required this.subunidade,
    required this.municipio,
    required this.bairro,
    required this.rua,
    required this.numero,
    required this.cep,
  });

  factory MilitarDetalheFull.fromJson(Map<String, dynamic> j) =>
      MilitarDetalheFull(
        cpf: j['cpf'],
        matRhNova: j['sigrh'].toString(),
        matricula: j['matricula'].toString(),
        postoGraduacao: j['postograduacao'],
        quadro: j['quadro'],
        qra: j['qra'],
        nomeCompleto: j['nomecompleto'],
        incorporacao: j['incorporacao'],
        telefone: j['telefone'].trim(),
        whats: (j['poli_cont_whats'] ?? 0) == 1,
        imagemUrl: j['imagemurl'],
        unidadeSigla: j['unid_sigla'] ?? '',
        subunidade: j['subu_descricao'],
        municipio: j['muni_nome'],
        bairro: j['bair_nome'],
        rua: j['concat'],
        numero: j['numero'],
        cep: j['cep'].toString(),
      );
}
