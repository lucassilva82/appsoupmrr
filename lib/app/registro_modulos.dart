import '../core/navegacao/modulo_app.dart';
import '../utils/app_routes.dart';

/// Todos os módulos do app, com as chaves do docs/SOUPM_2_2.md §3.2.
///
/// Na fase 0 o registro só descreve o que já existe (rota de hoje, prefixo
/// de erro, chave antiga); o menu e o roteador passam a ler daqui na fase 2.
final registroModulos = RegistroModulos(const [
  // ── Minha vida funcional ──────────────────────────────────────────────
  ModuloApp(
      chave: 'rh.ficha',
      rotuloPadrao: 'Ficha Individual',
      icone: 'pessoa',
      prefixoErro: 'FI',
      rota: AppRoutes.PAGE_MILITAR,
      apelidos: ['ficha_individual'],
      sinonimosPadrao: ['meus dados', 'cadastro', 'endereço', 'telefone']),
  ModuloApp(
      chave: 'rh.contracheques',
      rotuloPadrao: 'Contracheques',
      icone: 'contracheque',
      prefixoErro: 'CC',
      rota: AppRoutes.CONTRACHEQUE_PAGE,
      apelidos: ['contracheques'],
      sinonimosPadrao: ['salário', 'pagamento', 'holerite', 'folha']),
  ModuloApp(
      chave: 'rh.documentos',
      rotuloPadrao: 'Central de documentos',
      icone: 'documento',
      prefixoErro: 'DO',
      rota: AppRoutes.DOCUMENTOS,
      sinonimosPadrao: ['documentos', 'pdf', 'arquivos', 'baixados']),
  ModuloApp(
      chave: 'com.central',
      rotuloPadrao: 'Comunicados',
      icone: 'comunicado',
      prefixoErro: 'CM',
      rota: AppRoutes.COMUNICADOS,
      sinonimosPadrao: ['comunicado', 'aviso oficial', 'informe']),
  // Serviço operacional: o Operar do GAPE (operar.pmrr.online), aberto numa
  // tela interna. A chave é a mesma que o card da Início consulta para saber
  // se o painel ligou ou desligou o módulo.
  ModuloApp(
      chave: 'op.operacoes',
      rotuloPadrao: 'Operações',
      icone: 'escudo',
      prefixoErro: 'OP',
      rota: AppRoutes.OPERACOES,
      apelidos: ['operacoes'],
      sinonimosPadrao: ['operação', 'escala da operação', 'expoferr', 'enem', 'serviço', 'posto']),
  ModuloApp(
      chave: 'rh.validar',
      rotuloPadrao: 'Validar documento',
      icone: 'validar',
      prefixoErro: 'VD',
      rota: AppRoutes.VALIDAR,
      sinonimosPadrao: ['validar', 'conferir', 'autenticidade', 'qr code']),
  ModuloApp(
      chave: 'rh.carreira',
      rotuloPadrao: 'Linha do tempo da carreira',
      icone: 'carreira',
      prefixoErro: 'CR',
      rota: AppRoutes.CARREIRA,
      sinonimosPadrao: ['carreira', 'promoção', 'histórico', 'linha do tempo']),
  ModuloApp(
      chave: 'rh.contracheques.grafico',
      rotuloPadrao: 'Análise salarial',
      icone: 'grafico',
      prefixoErro: 'CC',
      rota: AppRoutes.CONTRACHEQUE_GRAFICO_PAGE,
      apelidos: ['contracheques.grafico']),
  ModuloApp(
      chave: 'rh.ferias',
      rotuloPadrao: 'Plano de férias',
      icone: 'ferias',
      prefixoErro: 'FE',
      rota: AppRoutes.PLANO_DE_FERIAS_PAGE,
      apelidos: ['plano_ferias'],
      sinonimosPadrao: ['férias', 'descanso']),
  ModuloApp(
      chave: 'rh.tempo_servico',
      rotuloPadrao: 'Tempo de serviço e inatividade',
      icone: 'tempo',
      prefixoErro: 'TS',
      rota: AppRoutes.CALCULO_INATIVIDADE_PAGE,
      apelidos: ['calculo_inatividade'],
      sinonimosPadrao: ['reserva', 'aposentadoria', 'inatividade']),
  ModuloApp(
      chave: 'rh.certidoes',
      rotuloPadrao: 'Certidões',
      icone: 'certidao',
      prefixoErro: 'CT',
      rota: AppRoutes.CERTIDOES_PAGE,
      apelidos: ['certidoes'],
      sinonimosPadrao: ['tempo de serviço', 'declaração', 'documento']),
  ModuloApp(
      chave: 'rh.declaracoes',
      rotuloPadrao: 'Declarações anuais',
      icone: 'declaracao',
      prefixoErro: 'DC',
      rota: AppRoutes.DECLARACOES_PAGE,
      apelidos: ['declaracoes'],
      sinonimosPadrao: ['bens', 'imposto de renda', 'irpf', 'parentesco']),
  ModuloApp(
      chave: 'rh.declaracoes.bens',
      rotuloPadrao: 'Declaração de bens',
      icone: 'declaracao',
      prefixoErro: 'DC',
      rota: AppRoutes.DECLARACAODEBENS,
      apelidos: ['declaracoes.bens']),
  ModuloApp(
      chave: 'rh.declaracoes.parentesco',
      rotuloPadrao: 'Parentesco',
      icone: 'declaracao',
      prefixoErro: 'DC',
      rota: AppRoutes.DECLARACAO_PARENTESCO_PAGE,
      apelidos: ['declaracoes.parentesco']),
  ModuloApp(
      chave: 'rh.declaracoes.acumulo',
      rotuloPadrao: 'Acúmulo de cargos',
      icone: 'declaracao',
      prefixoErro: 'DC',
      rota: AppRoutes.DECLARACAO_ACUMULO_CARGOS_PAGE,
      apelidos: ['declaracoes.acumulo']),
  // ── Serviço operacional ───────────────────────────────────────────────
  ModuloApp(
      chave: 'op.escalas',
      rotuloPadrao: 'Minhas escalas',
      icone: 'escala',
      prefixoErro: 'ES',
      rota: AppRoutes.ESCALAS,
      apelidos: ['escalas'],
      sinonimosPadrao: ['escala', 'serviço', 'turno', 'folga']),
  ModuloApp(
      chave: 'op.svi',
      rotuloPadrao: 'Serviço voluntário (SVI)',
      icone: 'svi',
      prefixoErro: 'SV',
      rota: AppRoutes.SVI_ESCALAS,
      apelidos: ['svi'],
      sinonimosPadrao: ['svi', 'voluntário', 'hora extra']),
  // O plantão passou a fazer parte de Minhas escalas (§3.2): fica fora do
  // menu, e quem chega por um push antigo cai nas escalas.
  ModuloApp(
      chave: 'op.plantao',
      rotuloPadrao: 'Meu plantão',
      icone: 'escala',
      prefixoErro: 'ES',
      rota: AppRoutes.PLANTAO,
      apelidos: ['plantao'],
      redirecionaPara: 'op.escalas'),
  // ── Normas ────────────────────────────────────────────────────────────
  ModuloApp(
      chave: 'normas.legislacoes',
      rotuloPadrao: 'Legislações',
      icone: 'lei',
      prefixoErro: 'NR',
      rota: AppRoutes.LEGISLACOES_PAGE,
      apelidos: ['legislacoes'],
      sinonimosPadrao: ['lei', 'decreto', 'estatuto', 'portaria']),
  ModuloApp(
      chave: 'normas.pops',
      rotuloPadrao: 'POPs',
      icone: 'pop',
      prefixoErro: 'NR',
      rota: AppRoutes.POP_PAGE,
      apelidos: ['pops'],
      sinonimosPadrao: ['procedimento', 'pop']),
  // ── Gestão ────────────────────────────────────────────────────────────
  ModuloApp(
      chave: 'gestao.mapa_forca',
      rotuloPadrao: 'Mapa da Força',
      icone: 'efetivo',
      prefixoErro: 'MF',
      rota: AppRoutes.MAPA_DA_FORCA,
      apelidos: ['mapa_forca'],
      sinonimosPadrao: ['efetivo', 'tropa', 'força', 'comando', 'unidade']),
  // Boletins e Patrimônio ainda não têm tela: entram no menu como "Em breve",
  // com a chave já reservada, para o painel poder liberá-las sem versão nova.
  ModuloApp(
      chave: 'gestao.boletins',
      rotuloPadrao: 'Boletins',
      icone: 'boletim',
      prefixoErro: 'BG',
      sinonimosPadrao: ['boletim', 'bg', 'publicação']),
  ModuloApp(
      chave: 'gestao.patrimonio',
      rotuloPadrao: 'Patrimônio e frota',
      icone: 'patrimonio',
      prefixoErro: 'PT',
      sinonimosPadrao: ['viatura', 'patrimônio', 'frota', 'bens']),
  // ── Atendimento e abas ────────────────────────────────────────────────
  ModuloApp(
      chave: 'atend.ajuda',
      rotuloPadrao: 'Preciso de ajuda',
      icone: 'ajuda',
      prefixoErro: 'AJ',
      rota: AppRoutes.AJUDA_PAGE,
      apelidos: ['ajuda'],
      sinonimosPadrao: ['ajuda', 'dúvida', 'suporte', 'problema']),
  ModuloApp(
      chave: 'atend.feedback',
      rotuloPadrao: 'Sugestões e elogios',
      icone: 'feedback',
      prefixoErro: 'FB',
      rota: AppRoutes.FEEDBACK,
      sinonimosPadrao: ['sugestão', 'ideia', 'elogio', 'melhoria']),
  // Chamados (fase 3c, SISCHAMADOS do solicitante). O menu continua "Em
  // breve" até o build ter a chave do app e o painel liberar a função.
  ModuloApp(
      chave: 'atend.chamados',
      rotuloPadrao: 'Meus chamados',
      icone: 'chamado',
      prefixoErro: 'CH',
      rota: AppRoutes.CHAMADOS,
      sinonimosPadrao: ['chamado', 'suporte', 'técnico', 'dti']),
  ModuloApp(
      chave: 'avisos',
      rotuloPadrao: 'Avisos',
      icone: 'aviso',
      prefixoErro: 'AV',
      rota: AppRoutes.NOTIFICATIONS_PAGE),
  ModuloApp(
      chave: 'perfil.configuracoes',
      rotuloPadrao: 'Configurações',
      icone: 'config',
      prefixoErro: 'AP',
      rota: AppRoutes.CONFIGURACOES),
  // Funções do Perfil (§3.2): fora do menu de Serviços, mas a ajuda e a
  // busca levam direto a elas.
  ModuloApp(
      chave: 'conta.email',
      rotuloPadrao: 'E-mail',
      icone: 'email',
      prefixoErro: 'LG',
      rota: AppRoutes.CONTA_EMAIL,
      apelidos: ['config.email']),
  ModuloApp(
      chave: 'conta.senha',
      rotuloPadrao: 'Alterar senha',
      icone: 'senha',
      prefixoErro: 'LG',
      rota: AppRoutes.CONTA_SENHA,
      apelidos: ['config.alterar_senha']),
  ModuloApp(
      chave: 'seg.biometria',
      rotuloPadrao: 'Face ID e biometria',
      icone: 'biometria',
      prefixoErro: 'LG',
      rota: AppRoutes.BIOMETRIA,
      apelidos: ['config.biometria']),
  ModuloApp(
      chave: 'notif.preferencias',
      rotuloPadrao: 'Notificações',
      icone: 'notificacao',
      prefixoErro: 'AV',
      rota: AppRoutes.NOTIF_PREFERENCIAS,
      apelidos: ['config.notificacoes']),
  ModuloApp(
      chave: 'apar.tema',
      rotuloPadrao: 'Aparência',
      icone: 'tema',
      prefixoErro: 'AP',
      rota: AppRoutes.APARENCIA,
      apelidos: ['config.tema']),
]);

/// Prefixos de erro da tabela do §9.1. Módulo novo com prefixo fora dela
/// precisa entrar lá antes (e no `soupm_config`, chave `erros`).
const prefixosConhecidos = {
  'LG', 'CF', 'CC', 'TS', 'CT', 'FE', 'FI', 'DC', 'NR', 'MF', 'AV', 'BU', //
  'FB', 'CH', 'PD', 'MD', 'AP', 'ES', 'SV', 'AJ', 'DO', 'NT', 'CM', 'CR', 'VD', 'BG', 'PT', 'LOG',
  'OP', // Operações (operar_token.php e a tela do módulo)
};
