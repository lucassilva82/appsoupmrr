import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/design/arte_cartao.dart';
import '../models/auth_model.dart';
import '../models/inatividade_model.dart';
import '../utils/app_theme.dart';
import '../utils/store.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/cartao_painel.dart';
import '../widgets/vidro.dart';
import '../widgets/aviso_rapido.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../core/design/folha_arte.dart';

class CalculoInatividadePage extends StatefulWidget {
  const CalculoInatividadePage({Key? key}) : super(key: key);

  @override
  State<CalculoInatividadePage> createState() => _CalculoInatividadePageState();
}

class _CalculoInatividadePageState extends State<CalculoInatividadePage> {
  static const _storeKey = 'calculo_inatividade_dados_v1';

  // ── Dados do formulário ────────────────────────────────────────────────
  DateTime? _dataIncorporacao;
  DateTime? _dataNascimento;

  Sexo _sexo = Sexo.masculino;
  PostoGraduacao? _posto;
  int _diasServicoMilitarAnterior = 0;
  int _diasAverbadosCivis = 0;
  int _diasFuncaoCivil = 0;
  HipoteseIncapacidade? _incapacidade;
  int _diasAfastamentos = 0;

  bool _carregando = true;

  /// Fluxo da tela: o militar preenche, aciona Calcular, acompanha as etapas
  /// e só então vê o resultado.
  _Fase _fase = _Fase.formulario;
  int _etapa = 0;
  Timer? _timer;
  ResultadoInatividade? _resultado;
  int? _iperDoSistema; // valor original vindo do IPER, para o botão "restaurar"
  DateTime? _incorporacaoDoSistema;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarDados());
  }

  // ── Carga inicial: sistema + preferências salvas ───────────────────────
  Future<void> _carregarDados() async {
    final auth = Provider.of<Auth>(context, listen: false);

    _incorporacaoDoSistema = _parseData(auth.dataIncorporacao);
    _dataIncorporacao = _incorporacaoDoSistema;

    final iper = await _buscarDiasAgregadosIper(auth.matricula ?? '');
    _iperDoSistema = iper;
    // O IPER devolve a averbação total sem distinguir origem; entra como civil
    // e o militar move para o campo militar a parte que for de OM.
    _diasAverbadosCivis = iper;

    // Preferências salvas sobrescrevem o que veio do sistema — o militar
    // pode ter corrigido dados desatualizados.
    final salvo = await Store.getMap(_storeKey);
    if (salvo.isNotEmpty) {
      _dataIncorporacao =
          _parseIso(salvo['dataIncorporacao']) ?? _dataIncorporacao;
      _dataNascimento = _parseIso(salvo['dataNascimento']);
      _sexo = salvo['sexo'] == 'feminino' ? Sexo.feminino : Sexo.masculino;
      _posto = _postoPorNome(salvo['posto']);
      if (salvo['diasAverbadosCivis'] is int) {
        _diasAverbadosCivis = salvo['diasAverbadosCivis'] as int;
      }
      _diasServicoMilitarAnterior =
          (salvo['diasServicoMilitarAnterior'] as int?) ?? 0;
      _diasFuncaoCivil = (salvo['diasFuncaoCivil'] as int?) ?? 0;
      final inc = salvo['incapacidade'];
      if (inc is String) {
        for (final h in HipoteseIncapacidade.values) {
          if (h.name == inc) _incapacidade = h;
        }
      }
      _diasAfastamentos = (salvo['diasAfastamentos'] as int?) ?? 0;
    }

    // Se havia um cálculo salvo, a aba reabre direto nele — sem repetir a
    // apuração, que o militar já acompanhou.
    final tinhaResultado =
        salvo['calculado'] == true && _dataIncorporacao != null;

    if (!mounted) return;
    setState(() {
      _carregando = false;
      if (tinhaResultado) {
        _resultado = _montarResultado();
        _fase = _Fase.pronto;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Roda as etapas em sequência e revela o resultado ao final.
  ///
  /// O cálculo em si é instantâneo — a cadência existe para o militar
  /// acompanhar o que está sendo apurado, já que cada etapa corresponde a
  /// uma parte real da conta.
  void _calcular() {
    if (_dataIncorporacao == null) {
      avisoAtencao(context, 'Informe a data de incorporação',
          texto: 'Ela é necessária para calcular a inatividade.');
      return;
    }

    final resultado = _montarResultado();

    _timer?.cancel();
    setState(() {
      _fase = _Fase.calculando;
      _etapa = 0;
      _resultado = resultado;
    });

    var i = 0;
    void proxima() {
      if (!mounted) return;
      if (i >= _etapas.length) {
        setState(() => _fase = _Fase.pronto);
        return;
      }
      setState(() => _etapa = i);
      final d = _etapas[i].duracao;
      i++;
      _timer = Timer(d, proxima);
    }

    proxima();
  }

  ResultadoInatividade _montarResultado() =>
      CalculadoraInatividade.calcular(EntradaInatividade(
        dataIncorporacao: _dataIncorporacao!,
        dataNascimento: _dataNascimento,
        sexo: _sexo,
        posto: _posto,
        diasServicoMilitarAnterior: _diasServicoMilitarAnterior,
        diasAverbadosCivis: _diasAverbadosCivis,
        diasFuncaoCivil: _diasFuncaoCivil,
        incapacidade: _incapacidade,
        // Data Base sempre o dia de hoje, como a célula E10 da planilha do
        // IPER, que o operador preenche com a data em que simula.
        dataReferencia: DateTime.now(),
        diasAfastamentos: _diasAfastamentos,
      ));

  /// Descarta o cálculo e todos os dados, voltando ao formulário em branco.
  Future<void> _novoCalculo() async {
    // Ação destrutiva: confirmação no desenho do app, em vermelho (DESIGN §5).
    final ok = await dialogoConfirmacao(
      context,
      titulo: 'Novo cálculo',
      mensagem: 'Os dados informados e o resultado atual serão apagados. '
          'Você preencherá tudo de novo.',
      textoConfirmar: 'Apagar e recomeçar',
      icone: Icons.restart_alt_rounded,
      cor: Theme.of(context).colorScheme.error,
    );
    if (!ok || !mounted) return;

    _timer?.cancel();
    await Store.saveMap(_storeKey, {});
    if (!mounted) return;
    setState(() {
      _fase = _Fase.formulario;
      _resultado = null;
      _dataIncorporacao = _incorporacaoDoSistema;
      _dataNascimento = null;
      _sexo = Sexo.masculino;
      _posto = null;
      _diasServicoMilitarAnterior = 0;
      _diasAverbadosCivis = _iperDoSistema ?? 0;
      _diasFuncaoCivil = 0;
      _diasAfastamentos = 0;
      _incapacidade = null;
    });
  }

  Future<void> _salvar() async {
    await Store.saveMap(_storeKey, {
      'dataIncorporacao': _dataIncorporacao?.toIso8601String(),
      'dataNascimento': _dataNascimento?.toIso8601String(),
      'sexo': _sexo == Sexo.feminino ? 'feminino' : 'masculino',
      'posto': _posto?.name,
      'diasServicoMilitarAnterior': _diasServicoMilitarAnterior,
      'diasAverbadosCivis': _diasAverbadosCivis,
      'diasFuncaoCivil': _diasFuncaoCivil,
      'incapacidade': _incapacidade?.name,
      // A aba reabre no resultado; o formulário só volta em Novo cálculo.
      'calculado': _fase == _Fase.pronto,
      'diasAfastamentos': _diasAfastamentos,
    });
  }

  void _atualizar(VoidCallback fn) {
    setState(fn);
    _salvar();
  }

  Future<void> _restaurarDoSistema() async {
    _atualizar(() {
      _dataIncorporacao = _incorporacaoDoSistema;
      _diasServicoMilitarAnterior = 0;
      _diasAverbadosCivis = _iperDoSistema ?? 0;
      _diasFuncaoCivil = 0;
      _diasAfastamentos = 0;
      _incapacidade = null;
    });
    if (!mounted) return;
    avisoInfo(context, 'Dados restaurados',
        texto: 'Os valores voltaram aos do SIGRH e do IPER.');
  }

  // ── Helpers de dados ───────────────────────────────────────────────────
  DateTime? _parseData(String? s) {
    if (s == null || s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseIso(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  PostoGraduacao? _postoPorNome(dynamic nome) {
    if (nome is! String) return null;
    for (final p in PostoGraduacao.values) {
      if (p.name == nome) return p;
    }
    return null;
  }

  Future<int> _buscarDiasAgregadosIper(String matricula) async {
    if (matricula.isEmpty) return 0;
    final uri = Uri.parse(
      'https://pmrr.online/flutter/sigrh/listar_policial_iper.php?matricula=$matricula',
    );
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return 0;
      final json = jsonDecode(resp.body);
      if (json['code'] != 1) return 0;
      return (json['result'] as List<dynamic>).fold<int>(0, (p, e) {
        final raw = e['poip_total_dias'];
        if (raw is int) return p + raw;
        if (raw is String) return p + (int.tryParse(raw) ?? 0);
        if (raw is num) return p + raw.toInt();
        return p;
      });
    } catch (_) {
      return 0;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_carregando) {
      return FundoSuave(child: Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: const FundoBarraVidro(),
            title: const Text('Cálculo de Inatividade')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      ));
    }

    final resultado = _fase == _Fase.pronto ? _resultado : null;
    final noResultado = resultado != null;

    return FundoSuave(child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const FundoBarraVidro(),
        title: Text(noResultado ? 'Seu cálculo' : 'Cálculo de Inatividade'),
        actions: [
          if (noResultado)
            IconButton(
              tooltip: 'Novo cálculo',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _novoCalculo,
            ),
          IconButton(
            tooltip: 'Base legal',
            icon: const Icon(Icons.gavel_rounded),
            onPressed: _mostrarBaseLegal,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
                    .animate(anim),
            child: child,
          ),
        ),
        child: _fase == _Fase.calculando
            ? _TelaEtapas(key: const ValueKey('etapas'), etapaAtual: _etapa)
            : noResultado
                // ── Tela de resultado: o formulário não aparece aqui ──
                ? ListView(
                    key: const ValueKey('resultado'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      TopoArte(
                        arte: Arte.de('ts'),
                        icone: Icons.hourglass_top_rounded,
                        titulo: 'Seu cálculo',
                        subtitulo: 'Estimativa a partir dos dados que você '
                            'conferiu: regime, prazos e requisitos.',
                        margem: const EdgeInsets.only(bottom: 16),
                      ),
                      _CardRegime(resultado: resultado),
                      const SizedBox(height: 12),
                      _CardPrevisao(resultado: resultado),
                      const SizedBox(height: 12),
                      _CardRequisito(
                        requisito: resultado.requisitoTempoTotal,
                        icone: Icons.timelapse_rounded,
                      ),
                      const SizedBox(height: 12),
                      _CardRequisito(
                        requisito: resultado.requisitoAtividadeMilitar,
                        icone: Icons.military_tech_rounded,
                      ),
                      if (resultado.regime == RegimeAplicavel.transicao) ...[
                        const SizedBox(height: 12),
                        _CardPedagio(resultado: resultado),
                      ],
                      const SizedBox(height: 12),
                      _CardProporcional(resultado: resultado),
                      const SizedBox(height: 12),
                      _CardReforma(resultado: resultado),
                      const SizedBox(height: 12),
                      _CardOficioOutras(resultado: resultado),
                      if (resultado.dataReservaOficio != null ||
                          resultado.entrada.posto != null) ...[
                        const SizedBox(height: 12),
                        _CardIdadeLimite(resultado: resultado),
                      ],
                      const SizedBox(height: 12),
                      _CardMemorial(resultado: resultado),
                      if (resultado.avisos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _CardAvisos(avisos: resultado.avisos),
                      ],
                      const SizedBox(height: 16),
                      _disclaimer(theme),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _novoCalculo,
                        icon: const Icon(Icons.restart_alt_rounded,
                            size: AppIconSize.sm),
                        label: const Text('Novo cálculo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Este cálculo fica guardado nesta aba. '
                        'Novo cálculo apaga os dados e recomeça.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor, fontSize: 11.5),
                      ),
                    ],
                  )
                // ── Tela de formulário ──
                : ListView(
                    key: const ValueKey('form'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      TopoArte(
                        arte: Arte.de('ts'),
                        icone: Icons.hourglass_top_rounded,
                        titulo: 'Tempo de serviço e inatividade',
                        subtitulo: 'Confira seus dados e os tempos averbados '
                            'para estimar quando você pode ir para a reserva.',
                        margem: const EdgeInsets.only(bottom: 16),
                      ),
                      _cardDados(theme),
                      const SizedBox(height: 10),
                      _cardTempos(theme),
                      const SizedBox(height: 16),
                      _botaoCalcular(theme),
                    ],
                  ),
      ),
    ));
  }

  Widget _botaoCalcular(ThemeData theme) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _calcular,
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('Calcular'),
          // Cor, forma e texto vêm do filledButtonTheme (DESIGN §5).
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Confira os dados acima antes de calcular.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
    ]);
  }

  // ── Card de dados (editável) ───────────────────────────────────────────
  Widget _cardDados(ThemeData theme) {
    return _Card(
      titulo: 'Identificação',
      icone: Icons.badge_outlined,
      arte: Arte.de('ts'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 0),
        Text(
          'Puxados do sistema. Confira e corrija — o cálculo usa '
          'exatamente estes valores.',
          style: TextStyle(fontSize: 12.5, color: TomCartao.medio(context)),
        ),
        const SizedBox(height: 14),
        _campoData(
          theme,
          rotulo: 'Data de incorporação / praça',
          valor: _dataIncorporacao,
          doSistema: _incorporacaoDoSistema != null &&
              _dataIncorporacao == _incorporacaoDoSistema,
          primeiro: DateTime(1960),
          onChanged: (d) => _atualizar(() => _dataIncorporacao = d),
        ),
        const SizedBox(height: 10),
        _campoData(
          theme,
          rotulo: 'Data de nascimento',
          valor: _dataNascimento,
          doSistema: false,
          primeiro: DateTime(1940),
          onChanged: (d) => _atualizar(() => _dataNascimento = d),
          ajuda: 'Define a idade-limite para reserva de ofício.',
        ),
        const SizedBox(height: 14),
        Text('Sexo',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SegmentedButton<Sexo>(
          segments: const [
            ButtonSegment(value: Sexo.masculino, label: Text('Masculino')),
            ButtonSegment(value: Sexo.feminino, label: Text('Feminino')),
          ],
          selected: {_sexo},
          onSelectionChanged: (s) => _atualizar(() => _sexo = s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
                theme.textTheme.labelMedium ?? const TextStyle()),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Define o tempo mínimo do ente: 30 anos (homem), 25 (mulher).',
          style: TextStyle(fontSize: 12, color: TomCartao.medio(context)),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<PostoGraduacao>(
          value: _posto,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Posto / graduação atual',
            isDense: true,
          ),
          items: PostoGraduacao.values
              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
              .toList(),
          onChanged: (p) => _atualizar(() => _posto = p),
        ),
      ]),
    );
  }

  /// Tempos que entram ou saem da conta. Separado da identificação porque
  /// são coisas de naturezas diferentes: ali é quem o militar é, aqui é o
  /// que ele traz de fora — e num card só viravam uma lista sem fim.
  Widget _cardTempos(ThemeData theme) {
    return _Card(
      titulo: 'Tempos averbados',
      icone: Icons.more_time_rounded,
      arte: Arte.de('ts'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _campoDuracao(
          theme,
          rotulo: 'Tempo militar em outra organização',
          ajuda: 'Forças Armadas, outra PM ou CBM. Conta como atividade '
              'militar.',
          dias: _diasServicoMilitarAnterior,
          onChanged: (d) =>
              _atualizar(() => _diasServicoMilitarAnterior = d ?? 0),
        ),
        const SizedBox(height: 16),
        _campoDuracao(
          theme,
          rotulo: 'Tempo averbado civil',
          ajuda: 'RGPS, outro RPPS ou iniciativa privada. Soma só na '
              'contribuição.',
          dias: _diasAverbadosCivis,
          doSistema: _iperDoSistema != null &&
              _diasAverbadosCivis == _iperDoSistema &&
              _iperDoSistema! > 0,
          onChanged: (d) => _atualizar(() => _diasAverbadosCivis = d ?? 0),
        ),
        if (_iperDoSistema != null && _iperDoSistema! > 0) ...[
          const SizedBox(height: 6),
          CartaoVidro(
            raio: 12,
            tingimento: _ambar(context),
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(
                child: Icon(Icons.call_split_rounded,
                    size: AppIconSize.xs, color: _ambar(context)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O IPER informa a averbação sem separar a origem. Se '
                  'parte dela for tempo de Forças Armadas ou de outra '
                  'PM/CBM, mova essa parte para o campo acima — lá ela '
                  'conta como atividade militar, aqui não.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11, height: 1.35),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        _campoDuracao(
          theme,
          rotulo: 'Tempo cedido a função civil',
          ajuda: 'Conta como tempo de serviço, mas sai da atividade '
              'militar. Zerado se nunca foi cedido.',
          dias: _diasFuncaoCivil,
          onChanged: (d) => _atualizar(() => _diasFuncaoCivil = d ?? 0),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<HipoteseIncapacidade?>(
          value: _incapacidade,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Incapacidade definitiva',
            helperText: 'Reforma por invalidez independe de tempo de '
                'serviço. Deixe vazio se não for o caso.',
            helperMaxLines: 3,
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('— não se aplica —')),
            ...HipoteseIncapacidade.values
                .map((h) => DropdownMenuItem(value: h, child: Text(h.label))),
          ],
          onChanged: (h) => _atualizar(() => _incapacidade = h),
        ),
        const SizedBox(height: 20),
        _campoDuracao(
          theme,
          rotulo: 'Afastamentos não computados',
          ajuda: 'LTIP, agregações e outros períodos que não contam como '
              'tempo de serviço.',
          dias: _diasAfastamentos,
          onChanged: (d) => _atualizar(() => _diasAfastamentos = d ?? 0),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _restaurarDoSistema,
            icon: const Icon(Icons.restore_rounded, size: AppIconSize.xs),
            label: const Text('Restaurar do sistema'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
      ]),
    );
  }

  Widget _campoData(
    ThemeData theme, {
    required String rotulo,
    required DateTime? valor,
    required bool doSistema,
    required DateTime primeiro,
    required ValueChanged<DateTime> onChanged,
    String? ajuda,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(rotulo,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        if (doSistema) _TagSistema(),
      ]),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: valor ?? DateTime(1995),
            firstDate: primeiro,
            lastDate: DateTime.now(),
            locale: const Locale('pt', 'BR'),
            helpText: rotulo,
          );
          if (d != null) onChanged(d);
        },
        icon: const Icon(Icons.calendar_today_rounded, size: AppIconSize.xs),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(valor == null ? 'Selecionar…' : TempoFmt.data(valor)),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(42),
          alignment: Alignment.centerLeft,
        ),
      ),
      if (ajuda != null) ...[
        const SizedBox(height: 4),
        Text(ajuda,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.hintColor, fontSize: 11)),
      ],
    ]);
  }

  /// Entrada de duração em anos / meses / dias.
  Widget _campoDuracao(
    ThemeData theme, {
    required String rotulo,
    required String ajuda,
    required int? dias,
    required ValueChanged<int?> onChanged,
    bool doSistema = false,
    bool opcional = false,
  }) {
    const a = ParametrosLegais.diasPorAno;
    const m = ParametrosLegais.diasPorMes;
    final v = dias ?? 0;
    final anos = v ~/ a;
    final meses = (v % a) ~/ m;
    final ds = (v % a) % m;

    void emitir(int novoA, int novoM, int novoD) {
      final total = novoA * a + novoM * m + novoD;
      onChanged(opcional && total == 0 ? null : total);
    }

    Widget caixa(String unidade, int? valor, int limite, ValueChanged<int> ao) {
      return Expanded(
        child: Column(
          children: [
            _MiniNumero(
              key: ValueKey('$rotulo-$unidade-$valor'),
              valorInicial: valor,
              max: limite,
              onChanged: ao,
            ),
            const SizedBox(height: 5),
            Text(
              unidade,
              style: TextStyle(fontSize: 11.5, color: TomCartao.medio(context)),
            ),
          ],
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(rotulo,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        if (doSistema) _TagSistema(),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        caixa('anos', dias == null ? null : anos, 99,
            (x) => emitir(x, meses, ds)),
        const SizedBox(width: 10),
        caixa('meses', dias == null ? null : meses, 11,
            (x) => emitir(anos, x, ds)),
        const SizedBox(width: 10),
        caixa('dias', dias == null ? null : ds, 29,
            (x) => emitir(anos, meses, x)),
      ]),
      const SizedBox(height: 8),
      // A ajuda ficou curta de propósito. A citação legal de cada campo foi
      // para a folha "Base legal" da barra superior: três linhas de
      // "LC/RR 305/2022, art. 2º, V" debaixo de cada campo era o que mais
      // dava peso de formulário web a esta tela.
      Text(
        dias == null || dias == 0
            ? ajuda
            : '$ajuda  •  total: ${TempoFmt.extenso(dias)}',
        style: TextStyle(fontSize: 12, color: TomCartao.medio(context)),
      ),
    ]);
  }

  void _mostrarBaseLegal() {
    // Folha no padrão 2.2 (FolhaArte): faixa com a arte do tempo de serviço,
    // alça, ícone e título; a lista embaixo rola com a folha arrastável.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (ctx) {
        final t = Theme.of(ctx);
        Widget item(String titulo, String corpo) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: t.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: t.colorScheme.primary)),
                  const SizedBox(height: 3),
                  Text(corpo,
                      style: t.textTheme.bodySmall?.copyWith(height: 1.45)),
                ],
              ),
            );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, controller) => Material(
            color: t.brightness == Brightness.dark
                ? const Color(0xFF10161F)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CabecalhoFolhaArte(
              arte: Arte.de('ts'),
              icone: Icons.gavel_rounded,
              titulo: 'Base legal',
              subtitulo: 'As normas que este cálculo aplica.',
            ),
            Expanded(
            child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 28 + MediaQuery.of(ctx).padding.bottom),
            children: [
              item(
                'DL 667/1969, art. 24-A, I, "a" — regra permanente',
                'Integral desde que cumprido o tempo mínimo de 35 anos de '
                    'serviço, dos quais no mínimo 30 anos de exercício de '
                    'atividade de natureza militar.',
              ),
              item(
                'DL 667/1969, art. 24-A, I, "b" — proporcional',
                'Proporcional, com base em tantas quotas de remuneração do '
                    'posto ou da graduação quantos forem os anos de serviço, se '
                    'transferido para a inatividade sem atingir o tempo mínimo.',
              ),
              item(
                'DL 667/1969, art. 24-F — direito adquirido',
                'Assegurado o direito adquirido a quem cumpriu os requisitos '
                    'da lei do ente federativo, observados os critérios de '
                    'concessão e de cálculo em vigor na data de atendimento.',
              ),
              item(
                'DL 667/1969, art. 24-G, I — pedágio',
                'Se o tempo mínimo exigido pela legislação do ente for de 30 '
                    'anos ou menos, cumprir o tempo de serviço faltante, '
                    'acrescido de 17%. Em Roraima o mínimo era 30 anos (homem) e '
                    '25 anos (mulher), logo aplica-se o pedágio.',
              ),
              item(
                'DL 667/1969, art. 24-G, parágrafo único',
                'Além do pedágio, o militar deve contar no mínimo 25 anos de '
                    'exercício de atividade de natureza militar, acrescidos de 4 '
                    'meses a cada ano faltante para atingir o tempo mínimo do '
                    'ente, limitado a 5 anos de acréscimo.',
              ),
              item(
                'LC/RR 305/2022, art. 23 — reserva a pedido',
                'Proventos integrais desde que implementadas as regras para a '
                    'inatividade previstas em norma geral da União. §1º: '
                    'admitidos até 15/12/2019 podem pedir proporcional com 20 '
                    'anos de efetivo serviço (homem) ou 15 anos (mulher). §2º: '
                    'ingressos a partir de 16/12/2019, 30 anos de natureza militar.',
              ),
              item(
                'LC/RR 305/2022, art. 24, I — idade-limite',
                'Coronel 67, tenente-coronel 65, major 64, capitães e oficiais '
                    'subalternos 63, subtenente 63, 1º sargento 57, cabo 54 e '
                    'soldado de 1ª classe 50 anos.',
              ),
              item(
                'LC/RR 305/2022, arts. 120 e 121 — disposições transitórias',
                'Integral a quem implementou, cumulativamente até 31/12/2021, '
                    '30 anos de contribuição (homem) ou 25 (mulher) e 20 anos de '
                    'efetivo serviço na PMRR/CBMRR (homem) ou 15 (mulher). É '
                    'também a data-base adotada neste cálculo.',
              ),
              item(
                'LC/RR 308/2022',
                'Alterou a LC/RR 194/2012 (Estatuto), remetendo os requisitos '
                    'de reserva remunerada à Lei do Sistema de Proteção Social '
                    'dos Militares de Roraima.',
              ),
            ],
          ),
            ),
            ]),
          ),
        );
      },
    );
  }

  Widget _disclaimer(ThemeData theme) => CartaoVidro(
        raio: 14,
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(
            child: Icon(Icons.info_outline_rounded,
                size: AppIconSize.xs, color: theme.hintColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estimativa de caráter informativo, calculada a partir dos dados '
              'informados nesta tela. Não substitui a certidão de tempo de '
              'serviço nem a análise oficial do IPER/SPSMRR, únicos documentos '
              'válidos para instruir o requerimento.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, height: 1.4, fontSize: 11),
            ),
          ),
        ]),
      );
}

