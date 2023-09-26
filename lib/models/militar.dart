import 'package:projetonovo/models/telefone.dart';

import 'endereco.dart';

class Militar {
  final String matricula;
  final String postoGraduacao;
  final String qra;
  final String cpf;
  final String nomeCompleto;
  //1 = telefone comum; 2 = whatsapp;
  List<Telefone> telefones = [];
  final String imageUrl;
  final String subUnidade;
  Endereco endereco;
  final String dataIncorporacao;
  final String quadro;
  bool alterouDados = false;

  Militar({
    required this.matricula,
    required this.postoGraduacao,
    required this.qra,
    required this.cpf,
    required this.nomeCompleto,
    required this.imageUrl,
    required this.subUnidade,
    required this.endereco,
    required this.dataIncorporacao,
    required this.quadro,
  });
}
