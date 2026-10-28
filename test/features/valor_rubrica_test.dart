import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/features/contracheque/valor_rubrica.dart';

void main() {
  group('valorRubrica lê os dois formatos', () {
    test('API nova: ponto é decimal, não milhar', () {
      // O caso que o leitor da tela errava: limpar os pontos sem olhar a
      // vírgula transformava 1234.56 em 123456.
      expect(valorRubrica('1234.56'), 1234.56);
      expect(valorRubrica('8791.85'), 8791.85);
    });

    test('API antiga: ponto é milhar e vírgula é decimal', () {
      expect(valorRubrica('1.234,56'), 1234.56);
      expect(valorRubrica('8.791,85'), 8791.85);
      expect(valorRubrica('12.345.678,90'), 12345678.90);
    });

    test('vazio é zero; ilegível é nulo, nunca zero', () {
      expect(valorRubrica(''), 0);
      expect(valorRubrica('   '), 0);
      expect(valorRubrica('n/d'), isNull);
      expect(valorRubrica('R\$ 1.234,56'), isNull);
    });
  });

  group('valorRubricaOuFalha protege o total', () {
    test('valor bom passa', () {
      expect(valorRubricaOuFalha('1.234,56', 'SOLDO'), 1234.56);
    });

    test('valor ilegível vira CC-VALOR, não zero', () {
      // Zerar daria um líquido errado, e o militar confere o líquido com o
      // que caiu na conta (APRENDIZADOS §37).
      expect(
        () => valorRubricaOuFalha('n/d', 'SOLDO'),
        throwsA(isA<FalhaApp>()
            .having((f) => f.codigo, 'código', 'CC-VALOR')
            .having((f) => f.detalhe, 'detalhe', contains('SOLDO'))),
      );
    });
  });
}
