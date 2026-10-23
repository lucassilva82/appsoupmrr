// ─────────────────────────────────────────────────────────────────────────────
// FalhaApp: o tipo único de erro do SouPMRR 2.2 (docs/SOUPM_2_2.md §9.1).
//
// Toda falha diz o que aconteceu, de quem é o problema, o que fazer e um
// código curto que vai junto para o log (regra "Erro sempre explicado" do
// CLAUDE.md; rejeição 2.1(a) da Apple, APRENDIZADOS §30–31).
//
// O código é `<PREFIXO>-<SUFIXO>`: o prefixo é do módulo (CC contracheque,
// CT certidões…, tabela do §9.1) e o sufixo segue o padrão do login: REDE,
// FORA, LENTO, SSL, SRV-nnn, RESP, API, DADOS, X-<tipo>.
// ─────────────────────────────────────────────────────────────────────────────

/// De quem é o problema. Decide o texto e o botão da tela de erro.
enum OrigemFalha { aparelho, rede, servidor, conta, dado, app }

/// O que o militar pode fazer na tela de erro.
enum AcaoFalha {
  tentarDeNovo,
  abrirChamado,
  atualizarApp,
  entrarDeNovo,
  nenhuma
}

class FalhaApp implements Exception {
  const FalhaApp({
    required this.codigo,
    required this.origem,
    required this.titulo,
    required this.texto,
    this.acao = AcaoFalha.tentarDeNovo,
    this.detalhe,
  });

  /// `CC-LENTO`, `CT-SRV-503`… Mostrado na tela e gravado no log.
  final String codigo;
  final OrigemFalha origem;

  /// Curto, sem ponto final ("O servidor demorou para responder").
  final String titulo;

  /// O que aconteceu e o que fazer, em português simples.
  final String texto;
  final AcaoFalha acao;

  /// Só para o log: mensagem técnica, sem dado sensível. Nunca vai à tela.
  final String? detalhe;

  /// "Problema do aparelho", "Problema do servidor"… (linha "de quem é").
  String get deQuem => switch (origem) {
        OrigemFalha.aparelho => 'Problema do aparelho',
        OrigemFalha.rede => 'Problema do aparelho ou da rede',
        OrigemFalha.servidor => 'Problema do servidor',
        OrigemFalha.conta => 'Problema da conta',
        OrigemFalha.dado => 'Problema nos dados do sistema',
        OrigemFalha.app => 'Problema do app',
      };

  /// Os passos do "O que fazer" da tela de erro (protótipo `telaErro`), pela
  /// origem e pela ação que a falha pede.
  List<String> get oQueFazer {
    final chamado = acao == AcaoFalha.tentarDeNovo ? 'Se continuar, abra um chamado técnico' : null;
    return switch (origem) {
      OrigemFalha.rede || OrigemFalha.aparelho => [
          'Confira o Wi-Fi ou os dados móveis',
          'Desligue o modo avião',
          if (acao == AcaoFalha.tentarDeNovo) 'Toque em Tentar de novo',
        ],
      OrigemFalha.servidor => [
          'Aguarde alguns minutos',
          if (acao == AcaoFalha.tentarDeNovo) 'Toque em Tentar de novo',
          if (chamado != null) chamado,
        ],
      OrigemFalha.conta => [
          if (acao == AcaoFalha.entrarDeNovo) 'Saia e entre de novo na sua conta',
          'Se continuar, procure a seção de pessoal da sua OPM',
        ],
      OrigemFalha.dado => [
          'Os dados vêm do SIGRH: peça a correção à Diretoria de Recursos Humanos - PMRR',
          if (chamado != null) chamado,
        ],
      OrigemFalha.app => [
          if (acao == AcaoFalha.atualizarApp) 'Atualize o app na loja',
          if (acao == AcaoFalha.tentarDeNovo) 'Toque em Tentar de novo',
          'Se repetir, abra um chamado técnico: o código e o registro vão junto',
        ],
    };
  }

  // ── Fábricas das falhas comuns de rede ────────────────────────────────────

  factory FalhaApp.semInternet(String prefixo, {String? detalhe}) => FalhaApp(
        codigo: '$prefixo-REDE',
        origem: OrigemFalha.rede,
        titulo: 'Sem conexão com a internet',
        texto: 'O aparelho não conseguiu chegar à internet. Nada foi alterado '
            'na sua conta. Confira o Wi-Fi ou os dados móveis e tente de novo.',
        detalhe: detalhe,
      );

