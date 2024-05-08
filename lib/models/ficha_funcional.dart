class AlteracaoFuncional {
  String tipoSituacao;
  String situacaoFuncional;
  String dataInicio;
  String dataFim;
  bool ativo;

  AlteracaoFuncional(
      {required this.tipoSituacao,
      required this.situacaoFuncional,
      required this.dataInicio,
      required this.dataFim,
      required this.ativo});
}

class FichaFuncional {
  List<AlteracaoFuncional> alteracoesFuncional = [];
}
