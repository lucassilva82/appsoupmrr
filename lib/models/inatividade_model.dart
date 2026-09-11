/// Motor de cálculo da inatividade dos militares estaduais de Roraima.
///
/// Base legal:
///  • Decreto-Lei Federal nº 667/1969, arts. 24-A a 24-J (red. Lei nº 13.954/2019)
///  • LC/RR nº 305, de 18/01/2022 — Sistema de Proteção Social dos Militares (SPSMRR)
///  • LC/RR nº 308, de 25/01/2022 — alterou a LC/RR nº 194/2012 (Estatuto)
///
/// Este arquivo é Dart puro (sem Flutter) para permitir teste isolado.
library;

// ─── Enums ───────────────────────────────────────────────────────────────────

enum Sexo { masculino, feminino }

extension SexoLabel on Sexo {
  String get label => this == Sexo.masculino ? 'Masculino' : 'Feminino';
}

/// Postos e graduações da PMRR/CBMRR.
enum PostoGraduacao {
  coronel,
  tenenteCoronel,
  major,
  capitao,
  primeiroTenente,
  segundoTenente,
  aspirante,
  subtenente,
  primeiroSargento,
  segundoSargento,
  terceiroSargento,
  cabo,
  soldado1Classe,
  soldado2Classe,
}

extension PostoInfo on PostoGraduacao {
  String get label {
    switch (this) {
      case PostoGraduacao.coronel:
        return 'Coronel';
      case PostoGraduacao.tenenteCoronel:
        return 'Tenente-Coronel';
      case PostoGraduacao.major:
        return 'Major';
      case PostoGraduacao.capitao:
        return 'Capitão';
      case PostoGraduacao.primeiroTenente:
        return '1º Tenente';
      case PostoGraduacao.segundoTenente:
        return '2º Tenente';
      case PostoGraduacao.aspirante:
        return 'Aspirante a Oficial';
      case PostoGraduacao.subtenente:
        return 'Subtenente';
      case PostoGraduacao.primeiroSargento:
        return '1º Sargento';
      case PostoGraduacao.segundoSargento:
        return '2º Sargento';
      case PostoGraduacao.terceiroSargento:
        return '3º Sargento';
      case PostoGraduacao.cabo:
        return 'Cabo';
      case PostoGraduacao.soldado1Classe:
        return 'Soldado de 1ª Classe';
      case PostoGraduacao.soldado2Classe:
        return 'Soldado de 2ª Classe';
    }
  }

  /// Idade-limite para a **reforma** — LC/RR 305/2022, art. 25, I.
  ///
  /// Diferente da idade de reserva, o art. 25 cobre todos os postos: 72 anos
  /// para oficiais superiores e 68 para os demais. É por aqui que 2º e 3º
  /// sargento e soldado de 2ª classe, ausentes do art. 24, I, têm idade.
  int get idadeLimiteReforma {
    switch (this) {
      case PostoGraduacao.coronel:
      case PostoGraduacao.tenenteCoronel:
      case PostoGraduacao.major:
        return 72; // alínea "a" — oficiais superiores
      case PostoGraduacao.capitao:
      case PostoGraduacao.primeiroTenente:
      case PostoGraduacao.segundoTenente:
      case PostoGraduacao.aspirante:
        return 68; // alínea "b" — capitães e oficiais subalternos
      default:
        return 68; // alínea "c" — praças
    }
  }

  /// Idade-limite para transferência ex-officio (LC/RR 305/2022, art. 24, I).
  ///
  /// Retorna `null` quando a graduação **não foi contemplada** nas alíneas
  /// "a" a "h" do inciso I — é uma lacuna real do texto legal, não um
  /// esquecimento deste código. Nesses casos a informação é exibida como
  /// "não prevista expressamente".
  int? get idadeLimite {
    switch (this) {
      case PostoGraduacao.coronel:
        return 67; // alínea "a"
      case PostoGraduacao.tenenteCoronel:
        return 65; // alínea "b"
      case PostoGraduacao.major:
        return 64; // alínea "c"
      case PostoGraduacao.capitao:
      case PostoGraduacao.primeiroTenente:
      case PostoGraduacao.segundoTenente:
      case PostoGraduacao.aspirante:
        return 63; // alínea "d" — capitães e oficiais subalternos
      case PostoGraduacao.subtenente:
        return 63; // alínea "e"
      case PostoGraduacao.primeiroSargento:
        return 57; // alínea "f"
      case PostoGraduacao.cabo:
        return 54; // alínea "g"
      case PostoGraduacao.soldado1Classe:
        return 50; // alínea "h"
      case PostoGraduacao.segundoSargento:
      case PostoGraduacao.terceiroSargento:
      case PostoGraduacao.soldado2Classe:
        return null; // lacuna do art. 24, I
    }
  }
}

