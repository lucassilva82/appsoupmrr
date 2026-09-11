import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/models/inatividade_model.dart';

/// Data fixa para que os cenários não mudem de resultado com o passar do tempo.
final _hoje = DateTime(2026, 8, 24);

ResultadoInatividade _calc({
  required DateTime incorporacao,
  Sexo sexo = Sexo.masculino,
  DateTime? nascimento,
  PostoGraduacao? posto,
  int averbados = 0,
  int militarAnterior = 0,
  int funcaoCivil = 0,
  HipoteseIncapacidade? incapacidade,
  int afastamentos = 0,
  DateTime? dataBase,
}) =>
    CalculadoraInatividade.calcular(EntradaInatividade(
      dataIncorporacao: incorporacao,
      sexo: sexo,
      dataNascimento: nascimento,
      posto: posto,
      diasServicoMilitarAnterior: militarAnterior,
      diasAverbadosCivis: averbados,
      diasFuncaoCivil: funcaoCivil,
      incapacidade: incapacidade,
      diasAfastamentos: afastamentos,
      dataReferencia: dataBase ?? _hoje,
    ));

void main() {
  group('Enquadramento no regime', () {
    test('ingresso a partir de 16/12/2019 cai na regra permanente', () {
      final r = _calc(incorporacao: DateTime(2021, 4, 1));
      expect(r.regime, RegimeAplicavel.permanente);
      // Art. 24-A, I, "a": 35 anos de serviço, 30 de atividade militar.
      expect(r.requisitoTempoTotal.exigidoDias, 35 * 365);
      expect(r.requisitoAtividadeMilitar.exigidoDias, 30 * 365);
      // Sem pedágio na regra permanente.
      expect(r.pedagioDias, 0);
    });

    test('quem cumpriu os requisitos do art. 120 até 31/12/2021 tem direito '
        'adquirido', () {
      // Homem com 30 anos de contribuição e 20 de PMRR em 31/12/2021.
      final r = _calc(incorporacao: DateTime(1991, 1, 1));
      expect(r.regime, RegimeAplicavel.direitoAdquirido);
      expect(r.integralJaCumprido, isTrue);
      expect(r.diasFaltantesIntegral, 0);
    });

    test('ingresso antigo sem o mínimo em 31/12/2021 cai na transição', () {
      final r = _calc(incorporacao: DateTime(2005, 3, 1));
      expect(r.regime, RegimeAplicavel.transicao);
      expect(r.pedagioDias, greaterThan(0));
    });
  });

  group('Pedágio do art. 24-G, I', () {
    test('é exatamente 17% do tempo faltante em 31/12/2021', () {
      final r = _calc(incorporacao: DateTime(2005, 3, 1));
      // TRUNC, como na planilha do IPER/DIMIL.
      final esperado = (r.faltanteNaDataCorteDias * 0.17).floor();
      expect(r.faltanteNaDataCorteDias, 30 * 365 - r.diasContribuicaoTotal);
      expect(r.pedagioDias, esperado);
      // Exigido = mínimo do ente (30 anos) + pedágio.
      expect(r.requisitoTempoTotal.exigidoDias, 30 * 365 + r.pedagioDias);
    });

    test('mulher usa o mínimo de 25 anos do ente', () {
      final r = _calc(
          incorporacao: DateTime(2010, 6, 15), sexo: Sexo.feminino);
      expect(r.requisitoTempoTotal.exigidoDias, 25 * 365 + r.pedagioDias);
    });

    test('converge para a regra permanente de 35 anos no pedágio máximo', () {
      // Quem entrou às vésperas do corte deve um pedágio quase integral.
      // 30 + 17% de 30 = 35,1 anos — a calibração legal do inciso I.
      final r = _calc(incorporacao: DateTime(2021, 12, 30));
      final anosExigidos = r.requisitoTempoTotal.exigidoDias / 365;
      expect(anosExigidos, closeTo(35.1, 0.15));
    });
  });

  group('Acréscimo de atividade militar (art. 24-G, parágrafo único)', () {
    test('mede o faltante contra 20 anos de tempo de serviço militar, '
        'aferido na Data Base', () {
      final r = _calc(incorporacao: DateTime(2015, 3, 1));
      expect(r.faltanteServicoNaDataCorteDias,
          20 * 365 - r.diasTempoServicoMilitar);
    });

    test('trunca os anos faltantes para baixo', () {
      final r = _calc(incorporacao: DateTime(2015, 3, 1));
      expect(r.anosFaltantesAcrescimo, r.faltanteServicoNaDataCorteDias ~/ 365);
      // 8 anos e pouco faltantes viram 8, não 9.
      expect(r.anosFaltantesAcrescimo, 8);
    });

    test('soma 4 meses por ano faltante sobre a base de 25 anos', () {
      final r = _calc(incorporacao: DateTime(2015, 3, 1));
      expect(r.acrescimoAtividadeMilitarMeses, 4 * r.anosFaltantesAcrescimo);
      final m = r.acrescimoAtividadeMilitarMeses;
      expect(
        r.requisitoAtividadeMilitar.exigidoDias,
        25 * 365 + (m ~/ 12) * 365 + (m % 12) * 30,
      );
    });

    test('a averbação civil não reduz o acréscimo', () {
      // O acréscimo olha o tempo de serviço militar — a averbação civil não
      // entra nessa base (planilha IPER, célula M10 usa só C14 + C20).
      final sem = _calc(incorporacao: DateTime(2015, 3, 1));
      final com = _calc(incorporacao: DateTime(2015, 3, 1), averbados: 8 * 365);
      expect(com.acrescimoAtividadeMilitarMeses,
          sem.acrescimoAtividadeMilitarMeses);
    });

    test('quem já tem 20 anos de serviço militar não sofre acréscimo', () {
      final r = _calc(incorporacao: DateTime(2000, 6, 1));
      expect(r.regime, RegimeAplicavel.transicao);
      expect(r.faltanteServicoNaDataCorteDias, 0);
      expect(r.acrescimoAtividadeMilitarMeses, 0);
      expect(r.requisitoAtividadeMilitar.exigidoDias, 25 * 365);
      expect(r.avisos.any((a) => a.contains('permanece em 25 anos')), isTrue);
    });

    test('mulher usa 15 anos como base do faltante', () {
      final r = _calc(incorporacao: DateTime(2015, 1, 1), sexo: Sexo.feminino);
      expect(r.faltanteServicoNaDataCorteDias,
          15 * 365 - r.diasTempoServicoMilitar);
    });

    test('respeita o teto de 5 anos de acréscimo', () {
      // Data Base logo após a vigência da LC 305, com pouco tempo de serviço.
      final r = _calc(
          incorporacao: DateTime(2019, 12, 1),
          dataBase: DateTime(2022, 1, 1));
      expect(r.acrescimoAtividadeMilitarMeses, 60);
      expect(r.avisos.any((a) => a.contains('teto legal de 5 anos')), isTrue);
    });
  });

  group('Composição do tempo', () {
    test('averbação civil soma na contribuição mas não na atividade militar',
        () {
      final r = _calc(
          incorporacao: DateTime(2010, 6, 15), averbados: 5 * 365);
      expect(r.diasContribuicaoTotal, r.diasServicoCorporacao + 5 * 365);
      expect(r.diasAtividadeMilitar, r.diasServicoCorporacao);
      expect(
          r.avisos.any(
              (a) => a.contains('não conta como atividade de natureza militar')),
          isTrue);
    });

    test('tempo militar de outra OM entra no tempo de serviço militar e conta '
        'como atividade militar', () {
      // LC/RR 305/2022, art. 2º, V e LC/RR 194/2012, art. 143, §1º, "a".
      final r = _calc(
          incorporacao: DateTime(2010, 6, 15), militarAnterior: 3 * 365);
      expect(r.diasTempoServicoMilitar, r.diasServicoCorporacao + 3 * 365);
      expect(r.diasAtividadeMilitar, r.diasTempoServicoMilitar);
      expect(r.diasContribuicaoTotal, r.diasTempoServicoMilitar);
    });

    test('tempo militar de outra OM não entra no serviço na Corporação, mas '
        'reduz o 2º pedágio', () {
      // Arts. 23, §1º, 120, II e 121 exigem serviço na PMRR/CBMRR — o tempo
      // de fora não conta ali. Já a base do 2º pedágio é o tempo de serviço
      // militar, que soma o averbado militar (planilha IPER, célula M10).
      final sem = _calc(incorporacao: DateTime(2010, 6, 15));
      final com = _calc(
          incorporacao: DateTime(2010, 6, 15), militarAnterior: 3 * 365);
      expect(com.diasServicoCorporacao, sem.diasServicoCorporacao);
      expect(com.diasServicoCorporacaoEm2021, sem.diasServicoCorporacaoEm2021);
      expect(com.acrescimoAtividadeMilitarMeses,
          lessThan(sem.acrescimoAtividadeMilitarMeses));
    });

    test('3 anos de Exército antecipam a integralidade', () {
      final sem = _calc(incorporacao: DateTime(2010, 6, 15));
      final com = _calc(
          incorporacao: DateTime(2010, 6, 15), militarAnterior: 3 * 365);
      expect(com.dataPrevistaIntegral.isBefore(sem.dataPrevistaIntegral),
          isTrue);
    });

    test('afastamentos são descontados do tempo de serviço', () {
      final semAfastamento = _calc(incorporacao: DateTime(2005, 3, 1));
      final comAfastamento =
          _calc(incorporacao: DateTime(2005, 3, 1), afastamentos: 365);
      expect(comAfastamento.diasServicoCorporacao,
          semAfastamento.diasServicoCorporacao - 365);
    });

    test('tempo cedido a função civil sai da atividade militar mas fica no '
        'tempo de serviço', () {
      final r =
          _calc(incorporacao: DateTime(2005, 3, 1), funcaoCivil: 4 * 365);
      expect(r.diasAtividadeMilitar, r.diasTempoServicoMilitar - 4 * 365);
      // Não mexe no tempo de serviço nem na contribuição.
      final sem = _calc(incorporacao: DateTime(2005, 3, 1));
      expect(r.diasServicoCorporacao, sem.diasServicoCorporacao);
      expect(r.diasContribuicaoTotal, sem.diasContribuicaoTotal);
    });

    test('cessão civil longa torna a atividade militar o gargalo', () {
      final r =
          _calc(incorporacao: DateTime(2005, 3, 1), funcaoCivil: 12 * 365);
      expect(r.requisitoLimitante, contains('natureza militar'));
      expect(r.dataPrevistaIntegral, r.dataPrevistaAtividadeMilitar);
    });

    test('sem cessão, atividade militar é o tempo de serviço militar inteiro',
        () {
      final r = _calc(
          incorporacao: DateTime(2010, 6, 15), militarAnterior: 3 * 365);
      expect(r.diasAtividadeMilitar, r.diasTempoServicoMilitar);
    });
  });

  group('Proventos proporcionais', () {
    test('admitido até 15/12/2019 precisa de 20 anos de PMRR (homem)', () {
      final r = _calc(incorporacao: DateTime(2005, 3, 1));
      expect(r.requisitoProporcional.exigidoDias, 20 * 365);
      expect(r.elegivelProporcional, isTrue);
    });

    test('mulher precisa de 15 anos de PMRR', () {
      final r =
          _calc(incorporacao: DateTime(2010, 6, 15), sexo: Sexo.feminino);
      expect(r.requisitoProporcional.exigidoDias, 15 * 365);
    });

    test('ingresso a partir de 16/12/2019 precisa de 30 anos de natureza '
        'militar', () {
      final r = _calc(incorporacao: DateTime(2021, 4, 1));
      expect(r.requisitoProporcional.exigidoDias, 30 * 365);
      expect(r.elegivelProporcional, isFalse);
    });

    test('as quotas usam 35 avos e nunca passam de 100%', () {
      final r = _calc(incorporacao: DateTime(2005, 3, 1));
      expect(r.percentualProporcional,
          closeTo(r.diasContribuicaoTotal / 365 / 35, 0.001));
      final veterano = _calc(incorporacao: DateTime(1980, 1, 1));
      expect(veterano.percentualProporcional, 1.0);
    });
  });

  group('Idade-limite (LC/RR 305/2022, art. 24, I)', () {
    test('aplica a idade da alínea correspondente ao posto', () {
      final r = _calc(
        incorporacao: DateTime(2005, 3, 1),
        posto: PostoGraduacao.primeiroSargento,
        nascimento: DateTime(1984, 5, 10),
      );
      expect(r.idadeLimite, 57);
      expect(r.dataReservaOficio, DateTime(2041, 5, 10));
    });

    test('sinaliza quando a idade-limite chega antes da integralidade', () {
      // Soldado de 1ª classe: limite de 50 anos, ingresso tardio.
      final r = _calc(
        incorporacao: DateTime(2021, 4, 1),
        posto: PostoGraduacao.soldado1Classe,
        nascimento: DateTime(1999, 7, 12),
      );
      expect(r.idadeLimiteAntesDaIntegralidade, isTrue);
    });

    test('graduações fora das alíneas "a" a "h" ficam sem idade-limite', () {
      // Lacuna real do art. 24, I — 2º/3º sargento e soldado de 2ª classe.
      for (final p in [
        PostoGraduacao.segundoSargento,
        PostoGraduacao.terceiroSargento,
        PostoGraduacao.soldado2Classe,
      ]) {
        expect(p.idadeLimite, isNull, reason: p.label);
      }
      final r = _calc(
          incorporacao: DateTime(2005, 3, 1),
          posto: PostoGraduacao.terceiroSargento);
      expect(r.avisos.any((a) => a.contains('não está prevista')), isTrue);
    });
  });

  group('Reforma (LC/RR 305/2022, arts. 25 e 26)', () {
    test('incapacidade com nexo com o serviço dá proventos integrais', () {
      final r = _calc(
          incorporacao: DateTime(2020, 1, 10),
          incapacidade: HipoteseIncapacidade.nexoComServico);
      expect(r.entrada.incapacidade!.integral, isTrue);
      // Não depende de tempo: mesmo com 6 anos de serviço.
      expect(r.diasTempoServicoMilitar, lessThan(10 * 365));
      expect(r.avisos.any((a) => a.contains('não depende de tempo de serviço')),
          isTrue);
    });

    test('doença grave do rol do art. 26, IV também é integral', () {
      expect(HipoteseIncapacidade.doencaGrave.integral, isTrue);
    });

    test('incapacidade sem nexo dá proporcionais', () {
      final r = _calc(
          incorporacao: DateTime(2010, 1, 10),
          incapacidade: HipoteseIncapacidade.semNexo);
      expect(r.entrada.incapacidade!.integral, isFalse);
      expect(r.avisos.any((a) => a.contains('salário-mínimo')), isTrue);
    });

    test('idade de reforma cobre todos os postos, inclusive os que o '
        'art. 24, I esqueceu', () {
      for (final p in PostoGraduacao.values) {
        expect(p.idadeLimiteReforma, anyOf(68, 72), reason: p.label);
      }
      expect(PostoGraduacao.terceiroSargento.idadeLimite, isNull);
      expect(PostoGraduacao.terceiroSargento.idadeLimiteReforma, 68);
      expect(PostoGraduacao.coronel.idadeLimiteReforma, 72);
      expect(PostoGraduacao.capitao.idadeLimiteReforma, 68);
    });

    test('data de reforma por idade sai do nascimento', () {
      final r = _calc(
          incorporacao: DateTime(2005, 3, 1),
          nascimento: DateTime(1980, 4, 12),
          posto: PostoGraduacao.major);
      expect(r.idadeReforma, 72);
      expect(r.dataReformaPorIdade, DateTime(2052, 4, 12));
    });
  });

  group('Outras hipóteses de reserva de ofício (art. 24, II a VI)', () {
    test('exigem 20 anos de contribuição', () {
      final novo = _calc(incorporacao: DateTime(2015, 1, 1));
      expect(novo.oficioOutrasLiberado, isFalse);
      expect(novo.oficioOutrasFaltaDias, greaterThan(0));

      final antigo = _calc(incorporacao: DateTime(2000, 1, 1));
      expect(antigo.oficioOutrasLiberado, isTrue);
      expect(antigo.oficioOutrasFaltaDias, 0);
    });

    test('o rol tem as cinco hipóteses dos incisos II a VI', () {
      expect(hipotesesReservaOficio.length, 5);
      expect(hipotesesReservaOficio.map((h) => h[0]).toList(),
          ['II', 'III', 'IV', 'V', 'VI']);
    });
  });

  group('Conferência contra a planilha do IPER/DIMIL', () {
    // Caso gravado na planilha "1 - Simulação Inatividade Militares.xlsx":
    // inclusão 19/02/2001 (B10), Data Base 27/08/2026 (E10), averbado militar
    // 1825 dias (C20), sem averbação civil, homem. Valores gravados na
    // planilha: C14=9321, J10=0, G21=0, C31=10950, C39=13/02/2026.
    final r = CalculadoraInatividade.calcular(EntradaInatividade(
      dataIncorporacao: DateTime(2001, 2, 19),
      sexo: Sexo.masculino,
      diasServicoMilitarAnterior: 1825,
      dataReferencia: DateTime(2026, 8, 27),
    ));

    test('serviço na instituição bate com a célula C14', () {
      // C14 = E10 − B10 + 1 = 9321 dias em 27/08/2026.
      expect(r.diasServicoCorporacao, 9321);
    });

    test('1º pedágio bate com a célula J10', () {
      // Na Data Base ele já supera os 30 anos de contribuição: pedágio zero.
      expect(r.pedagioDias, 0);
    });

    test('2º pedágio zerado, como na célula G21', () {
      expect(r.acrescimoAtividadeMilitarMeses, 0);
      expect(r.requisitoAtividadeMilitar.exigidoDias, 25 * 365);
    });

    test('exigido de contribuição bate com a célula C31', () {
      expect(r.requisitoTempoTotal.exigidoDias, 10950);
    });

    test('data da reserva integral bate com a célula C39', () {
      expect(r.dataPrevistaIntegral, DateTime(2026, 2, 13));
    });
  });

  group('Formatação de tempo', () {
    test('converte dias em anos/meses/dias no padrão 365/30', () {
      expect(TempoFmt.extenso(365), '1 ano');
      expect(TempoFmt.extenso(395), '1 ano e 1 mês');
      expect(TempoFmt.extenso(0), '0 dias');
      expect(TempoFmt.curto(365 * 2 + 30 * 3 + 5), '2a 3m 5d');
    });

    test('nunca exibe 12 meses — 12×30 não fecha um ano de 365', () {
      // 25 anos + 12 meses de acréscimo = 9485 dias.
      expect(TempoFmt.extenso(25 * 365 + 12 * 30), '25 anos, 11 meses e 30 dias');
      expect(TempoFmt.extenso(364), '11 meses e 34 dias');
      expect(TempoFmt.curto(365 * 7 + 364), '7a 11m 34d');
    });
  });
}
