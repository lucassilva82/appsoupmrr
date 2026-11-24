import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/data/store.dart';
import 'package:projetonovo/services/certidao_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O índice das certidões era regravado em quatro lugares a partir da lista
/// lida, e o `Store.getMap` devolvia `{}` tanto para "não existe" como para
/// "não consegui ler". Com o índice ilegível, tirar **uma** certidão gravava
/// `{itens: []}` e o militar perdia o registro de **todas** — é o sintoma do
/// APRENDIZADOS §26, pela porta de trás.
///
/// Estes testes cobrem só o caminho do índice ilegível, que é o perigoso: ele
/// devolve antes de tocar o disco, então roda sem simular o sistema de
/// arquivos.
void main() {
  const matricula = '1234567';
  const chave = 'certidoes_$matricula';
  const corrompido = '{"itens":[{"codigo":"CT-2026-0001"';  // JSON truncado

  test('guardadas diz que não leu, em vez de dizer que não tem nenhuma',
      () async {
    SharedPreferences.setMockInitialValues({chave: corrompido});

    final r = await CertidaoService.guardadas(matricula);

    expect(r.indiceLido, isFalse, reason: 'a tela precisa saber a diferença');
    expect(r.lista, isEmpty);
  });

  test('índice ilegível: remover não grava {itens: []} por cima', () async {
    SharedPreferences.setMockInitialValues({chave: corrompido});

    final r = await CertidaoService.remover(matricula, 'CT-2026-0001');

    expect(r.indiceLido, isFalse);
    // O que importa: o índice continua exatamente como estava. Antes, o
    // `_salvarIndice(resto)` com `resto` vazio apagava o registro de todas.
    expect(await Store.getString(chave), corrompido,
        reason: 'nada foi regravado por cima do que não se leu');
  });
}

// O caminho do índice **legível** não está coberto aqui, e não é esquecimento:
// ele chega ao `_pasta()`, que usa `getApplicationSupportDirectory` — canal de
// plataforma, que não existe no `flutter test`. Cobri-lo pede injetar a pasta
// no `CertidaoService`, como o `DocumentosLocais(raiz: ...)` já faz
// (`documentos_test.dart`), e isso é um refactor da classe estática, não parte
// desta correção. O que estes dois testes guardam é o caminho perigoso: o que
// destruía dado.