/// Fases da tela: preencher, apurar, ver o resultado.
enum _Fase { formulario, calculando, pronto }

/// Uma etapa da apuração. Cada uma corresponde a um trecho real do cálculo —
/// os rótulos descrevem o que o motor de fato faz, na ordem em que faz.
class _Etapa {
  final String titulo;
  final String detalhe;
  final IconData icone;
  final Duration duracao;
  const _Etapa(this.titulo, this.detalhe, this.icone, this.duracao);
}

const _etapas = <_Etapa>[
  _Etapa(
    'Conferindo seus dados',
    'Data de praça, sexo, posto e afastamentos informados',
    Icons.fact_check_rounded,
    Duration(milliseconds: 650),
  ),
  _Etapa(
    'Somando o tempo averbado',
    'Serviço na Corporação, tempo militar de outra OM e averbação civil',
    Icons.playlist_add_check_rounded,
    Duration(milliseconds: 850),
  ),
  _Etapa(
    'Consultando a legislação',
    'DL 667/1969, arts. 24-A a 24-G, e LC/RR 305/2022',
    Icons.gavel_rounded,
    Duration(milliseconds: 800),
  ),
  _Etapa(
    'Enquadrando no regime',
    'Direito adquirido, regra de transição ou regra permanente',
    Icons.rule_rounded,
    Duration(milliseconds: 700),
  ),
  _Etapa(
    'Aplicando os dois pedágios',
    'Os 17% do inciso I e os 4 meses por ano do parágrafo único',
    Icons.toll_rounded,
    Duration(milliseconds: 800),
  ),
  _Etapa(
    'Projetando as datas',
    'Integralidade, reserva de ofício e reforma',
    Icons.event_available_rounded,
    Duration(milliseconds: 700),
  ),
];

