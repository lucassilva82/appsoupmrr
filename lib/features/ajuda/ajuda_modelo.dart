/// "Preciso de ajuda" (docs/SOUPM_2_2.md §8.0): assuntos e perguntas vêm do
/// `app_config` (`ajuda`), editados no painel. [ajudaPadrao] é a reserva
/// para quando o app ainda não recebeu nada (igual à carga do banco,
/// api-soupmrr/sql/2026-10-23_soupm_atendimento.sql).
class AjudaPergunta {
  const AjudaPergunta({
    required this.id,
    required this.pergunta,
    required this.resposta,
    this.destino,
  });

  final int id;
  final String pergunta;
  final String resposta;

  /// Chave da função que resolve (vira o botão da resposta).
  final String? destino;
}

class AjudaAssunto {
  const AjudaAssunto({
    required this.chave,
    required this.nome,
    required this.icone,
    required this.perguntas,
  });

  final String chave;
  final String nome;
  final String icone;
  final List<AjudaPergunta> perguntas;

  /// Lê `ajuda.assuntos`. Assunto ou pergunta sem campo essencial é
  /// ignorado; nada aqui derruba a tela.
  static List<AjudaAssunto>? lista(Object? j) {
    if (j is! Map || j['assuntos'] is! List) return null;
    return [
      for (final a in j['assuntos'] as List)
        if (a is Map && a['chave'] is String && a['nome'] is String)
          AjudaAssunto(
            chave: a['chave'] as String,
            nome: a['nome'] as String,
            icone: '${a['icone'] ?? 'ajuda'}',
            perguntas: [
              if (a['perguntas'] is List)
                for (final p in a['perguntas'] as List)
                  if (p is Map && p['id'] is num && p['pergunta'] is String && p['resposta'] is String)
                    AjudaPergunta(
                      id: (p['id'] as num).toInt(),
                      pergunta: p['pergunta'] as String,
                      resposta: p['resposta'] as String,
                      destino: p['destino'] as String?,
                    ),
            ],
          ),
    ];
  }
}

const ajudaPadrao = [
  AjudaAssunto(chave: 'acesso', nome: 'Conta e senha', icone: 'pessoa', perguntas: [
    AjudaPergunta(
        id: -1,
        pergunta: 'Quero trocar minha senha',
        resposta: 'Em Perfil, na seção Conta, toque em Alterar senha. Se não lembrar a senha atual, use '
            '"Não lembro minha senha atual": o código chega no seu e-mail confirmado.',
        destino: 'perfil.configuracoes'),
    AjudaPergunta(
        id: -2,
        pergunta: 'Como entrar com Face ID ou biometria',
        resposta: 'Em Perfil, na seção Segurança, ligue a entrada com biometria. Na próxima abertura o app '
            'pede o seu rosto ou a sua digital no lugar da senha.',
        destino: 'perfil.configuracoes'),
  ]),
  AjudaAssunto(chave: 'contracheque', nome: 'Contracheque', icone: 'contracheque', perguntas: [
    AjudaPergunta(
        id: -3,
        pergunta: 'O contracheque do mês não aparece',
        resposta: 'O mês aparece depois que a folha é publicada no SIGRH. Abra Contracheques e puxe a lista '
            'para baixo para atualizar. Se o mês anterior aparece e o atual não, a folha dele ainda não foi liberada.',
        destino: 'rh.contracheques'),
  ]),
  AjudaAssunto(chave: 'documentos', nome: 'Certidões e documentos', icone: 'certidao', perguntas: [
    AjudaPergunta(
        id: -4,
        pergunta: 'Como emitir uma certidão',
        resposta: 'Em Certidões, toque em "Emitir nova certidão" e escolha o tipo. O PDF sai na hora, com QR '
            'Code de conferência, e uma cópia vai para o seu e-mail confirmado.',
        destino: 'rh.certidoes'),
  ]),
  AjudaAssunto(chave: 'app', nome: 'O app deu erro ou travou', icone: 'ajuda', perguntas: [
    AjudaPergunta(
        id: -5,
        pergunta: 'O app fechou ou mostrou um erro',
        resposta: 'Feche e abra o app de novo. Se o erro voltar, anote o código que aparece na tela (por '
            'exemplo, CC-LENTO) e abra um chamado técnico com ele.'),
  ]),
];
