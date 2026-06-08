// lib/models/militar_detalhe_model.dart
class MilitarDetalheModel {
  final String matricula;
  final String postoGraduacao;
  final String nome;
  final String comando;
  final String unidade;
  final String subunidade;
  final String? imagemUrl;

  MilitarDetalheModel({
    required this.matricula,
    required this.postoGraduacao,
    required this.nome,
    required this.comando,
    required this.unidade,
    required this.subunidade,
    this.imagemUrl,
  });

  factory MilitarDetalheModel.fromJson(Map<String, dynamic> j) =>
      MilitarDetalheModel(
        matricula: j['matricula'].toString(),
        postoGraduacao: j['posto_graduacao'] ?? '',
        nome: j['nome'] ?? '',
        comando: j['comando'] ?? '',
        unidade: j['unidade'] ?? '',
        subunidade: j['subunidade'] ?? '',
        imagemUrl: j['imagemurl'],
      );
}