/// Hipóteses de incapacidade definitiva — LC/RR 305/2022, art. 26.
///
/// Os incisos I a IV geram proventos integrais (art. 25, §5º, e art. 24-A, II
/// do DL 667/1969); o inciso V, sem nexo com o serviço, gera proporcionais
/// (art. 25, §3º). A reforma por invalidez não exige tempo de serviço algum.
enum HipoteseIncapacidade {
  /// Ferimento na atividade militar, acidente em serviço ou doença com
  /// relação de causa e efeito com o serviço — art. 26, I a III.
  nexoComServico,

  /// Doença grave do rol do art. 26, IV.
  doencaGrave,

  /// Acidente ou doença sem relação com o serviço — art. 26, V.
  semNexo,
}

extension HipoteseInfo on HipoteseIncapacidade {
  bool get integral => this != HipoteseIncapacidade.semNexo;

  String get label {
    switch (this) {
      case HipoteseIncapacidade.nexoComServico:
        return 'Ferimento, acidente ou doença com nexo com o serviço';
      case HipoteseIncapacidade.doencaGrave:
        return 'Doença grave do rol legal';
      case HipoteseIncapacidade.semNexo:
        return 'Acidente ou doença sem relação com o serviço';
    }
  }

  String get fundamento {
    switch (this) {
      case HipoteseIncapacidade.nexoComServico:
        return 'LC/RR 305/2022, art. 26, I a III, c/c art. 25, §5º e '
            'DL 667/1969, art. 24-A, II';
      case HipoteseIncapacidade.doencaGrave:
        return 'LC/RR 305/2022, art. 26, IV, c/c art. 25, §5º';
      case HipoteseIncapacidade.semNexo:
        return 'LC/RR 305/2022, art. 26, V, c/c art. 25, §3º';
    }
  }
}

/// Demais hipóteses de reserva de ofício — art. 24, II a VI da LC/RR
/// 305/2022. Todas exigem 20 anos de contribuição e geram proporcionais.
const hipotesesReservaOficio = <List<String>>[
  ['II', 'Mais de 2 anos, contínuos ou não, em licença para tratar de '
      'interesse particular'],
  ['III', 'Mais de 2 anos contínuos em licença para tratamento de saúde de '
      'pessoa da família'],
  ['IV', 'Mais de 2 anos agregado por posse em cargo público civil temporário'],
  ['V', 'Promoção por tempo de contribuição e serviço militar'],
  ['VI', 'Diplomação em cargo eletivo'],
];

/// Regime jurídico em que o militar se enquadra.
enum RegimeAplicavel {
  /// Cumpriu os requisitos do art. 120 da LC/RR 305/2022 até 31/12/2021.
  direitoAdquirido,

  /// Ingressou até 15/12/2019 e não completou o mínimo — art. 24-G do DL 667.
  transicao,

  /// Ingressou a partir de 16/12/2019 — regra permanente do art. 24-A.
  permanente,
}

extension RegimeInfo on RegimeAplicavel {
  String get label {
    switch (this) {
      case RegimeAplicavel.direitoAdquirido:
        return 'Direito adquirido';
      case RegimeAplicavel.transicao:
        return 'Regra de transição (com pedágio)';
      case RegimeAplicavel.permanente:
        return 'Regra permanente';
    }
  }

  String get fundamento {
    switch (this) {
      case RegimeAplicavel.direitoAdquirido:
        return 'LC/RR nº 305/2022, art. 120 c/c DL 667/1969, art. 24-F';
      case RegimeAplicavel.transicao:
        return 'DL 667/1969, art. 24-G, I e parágrafo único';
      case RegimeAplicavel.permanente:
        return 'DL 667/1969, art. 24-A, I, "a"';
    }
  }
}

// ─── Constantes legais ───────────────────────────────────────────────────────

class ParametrosLegais {
  ParametrosLegais._();

  /// Conversões usadas na contagem de tempo (padrão adotado pelo SIGRH/IPER).
  static const int diasPorAno = 365;
  static const int diasPorMes = 30;

  /// Corte do direito adquirido — arts. 120 e 121 da LC/RR 305/2022, que
  /// fixam 31/12/2021 no próprio texto.
  ///
  /// Não confundir com a **Data Base**: os pedágios do art. 24-G são aferidos
  /// na data da simulação, como faz a planilha do IPER/DIMIL (célula E10).
  static final DateTime dataCorteDireitoAdquirido = DateTime(2021, 12, 31);

  /// Corte de ingresso — art. 23, §§ 1º e 2º da LC/RR 305/2022.
  /// Admitidos ATÉ esta data seguem a transição; a partir de 16/12/2019,
  /// a regra permanente.
  static final DateTime dataLimiteIngressoTransicao = DateTime(2019, 12, 15);

