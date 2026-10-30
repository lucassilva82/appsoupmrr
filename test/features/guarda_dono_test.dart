import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/operacoes/guarda_dono.dart';

/// A guarda de dono é JavaScript: ela roda dentro da WebView, antes do
/// `app.js` do Operar. Então o teste roda o script de verdade, no node, com um
/// `localStorage` de mentira — conferir a string gerada não diria nada sobre o
/// que ela faz, e é o que ela faz que impede um militar de entrar como outro.
///
/// Sem node, o grupo é pulado em vez de falhar: a máquina de quem roda o teste
/// não é a WebView, e o módulo não depende de node para funcionar.
const _harness = r'''
var dados = DADOS;
function chaves() { return Object.keys(dados); }
var window = { localStorage: {
  getItem: function (k) {
    return Object.prototype.hasOwnProperty.call(dados, k) ? dados[k] : null;
  },
  setItem: function (k, v) { dados[k] = String(v); },
  removeItem: function (k) { delete dados[k]; },
  key: function (i) { var c = chaves()[i]; return c === undefined ? null : c; },
  get length() { return chaves().length; }
}};
GUARDA
console.log(JSON.stringify(dados));
''';

String? _node() {
  for (final c in ['/opt/homebrew/bin/node', '/usr/local/bin/node', '/usr/bin/node']) {
    if (File(c).existsSync()) return c;
  }
  final r = Process.runSync('which', ['node']);
  final s = '${r.stdout}'.trim();
  return s.isEmpty ? null : s;
}

/// O que sobra no `localStorage` depois de a guarda rodar.
Map<String, String> _depois(
  String node,
  Map<String, String> antes, {
  String? matricula,
  String? token,
  bool forcar = false,
}) {
  final js = _harness
      .replaceFirst('DADOS', jsonEncode(antes))
      .replaceFirst('GUARDA',
          guardaDeDonoJs(matricula: matricula, token: token, forcar: forcar));
  final f = File('${Directory.systemTemp.path}/guarda_${antes.hashCode}_$forcar.js')
    ..writeAsStringSync(js);
  try {
    final r = Process.runSync(node, [f.path]);
    expect(r.exitCode, 0, reason: 'node falhou: ${r.stderr}');
    return Map<String, String>.from(jsonDecode('${r.stdout}'.trim()) as Map);
  } finally {
    f.deleteSync();
  }
}

/// Como o app do Operar grava: tudo passa por `JSON.stringify`.
String _v(Object? x) => jsonEncode(x);

