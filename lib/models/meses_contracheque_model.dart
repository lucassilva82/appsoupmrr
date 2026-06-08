//TIPOS DE CONTRACHEQUE (Mudanca Folha de pagamento)
//A - Antes de Agosto/2025
//B - Após Agosto/2025
class MesesContracheque {
  String tipo; //A ou B
  String codProvento;
  String mes;
  String folha;
  String mesExtenso;
  String relacaoTrabalho;

  String cpf;
  String ano;
  String matricula;

  MesesContracheque(
      {required this.tipo,
      required this.codProvento,
      required this.mes,
      required this.folha,
      required this.mesExtenso,
      required this.relacaoTrabalho,
      required this.cpf,
      required this.ano,
      required this.matricula});
}