/// Tela de apuração: mostra o que está sendo apurado, etapa a etapa.
class _TelaEtapas extends StatelessWidget {
  final int etapaAtual;
  const _TelaEtapas({Key? key, required this.etapaAtual}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progresso = (etapaAtual + 1) / _etapas.length;

    // Topo com a arte do tempo de serviço (padrão 2.2): título, etapa e a
    // barra de progresso sobre a arte; as etapas numa caixa de vidro.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TopoArte(
          arte: Arte.de('ts'),
          icone: Icons.hourglass_top_rounded,
          titulo: 'Apurando sua inatividade',
          subtitulo: 'Etapa ${etapaAtual + 1} de ${_etapas.length}',
          margem: const EdgeInsets.only(bottom: 16),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progresso),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        CartaoVidro(
          arte: Arte.de('ts'),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Column(
            children: [
              for (var i = 0; i < _etapas.length; i++)
                _LinhaEtapa(
                  etapa: _etapas[i],
                  estado: i < etapaAtual
                      ? _EstadoEtapa.concluida
                      : i == etapaAtual
                          ? _EstadoEtapa.ativa
                          : _EstadoEtapa.pendente,
                  isDark: isDark,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _EstadoEtapa { pendente, ativa, concluida }

class _LinhaEtapa extends StatelessWidget {
  final _Etapa etapa;
  final _EstadoEtapa estado;
  final bool isDark;
  const _LinhaEtapa(
      {required this.etapa, required this.estado, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ativa = estado == _EstadoEtapa.ativa;
    final feita = estado == _EstadoEtapa.concluida;
    final cor = feita
        ? _verde(context)
        : ativa
            ? theme.colorScheme.primary
            : theme.hintColor;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 320),
      opacity: estado == _EstadoEtapa.pendente ? 0.38 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: ativa
              ? cor.withOpacity(isDark ? 0.14 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativa ? cor.withOpacity(0.30) : Colors.transparent,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 22,
            height: 22,
            child: feita
                ? Icon(Icons.check_circle_rounded,
                    size: AppIconSize.sm, color: cor)
                : ativa
                    ? CircularProgressIndicator(strokeWidth: 2.2, color: cor)
                    : Icon(etapa.icone, size: AppIconSize.sm, color: cor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(etapa.titulo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: ativa ? FontWeight.bold : FontWeight.w600,
                    color: ativa ? cor : null,
                    fontSize: 14,
                  )),
              const SizedBox(height: 2),
              Text(etapa.detalhe,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5, height: 1.35, color: theme.hintColor)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Componentes visuais ─────────────────────────────────────────────────────

// Cores de estado nos pares de cada tema (DESIGN §3): a versão clara no
// fundo escuro e a escura no claro, para passar de 4,5:1 nos dois.
Color _verde(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? AppColors.sucessoEscuro
    : AppColors.sucesso;
Color _ambar(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? Colors.amber.shade300
    : Colors.amber.shade900;
Color _azul(BuildContext c) => Theme.of(c).colorScheme.primary;

/// Superfície dos cards do módulo. Era um `Container` com cor e borda
/// próprias — mais uma superfície opaca fora do padrão, justamente o que o
/// DESIGN.md §2 manda não refazer. Agora é o `CartaoVidro` do app, com o
/// mesmo recheio dos cards do painel.
class _Card extends StatelessWidget {
  final Widget child;
  final String? titulo;
  final IconData? icone;

  /// Arte discreta da área (padrão 2.2), nas seções do formulário.
  final Arte? arte;

  const _Card({required this.child, this.titulo, this.icone, this.arte});

  @override
  Widget build(BuildContext context) {
    return CartaoVidro(
      raio: 16,
      arte: arte,
      child: Padding(
        padding: kPaddingCartao,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titulo != null) ...[
              CabecalhoCartao(
                icone: icone ?? Icons.info_outline_rounded,
                titulo: titulo!,
                mostrarSeta: false,
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _TagSistema extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('do sistema',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary)),
    );
  }
}

/// Campo numérico compacto usado nos trios anos/meses/dias.
/// Só a caixa. O rótulo da unidade fica **fora**, abaixo dela.
///
/// Antes era `suffixText` dentro do campo, e ele simplesmente não aparecia:
/// o InputDecorator esconde prefixo e sufixo enquanto o campo está vazio e
/// sem foco. O resultado eram três caixas idênticas com "0", sem nada que
/// dissesse qual era ano, mês ou dia.
class _MiniNumero extends StatefulWidget {
  final int? valorInicial;
  final int max;
  final ValueChanged<int> onChanged;

  const _MiniNumero({
    Key? key,
    required this.valorInicial,
    required this.onChanged,
    this.max = 99,
  }) : super(key: key);

  @override
  State<_MiniNumero> createState() => _MiniNumeroState();
}

class _MiniNumeroState extends State<_MiniNumero> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.valorInicial == null || widget.valorInicial == 0
            ? ''
            : '${widget.valorInicial}');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        hintText: '0',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      ),
      onChanged: (s) {
        final n = int.tryParse(s) ?? 0;
        widget.onChanged(n > widget.max ? widget.max : n);
      },
    );
  }
}

/// Faixa superior: regime jurídico em que o militar se enquadra.
class _CardRegime extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardRegime({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    late final Color cor;
    late final IconData icone;
    switch (resultado.regime) {
      case RegimeAplicavel.direitoAdquirido:
        cor = _verde(context);
        icone = Icons.verified_rounded;
        break;
      case RegimeAplicavel.transicao:
        cor = _ambar(context);
        icone = Icons.swap_horiz_rounded;
        break;
      case RegimeAplicavel.permanente:
        cor = _azul(context);
        icone = Icons.rule_rounded;
        break;
    }

    // Vidro tingido pela cor do regime (DESIGN §11: aviso dentro da tela),
    // sem círculo tingido atrás do ícone (§2b).
    return CartaoVidro(
      raio: 16,
      tingimento: cor,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        ExcludeSemantics(
            child: Icon(icone, color: cor, size: AppIconSize.md)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Regime aplicável',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 1),
            Text(resultado.regime.label,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: cor, height: 1.2)),
            const SizedBox(height: 3),
            Text(resultado.regime.fundamento,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
          ]),
        ),
      ]),
    );
  }
}

/// Destaque: quando o militar atinge a integralidade.
class _CardPrevisao extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardPrevisao({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = resultado.integralJaCumprido;
    final cor = ok ? _verde(context) : _azul(context);

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CabecalhoCartao(
          icone: ok
              ? Icons.check_circle_outline_rounded
              : Icons.event_available_outlined,
          titulo: ok ? 'Você já pode requerer' : 'Previsão de integralidade',
          mostrarSeta: false,
        ),
        const SizedBox(height: 12),
        if (ok)
          DestaqueCartao(
            valor: 'Agora',
            complemento: 'Reserva com proventos integrais',
            tamanho: AppDisplaySize.heroiMenor,
            corValor: cor,
          )
        else ...[
          // Mês/ano grande e a data exata logo abaixo: o militar quer saber
          // "quando", e a precisão de dia é apoio, não manchete.
          DestaqueCartao(
            valor:
                TempoFmt.mesAno(resultado.dataPrevistaIntegral).toUpperCase(),
            tamanho: AppDisplaySize.heroi,
            corValor: cor,
          ),
          const SizedBox(height: 6),
          Text(
            '${TempoFmt.data(resultado.dataPrevistaIntegral)}  ·  faltam '
            '${TempoFmt.extenso(resultado.diasFaltantesIntegral)}',
            style: TextStyle(fontSize: 13, color: TomCartao.medio(context)),
          ),
          const DivisorCartao(espaco: 12),
          RodapeCartao(
            icone: Icons.flag_outlined,
            texto: 'Define a data: ${resultado.requisitoLimitante}',
          ),
        ],
        if (resultado.idadeLimiteAntesDaIntegralidade) ...[
          const SizedBox(height: 10),
          CartaoVidro(
            raio: 12,
            tingimento: theme.colorScheme.error,
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded,
                  size: AppIconSize.xs, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Atenção: a idade-limite do seu posto/graduação '
                  '(${TempoFmt.mesAno(resultado.dataReservaOficio!)}) chega '
                  'ANTES da integralidade. Nesse cenário a transferência será '
                  'de ofício, com proventos proporcionais '
                  '(LC/RR 305/2022, art. 24, §2º).',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11, height: 1.35),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Progresso de um requisito legal isolado.
class _CardRequisito extends StatelessWidget {
  final Requisito requisito;
  final IconData icone;
  const _CardRequisito({required this.requisito, required this.icone});

  @override
  Widget build(BuildContext context) {
    final ok = requisito.cumprido;
    final cor = ok ? _verde(context) : _azul(context);

    final pct = '${(requisito.percentual * 100).toStringAsFixed(1)}%'
        .replaceAll('.', ',');

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabeçalho e percentual ao lado, como nos cards do painel. Eram
        // três métricas de peso igual e o militar tinha de garimpar qual
        // delas respondia "e aí, quanto falta?".
        Row(children: [
          Icon(icone, size: AppIconSize.sm, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(requisito.nome,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, height: 1.2)),
          ),
          const SizedBox(width: 8),
          Text(
            ok ? 'cumprido' : pct,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: cor),
          ),
        ]),

        const SizedBox(height: 12),

        // O herói é o que falta. É a pergunta que leva o militar a abrir
        // esta tela; cumprido, o herói passa a ser o próprio cumprimento.
        DestaqueCartao(
          rotulo: ok ? 'Requisito' : 'Falta',
          valor: ok ? 'Cumprido' : TempoFmt.curto(requisito.faltaDias),
          tamanho: AppDisplaySize.heroiMenor,
          corValor: ok ? cor : null,
        ),

        const SizedBox(height: 14),

        BarraProgressoCartao(
          valor: requisito.percentual,
          semantica: requisito.nome,
        ),

        const SizedBox(height: 10),

        Row(children: [
          _Metrica(
            rotulo: 'Exigido',
            valor: TempoFmt.curto(requisito.exigidoDias),
            detalhe: requisito.detalheExigido,
          ),
          _Metrica(
              rotulo: 'Você tem', valor: TempoFmt.curto(requisito.atualDias)),
        ]),
        // Quando a parcela de dias passa de 29 — "19a 11m 34d" — o militar
        // lê como erro de conta. Não é, e a explicação aparece aqui mesmo,
        // junto do número, em vez de ficar escondida numa ajuda.
        if (TempoFmt.notaResto(requisito.atualDias) != null) ...[
          const SizedBox(height: 10),
          _NotaResto(texto: TempoFmt.notaResto(requisito.atualDias)!),
        ],

        // A base legal é referência, não manchete: sai de debaixo do título
        // e vira rodapé, como nos cards do painel.
        const DivisorCartao(espaco: 12),
        RodapeCartao(icone: Icons.gavel_rounded, texto: requisito.fundamento),
      ]),
    );
  }
}

