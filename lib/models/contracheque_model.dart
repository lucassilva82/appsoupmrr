import 'package:intl/intl.dart';

class TipoProvento {
  String dp;
  String descricao;
  String valor;
  String parcela;

  TipoProvento({
    required this.dp,
    required this.descricao,
    required this.valor,
    required this.parcela,
  });
}

class ContrachequeModel {
  late List<TipoProvento> proventos;
}