void main() {
  final node = _node();

  group('guarda de dono', skip: node == null ? 'node não encontrado' : null, () {
    // O armazém do militar que está logado agora não pode ser mexido: apagar a
    // escala dele a cada abertura tiraria o módulo do ar sem sinal, que é
    // justamente quando ele serve.
    test('mesmo dono: nada é apagado', () {
      final antes = {
        'e26.soupm_dono': _v('452955'),
        'e26.token': _v('tok-A'),
        'e26.servico': _v({'posto': 'Portão 2'}),
        'e26.pin': _v({'s': 'sal', 'h': 'hash'}),
      };
      expect(_depois(node!, antes, matricula: '452955', token: 'tok-A'), antes);
    });

    // O furo que a guarda fecha: o A sai, o B entra, o token do B não vem
    // (rede, senha trocada) e a página subiria com a sessão do A.
    test('outro dono: token, PIN e escala somem', () {
      final r = _depois(
        node!,
        {
          'e26.soupm_dono': _v('452955'),
          'e26.token': _v('tok-A'),
          'e26.matricula': _v('452955'),
          'e26.servico': _v({'posto': 'Portão 2'}),
          'e26.pin': _v({'s': 'sal', 'h': 'hash'}),
        },
        matricula: '410969',
      );
      expect(r.containsKey('e26.token'), isFalse);
      expect(r.containsKey('e26.pin'), isFalse);
      expect(r.containsKey('e26.servico'), isFalse);
      expect(r['e26.soupm_dono'], _v('410969'));
    });

    // Registros feitos no campo e ainda não enviados são fato, não cache.
    // Ficam em nome de quem os fez, na chave e no formato do `entrar()` do
    // Operar, para subirem quando aquele militar entrar de novo.
    test('a fila do dono anterior é guardada em nome dele, não apagada', () {
      final r = _depois(
        node!,
        {
          'e26.soupm_dono': _v('452955'),
          'e26.matricula': _v('452955'),
          'e26.fila': _v([
            {'o': 'CHEGUEI'},
            {'o': 'FIM'}
          ]),
        },
        matricula: '410969',
      );
      expect(r.containsKey('e26.fila'), isFalse);
      final orfas = jsonDecode(r['e26.filaOrfa']!) as Map;
      expect((orfas['452955'] as List).length, 2);
    });

    test('fila órfã de terceiros sobrevive a mais uma troca de dono', () {
      final r = _depois(
        node!,
        {
          'e26.soupm_dono': _v('452955'),
          'e26.filaOrfa': _v({
            '111111': [{'o': 'CHEGUEI'}]
          }),
        },
        matricula: '410969',
      );
      final orfas = jsonDecode(r['e26.filaOrfa']!) as Map;
      expect((orfas['111111'] as List).length, 1);
    });

    // Quem já usava o módulo antes desta versão não tem etiqueta. Apagar
    // nesse caso pediria `/acesso` novo e derrubaria o aparelho dele no
    // navegador — a regra mais cara do módulo.
    test('armazém sem etiqueta, com o nosso token: mantém e etiqueta', () {
      final r = _depois(
        node!,
        {'e26.token': _v('tok-A'), 'e26.servico': _v({'posto': 'Portão 2'})},
        matricula: '452955',
        token: 'tok-A',
      );
      expect(r['e26.servico'], isNotNull);
      expect(r['e26.soupm_dono'], _v('452955'));
    });

    test('armazém sem etiqueta, com token de outro: esvazia', () {
      final r = _depois(
        node!,
        {'e26.token': _v('tok-OUTRO'), 'e26.servico': _v({'posto': 'Portão 2'})},
        matricula: '452955',
        token: 'tok-A',
      );
      expect(r.containsKey('e26.token'), isFalse);
      expect(r.containsKey('e26.servico'), isFalse);
      expect(r['e26.soupm_dono'], _v('452955'));
    });

    test('armazém vazio: só ganha a etiqueta', () {
      final r = _depois(node!, {}, matricula: '452955', token: 'tok-A');
      expect(r, {'e26.soupm_dono': _v('452955')});
    });

    // Sair do Sou PM é sair do Operar: não há "sair" dentro do módulo.
    test('marca do logout esvazia mesmo sendo o mesmo militar', () {
      final r = _depois(
        node!,
        {'e26.soupm_dono': _v('452955'), 'e26.token': _v('tok-A')},
        matricula: '452955',
        token: 'tok-A',
        forcar: true,
      );
      expect(r.containsKey('e26.token'), isFalse);
      expect(r['e26.soupm_dono'], _v('452955'));
    });

    test('sem matrícula no Sou PM: esvazia e não etiqueta ninguém', () {
      final r = _depois(node!, {'e26.token': _v('tok-A')});
      expect(r, isEmpty);
    });

    // A guarda é do Operar; o resto da WebView não é da conta dela.
    test('chave de fora do prefixo e26 não é tocada', () {
      final r = _depois(
        node!,
        {'e26.token': _v('tok-A'), 'outra.coisa': 'fica'},
        matricula: '452955',
      );
      expect(r['outra.coisa'], 'fica');
    });

    // A matrícula vai para dentro de uma string de JavaScript. Se escapasse,
    // qualquer coisa que a nossa API devolvesse viraria código aqui dentro.
    test('matrícula com aspas e barra não escapa da string', () {
      final r = _depois(
        node!,
        {'e26.token': _v('tok-A')},
        matricula: r'''45"29\55''',
        token: 'tok-A',
      );
      expect(r['e26.soupm_dono'], _v(r'''45"29\55'''));
    });
  });
}
