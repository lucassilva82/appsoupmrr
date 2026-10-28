import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/documentos/validar_page.dart';

void main() {
  test('entende código de certidão, de contracheque e o link do QR', () {
    final cert = entenderCodigo('ABCD 1234 abcd 1234 ABCD 1234 abcd 1234');
    expect(cert?.tipo, 'certidao');
    expect(cert?.url.queryParameters['codigo'], 'abcd1234abcd1234abcd1234abcd1234');
    expect(entenderCodigo('0123-4567-89ab-cdef')?.tipo, 'contracheque');
    expect(entenderCodigo('https://exemplo.invalid/flutter/sigrh/doc/conferir.php?c=0123456789abcdef')?.url.path,
        endsWith('/doc/conferir.php'));
  });

  test('recusa o que não é código da PMRR', () {
    expect(entenderCodigo(''), isNull);
    expect(entenderCodigo('123'), isNull);
    expect(entenderCodigo('zzzz567890abcdef'), isNull);
    expect(entenderCodigo('https://golpe.invalid/pagina?c=0123456789abcdef'), isNull);
  });
}
