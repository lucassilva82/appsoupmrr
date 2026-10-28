import '../../core/erros/falha_app.dart';

/// Lê o valor de uma rubrica do contracheque. Devolve nulo quando o texto não
/// é um número — **nunca zero**, porque quem chama precisa saber a diferença
/// (APRENDIZADOS §37: "zero" e "não sei" são coisas diferentes para quem lê).
///
/// As duas APIs mandam formatos diferentes: a nova (folhas de 2024 em diante)
/// manda `"1234.56"` e a antiga manda `"1.234,56"`. **A vírgula é o que
/// distingue as duas** — sem ela o ponto já é o separador decimal, e limpar os
/// pontos transformaria `1234.56` em `123456`.
double? valorRubrica(String v) {
  final t = v.trim();
  if (t.isEmpty) return 0;
  final normal =
      t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(normal);
}

/// O mesmo leitor, para quem **não pode** seguir com um valor ilegível: a soma
/// do contracheque. Um total errado é pior que um erro, porque o militar
/// confere o líquido com o que caiu na conta e não teria como saber que faltou
/// uma rubrica.
double valorRubricaOuFalha(String bruto, String rubrica) {
  final valor = valorRubrica(bruto);
  if (valor == null) {
    throw FalhaApp(
      codigo: 'CC-VALOR',
      origem: OrigemFalha.dado,
      titulo: 'Um valor do contracheque não pôde ser lido',
      texto: 'O servidor mandou um valor fora do formato esperado, então o '
          'total deste mês não pode ser calculado. Abra um chamado para o '
          'DTI conferir a folha.',
      acao: AcaoFalha.abrirChamado,
      detalhe: 'rubrica "$rubrica" com valor "$bruto"',
    );
  }
  return valor;
}