/// A explicação dos dias que passam de 29.
class _NotaResto extends StatelessWidget {
  const _NotaResto({Key? key, required this.texto}) : super(key: key);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.help_outline_rounded,
            size: AppIconSize.xs, color: TomCartao.medio(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
                fontSize: 12, height: 1.4, color: TomCartao.medio(context)),
          ),
        ),
      ]),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String rotulo;
  final String valor;
  final String? detalhe;
  const _Metrica({required this.rotulo, required this.valor, this.detalhe});

  @override
  Widget build(BuildContext context) {
    // Métrica de apoio: o número que importa virou o herói do card, então
    // estas duas ficam no tamanho de leitura, não de manchete.
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo,
            style: TextStyle(fontSize: 12, color: TomCartao.medio(context))),
        const SizedBox(height: 2),
        Text(valor,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (detalhe != null)
          Text(detalhe!,
              style: TextStyle(fontSize: 11, color: TomCartao.fraco(context))),
      ]),
    );
  }
}

/// Detalhamento do pedágio de 17% (art. 24-G, I).
class _CardPedagio extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardPedagio({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = _ambar(context);
    final r = resultado;
    final minEnte = ParametrosLegais.minimoEnteAnos(r.entrada.sexo);
    final minCorporacao =
        ParametrosLegais.minimoServicoCorporacaoAnos(r.entrada.sexo);

    Widget linha(String rot, String val, {bool forte = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
              child: Text(rot,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: forte ? null : theme.hintColor,
                      fontWeight: forte ? FontWeight.w600 : null)),
            ),
            Text(val,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: forte ? cor : null)),
          ]),
        );

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.toll_rounded, size: AppIconSize.sm, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Os dois pedágios',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 3),
        Text('DL 667/1969, art. 24-G — ambos aferidos na Data Base',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
        const SizedBox(height: 12),
        Text('1º pedágio — 17% sobre o tempo total',
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: cor)),
        const SizedBox(height: 6),
        linha('Mínimo de contribuição (${r.entrada.sexo.label.toLowerCase()})',
            '$minEnte anos'),
        linha('Sua contribuição na Data Base',
            TempoFmt.curto(r.diasContribuicaoTotal)),
        linha('Faltante', TempoFmt.curto(r.faltanteNaDataCorteDias)),
        linha('Pedágio (17% do faltante)', TempoFmt.curto(r.pedagioDias),
            forte: true),
        const Divider(height: 18),
        Text('2º pedágio — 4 meses por ano de atividade militar',
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: cor)),
        const SizedBox(height: 6),
        linha('Mínimo de serviço militar', '$minCorporacao anos'),
        linha('Seu serviço militar na Data Base',
            TempoFmt.curto(r.diasTempoServicoMilitar)),
        linha('Faltante', TempoFmt.curto(r.faltanteServicoNaDataCorteDias)),
        linha('Anos faltantes (truncados)', '${r.anosFaltantesAcrescimo}'),
        linha('Acréscimo (4 meses por ano)',
            '${r.acrescimoAtividadeMilitarMeses} meses',
            forte: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            r.acrescimoAtividadeMilitarMeses == 0
                ? 'Você já contava os $minCorporacao anos de efetivo serviço em '
                    '31/12/2021, então o 2º pedágio não se aplica: a exigência '
                    'de atividade militar fica em 25 anos. O 1º pedágio '
                    'continua valendo.'
                : 'Os dois pedágios são independentes e precisam ser cumpridos '
                    'juntos: cada um tem sua própria base de cálculo e a '
                    'integralidade só vem quando o último deles fechar.',
            style:
                theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

/// Situação dos proventos proporcionais.
class _CardProporcional extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardProporcional({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = resultado;
    final ok = r.elegivelProporcional;
    final cor = ok ? _azul(context) : theme.hintColor;
    final quotas =
        (r.percentualProporcional * ParametrosLegais.quotasDenominador).floor();

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pie_chart_rounded, size: 17, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Proventos proporcionais',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(ok ? 'elegível hoje' : 'ainda não',
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.bold, color: cor)),
          ),
        ]),
        const SizedBox(height: 3),
        Text(r.requisitoProporcional.fundamento,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
        const SizedBox(height: 12),
        if (ok) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$quotas',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: _azul(context))),
            Text('/35 avos',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor)),
            const Spacer(),
            Text('${(r.percentualProporcional * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: _azul(context))),
          ]),
          const SizedBox(height: 6),
          Text(
            'Se requerer a reserva hoje, os proventos seriam calculados em '
            'tantas quotas quantos forem os anos de serviço '
            '(DL 667/1969, art. 24-A, I, "b").',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11, color: theme.hintColor, height: 1.35),
          ),
        ] else
          Text(
            'Você ainda não atingiu o mínimo de '
            '${TempoFmt.extenso(r.requisitoProporcional.exigidoDias)} exigido '
            'para requerer proventos proporcionais. '
            'Faltam ${TempoFmt.extenso(r.requisitoProporcional.faltaDias)}.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
      ]),
    );
  }
}