  factory FalhaApp.servidorFora(String prefixo, {String? detalhe}) => FalhaApp(
        codigo: '$prefixo-FORA',
        origem: OrigemFalha.servidor,
        titulo: 'O servidor não atendeu',
        texto: 'Sua internet está funcionando, mas o servidor da PMRR não '
            'respondeu. Tente de novo em alguns minutos. Se continuar, abra '
            'um chamado técnico.',
        detalhe: detalhe,
      );

  factory FalhaApp.lento(String prefixo, {String? detalhe}) => FalhaApp(
        codigo: '$prefixo-LENTO',
        origem: OrigemFalha.servidor,
        titulo: 'O servidor demorou para responder',
        texto: 'Esperamos e o servidor não respondeu a tempo. Pode ser um pico '
            'de acessos. Aguarde alguns minutos e tente de novo.',
        detalhe: detalhe,
      );

  factory FalhaApp.conexaoSegura(String prefixo, {String? detalhe}) => FalhaApp(
        codigo: '$prefixo-SSL',
        origem: OrigemFalha.aparelho,
        titulo: 'A conexão segura foi recusada',
        texto: 'Confira se a data e a hora do aparelho estão certas. Em Wi-Fi '
            'com página de cadastro (hotel, aeroporto), entre nela primeiro ou '
            'use os dados móveis.',
        detalhe: detalhe,
      );

  factory FalhaApp.httpStatus(String prefixo, int status, {String? detalhe}) =>
      FalhaApp(
        codigo: '$prefixo-SRV-$status',
        origem: OrigemFalha.servidor,
        titulo: 'O servidor recusou o pedido',
        texto: 'O servidor da PMRR respondeu com erro. O problema é do '
            'servidor, não do seu aparelho. Tente de novo mais tarde.',
        acao: status >= 500 ? AcaoFalha.tentarDeNovo : AcaoFalha.abrirChamado,
        detalhe: detalhe,
      );

  factory FalhaApp.respostaInvalida(String prefixo, {String? detalhe}) =>
      FalhaApp(
        codigo: '$prefixo-RESP',
        origem: OrigemFalha.servidor,
        titulo: 'A resposta do servidor veio incompleta',
        texto: 'Chegou uma resposta que o app não entende. Se você está num '
            'Wi-Fi com página de cadastro, entre nela primeiro. Se não, tente '
            'de novo em alguns minutos.',
        detalhe: detalhe,
      );

  /// Qualquer outra coisa: o tipo do erro vai no código, para o DTI achar.
  factory FalhaApp.inesperada(String prefixo, Object erro) => FalhaApp(
        codigo: '$prefixo-X-${erro.runtimeType}',
        origem: OrigemFalha.app,
        titulo: 'Algo saiu diferente do esperado',
        texto: 'O app não conseguiu terminar esta ação. O registro foi gravado '
            'para a equipe do DTI. Tente de novo; se repetir, abra um chamado '
            'técnico.',
        acao: AcaoFalha.abrirChamado,
        detalhe: '$erro',
      );

  /// Recusa explicada pela API (`{code: 0, erro, message}`): o texto vem do
  /// servidor e o código vira `<prefixo>-<ERRO>` (FB-ANEXO-GRANDE).
  factory FalhaApp.daApi(String prefixo, String erro, String? mensagem) {
    final (origem, acao, titulo) = switch (erro) {
      'SESSAO_INVALIDA' => (OrigemFalha.conta, AcaoFalha.entrarDeNovo, 'Entre de novo no app'),
      'MUITAS_TENTATIVAS' => (OrigemFalha.conta, AcaoFalha.nenhuma, 'Acesso bloqueado por 15 minutos'),
      'LIMITE_DIA' => (OrigemFalha.conta, AcaoFalha.nenhuma, 'Limite do dia atingido'),
      'DESLIGADO' => (OrigemFalha.servidor, AcaoFalha.nenhuma, 'Função desligada no momento'),
      'ANEXO_GRANDE' || 'ANEXO_TIPO' => (OrigemFalha.aparelho, AcaoFalha.nenhuma, 'Anexo não aceito'),
      'DADOS_INVALIDOS' || 'NAO_ENCONTRADO' => (OrigemFalha.dado, AcaoFalha.nenhuma, 'Confira os dados'),
      _ => (OrigemFalha.servidor, AcaoFalha.tentarDeNovo, 'O servidor não conseguiu atender'),
    };
    return FalhaApp(
      codigo: '$prefixo-${erro.replaceAll('_', '-')}',
      origem: origem,
      titulo: titulo,
      texto: (mensagem == null || mensagem.isEmpty)
          ? 'Tente de novo em alguns minutos.'
          : mensagem,
      acao: acao,
      detalhe: 'API: $erro',
    );
  }

  @override
  String toString() => 'FalhaApp($codigo: ${detalhe ?? titulo})';
}