  /// Tempo mínimo exigido pela legislação do ente antes da reforma
  /// (LC/RR 194/2012, art. 115, II, red. LC/RR 260/2017).
  /// Como é ≤ 30 anos, aplica-se o **inciso I** do art. 24-G (pedágio de 17%).
  static int minimoEnteAnos(Sexo s) => s == Sexo.masculino ? 30 : 25;

  /// Efetivo serviço na PMRR/CBMRR — art. 120, II e art. 121 da LC/RR 305/2022.
  static int minimoServicoCorporacaoAnos(Sexo s) =>
      s == Sexo.masculino ? 20 : 15;

  /// Pedágio do art. 24-G, I do DL 667/1969.
  static const double pedagio = 0.17;

  /// Regra permanente — art. 24-A, I, "a".
  static const int permanenteServicoAnos = 35;
  static const int permanenteAtividadeMilitarAnos = 30;

  /// Transição — art. 24-G, parágrafo único.
  static const int transicaoAtividadeMilitarBaseAnos = 25;
  static const int acrescimoMesesPorAnoFaltante = 4;
  static const int acrescimoTetoAnos = 5;

  /// Denominador das quotas de proventos proporcionais (art. 24-A, I, "b",
  /// lido em conjunto com a alínea "a", que fixa 35 anos como integralidade).
  static const int quotasDenominador = 35;

  /// Tolerância do art. 121, §3º da LC/RR 305/2022: diferença de até 1 dia
  /// é considerada tempo concluso.
  static const int toleranciaDias = 1;
}

// ─── Entrada ─────────────────────────────────────────────────────────────────

class EntradaInatividade {
  /// Data de praça / incorporação na PMRR ou CBMRR.
  final DateTime dataIncorporacao;

  final DateTime? dataNascimento;
  final Sexo sexo;
  final PostoGraduacao? posto;

  /// Tempo de serviço militar prestado a **outras organizações militares**
  /// (Forças Armadas, outra PM/CBM), averbado, em dias.
  ///
  /// LC/RR 305/2022, art. 2º, V e LC/RR 194/2012, art. 143, §1º, "a": integra
  /// o próprio tempo de serviço militar, e não uma averbação civil. Conta,
  /// portanto, como exercício de atividade de natureza militar.
  final int diasServicoMilitarAnterior;

  /// Tempo averbado **civil** (RGPS, RPPS, iniciativa privada), em dias —
  /// LC/RR 194/2012, art. 144, I e LC/RR 305/2022, art. 2º, VI. Integra apenas
  /// o tempo de contribuição: não é atividade de natureza militar.
  final int diasAverbadosCivis;

  /// Tempo em que o militar esteve cedido ou exercendo função de natureza
  /// civil, em dias.
  ///
  /// Conta como tempo de serviço, mas não como exercício de atividade de
  /// natureza militar: a LC/RR 305/2022, art. 2º, IV define atividade militar
  /// como a "atividade continuada e inteiramente devotada às finalidades
  /// precípuas" da carreira. Por isso subtrai apenas da atividade militar.
  final int diasFuncaoCivil;

  /// Períodos que não são computados no tempo de serviço (LTIP, agregações
  /// e demais afastamentos), em dias.
  final int diasAfastamentos;

  /// Hipótese de incapacidade definitiva, quando houver. A reforma por
  /// invalidez independe de tempo de serviço.
  final HipoteseIncapacidade? incapacidade;

  /// Data em que o cálculo é aferido — normalmente `DateTime.now()`.
  final DateTime dataReferencia;

  EntradaInatividade({
    required this.dataIncorporacao,
    required this.sexo,
    this.dataNascimento,
    this.posto,
    this.diasServicoMilitarAnterior = 0,
    this.diasAverbadosCivis = 0,
    this.diasFuncaoCivil = 0,
    this.incapacidade,
    this.diasAfastamentos = 0,
    DateTime? dataReferencia,
  }) : dataReferencia = dataReferencia ?? DateTime.now();
}

// ─── Requisito individual ────────────────────────────────────────────────────

/// Um requisito legal isolado: quanto é exigido, quanto já se tem, o que falta.
class Requisito {
  final String nome;
  final String fundamento;
  final int exigidoDias;
  final int atualDias;

  /// Como o exigido se compõe, quando ele não é um número redondo da lei.
  /// Ex.: "30a + 9m 6d de pedágio" — sem isso o militar lê "30a 9m 6d" e
  /// conclui que já cumpriu por ter passado dos 30 anos.
  final String? detalheExigido;

  const Requisito({
    required this.nome,
    required this.fundamento,
    required this.exigidoDias,
    required this.atualDias,
    this.detalheExigido,
  });

  int get faltaDias => (exigidoDias - atualDias).clamp(0, 1 << 31);
  bool get cumprido => atualDias >= exigidoDias;
  double get percentual =>
      exigidoDias <= 0 ? 1.0 : (atualDias / exigidoDias).clamp(0.0, 1.0);
}