/// Reserva de ofício por idade-limite.
class _CardIdadeLimite extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardIdadeLimite({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = resultado;
    final posto = r.entrada.posto;

    String corpo;
    if (posto == null) {
      corpo = 'Informe seu posto ou graduação para ver a idade-limite.';
    } else if (r.idadeLimite == null) {
      corpo = 'A idade-limite para ${posto.label} não está prevista '
          'expressamente no art. 24, I da LC/RR 305/2022.';
    } else if (r.dataReservaOficio == null) {
      corpo = 'Idade-limite de ${r.idadeLimite} anos. Informe sua data de '
          'nascimento para ver a data prevista.';
    } else {
      final falta =
          r.dataReservaOficio!.difference(r.entrada.dataReferencia).inDays;
      corpo = falta > 0
          ? 'Idade-limite de ${r.idadeLimite} anos, atingida em '
              '${TempoFmt.data(r.dataReservaOficio!)} '
              '(em ${TempoFmt.extenso(falta)}).'
          : 'Idade-limite de ${r.idadeLimite} anos já atingida em '
              '${TempoFmt.data(r.dataReservaOficio!)}.';
    }

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.hourglass_bottom_rounded,
              size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Reserva de ofício por idade-limite',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, height: 1.2)),
          ),
        ]),
        const SizedBox(height: 3),
        Text('LC/RR 305/2022, art. 24, I',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
        const SizedBox(height: 10),
        Text(corpo, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
      ]),
    );
  }
}

