import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/contracheque/o_que_mudou.dart';
import 'package:projetonovo/models/contracheque_model.dart';
import 'package:projetonovo/models/meses_contracheque_model.dart';

TipoProvento _p(String d, String v) => TipoProvento(tipoRubrica: 'P', descricaoRubrica: d, provento: v, parcelas: '', desconto: '0');
TipoProvento _d(String d, String v) => TipoProvento(tipoRubrica: 'D', descricaoRubrica: d, provento: '0', parcelas: '', desconto: v);
MesesContracheque _m(String ano, String mes, {String folha = 'NORMAL'}) => MesesContracheque(
    tipo: 'B', codProvento: '0', mes: mes, folha: folha, mesExtenso: 'X', relacaoTrabalho: 'ATIVO', cpf: '1', ano: ano, matricula: '1');

void main() {
  test('lê valores da API e já formatados', () {
    expect(valorRubrica('1234.56'), 1234.56);
    expect(valorRubrica('1.234,56'), 1234.56);
    expect(valorRubrica(''), 0);
  });

  test('acha o que entrou, saiu e mudou, maior diferença primeiro', () {
    final r = compararRubricas(
      [_p('SOLDO', '5.000,00'), _p('GRATIFICAÇÃO', '300.00'), _d('PENSÃO', '100.00')],
      [_p('SOLDO', '4500.00'), _d('PENSÃO', '100.00'), _d('EMPRÉSTIMO', '250.00')],
    );
    expect(r.map((m) => (m.descricao, m.tipo)).toList(), [
      ('SOLDO', TipoMudanca.mudou),
      ('GRATIFICAÇÃO', TipoMudanca.entrou),
      ('EMPRÉSTIMO', TipoMudanca.saiu),
    ]);
    expect(r.first.diferenca, closeTo(500, 0.001));
  });

  test('mês anterior é da mesma folha e mais recente', () {
    final lista = [_m('2026', '8'), _m('2026', '9', folha: '13º'), _m('2026', '7'), _m('2026', '10')];
    expect(mesAnteriorNaLista(_m('2026', '10'), lista)?.mes, '8');
    expect(mesAnteriorNaLista(_m('2026', '7'), lista), isNull);
  });
}
