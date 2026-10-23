import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/erros/falha_de.dart';

void main() {
  test('cada exceção vira um código que diz de quem é o problema', () {
    expect(falhaDe('DC', const SocketException('x')).codigo, 'DC-REDE');
    expect(falhaDe('DC', TimeoutException('x')).codigo, 'DC-LENTO');
    expect(falhaDe('DC', const FormatException('x')).codigo, 'DC-RESP');
    expect(falhaDe('DC', StateError('x')).codigo, 'DC-X-StateError');
    expect(textoFalha('MF', const SocketException('x')), allOf(contains('Código MF-REDE.'), isNot(contains('SocketException'))));
  });
}
