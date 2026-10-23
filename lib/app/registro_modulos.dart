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
      sinonimosPadrao: ['efetivo', 'tropa', 'força']),
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
  // Chamados no app chegam na fase 3c (SISCHAMADOS): por enquanto o menu
  // traz a função bloqueada "Em breve", e sem rota esta versão não a abre.
  ModuloApp(
      chave: 'atend.chamados',
      rotuloPadrao: 'Meus chamados',
      icone: 'chamado',
      prefixoErro: 'CH'),
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
]);

/// Prefixos de erro da tabela do §9.1. Módulo novo com prefixo fora dela
/// precisa entrar lá antes (e no `soupm_config`, chave `erros`).
const prefixosConhecidos = {
  'LG', 'CF', 'CC', 'TS', 'CT', 'FE', 'FI', 'DC', 'NR', 'MF', 'AV', 'BU', //
  'FB', 'CH', 'PD', 'MD', 'AP', 'ES', 'SV', 'AJ', 'DO', 'NT', 'CM', 'LOG',
};
