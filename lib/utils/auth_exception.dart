import 'package:flutter/material.dart';

/// O que o botão principal do cartão de erro faz.
enum AcaoErroLogin { tentarDeNovo, recuperarSenha, primeiroAcesso, fechar }

/// Gravidade, para a cor do cartão (mesmas cores dos avisos, DESIGN §10).
enum GravidadeErroLogin { erro, atencao }

/// Falha de login, com tudo que a tela precisa para explicar o que houve.
///
/// [key] é a causa (SENHA_INVALIDA, SEM_INTERNET...). [codigo] é a versão
/// curta mostrada ao militar e gravada no log, para o DTI conferir a causa
/// quando alguém ligar. [detalhe] é o erro técnico: vai para o debugPrint,
/// nunca para a tela.
class AuthException implements Exception {
  final String key;

  /// Texto vindo do servidor (sigrh/login.php). Vai para o log; a tela usa
  /// os textos daqui, para todas as mensagens terem o mesmo formato.
  final String? mensagemServidor;

  /// Erro técnico de origem (exceção, status HTTP...).
  final String? detalhe;

  /// Em quantos segundos o bloqueio por tentativas libera.
  final int? liberaEmSeg;

  /// Matrícula digitada, para a mensagem de "não encontrada".
  final String? matricula;

  AuthException(
    String key, [
    this.mensagemServidor,
  ])  : key = key.toUpperCase(),
        detalhe = null,
        liberaEmSeg = null,
        matricula = null;

  AuthException.completa(
    String key, {
    this.mensagemServidor,
    this.detalhe,
    this.liberaEmSeg,
    this.matricula,
  }) : key = key.toUpperCase();

  // Cada causa: código curto, título, explicação, o que fazer, ação, ícone.
  static const Map<String, _Causa> _causas = {
    'SEM_INTERNET': _Causa(
      'LG-REDE',
      'Sem conexão com a internet',
      'O aparelho não está conectado à internet, então o app não conseguiu '
          'falar com o SIGRH\u2011PMRR. Sua matrícula e sua senha não foram '
          'conferidas.',
      'Ligue o Wi-Fi ou os dados móveis e toque em "Tentar de novo".',
      AcaoErroLogin.tentarDeNovo,
      Icons.wifi_off_rounded,
      GravidadeErroLogin.atencao,
    ),
    'SERVIDOR_INACESSIVEL': _Causa(
      'LG-FORA',
      'Servidor do SIGRH\u2011PMRR indisponível',
      'Seu aparelho tem internet, mas o servidor do SIGRH\u2011PMRR não atendeu. '
          'Pode ser manutenção ou instabilidade passageira. Não é problema '
          'com sua matrícula nem com sua senha.',
      'Aguarde alguns minutos e tente de novo. Se continuar, avise o '
          'DTI/PMRR informando o código abaixo.',
      AcaoErroLogin.tentarDeNovo,
      Icons.cloud_off_rounded,
      GravidadeErroLogin.erro,
    ),
    'SERVIDOR_LENTO': _Causa(
      'LG-LENTO',
      'O servidor demorou para responder',
      'Esperamos 20 segundos e o SIGRH\u2011PMRR não respondeu. Costuma ser sinal '
          'fraco de internet ou o servidor sobrecarregado.',
      'Confira o sinal (ou troque entre Wi-Fi e dados móveis) e tente de '
          'novo em instantes.',
      AcaoErroLogin.tentarDeNovo,
      Icons.hourglass_empty_rounded,
      GravidadeErroLogin.atencao,
    ),
    'CONEXAO_SEGURA': _Causa(
      'LG-SSL',
      'Conexão segura não foi aberta',
      'O aparelho recusou a conexão com o servidor por segurança. Isso '
          'acontece quando a data e a hora do aparelho estão erradas ou em '
          'redes Wi-Fi que pedem cadastro (hotel, aeroporto, shopping).',
      'Ative data e hora automáticas nos ajustes do aparelho, ou troque '
          'para os dados móveis, e tente de novo.',
      AcaoErroLogin.tentarDeNovo,
      Icons.lock_outline_rounded,
      GravidadeErroLogin.atencao,
    ),
    'ERRO_SERVIDOR': _Causa(
      'LG-SRV',
      'Erro no servidor do SIGRH\u2011PMRR',
      'O servidor recebeu seu pedido, mas falhou ao processá-lo. Não é '
          'problema com sua matrícula nem com sua senha.',
      'Tente de novo em alguns minutos. Se continuar, avise o DTI/PMRR '
          'informando o código abaixo.',
      AcaoErroLogin.tentarDeNovo,
      Icons.dns_rounded,
      GravidadeErroLogin.erro,
    ),
    'RESPOSTA_INVALIDA': _Causa(
      'LG-RESP',
      'Resposta inesperada do servidor',
      'O servidor respondeu, mas num formato que o app não entendeu. '
          'Costuma ser uma rede que intercepta a conexão (Wi-Fi com página '
          'de cadastro) ou uma falha passageira do servidor.',
      'Troque de rede ou tente de novo em alguns minutos. Se continuar, '
          'avise o DTI/PMRR informando o código abaixo.',
      AcaoErroLogin.tentarDeNovo,
      Icons.report_gmailerrorred_rounded,
      GravidadeErroLogin.erro,
    ),
    'SENHA_INVALIDA': _Causa(
      'LG-SENHA',
      'Senha incorreta',
      'A matrícula está cadastrada, mas a senha não confere. É a mesma '
          'senha do SIGRH\u2011PMRR.',
      'Confira letras maiúsculas e minúsculas. Se não lembrar, toque em '
          '"Recuperar senha" para receber um código no seu e-mail.',
      AcaoErroLogin.recuperarSenha,
      Icons.password_rounded,
      GravidadeErroLogin.atencao,
    ),
    'MATRICULA_NAO_ENCONTRADA': _Causa(
      'LG-MATR',
      'Matrícula não encontrada',
      'Não há acesso ao SouPMRR cadastrado para esta matrícula.',
      'Confira os números digitados. Se é sua primeira vez no app, toque em '
          '"Primeiro acesso" para criar sua senha.',
      AcaoErroLogin.primeiroAcesso,
      Icons.person_search_rounded,
      GravidadeErroLogin.atencao,
    ),
    'MUITAS_TENTATIVAS': _Causa(
      'LG-BLOQ',
      'Acesso pausado por segurança',
      'Houve várias tentativas com senha errada nesta matrícula, então o '
          'acesso foi pausado por alguns minutos para proteger sua conta.',
      'Aguarde e tente de novo. Se esqueceu a senha, toque em '
          '"Recuperar senha".',
      AcaoErroLogin.recuperarSenha,
      Icons.timer_outlined,
      GravidadeErroLogin.atencao,
    ),
    'CONTA_INATIVA': _Causa(
      'LG-INAT',
      'Conta desativada',
      'Sua senha está certa, mas sua conta está desativada no SIGRH\u2011PMRR.',
      'Procure a Diretoria de Recursos Humanos\u00A0-\u00A0PMRR para reativar o '
          'acesso.',
      AcaoErroLogin.fechar,
      Icons.person_off_rounded,
      GravidadeErroLogin.erro,
    ),
    'SQL': _Causa(
      'LG-FUNC',
      'Não conseguimos carregar seus dados',
      'Sua senha está certa, mas o SIGRH\u2011PMRR não devolveu sua ficha '
          'funcional (nome, posto e lotação), e sem ela o app não abre.',
      'Tente de novo em alguns minutos. Se continuar, procure a Diretoria '
          'de Recursos Humanos\u00A0-\u00A0PMRR informando o código abaixo.',
      AcaoErroLogin.tentarDeNovo,
      Icons.badge_outlined,
      GravidadeErroLogin.erro,
    ),
    'DADOS_INVALIDOS': _Causa(
      'LG-DADOS',
      'Matrícula inválida',
      'A matrícula digitada tem caracteres que não são aceitos.',
      'Digite apenas os números da sua matrícula, sem pontos ou traços.',
      AcaoErroLogin.fechar,
      Icons.pin_outlined,
      GravidadeErroLogin.atencao,
    ),
  };