/// Memorial de cálculo — deixa toda a conta auditável.

/// Reforma — por incapacidade definitiva ou por idade (arts. 25 e 26).
class _CardReforma extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardReforma({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = resultado;
    final hip = r.entrada.incapacidade;

    Widget bloco(String titulo, String corpo, {Color? cor, String? tag}) =>
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CartaoVidro(
          raio: 12,
          tingimento: cor,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
          width: double.infinity,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.hintColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(tag,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.hintColor)),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(corpo,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11.5, height: 1.4)),
                  ]),
            ),
          ]),
          ),
          ),
        );

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_hospital_rounded,
              size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Reforma',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 3),
        Text('LC/RR 305/2022, arts. 25 e 26 — sempre de ofício',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
        if (hip != null)
          bloco(
            hip.label,
            hip.integral
                ? 'Proventos integrais, com base no último subsídio do posto '
                    'ou graduação. Não depende de tempo de serviço: a reforma '
                    'se dá de imediato, sem pedágio.\n${hip.fundamento}'
                : 'Proventos proporcionais ao tempo de contribuição, pela '
                    'fração do art. 25, §7º, e nunca inferiores ao '
                    'salário-mínimo (§9º).\n${hip.fundamento}',
            cor: hip.integral
                ? _verde(context)
                : _ambar(context),
          )
        else
          bloco(
            'Reforma por incapacidade definitiva',
            'Ferimento, acidente em serviço ou doença com nexo — e as doenças '
                'graves do rol do art. 26, IV — dão reforma com proventos '
                'integrais, sem exigência de tempo. Sem nexo, os proventos são '
                'proporcionais. Selecione a hipótese no formulário para simular.',
          ),
        if (r.dataReformaPorIdade != null)
          bloco(
            'Reforma por idade',
            '${r.dataReformaPorIdade!.isBefore(r.entrada.dataReferencia) ? "Idade atingida em" : "Prevista para"} '
                '${TempoFmt.data(r.dataReformaPorIdade!)}. Proventos integrais '
                'do posto ou graduação em que estava na reserva (art. 25, §2º).',
            tag: '${r.idadeReforma} anos',
          ),
      ]),
    );
  }
}

