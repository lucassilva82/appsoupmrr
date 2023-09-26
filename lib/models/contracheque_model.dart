class TipoProvento {
  String dp;
  String descricao;
  String valor;

  TipoProvento({
    required this.dp,
    required this.descricao,
    required this.valor,
  });
}

class ContrachequeModel {
  late List<TipoProvento> proventos;
}