  static const _Causa _desconhecida = _Causa(
    'LG-X',
    'Não foi possível entrar',
    'Aconteceu um erro que o app não esperava. Sua senha não chegou a ser '
        'recusada.',
    'Tente de novo. Se continuar, avise o DTI/PMRR informando o código '
        'abaixo.',
    AcaoErroLogin.tentarDeNovo,
    Icons.error_outline_rounded,
    GravidadeErroLogin.erro,
  );

  _Causa get _causa => _causas[key] ?? _desconhecida;

  /// Código curto para a tela e para o log. Causas desconhecidas levam o
  /// nome da causa junto (LG-X-HANDSHAKE...), para dar para achar no log.
  String get codigo {
    final base = _causas.containsKey(key) ? _causa.codigo : 'LG-X-$key';
    return detalheCodigo == null ? base : '$base-$detalheCodigo';
  }

  /// Complemento do código (ex.: status HTTP 503).
  String? get detalheCodigo {
    final d = detalhe;
    if (d == null) return null;
    final http = RegExp(r'^HTTP (\d{3})').firstMatch(d);
    return http?.group(1);
  }

  String get titulo => _causa.titulo;

  String get explicacao {
    if (key == 'MATRICULA_NAO_ENCONTRADA' && (matricula ?? '').isNotEmpty) {
      return 'Não há acesso ao SouPMRR cadastrado para a matrícula '
          '$matricula.';
    }
    return _causa.explicacao;
  }

  String get oQueFazer {
    final seg = liberaEmSeg;
    if (key == 'MUITAS_TENTATIVAS' && seg != null && seg > 0) {
      final hora = DateTime.now().add(Duration(seconds: seg));
      final hh = hora.hour.toString().padLeft(2, '0');
      final mm = hora.minute.toString().padLeft(2, '0');
      final min = (seg / 60).ceil();
      return 'O acesso libera às $hh:$mm (em cerca de $min min). Se esqueceu '
          'a senha, toque em "Recuperar senha".';
    }
    return _causa.oQueFazer;
  }

  AcaoErroLogin get acao => _causa.acao;
  IconData get icone => _causa.icone;
  GravidadeErroLogin get gravidade => _causa.gravidade;

  /// Texto corrido, para quem só precisa de uma string (log, telas antigas).
  @override
  String toString() => '$titulo. $explicacao $oQueFazer';
}

class _Causa {
  final String codigo;
  final String titulo;
  final String explicacao;
  final String oQueFazer;
  final AcaoErroLogin acao;
  final IconData icone;
  final GravidadeErroLogin gravidade;

  const _Causa(this.codigo, this.titulo, this.explicacao, this.oQueFazer,
      this.acao, this.icone, this.gravidade);
}
