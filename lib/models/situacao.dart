class Situacao {
  final int id;
  final String descricao;
  final int quantidade;
  Situacao(
      {required this.id, required this.descricao, required this.quantidade});
  factory Situacao.fromJson(Map<String, dynamic> j) => Situacao(
        id: j['id_situacao'] as int,
        descricao: j['descricao_situacao'] as String,
        quantidade: j['quantidade'] as int,
      );
}