// ─── Resultado ───────────────────────────────────────────────────────────────

class ResultadoInatividade {
  final RegimeAplicavel regime;
  final EntradaInatividade entrada;

  // Situação atual
  /// Serviço prestado exclusivamente na PMRR/CBMRR. É o que os arts. 23, §1º,
  /// 120, II e 121 da LC/RR 305/2022 exigem — tempo militar de fora não entra.
  final int diasServicoCorporacao;

  final int diasServicoMilitarAnterior;
  final int diasAverbadosCivis;
  final int diasContribuicaoTotal;
  final int diasAtividadeMilitar;

  /// Snapshot em 31/12/2021 — serve apenas ao art. 120 da LC/RR 305/2022
  /// (direito adquirido), que fixa essa data no texto. Os pedágios do
  /// art. 24-G são medidos na Data Base, não aqui.
  final int diasContribuicaoEm2021;
  final int diasServicoCorporacaoEm2021;

  // Pedágio (só no regime de transição)
  final int faltanteNaDataCorteDias;
  final int pedagioDias;

  /// Faltante de **efetivo serviço na Corporação** em 31/12/2021, medido
  /// contra 20 anos (homem) ou 15 anos (mulher). É a base do acréscimo do
  /// parágrafo único do art. 24-G — não se confunde com o faltante de
  /// contribuição usado no pedágio de 17%.
  final int faltanteServicoNaDataCorteDias;

  /// Anos faltantes truncados para baixo, como manda a praxe de cálculo.
  final int anosFaltantesAcrescimo;

  final int acrescimoAtividadeMilitarMeses;

  // Requisitos da integralidade
  final Requisito requisitoTempoTotal;
  final Requisito requisitoAtividadeMilitar;

  // Proporcional
  final bool elegivelProporcional;
  final Requisito requisitoProporcional;
  final double percentualProporcional;

  // Reserva de ofício por idade-limite
  final int? idadeLimite;
  final DateTime? dataReservaOficio;

  /// Reforma por idade — art. 25, I. Proventos integrais (§2º).
  final int? idadeReforma;
  final DateTime? dataReformaPorIdade;

  /// Reserva de ofício pelas hipóteses do art. 24, II a VI: exigem 20 anos
  /// de contribuição. Sem eles o militar é licenciado ou exonerado
  /// (LC/RR 194/2012, art. 115-B, parágrafo único).
  final bool oficioOutrasLiberado;
  final int oficioOutrasFaltaDias;

  final List<String> avisos;

  const ResultadoInatividade({
    required this.regime,
    required this.entrada,
    required this.diasServicoCorporacao,
    required this.diasServicoMilitarAnterior,
    required this.diasAverbadosCivis,
    required this.diasContribuicaoTotal,
    required this.diasAtividadeMilitar,
    required this.diasContribuicaoEm2021,
    required this.diasServicoCorporacaoEm2021,
    required this.faltanteNaDataCorteDias,
    required this.pedagioDias,
    required this.faltanteServicoNaDataCorteDias,
    required this.anosFaltantesAcrescimo,
    required this.acrescimoAtividadeMilitarMeses,
    required this.requisitoTempoTotal,
    required this.requisitoAtividadeMilitar,
    required this.elegivelProporcional,
    required this.requisitoProporcional,
    required this.percentualProporcional,
    required this.idadeLimite,
    required this.dataReservaOficio,
    required this.idadeReforma,
    required this.dataReformaPorIdade,
    required this.oficioOutrasLiberado,
    required this.oficioOutrasFaltaDias,
    required this.avisos,
  });

  /// Tempo de serviço militar do art. 2º, V da LC/RR 305/2022: o serviço na
  /// Corporação somado ao prestado a outras organizações militares.
  int get diasTempoServicoMilitar =>
      diasServicoCorporacao + diasServicoMilitarAnterior;

  /// Já pode requerer a reserva remunerada com proventos integrais?
  bool get integralJaCumprido =>
      requisitoTempoTotal.cumprido && requisitoAtividadeMilitar.cumprido;

  /// Data em que o tempo total exigido será atingido.
  ///
  /// Ancorada na data de inclusão, como a célula C35 da planilha do IPER
  /// (`B10 + exigido − averbados`), e não somando o faltante a partir de hoje:
  /// o resultado não deve depender do dia em que a simulação é rodada.
  DateTime get dataPrevistaTempoTotal {
    final creditos = diasServicoMilitarAnterior + diasAverbadosCivis;
    final servicoNecessario = requisitoTempoTotal.exigidoDias - creditos;
    return entrada.dataIncorporacao
        .add(Duration(days: servicoNecessario + entrada.diasAfastamentos));
  }

