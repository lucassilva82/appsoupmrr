import '../config/app_config.dart';

/// Menu de reserva, igual à árvore do protótipo da 2.2 (`prototipos/`,
/// Artifact "Protótipo SouPMRR 2.2", constante `MENU`) e à carga do
/// `soupm_menu_item` (api-soupmrr/sql/2026-10-23_soupm_menu_prototipo.sql).
/// Vale enquanto o `app_config` não chegou (primeira abertura sem internet).
///
/// A ordem das áreas é a do protótipo: Minha vida funcional, Serviço
/// operacional, Normas, Gestão, Atendimento DTI e Institucional. Dentro de
/// cada uma, a ordem também: no RH o contracheque vem primeiro, porque é o
/// que o militar mais abre.
///
/// [gestor] segue a regra de hoje do app (`Auth.isSuperUser`) até a fase 5.
List<ItemMenu> menuPadrao({required bool gestor}) {
  /// Uma função do menu. [rota] nula é função sem tela ainda: ela aparece,
  /// com o selo, e o toque abre a folha de bloqueio em vez de uma tela vazia.
  ItemMenu f(String chave, String rotulo, String icone,
          {String? rota,
          String? descricao,
          List<String> sinonimos = const [],
          List<String> apelidos = const [],
          bool emBreve = false,
          bool novo = false,
          bool visivel = true,
          String? tituloBloqueio,
          String? textoBloqueio}) =>
      ItemMenu(
        chave: chave,
        tipo: 'funcao',
        rotulo: rotulo,
        descricao: descricao,
        icone: icone,
        rota: rota,
        sinonimos: sinonimos,
        apelidos: apelidos,
        visivel: visivel,
        bloqueado: emBreve,
        selo: emBreve ? 'Em breve' : (novo ? 'Novo' : null),
        mensagem: emBreve
            ? MensagemBloqueio(
                motivo: 'em_breve',
                titulo: tituloBloqueio ?? '$rotulo: em breve',
                texto: textoBloqueio ??
                    'Esta função está sendo preparada com o sistema da PMRR e ainda não abre no app.',
                codigo: 'MD-${chave.toUpperCase()}-EM_BREVE')
            : null,
      );

  return [
    ItemMenu(
      chave: 'rh',
      tipo: 'area',
      rotulo: 'Minha vida funcional',
      descricao: 'Contracheque, férias, certidões e seus dados',
      icone: 'rh',
      arte: 'rh',
      filhos: [
        f('rh.contracheques', 'Contracheques', 'contracheque',
            rota: '/contracheque-page',
            descricao: 'Mês a mês, PDF e análise salarial',
            sinonimos: [
              'salário', 'salario', 'pagamento', 'holerite', //
              'folha', 'contra cheque', 'vencimento'
            ],
            apelidos: ['contracheques']),
        f('rh.certidoes', 'Certidões', 'certidao',
            rota: '/certidoes-page',
            descricao: 'Emita na hora, com QR Code',
            sinonimos: [
              'tempo de serviço', 'vínculo', 'comportamento', //
              'ficha funcional', 'documento', 'declaração'
            ],
            apelidos: ['certidoes']),
        f('rh.ferias', 'Plano de férias', 'ferias',
            rota: '/plano-de-ferias-page',
            descricao: 'Parcelas, datas e 13º',
            sinonimos: ['férias', 'ferias', 'descanso', 'recesso'],
            apelidos: ['plano_ferias']),
        f('rh.ficha', 'Ficha Individual', 'pessoa',
            rota: '/page-militar',
            descricao: 'Seus dados, telefones e endereço',
            sinonimos: [
              'meus dados', 'cadastro', 'endereço', //
              'telefone', 'contato', 'perfil'
            ],
            apelidos: ['ficha_individual']),
        f('rh.tempo_servico', 'Tempo de serviço e inatividade', 'tempo',
            rota: '/calculo-inatividade-page',
            descricao: 'Tempo averbado e simulação da reserva',
            sinonimos: [
              'reserva', 'aposentadoria', 'inatividade', //
              'averbação', 'iper', 'tempo'
            ],
            apelidos: ['calculo_inatividade']),
        f('rh.declaracoes', 'Declarações anuais', 'declaracao',
            rota: '/declaracoes-page',
            descricao: 'Bens, IRPF, parentesco e acúmulo',
            sinonimos: [
              'bens', 'imposto de renda', 'irpf', //
              'parentesco', 'acúmulo de cargos'
            ],
            apelidos: ['declaracoes']),
        f('rh.documentos', 'Central de documentos', 'documento',
            rota: '/rh/documentos',
            descricao: 'Certidões, contracheques e declarações',
            sinonimos: ['documentos', 'pdf', 'arquivos'],
            novo: true),
        f('rh.carreira', 'Linha do tempo da carreira', 'carreira',
            rota: '/rh/carreira',
            descricao: 'Incorporação, promoções e lotações',
            sinonimos: ['carreira', 'promoção', 'histórico', 'lotação'],
            novo: true),
        f('rh.validar', 'Validar documento', 'validar',
            rota: '/rh/validar',
            descricao: 'Leia o QR Code de uma certidão',
            sinonimos: ['qr', 'validar', 'autenticidade', 'conferir'],
            novo: true),
      ],
    ),
    ItemMenu(
      chave: 'operacional',
      tipo: 'area',
      rotulo: 'Serviço operacional',
      descricao: 'Escalas, SVI e plantão',
      icone: 'operacional',
      arte: 'operacional',
      filhos: [
        f('op.escalas', 'Minhas escalas', 'escala',
            rota: '/escalas',
            descricao: 'Escalas, plantões e ciência',
            sinonimos: ['escala', 'serviço', 'ciência', 'turno', 'plantão', 'folga'],
            apelidos: ['escalas'],
            emBreve: true),
        f('op.svi', 'Serviço voluntário (SVI)', 'svi',
            rota: '/svi/escalas',
            descricao: 'Vagas e adesão',
            sinonimos: ['svi', 'voluntário', 'extra', 'hora extra'],
            apelidos: ['svi'],
            emBreve: true),
        // Fora do menu, como manda o §3.2: o plantão virou parte de Minhas
        // escalas. A chave segue viva para o push antigo continuar abrindo.
        f('op.plantao', 'Meu plantão', 'escala',
            rota: '/plantao', apelidos: ['plantao'], emBreve: true, visivel: false),
      ],
    ),
    ItemMenu(
      chave: 'normas',
      tipo: 'area',
      rotulo: 'Normas e procedimentos',
      descricao: 'Legislações e POPs',
      icone: 'normas',
      arte: 'normas',
      filhos: [
        f('normas.legislacoes', 'Legislações', 'lei',
            rota: '/legislacoes-page',
            descricao: 'Leis, decretos e portarias',
            sinonimos: ['lei', 'decreto', 'estatuto', 'portaria', 'norma'],
            apelidos: ['legislacoes']),
        f('normas.pops', 'POPs', 'pop',
            rota: '/pop-page',
            descricao: 'Procedimentos operacionais padrão',
            sinonimos: ['procedimento', 'pop', 'operacional padrão'],
            apelidos: ['pops']),
      ],
    ),
    if (gestor)
      ItemMenu(
        chave: 'gestao',
        tipo: 'area',
        rotulo: 'Gestão',
        descricao: 'Para comandantes e gestores, no escopo de cada um',
        icone: 'gestao',
        arte: 'gestao',
        filhos: [
          f('gestao.mapa_forca', 'Mapa da Força', 'efetivo',
              rota: '/mapa-da-forca-page',
              descricao: 'Efetivo e situação, no seu escopo',
              sinonimos: ['efetivo', 'tropa', 'força', 'comando', 'unidade'],
              apelidos: ['mapa_forca']),
          f('gestao.boletins', 'Boletins', 'boletim',
              descricao: 'Boletim geral e reservado',
              sinonimos: ['boletim', 'bg', 'publicação'],
              emBreve: true),
          f('gestao.patrimonio', 'Patrimônio e frota', 'patrimonio',
              descricao: 'Bens e viaturas da unidade',
              sinonimos: ['viatura', 'patrimônio', 'frota', 'bens'],
              emBreve: true),
        ],
      ),
    ItemMenu(
      chave: 'atendimento',
      tipo: 'area',
      rotulo: 'Atendimento DTI',
      descricao: 'Ajuda, chamados de suporte e sugestões',
      icone: 'atendimento',
      arte: 'atendimento',
      filhos: [
        f('atend.ajuda', 'Preciso de ajuda', 'ajuda',
            rota: '/ajuda-page',
            descricao: 'Respostas rápidas para as dúvidas mais comuns',
            sinonimos: [
              'ajuda', 'socorro', 'dúvida', 'duvida', 'como faço', //
              'não consigo', 'whatsapp', 'telefone', 'suporte'
            ],
            apelidos: ['ajuda']),
        // "Em breve" até o build ter a chave do app no SISCHAMADOS
        // (docs/PENDENTE_USUARIO.md §2b) e o painel liberar a função.
        f('atend.chamados', 'Meus chamados', 'chamado',
            rota: '/atend/chamados',
            descricao: 'Suporte técnico: erro no app, acesso, senha, rede, equipamento',
            sinonimos: [
              'chamado', 'suporte', 'dti', 'sischamados', 'atendimento', //
              'protocolo', 'erro', 'problema', 'bug', 'travou', 'não funciona'
            ],
            emBreve: true,
            tituloBloqueio: 'Chamados no app em breve',
            textoBloqueio:
                'Em breve você vai abrir e acompanhar chamados técnicos do DTI por aqui.'),
        f('atend.feedback', 'Sugestões e elogios', 'feedback',
            rota: '/atend/feedback',
            descricao: 'Ideias de melhoria e funções novas para o DTI',
            sinonimos: [
              'sugestão', 'ideia', 'melhoria', //
              'função nova', 'elogio', 'feedback'
            ],
            novo: true),
      ],
    ),
    ItemMenu(
      chave: 'institucional',
      tipo: 'area',
      rotulo: 'Institucional',
      descricao: 'Comunicados, notícias e agenda',
      icone: 'institucional',
      arte: 'institucional',
      filhos: [
        f('com.central', 'Comunicados', 'comunicado',
            rota: '/com/central',
            descricao: 'Central de comunicados oficiais',
            sinonimos: ['comunicado', 'aviso oficial', 'informe', 'nota']),
        // No protótipo aparece liberada, mas a intranet ainda não tem rota de
        // notícias, e a agenda que existe é só a dos comandantes (§16, P7).
        // Enquanto não houver de onde ler, fica "Em breve": descrição só pode
        // citar o que abre de verdade (APRENDIZADOS §7).
        f('inst.noticias', 'Notícias e agenda', 'noticia',
            descricao: 'Da intranet da PMRR',
            sinonimos: ['notícia', 'agenda', 'evento', 'formatura'],
            emBreve: true),
      ],
    ),
  ];
}
