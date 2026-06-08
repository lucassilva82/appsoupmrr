import 'package:intl/intl.dart';

class MapBuscaDetalhesModel {
  String idSituacao;
  String descricao;
  List<String> postoGraduacao;
  String quantidade;

  MapBuscaDetalhesModel(
      {required this.idSituacao,
      required this.descricao,
      required this.postoGraduacao,
      required this.quantidade});
}