  /// Data em que a atividade de natureza militar exigida será atingida —
  /// célula G35 da planilha (`B10 + exigido − averbado militar`).
  DateTime get dataPrevistaAtividadeMilitar {
    final servicoNecessario =
        requisitoAtividadeMilitar.exigidoDias - diasServicoMilitarAnterior;
    return entrada.dataIncorporacao.add(Duration(
        days: servicoNecessario +
            entrada.diasAfastamentos +
            entrada.diasFuncaoCivil));
  }

  /// Data em que a integralidade será atingida — o requisito que vencer
  /// por último é o que manda (célula C39: `=IF(C35>G35,C35,G35)`).
  DateTime get dataPrevistaIntegral {
    final a = dataPrevistaTempoTotal;
    final b = dataPrevistaAtividadeMilitar;
    return a.isAfter(b) ? a : b;
  }

  /// Dias que ainda faltam para a integralidade.
  int get diasFaltantesIntegral => dataPrevistaIntegral
      .difference(entrada.dataReferencia)
      .inDays
      .clamp(0, 1 << 31);

  /// Qual dos dois requisitos é o gargalo.
  String get requisitoLimitante {
    if (integralJaCumprido) return 'Nenhum — requisitos cumpridos';
    return dataPrevistaTempoTotal.isAfter(dataPrevistaAtividadeMilitar)
        ? requisitoTempoTotal.nome
        : requisitoAtividadeMilitar.nome;
  }

  /// A idade-limite chega antes da integralidade? Se sim, o militar será
  /// transferido de ofício com proventos proporcionais (LC/RR 305, art. 24, §2º).
  bool get idadeLimiteAntesDaIntegralidade {
    final d = dataReservaOficio;
    if (d == null || integralJaCumprido) return false;
    return d.isBefore(dataPrevistaIntegral);
  }
}

// ─── Calculadora ─────────────────────────────────────────────────────────────

class CalculadoraInatividade {
  const CalculadoraInatividade._();

  static int _anosParaDias(num anos) =>
      (anos * ParametrosLegais.diasPorAno).round();

  /// Tempo de serviço na Corporação, em dias, aferido em [data].
  /// Os afastamentos são descontados integralmente por serem fatos pretéritos.
  static int _servicoEm(EntradaInatividade e, DateTime data) {
    // A planilha do IPER/DIMIL conta `Data Base − Data de Inclusão + 1`,
    // incluindo os dois extremos: o dia da inclusão é dia de serviço.
    final bruto = data.difference(e.dataIncorporacao).inDays + 1;
    if (bruto <= 0) return 0;
    return (bruto - e.diasAfastamentos).clamp(0, 1 << 31);
  }

