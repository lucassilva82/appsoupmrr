// ─────────────────────────────────────────────────────────────────────────────
// Entrada no Operar (operar.pmrr.online), o sistema de operações do GAPE.
//
// O módulo Operações abre o app de campo do Operar e precisa abrir JÁ LOGADO:
// o militar acabou de entrar no Sou PM, não faz sentido pedir login de novo. O
// Operar autentica por "token de aparelho", e quem pode pedir esse token é a
// NOSSA API — é o nosso login que atesta quem é o militar. A senha da operação
// fica no servidor, cadastrada no painel, e nunca chega ao aparelho.
//
// REGRA QUE NÃO PODE SER QUEBRADA: o `/api/acesso` do Operar revoga todos os
// outros aparelhos daquela matrícula. Então SessaoOperar.token pede um token
// novo SÓ quando não há nenhum guardado no cofre. Se o módulo pedisse a cada
// abertura, quem usa o app do Operar pelo navegador seria derrubado toda vez —
// e o militar não entenderia por quê.
//
// Falha aqui não é fim de linha: a tela cai no login do próprio Operar
// (decisão do Lucas, 29/10/2026), que continua funcionando com matrícula, CPF
// e senha da operação.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/ambiente_app.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../core/sessao/sessao.dart' show Cofre, CofreSeguro, Sessao;

/// O que a nossa API devolve quando o Operar aceita o militar.
class TokenOperar {
  const TokenOperar({
    required this.token,
    required this.matricula,
    this.nome,
    this.posto,
    this.cpfGravado = false,
  });

  final String token;
  final String matricula;
  final String? nome;
  final String? posto;

  /// O Operar não tinha o CPF deste militar e gravou o que mandamos, marcando
  /// para a DRH conferir. Autorizado pelo Lucas em 29/10/2026: a base do
  /// Operar é cópia do mesmo SIGRH que a nossa API lê, então é preencher um
  /// campo vazio com o valor da mesma fonte. Fica no log, sem nada na tela.
  final bool cpfGravado;

  static TokenOperar? deJson(Object? j) =>
      j is Map && j['token'] is String && '${j['token']}'.isNotEmpty
          ? TokenOperar(
              token: j['token'] as String,
              matricula: '${j['matricula'] ?? ''}',
              nome: j['nome'] as String?,
              posto: j['posto'] as String?,
              cpfGravado: j['cpf_gravado'] == true,
            )
          : null;
}

/// Pede à nossa API o token de aparelho do Operar.
class OperarApi {
  OperarApi({
    required this.api,
    required this.matricula,
    required this.senhaMd5,
    Uri? url,
  }) : url = url ?? Uri.parse('$urlSigrh/operar_token.php');

  final ApiClient api;
  final String matricula;

  /// O mesmo md5 que os outros endpoints do `sigrh/` já recebem. Com este
  /// endpoint ele passa a alcançar também o Operar — dívida conhecida, dita
  /// ao Lucas por escrito e aceita por ele em 29/10/2026.
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'OP';
  static const chaveLog = 'op.operacoes';

  /// Onde o app do Operar guarda o token do aparelho, com o prefixo dele.
  /// A ponte de download lê daqui para assinar os pedidos de arquivo.
  static const chaveTokenNoOperar = 'e26.token';

  Future<TokenOperar> pedirToken() async {
    final j = await api.postJson(url, prefixo: prefixo, campos: {
      'matricula': matricula,
      'senha': senhaMd5,
      'plataforma': AmbienteApp.plataforma,
      'app_versao': AmbienteApp.versao,
    });
    if (j is! Map) {
      throw FalhaApp.respostaInvalida(prefixo,
          detalhe: 'operar_token.php não devolveu objeto');
    }
    if (j['code'] != 1) {
      final erro = '${j['erro'] ?? 'ERRO_SERVIDOR'}';
      registrar('operacoes.token', chave: chaveLog, resultado: 'falhou',
          codigo: '$prefixo-${erro.replaceAll('_', '-')}');
      throw FalhaApp.daApi(prefixo, erro, j['message'] as String?);
    }
    final t = TokenOperar.deJson(j);
    if (t == null) {
      throw FalhaApp.respostaInvalida(prefixo, detalhe: 'token ausente ou vazio');
    }
    registrar('operacoes.token', chave: chaveLog,
        dados: {'cpf_gravado': t.cpfGravado});
    return t;
  }
}

/// O token do Operar guardado no aparelho: Keychain no iPhone, Keystore no
/// Android. Vive junto da sessão do Sou PM e morre com ela.
class SessaoOperar {
  SessaoOperar({required this.api, Cofre cofre = const CofreSeguro()})
      : _cofre = cofre;

  /// Monta a sessão a partir de quem está logado no Sou PM agora. Devolve
  /// nulo quando não há login — o card da Início some em vez de pedir senha.
  static Future<SessaoOperar?> doLoginAtual({ApiClient? cliente}) async {
    final mat = Sessao.matriculaAtual;
    final senha = await Sessao.instancia.senha();
    if (mat == null || mat.isEmpty || senha == null || senha.isEmpty) return null;
    return SessaoOperar(
      api: OperarApi(
        api: cliente ?? ApiClient(),
        matricula: mat,
        senhaMd5: md5.convert(utf8.encode(senha)).toString(),
      ),
    );
  }

  final OperarApi api;
  final Cofre _cofre;

  static const _chaveToken = 'operar_token';
  static const _chaveMatricula = 'operar_matricula';

  /// O token para a WebView e para as chamadas ao Operar.
  ///
  /// Reusa o que está no cofre; só pede um novo quando não há nenhum, ou
  /// quando o guardado é de OUTRA matrícula (o aparelho trocou de dono).
  /// [renovar] força o pedido — use só depois de o Operar responder 401, que
  /// é o sinal de que o aparelho foi desligado do outro lado.
  Future<String> token({bool renovar = false}) async {
    if (!renovar) {
      final guardado = await _cofre.ler(_chaveToken);
      final dono = await _cofre.ler(_chaveMatricula);
      if (guardado != null && guardado.isNotEmpty && dono == api.matricula) {
        return guardado;
      }
    }
    final t = await api.pedirToken();
    await _cofre.gravar(_chaveToken, t.token);
    await _cofre.gravar(_chaveMatricula, t.matricula.isEmpty ? api.matricula : t.matricula);
    return t.token;
  }

  /// Apaga o token deste aparelho. Chamado ao sair do Sou PM: o token do
  /// Operar não deve sobreviver à sessão de quem o pediu.
  Future<void> limpar() => limparDoAparelho(cofre: _cofre);

  /// A mesma limpeza, sem precisar de uma sessão montada — é o que o logout
  /// do app chama, junto das certidões. Quem sai leva o acesso ao Operar
  /// embora: o próximo militar neste aparelho pede o token dele.
  static Future<void> limparDoAparelho({Cofre cofre = const CofreSeguro()}) async {
    await cofre.apagar(_chaveToken);
    await cofre.apagar(_chaveMatricula);
  }
}
