import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/navegacao/abrir_funcao.dart';

void main() {
  final agora = DateTime(2026, 10, 23, 9, 41);

  test('previsão de volta fala hoje, amanhã ou a data', () {
    expect(FolhaBloqueio.previsaoTexto(DateTime(2026, 10, 23, 18), agora), 'Volta hoje às 18h');
    expect(FolhaBloqueio.previsaoTexto(DateTime(2026, 10, 24, 7, 30), agora), 'Volta amanhã às 7h30');
    expect(FolhaBloqueio.previsaoTexto(DateTime(2026, 10, 30, 18), agora), 'Volta em 30/10 às 18h');
  });
}
