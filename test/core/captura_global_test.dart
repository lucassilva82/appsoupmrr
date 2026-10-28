import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/erros/captura_global.dart';
import 'package:projetonovo/core/log/registro_log.dart';

class _Armazem implements ArmazemLog {
  List<Map<String, Object?>> fila = [];
  @override
  Future<List<Map<String, Object?>>> ler() async => List.of(fila);
  @override
  Future<void> gravar(List<Map<String, Object?>> itens) async =>
      fila = List.of(itens);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('erro que escapou vira AP-FATAL-<tipo> no log, com a pilha', () async {
    final armazem = _Armazem();
    RegistroLog.atual = RegistroLog(
        armazem: armazem, enviar: (_) async {}, matricula: () => null);
    final antes = FlutterError.onError;
    instalarCapturaGlobal();

    FlutterError.onError!(FlutterErrorDetails(
      exception: RangeError('índice 3'),
      stack: StackTrace.current,
      library: 'teste',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    FlutterError.onError = antes;

    final item = armazem.fila.single;
    expect(item['tipo'], 'erro');
    expect(item['codigo'], 'AP-FATAL-RangeError');
    expect(item['mostrado'], false);
    expect(item['pilha'], isNotNull);
  });
}
