import 'package:intl/intl.dart';

class TipoProvento {
  String tipoRubrica;
  String descricaoRubrica;
  String provento;
  String parcelas;
  String desconto;

  TipoProvento({
    required this.tipoRubrica,
    required this.descricaoRubrica,
    required this.provento,
    required this.parcelas,
    required this.desconto,
  });
}

class ContrachequeModel {
  String matricula;
  String matriculaLegado;
  String mesExtenso;
  String UnidadeOrganizacional;
  String Folha;
  late List<TipoProvento> proventos;

  ContrachequeModel({
    this.matricula = '',
    this.matriculaLegado = '',
    this.mesExtenso = '',
    this.UnidadeOrganizacional = '',
    this.Folha = '',
    List<TipoProvento>? proventos,
  }) {
    this.proventos = proventos ?? [];
  }
}