  static ResultadoInatividade calcular(EntradaInatividade e) {
    final avisos = <String>[];

    // ── Situação atual ────────────────────────────────────────────────────
    // Serviço na Corporação (PMRR/CBMRR), isolado: é o que os arts. 23, §1º,
    // 120, II e 121 da LC/RR 305/2022 exigem.
    final servicoHoje = _servicoEm(e, e.dataReferencia);

    // Tempo de serviço militar do art. 2º, V: soma o prestado a outras
    // organizações militares.
    final tempoServicoMilitarHoje = servicoHoje + e.diasServicoMilitarAnterior;

    // Contribuição do art. 2º, VI: acrescenta a averbação civil.
    final contribHoje = tempoServicoMilitarHoje + e.diasAverbadosCivis;

    // Atividade de natureza militar: todo o tempo de serviço militar, menos o
    // período cedido a função civil. O serviço prestado a outra organização
    // militar é, por definição, atividade militar — por isso entra somando.
    final ativMilitarHoje =
        (tempoServicoMilitarHoje - e.diasFuncaoCivil).clamp(0, 1 << 31);

    if (e.diasAverbadosCivis > 0) {
      avisos.add(
        'A averbação civil (RGPS, RPPS ou iniciativa privada) soma no seu tempo '
        'de contribuição, mas não conta como atividade de natureza militar.',
      );
    }
    if (e.diasFuncaoCivil > tempoServicoMilitarHoje) {
      avisos.add(
        'O tempo em função civil informado é maior que o seu tempo de serviço '
        'militar. Verifique os valores.',
      );
    }

    // ── Aferição na data-base 31/12/2021 ──────────────────────────────────
    final corte = ParametrosLegais.dataCorteDireitoAdquirido;
    // Só o serviço na Corporação conta para os arts. 120, II e 121.
    final servicoNoCorte = _servicoEm(e, corte);
    final contribNoCorte =
        servicoNoCorte + e.diasServicoMilitarAnterior + e.diasAverbadosCivis;

    final minEnteDias =
        _anosParaDias(ParametrosLegais.minimoEnteAnos(e.sexo));
    final minCorporacaoDias =
        _anosParaDias(ParametrosLegais.minimoServicoCorporacaoAnos(e.sexo));
    final tol = ParametrosLegais.toleranciaDias;

    // ── Enquadramento ─────────────────────────────────────────────────────
    final ingressouAntesDoCorte = !e.dataIncorporacao
        .isAfter(ParametrosLegais.dataLimiteIngressoTransicao);

    // O mínimo de 20/15 anos é medido sobre o **tempo de serviço militar**:
    // o prestado a outras Forças ou instituições militares conta igual ao da
    // Corporação. O que fica de fora é o tempo civil, que só entra na
    // contribuição. A letra dos arts. 120, II e 121 diz "efetivo serviço na
    // PMRR/CBMRR", mas o critério aplicado é o da natureza militar do tempo.
    final servicoMilitarNoCorte =
        servicoNoCorte + e.diasServicoMilitarAnterior;
    final cumpriuArt120 = contribNoCorte >= (minEnteDias - tol) &&
        servicoMilitarNoCorte >= (minCorporacaoDias - tol);

    final RegimeAplicavel regime;
    if (!ingressouAntesDoCorte) {
      regime = RegimeAplicavel.permanente;
    } else if (cumpriuArt120) {
      regime = RegimeAplicavel.direitoAdquirido;
    } else {
      regime = RegimeAplicavel.transicao;
    }

    // ── Requisitos da integralidade ───────────────────────────────────────
    int faltanteNoCorte = 0;
    int pedagioDias = 0;
    int faltanteServicoNoCorte = 0;
    int anosFaltantesAcrescimo = 0;
    int acrescimoMeses = 0;
    late Requisito reqTempo;
    late Requisito reqAtiv;

    switch (regime) {
      case RegimeAplicavel.direitoAdquirido:
        // Requisitos já implementados até 31/12/2021 — nada mais a cumprir.
        reqTempo = Requisito(
          nome: 'Tempo de contribuição',
          fundamento: 'LC/RR 305/2022, art. 120, I',
          exigidoDias: minEnteDias,
          atualDias: contribHoje,
        );
        reqAtiv = Requisito(
          nome: 'Tempo de serviço militar',
          fundamento: 'LC/RR 305/2022, art. 120, II',
          exigidoDias: minCorporacaoDias,
          atualDias: tempoServicoMilitarHoje,
        );
        avisos.add(
          'Você implementou os requisitos da integralidade até 31/12/2021. '
          'O direito adquirido pode ser exercido a qualquer tempo '
          '(DL 667/1969, art. 24-F), com os critérios de cálculo vigentes na '
          'data em que os requisitos foram atendidos.',
        );
        break;

      case RegimeAplicavel.transicao:
        // Art. 24-G, I — tempo faltante + 17%.
        // Faltante aferido na Data Base (célula E10 da planilha do IPER),
        // que é a data da simulação — não o corte de 31/12/2021.
        faltanteNoCorte = (minEnteDias - contribHoje).clamp(0, 1 << 31);
        // TRUNC, como na planilha do IPER — não arredonda para cima.
        pedagioDias = (faltanteNoCorte * ParametrosLegais.pedagio).floor();
        final exigidoTotal = minEnteDias + pedagioDias;

        // Art. 24-G, parágrafo único — 25 anos de atividade de natureza
        // militar acrescidos de 4 meses por ano faltante, teto de 5 anos.
        //
        // O "tempo mínimo exigido pela legislação do ente" aferido aqui é de
        // 20 anos (homem) e 15 anos (mulher), medido sobre o **tempo de
        // serviço militar** — serviço na Corporação mais o averbado de outra
        // organização militar. É o que a planilha do IPER/DIMIL faz na célula
        // M10 (`C14 + C20`), aferido na Data Base. A averbação civil não entra.
        //
        // Quem já conta esse mínimo não sofre acréscimo algum: o faltante
        // zera e a exigência fica nos 25 anos secos.
        faltanteServicoNoCorte =
            (minCorporacaoDias - tempoServicoMilitarHoje).clamp(0, 1 << 31);

        // Anos faltantes truncados para baixo (inteiro), não arredondados.
        anosFaltantesAcrescimo =
            faltanteServicoNoCorte ~/ ParametrosLegais.diasPorAno;

        final tetoMeses = ParametrosLegais.acrescimoTetoAnos * 12;
        acrescimoMeses = (anosFaltantesAcrescimo *
                ParametrosLegais.acrescimoMesesPorAnoFaltante)
            .clamp(0, tetoMeses);
        // Converte o acréscimo agrupando em anos de 365 dias e o resto em
        // meses de 30 — como as células F23/G23/H23 e G31 da planilha do
        // IPER. Coerente com o art. 143, §3º da LC/RR 194/2012, que manda
        // aplicar o divisor de 365 dias para obter anos.
        final exigidoAtiv =
            _anosParaDias(ParametrosLegais.transicaoAtividadeMilitarBaseAnos) +
                (acrescimoMeses ~/ 12) * ParametrosLegais.diasPorAno +
                (acrescimoMeses % 12) * ParametrosLegais.diasPorMes;

        reqTempo = Requisito(
          nome: 'Tempo total (mínimo do ente + pedágio de 17%)',
          fundamento: 'DL 667/1969, art. 24-G, I',
          exigidoDias: exigidoTotal,
          atualDias: contribHoje,
          detalheExigido: '${TempoFmt.curto(minEnteDias)} + '
              '${TempoFmt.curto(pedagioDias)} de pedágio',
        );
        reqAtiv = Requisito(
          nome: 'Atividade de natureza militar',
          fundamento: 'DL 667/1969, art. 24-G, parágrafo único',
          exigidoDias: exigidoAtiv,
          atualDias: ativMilitarHoje,
          detalheExigido: acrescimoMeses > 0
              ? '${TempoFmt.curto(_anosParaDias(ParametrosLegais.transicaoAtividadeMilitarBaseAnos))}'
                  ' + $acrescimoMeses' 'm de acréscimo'
              : null,
        );

        if (acrescimoMeses >= tetoMeses) {
          avisos.add(
            'O acréscimo de atividade militar atingiu o teto legal de 5 anos '
            '(DL 667/1969, art. 24-G, parágrafo único).',
          );
        } else if (acrescimoMeses == 0) {
          final minAnos =
              ParametrosLegais.minimoServicoCorporacaoAnos(e.sexo);
          avisos.add(
            'Você já conta os $minAnos anos de tempo de serviço militar, '
            'portanto o 2º pedágio não se aplica: a exigência de atividade de '
            'natureza militar permanece em 25 anos.',
          );
        }
        break;

      case RegimeAplicavel.permanente:
        reqTempo = Requisito(
          nome: 'Tempo de serviço',
          fundamento: 'DL 667/1969, art. 24-A, I, "a"',
          exigidoDias: _anosParaDias(ParametrosLegais.permanenteServicoAnos),
          atualDias: contribHoje,
        );
        reqAtiv = Requisito(
          nome: 'Atividade de natureza militar',
          fundamento: 'DL 667/1969, art. 24-A, I, "a"',
          exigidoDias:
              _anosParaDias(ParametrosLegais.permanenteAtividadeMilitarAnos),
          atualDias: ativMilitarHoje,
        );
        break;
    }

    // ── Proventos proporcionais ───────────────────────────────────────────
    final Requisito reqProp;
    if (regime == RegimeAplicavel.permanente) {
      // Art. 23, §2º — ingresso a partir de 16/12/2019.
      reqProp = Requisito(
        nome: 'Serviço de natureza militar (proporcional)',
        fundamento: 'LC/RR 305/2022, art. 23, §2º',
        exigidoDias: _anosParaDias(30),
        atualDias: ativMilitarHoje,
      );
    } else {
      // Art. 23, §1º / art. 121 — admitidos até 15/12/2019.
      // Também aqui vale o tempo de serviço militar, e não só o da
      // Corporação: o que qualifica é a natureza militar do tempo.
      reqProp = Requisito(
        nome: 'Tempo de serviço militar (proporcional)',
        fundamento: 'LC/RR 305/2022, art. 23, §1º c/c art. 121',
        exigidoDias: minCorporacaoDias,
        atualDias: tempoServicoMilitarHoje,
      );
    }

    // Denominador das quotas.
    //
    // No direito adquirido vale a regra antiga da LC/RR 258/2017, que a
    // planilha do IPER aplica na aba "Simulação Proventos R. Antiga":
    // provento = remuneração × dias ÷ (30 anos), ou ÷ (25 anos) se mulher.
    // Nos demais regimes, a integralidade do art. 24-A, I, "a" é de 35 anos,
    // que passa a ser o denominador.
    final quotasDenominadorDias = regime == RegimeAplicavel.direitoAdquirido
        ? minEnteDias
        : _anosParaDias(ParametrosLegais.quotasDenominador);
    final percProp = (contribHoje / quotasDenominadorDias).clamp(0.0, 1.0);

    // ── Idade-limite (reserva ex-officio) ─────────────────────────────────
    final idadeLimite = e.posto?.idadeLimite;
    DateTime? dataReservaOficio;
    if (idadeLimite != null && e.dataNascimento != null) {
      final n = e.dataNascimento!;
      dataReservaOficio = DateTime(n.year + idadeLimite, n.month, n.day);
    }
    if (e.posto != null && idadeLimite == null) {
      avisos.add(
        'A idade-limite para ${e.posto!.label} não está prevista expressamente '
        'no art. 24, I da LC/RR 305/2022 — o dispositivo enumera apenas '
        'coronel, tenente-coronel, major, capitães e subalternos, subtenente, '
        '1º sargento, cabo e soldado de 1ª classe. A idade de reforma do '
        'art. 25, I, essa sim, alcança todos os postos.',
      );
    }

    // Reforma por idade — art. 25, I. Cobre todos os postos.
    final idadeReforma = e.posto?.idadeLimiteReforma;
    DateTime? dataReformaPorIdade;
    if (idadeReforma != null && e.dataNascimento != null) {
      final n = e.dataNascimento!;
      dataReformaPorIdade = DateTime(n.year + idadeReforma, n.month, n.day);
    }

    // Portão dos 20 anos de contribuição do art. 24, II a VI.
    final oficioMin = _anosParaDias(20);
    final oficioFalta = (oficioMin - contribHoje).clamp(0, 1 << 31);

    if (e.incapacidade != null) {
      avisos.add(
        e.incapacidade!.integral
            ? 'Reforma por incapacidade definitiva com proventos integrais: '
                'não depende de tempo de serviço, e nenhum dos pedágios se '
                'aplica. As datas abaixo valem apenas se a reforma não ocorrer.'
            : 'Incapacidade sem nexo com o serviço gera proventos '
                'proporcionais ao tempo de contribuição, nunca inferiores ao '
                'salário-mínimo (LC/RR 305/2022, art. 25, §9º).',
      );
    }

    return ResultadoInatividade(
      regime: regime,
      entrada: e,
      diasServicoCorporacao: servicoHoje,
      diasServicoMilitarAnterior: e.diasServicoMilitarAnterior,
      diasAverbadosCivis: e.diasAverbadosCivis,
      diasContribuicaoTotal: contribHoje,
      diasAtividadeMilitar: ativMilitarHoje,
      diasContribuicaoEm2021: contribNoCorte,
      diasServicoCorporacaoEm2021: servicoNoCorte,
      faltanteNaDataCorteDias: faltanteNoCorte,
      pedagioDias: pedagioDias,
      faltanteServicoNaDataCorteDias: faltanteServicoNoCorte,
      anosFaltantesAcrescimo: anosFaltantesAcrescimo,
      acrescimoAtividadeMilitarMeses: acrescimoMeses,
      requisitoTempoTotal: reqTempo,
      requisitoAtividadeMilitar: reqAtiv,
      elegivelProporcional: reqProp.cumprido,
      requisitoProporcional: reqProp,
      percentualProporcional: percProp.toDouble(),
      idadeLimite: idadeLimite,
      dataReservaOficio: dataReservaOficio,
      idadeReforma: idadeReforma,
      dataReformaPorIdade: dataReformaPorIdade,
      oficioOutrasLiberado: oficioFalta == 0,
      oficioOutrasFaltaDias: oficioFalta,
      avisos: avisos,
    );
  }
}

