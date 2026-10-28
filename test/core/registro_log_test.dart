import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/log/registro_log.dart';

class _ArmazemMemoria implements ArmazemLog {
  List<Map<String, Object?>> fila = [];
  @override
  Future<List<Map<String, Object?>>> ler() async => List.of(fila);
  @override
  Future<void> gravar(List<Map<String, Object?>> itens) async =>
      fila = List.of(itens);
}

void main() {
  late _ArmazemMemoria armazem;
  late List<List<Map<String, Object?>>> enviados;
  var falharEnvio = false;

  RegistroLog novo({int limite = 500, int lote = 50}) => RegistroLog(
        armazem: armazem,
        enviar: (itens) async {
          if (falharEnvio) {
            throw const FalhaApp(
                codigo: 'LOG-REDE',
                origem: OrigemFalha.rede,
                titulo: 't',
                texto: 't');
          }
          enviados.add(itens);
        },
        matricula: () => '1234567',
        limite: limite,
        lote: lote,
      );

  setUp(() {
    armazem = _ArmazemMemoria();
    enviados = [];
    falharEnvio = false;
  });

  test('evento entra na fila com o nome, a chave, o resultado e quem fez',
      () async {
    final log = novo();
    await log.evento('tela.abrir', chave: 'rh.contracheques');
    final item = armazem.fila.single;
    expect(item['tipo'], 'evento');
    expect(item['evento'], 'tela.abrir');
    expect(item['chave'], 'rh.contracheques');
    expect(item['resultado'], 'ok');
    expect(item['matricula'], '1234567');
    expect(item['aparelho_id'], isNotNull);
    expect(item['sessao_id'], isNotNull);
    expect(item['ocorrido_em'], isNotNull);
  });

  test('erro guarda o código e o detalhe técnico', () async {
    final log = novo();
    await log.erro(FalhaApp.lento('CC', detalhe: 'timeout 15s'),
        tela: 'rh.contracheques');
    final item = armazem.fila.single;
    expect(item['tipo'], 'erro');
    expect(item['codigo'], 'CC-LENTO');
    expect(item['modulo'], 'CC');
    expect(item['tela'], 'rh.contracheques');
    expect(item['mensagem'], 'timeout 15s');
  });

  test('nunca guarda dado sensível nos dados extras', () async {
    final log = novo();
    await log.evento('conta.senha_alterar', dados: {
      'senha': 'x',
      'senha_md5': 'y',
      'cpf': '123',
      'token': 'z',
      'valor_liquido': '4812.37',
      'mes': '09',
    });
    expect(armazem.fila.single['dados'], {'mes': '09'});
  });

  test('a fila guarda no máximo o limite, saindo os mais antigos', () async {
    final log = novo(limite: 3);
    for (var i = 1; i <= 5; i++) {
      await log.evento('teste.n', dados: {'n': '$i'});
    }
    expect(armazem.fila.map((e) => (e['dados'] as Map)['n']), ['3', '4', '5']);
  });

  test('enviar manda um lote e tira da fila só o que foi aceito', () async {
    final log = novo(lote: 2);
    for (var i = 1; i <= 3; i++) {
      await log.evento('teste.n', dados: {'n': '$i'});
    }
    await log.enviar();
    expect(enviados.single.length, 2);
    expect(armazem.fila.length, 1);
  });

  test('sem rede, nada se perde e o erro do envio não vira log', () async {
    final log = novo();
    await log.evento('app.abrir');
    falharEnvio = true;
    await log.enviar();
    expect(armazem.fila.length, 1);
    expect(armazem.fila.single['evento'], 'app.abrir');
  });

  test('ir para o fundo e sair da tela não viram linha, só passos', () async {
    final log = novo();
    await log.evento('app.fundo');
    await log.evento('tela.sair', chave: 'rh.contracheques');
    expect(armazem.fila, isEmpty);
    expect(log.passos.map((p) => p['evento']), ['app.fundo', 'tela.sair']);
  });

  test('o erro leva os últimos 20 passos, sem os dados extras', () async {
    final log = novo();
    for (var i = 1; i <= 25; i++) {
      await log.evento('tela.abrir', chave: 'rh.n$i', dados: {'mes': '09'});
    }
    await log.erro(FalhaApp.lento('CC', detalhe: 'timeout 15s'));
    final passos = armazem.fila.last['passos'] as List;
    expect(passos.length, RegistroLog.maxPassos);
    expect((passos.first as Map)['chave'], 'rh.n6');
    expect((passos.last as Map)['chave'], 'rh.n25');
    expect((passos.last as Map).containsKey('dados'), isFalse);
  });
}
