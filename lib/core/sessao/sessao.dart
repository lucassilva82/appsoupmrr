import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../log/registro_log.dart';

/// Onde a senha fica guardada: Keychain no iPhone, Keystore no Android.
abstract class Cofre {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> apagar(String chave);
}

class CofreSeguro implements Cofre {
  const CofreSeguro();
  static const _s = FlutterSecureStorage();

  /// Se o cofre não abre (no Android, um backup restaurado traz o arquivo
  /// cifrado sem a chave do Keystore e a leitura falha), o que está lá é
  /// lixo: apaga tudo e volta nulo. O militar só entra de novo, em vez de o
  /// app falhar ao abrir.
  @override
  Future<String?> ler(String chave) async {
    try {
      return await _s.read(key: chave);
    } catch (e) {
      registrar('sessao.cofre_ilegivel', resultado: 'falhou', codigo: 'LG-COFRE');
      try {
        await _s.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> gravar(String chave, String valor) =>
      _s.write(key: chave, value: valor);
  @override
  Future<void> apagar(String chave) => _s.delete(key: chave);
}

/// Sessão do militar no aparelho (docs/SOUPM_2_2.md §6.6, fase 0).
///
/// Até a 2.1.x a senha ficava em texto puro no SharedPreferences, em dois
/// lugares: dentro de `userData` (a sessão) e na chave `password` (o
/// "Lembrar meus dados" da tela de login). Agora as duas ficam no [Cofre].
///
/// Enquanto a API exigir o MD5 da senha, ela precisa existir no aparelho;
/// na 2.3 o lugar dela passa a ser de um token da intranet, e só esta classe
/// muda.
class Sessao {
  Sessao({Cofre cofre = const CofreSeguro()}) : _cofre = cofre;

  static Sessao instancia = Sessao();

  /// Matrícula de quem está logado, para o log e para quem precisar saber
  /// sem depender do Provider. Atualizada pelo `Auth`.
  static String? matriculaAtual;

  final Cofre _cofre;

  static const _chaveSenha = 'soupm_senha';
  static const _chaveLembrada = 'soupm_senha_lembrada';

  Future<String?> senha() => _cofre.ler(_chaveSenha);

  Future<void> gravarSenha(String? senha) => senha == null || senha.isEmpty
      ? _cofre.apagar(_chaveSenha)
      : _cofre.gravar(_chaveSenha, senha);

  Future<String?> senhaLembrada() => _cofre.ler(_chaveLembrada);

  Future<void> gravarSenhaLembrada(String? senha) =>
      senha == null || senha.isEmpty
          ? _cofre.apagar(_chaveLembrada)
          : _cofre.gravar(_chaveLembrada, senha);

  Future<void> apagarTudo() async {
    await _cofre.apagar(_chaveSenha);
    await _cofre.apagar(_chaveLembrada);
  }

  /// Leva as senhas da versão antiga para o cofre, sem deslogar ninguém.
  ///
  /// Ordem segura: primeiro grava no cofre, depois apaga do armazenamento
  /// comum. Se o app fechar no meio, na próxima abertura a senha ainda está
  /// num dos dois lugares e a migração termina. Devolve se migrou algo.
  Future<bool> migrar() async {
    final prefs = await SharedPreferences.getInstance();
    var migrou = false;

    final bruto = prefs.getString('userData');
    if (bruto != null) {
      Map<String, dynamic>? dados;
      try {
        dados = jsonDecode(bruto) as Map<String, dynamic>;
      } catch (_) {}
      final antiga = dados?['password'];
      if (dados != null && dados.containsKey('password')) {
        if (antiga is String && antiga.isNotEmpty) {
          await gravarSenha(antiga);
        }
        dados.remove('password');
        await prefs.setString('userData', jsonEncode(dados));
        migrou = true;
      }
    }

    final lembrada = prefs.getString('password');
    if (lembrada != null) {
      if (lembrada.isNotEmpty) await gravarSenhaLembrada(lembrada);
      await prefs.remove('password');
      migrou = true;
    }

    if (migrou) registrar('sessao.migrar');
    return migrou;
  }
}