// ─── Formatação de tempo ─────────────────────────────────────────────────────

class TempoFmt {
  TempoFmt._();

  /// "24 anos, 3 meses e 12 dias"
  static String extenso(int totalDias) {
    if (totalDias <= 0) return '0 dias';
    const a = ParametrosLegais.diasPorAno;
    const m = ParametrosLegais.diasPorMes;
    final anos = totalDias ~/ a;
    final resto = totalDias % a;
    // Um ano tem 365 dias mas 12 meses valem 360, então o resto pode chegar
    // a 12 meses sem fechar um ano. Trava em 11 e o excedente vira dias.
    final meses = (resto ~/ m).clamp(0, 11);
    final dias = resto - meses * m;

    final partes = <String>[];
    if (anos > 0) partes.add('$anos ${anos > 1 ? "anos" : "ano"}');
    if (meses > 0) partes.add('$meses ${meses > 1 ? "meses" : "mês"}');
    if (dias > 0 || partes.isEmpty) {
      partes.add('$dias ${dias > 1 ? "dias" : "dia"}');
    }
    if (partes.length > 1) {
      final ultimo = partes.removeLast();
      return '${partes.join(", ")} e $ultimo';
    }
    return partes.first;
  }

  /// "24a 3m 12d" — versão compacta para chips e tabelas.
  static String curto(int totalDias) {
    if (totalDias <= 0) return '0d';
    const a = ParametrosLegais.diasPorAno;
    const m = ParametrosLegais.diasPorMes;
    final anos = totalDias ~/ a;
    final resto = totalDias % a;
    final meses = (resto ~/ m).clamp(0, 11);
    final dias = resto - meses * m;
    final p = <String>[];
    if (anos > 0) p.add('${anos}a');
    if (meses > 0) p.add('${meses}m');
    if (dias > 0 || p.isEmpty) p.add('${dias}d');
    return p.join(' ');
  }

  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  /// "12/mar/2031"
  static String data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${_meses[d.month - 1]}/${d.year}';

  /// "mar/2031"
  static String mesAno(DateTime d) => '${_meses[d.month - 1]}/${d.year}';
}
