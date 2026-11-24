import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/erros/falha_app.dart';
import '../core/log/registro_log.dart';

class Store {
  static Future<bool> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(key, value);
  }

  static Future<bool> saveMap(String key, Map<String, dynamic> value) async {
    return saveString(key, jsonEncode(value));
  }

  static Future<String> getString(String key,
      [String defaultValue = '']) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  /// Lê um mapa guardado, distinguindo os dois casos que o [getMap] junta:
  /// devolve `{}` quando a chave **não existe** e **`null`** quando ela
  /// existe e **não pôde ser lida** (JSON corrompido, ou um valor que não é
  /// objeto).
  ///
  /// Quem vai **regravar** por cima do que leu tem de usar este, não o
  /// [getMap]: com `{}` nos dois casos, uma leitura que falhou é gravada de
  /// volta como "estava vazio" e apaga o que havia. Foi assim que as
  /// certidões sumiram do aparelho (APRENDIZADOS §26), e é o §27, o §37 e o
  /// §52 na mesma linha — "não consegui ler" não é "não existe".
  ///
  /// A falha vai para o log com o código `ST-LEITURA`, sem o valor: o que
  /// está guardado aqui é a sessão e os índices, e valor em log foi o motivo
  /// de o `utils/store.dart` ter sido apagado (23/11/2026).
  static Future<Map<String, dynamic>?> lerMapa(String key) async {
    String? bruto;
    try {
      bruto = await getString(key);
      if (bruto.isEmpty) return <String, dynamic>{};
      final lido = jsonDecode(bruto);
      if (lido is Map) return lido.cast<String, dynamic>();
    } catch (_) {
      // Cai no registro abaixo. O `getString` fica **dentro** do try de
      // propósito: se o SharedPreferences falhar (canal da plataforma,
      // disco), isto é "não consegui ler", não um estouro para os 11
      // chamadores — era o que o `catch` antigo já fazia, de graça.
    }
    await RegistroLog.atual?.erro(
      FalhaApp(
        codigo: 'ST-LEITURA',
        origem: OrigemFalha.aparelho,
        titulo: 'Não foi possível ler um dado guardado',
        texto: 'O app não conseguiu ler uma informação guardada neste '
            'aparelho. Nada foi perdido: tente de novo.',
        acao: AcaoFalha.tentarDeNovo,
        detalhe: 'chave=$key bytes=${bruto?.length ?? -1}',
      ),
      mostrado: false,
    );
    return null;
  }

  /// Mantém o comportamento tolerante de sempre: `{}` para a chave ausente
  /// **e** para a ilegível. Serve a quem só lê; quem regrava usa o
  /// [lerMapa], que diz qual dos dois casos aconteceu.
  static Future<Map<String, dynamic>> getMap(String key) async =>
      await lerMapa(key) ?? <String, dynamic>{};

  static Future<bool> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(key);
  }
}