/// Demais hipóteses de reserva de ofício — art. 24, II a VI.
class _CardOficioOutras extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardOficioOutras({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = resultado;
    final ok = r.oficioOutrasLiberado;
    final cor = ok ? _verde(context) : _ambar(context);

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.checklist_rounded,
              size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Outras hipóteses de reserva de ofício',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, height: 1.2)),
          ),
        ]),
        const SizedBox(height: 3),
        Text('LC/RR 305/2022, art. 24, II a VI — proventos proporcionais (§2º)',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
        const SizedBox(height: 10),
        ...hipotesesReservaOficio.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 24,
                  child: Text(h[0],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _ambar(context))),
                ),
                Expanded(
                  child: Text(h[1],
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 12, height: 1.4)),
                ),
              ]),
            )),
        const SizedBox(height: 6),
        CartaoVidro(
          raio: 12,
          tingimento: cor,
          padding: const EdgeInsets.all(11),
          child: SizedBox(
          width: double.infinity,
          child: Text(
            ok
                ? 'Você já conta os 20 anos de contribuição que essas '
                    'hipóteses exigem.'
                : 'Todas exigem 20 anos de contribuição — faltam '
                    '${TempoFmt.extenso(r.oficioOutrasFaltaDias)}. Sem esse '
                    'tempo, o enquadramento leva a licenciamento ou '
                    'exoneração, não à reserva (LC/RR 194/2012, art. 115-B, '
                    'parágrafo único).',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11.5, height: 1.4, color: cor),
          ),
          ),
        ),
      ]),
    );
  }
}

