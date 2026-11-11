// A conta da folga de baixo da barra solta do iPhone.
//
// Existe porque a versao 2.3.0, que esta nas lojas, fecha com
// `Invalid argument(s): 8.0` quando a area segura de baixo fica entre 0 e 8:
// o `clamp(8.0, base)` tinha o minimo maior que o maximo. 60 ocorrencias em
// 24 h, 12 militares, medidas no soupm_erro em 11/11/2026.
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/widgets/barra_navegacao.dart';

void main() {
  group('folgaDeBaixo', () {
    test('sem area segura: o valor fixo de 16', () {
      expect(folgaDeBaixo(0), 16);
    });

    test('iPhone com indicador (34): a area segura menos 12', () {
      expect(folgaDeBaixo(34), 22);
    });

    test('area segura entre 0 e 8: era aqui que o app fechava', () {
      // com clamp(8.0, base) isto lancava Invalid argument(s): 8.0
      for (final base in <double>[0.1, 1, 4, 7.9]) {
        expect(folgaDeBaixo(base), 8, reason: 'base = $base');
      }
    });

    test('area segura entre 8 e 20: o piso de 8 vale', () {
      expect(folgaDeBaixo(12), 8);
      expect(folgaDeBaixo(19), 8);
      expect(folgaDeBaixo(21), 9);
    });

    test('nunca devolve menos que 8 quando ha area segura', () {
      for (var i = 1; i <= 60; i++) {
        expect(folgaDeBaixo(i.toDouble()) >= 8, isTrue, reason: 'base = $i');
      }
    });
  });
}