class _CardMemorial extends StatelessWidget {
  final ResultadoInatividade resultado;
  const _CardMemorial({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = resultado;

    Widget linha(String rot, String val) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: Text(rot,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11, color: theme.hintColor)),
            ),
            Expanded(
              flex: 2,
              child: Text(val,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        );

    return _Card(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4),
          leading: Icon(Icons.calculate_rounded,
              size: 17, color: theme.colorScheme.primary),
          title: Text('Memorial de cálculo',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text('Como chegamos a esses números',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 10.5, color: theme.hintColor)),
          children: [
            linha('Data de incorporação',
                TempoFmt.data(r.entrada.dataIncorporacao)),
            linha('Data do cálculo', TempoFmt.data(r.entrada.dataReferencia)),
            linha('Data Base (aferição dos pedágios)',
                '${TempoFmt.data(r.entrada.dataReferencia)} — hoje'),
            linha('Corte do direito adquirido', '31/12/2021'),
            const Divider(height: 14),
            linha('Serviço na Corporação (PMRR/CBMRR)',
                TempoFmt.extenso(r.diasServicoCorporacao)),
            if (r.diasServicoMilitarAnterior > 0)
              linha('Militar em outra OM',
                  '+ ${TempoFmt.extenso(r.diasServicoMilitarAnterior)}'),
            linha('Tempo de serviço militar',
                TempoFmt.extenso(r.diasTempoServicoMilitar)),
            if (r.diasAverbadosCivis > 0)
              linha('Averbado civil',
                  '+ ${TempoFmt.extenso(r.diasAverbadosCivis)}'),
            linha('Contribuição total',
                TempoFmt.extenso(r.diasContribuicaoTotal)),
            if (r.entrada.diasFuncaoCivil > 0)
              linha('Cedido a função civil',
                  '− ${TempoFmt.extenso(r.entrada.diasFuncaoCivil)}'),
            linha('Atividade de natureza militar',
                TempoFmt.extenso(r.diasAtividadeMilitar)),
            if (r.entrada.diasAfastamentos > 0)
              linha('Afastamentos descontados',
                  '− ${TempoFmt.extenso(r.entrada.diasAfastamentos)}'),
            const Divider(height: 14),
            linha('Serviço na Corporação em 31/12/2021',
                TempoFmt.extenso(r.diasServicoCorporacaoEm2021)),
            linha('Contribuição em 31/12/2021',
                TempoFmt.extenso(r.diasContribuicaoEm2021)),
            if (r.regime == RegimeAplicavel.transicao) ...[
              linha('Faltante de contribuição',
                  TempoFmt.extenso(r.faltanteNaDataCorteDias)),
              linha('Pedágio (17%)', TempoFmt.extenso(r.pedagioDias)),
              linha('Faltante de serviço na Corporação',
                  TempoFmt.extenso(r.faltanteServicoNaDataCorteDias)),
              linha('Anos faltantes (truncados)',
                  '${r.anosFaltantesAcrescimo} anos'),
              linha('Acréscimo ativ. militar',
                  '${r.acrescimoAtividadeMilitarMeses} meses'),
            ],
            const Divider(height: 14),
            linha('Exige — ${r.requisitoTempoTotal.nome}',
                TempoFmt.extenso(r.requisitoTempoTotal.exigidoDias)),
            linha('Exige — ${r.requisitoAtividadeMilitar.nome}',
                TempoFmt.extenso(r.requisitoAtividadeMilitar.exigidoDias)),
            const Divider(height: 14),
            linha('Data prevista da integralidade',
                TempoFmt.data(r.dataPrevistaIntegral)),
            if (r.dataReformaPorIdade != null)
              linha('Reforma por idade (${r.idadeReforma} anos)',
                  TempoFmt.data(r.dataReformaPorIdade!)),
            const SizedBox(height: 8),
            Text(
              'Contagem em dias corridos, convertidos a 365 dias/ano e 30 '
              'dias/mês — mesmo critério do SIGRH. A projeção assume serviço '
              'contínuo e ininterrupto a partir de hoje.',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5, color: theme.hintColor, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAvisos extends StatelessWidget {
  final List<String> avisos;
  const _CardAvisos({required this.avisos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = _ambar(context);
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_rounded, size: AppIconSize.sm, color: cor),
          const SizedBox(width: 8),
          Text('Observações',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ...avisos.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration:
                        BoxDecoration(color: cor, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(a,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 11.5, height: 1.4)),
                ),
              ]),
            )),
      ]),
    );
  }
}
