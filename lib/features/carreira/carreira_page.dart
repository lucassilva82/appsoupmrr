import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enderecos.dart';
import '../../core/erros/estado_erro.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import '../../core/design/esqueleto.dart';
import '../../core/design/arte_cartao.dart';
import '../../utils/app_routes.dart';
import '../../widgets/cartao_painel.dart';

const _chave = 'rh.carreira';

/// Um marco da carreira (P5, docs/SOUPM_2_2.md §11): incorporação,
/// promoção, comportamento, escolaridade ou tempo averbado.
class MarcoCarreira {
  const MarcoCarreira(
      {required this.data, required this.tipo, required this.titulo, this.detalhe, this.semData = false});
  final DateTime data;

  /// O SIGRH não tem a data (a API manda 1900-01-01): vai para o fim da lista.
  final bool semData;
  final String tipo;
  final String titulo;
  final String? detalhe;

  static MarcoCarreira? deJson(Object? j) {
    if (j is! Map || j['titulo'] is! String) return null;
    final d = DateTime.tryParse('${j['data'] ?? ''}');
    if (d == null) return null;
    return MarcoCarreira(
        data: d,
        tipo: '${j['tipo'] ?? ''}',
        titulo: j['titulo'] as String,
        detalhe: j['detalhe'] as String?,
        semData: j['sem_data'] == true);
  }
}

/// Resposta do `carreira.php`. [falhas] são as seções que o SIGRH não
/// respondeu: aparecem como "não foi possível conferir", nunca como vazio.
class LinhaDoTempo {
  const LinhaDoTempo({required this.marcos, required this.falhas});
  final List<MarcoCarreira> marcos;
  final List<String> falhas;

  int conta(Set<String> tipos) => marcos.where((m) => tipos.contains(m.tipo)).length;

  /// Anos desde a incorporação (nulo sem ela).
  int? get anosNaPmrr {
    final inc = marcos.where((m) => m.tipo == 'incorporacao').firstOrNull;
    if (inc == null) return null;
    final h = DateTime.now();
    var anos = h.year - inc.data.year;
    if (h.month < inc.data.month || (h.month == inc.data.month && h.day < inc.data.day)) anos--;
    return anos < 0 ? 0 : anos;
  }
}

class CarreiraRepositorio {
  CarreiraRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/carreira.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'CR';

  /// A última linha do tempo carregada (a Início e a tela usam a mesma),
  /// e de quem ela é: outra conta no mesmo aparelho não aproveita.
  static final emUso = ValueNotifier<LinhaDoTempo?>(null);
  static String? _deQuem;

  /// A linha do tempo guardada, só se for desta matrícula.
  static LinhaDoTempo? guardadaDe(String? matricula) => _deQuem == matricula ? emUso.value : null;

  Future<LinhaDoTempo> carregar() async {
    final j = await api.postJson(url, prefixo: prefixo, campos: {'matricula': matricula, 'senha': senhaMd5});
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'carreira.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    final marcos = [
      for (final e in (j['eventos'] as List? ?? const []))
        if (MarcoCarreira.deJson(e) case final m?) m,
    ]..sort((a, b) => a.data.compareTo(b.data));
    final l = LinhaDoTempo(marcos: marcos, falhas: [for (final f in (j['falhas'] as List? ?? const [])) '$f']);
    _deQuem = matricula;
    emUso.value = l;
    return l;
  }
}

const _nomesSecao = {
  'incorporacao': 'a incorporação',
  'promocoes': 'as promoções',
  'comportamento': 'o comportamento',
  'escolaridade': 'a escolaridade',
  'averbacao': 'o tempo averbado',
  'cursos': 'os cursos',
  'condecoracoes': 'os elogios, menções e medalhas',
};

/// Grupos do filtro da tela (cada marco cai em um).
enum GrupoMarco {
  todos('Todos', Icons.timeline_rounded, {}),
  promocoes('Promoções', Icons.military_tech_rounded, {'promocao', 'incorporacao'}),
  cursos('Cursos', Icons.school_rounded, {'curso', 'escolaridade'}),
  honrarias('Elogios e medalhas', Icons.workspace_premium_rounded, {'elogio', 'mencao', 'medalha', 'condecoracao'}),
  outros('Outros', Icons.more_horiz_rounded, {'comportamento', 'averbacao'});

  const GrupoMarco(this.rotulo, this.icone, this.tipos);
  final String rotulo;
  final IconData icone;
  final Set<String> tipos;

  bool contem(MarcoCarreira m) => this == todos || tipos.contains(m.tipo);
}

IconData _icone(String tipo) => switch (tipo) {
      'incorporacao' => Icons.flag_rounded,
      'promocao' => Icons.military_tech_rounded,
      'comportamento' => Icons.verified_rounded,
      'escolaridade' => Icons.school_rounded,
      'averbacao' => Icons.history_rounded,
      'curso' => Icons.menu_book_rounded,
      'elogio' => Icons.thumb_up_alt_rounded,
      'mencao' => Icons.star_rounded,
      'medalha' => Icons.workspace_premium_rounded,
      'condecoracao' => Icons.emoji_events_rounded,
      _ => Icons.circle,
    };

/// A cor de cada tipo vem do catálogo de artes (padrão 2.2), no tom de
/// destaque no escuro e no tom do meio no claro (contraste 3:1 do ícone).
Color _corTipo(String tipo, Brightness brilho) {
  final arte = Arte.de(switch (tipo) {
    'promocao' || 'medalha' || 'condecoracao' => 'ts',
    'curso' || 'escolaridade' => 'fe',
    'elogio' || 'mencao' => 'rosa',
    'comportamento' => 'institucional',
    'averbacao' => 'dc',
    _ => 'rh',
  });
  return brilho == Brightness.dark ? arte.destaque : arte.meio;
}

String _nomeTipo(String tipo) => switch (tipo) {
      'incorporacao' => 'Incorporação',
      'promocao' => 'Promoção',
      'comportamento' => 'Comportamento',
      'escolaridade' => 'Escolaridade',
      'averbacao' => 'Tempo averbado',
      'curso' => 'Curso',
      'elogio' => 'Elogio',
      'mencao' => 'Menção honrosa',
      'medalha' => 'Medalha',
      'condecoracao' => 'Condecoração',
      _ => 'Marco',
    };

String _data(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

CarreiraRepositorio repositorioCarreira(BuildContext context) {
  final auth = context.read<Auth>();
  return CarreiraRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}

/// Linha do tempo da carreira (`rh.carreira`).
class CarreiraPage extends StatefulWidget {
  const CarreiraPage({super.key, this.repositorio});
  final CarreiraRepositorio? repositorio;

  @override
  State<CarreiraPage> createState() => _CarreiraPageState();
}

class _CarreiraPageState extends State<CarreiraPage> {
  late final CarreiraRepositorio _repo = widget.repositorio ?? repositorioCarreira(context);
  late LinhaDoTempo? _linha = CarreiraRepositorio.guardadaDe(context.read<Auth>().matricula);
  FalhaApp? _falha;
  GrupoMarco _grupo = GrupoMarco.todos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    try {
      final l = await _repo.carregar();
      registrar('carreira.ver', chave: _chave, dados: {'marcos': l.marcos.length, 'falhas': l.falhas.length});
      if (mounted) setState(() => _linha = l);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    } catch (e) {
      final f = FalhaApp.inesperada(CarreiraRepositorio.prefixo, e);
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linha = _linha;
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Linha do tempo'),
        body: _falha != null && linha == null
            ? EstadoErro(falha: _falha!, aoTentar: _carregar, tela: _chave, chave: _chave)
            : linha == null
                ? const EsqueletoLista()
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: _Conteudo(
                      linha: linha,
                      grupo: _grupo,
                      aoFiltrar: (g) {
                        registrar('carreira.filtrar', chave: _chave, dados: {'grupo': g.name});
                        setState(() => _grupo = g);
                      },
                    ),
                  ),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.linha, required this.grupo, required this.aoFiltrar});
  final LinhaDoTempo linha;
  final GrupoMarco grupo;
  final ValueChanged<GrupoMarco> aoFiltrar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtrados = linha.marcos.reversed.where(grupo.contem).toList();
    final anos = <int, List<MarcoCarreira>>{};
    for (final m in filtrados) {
      anos.putIfAbsent(m.semData ? 0 : m.data.year, () => []).add(m);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _Resumo(linha: linha),
        const SizedBox(height: 14),
        // Filtros por grupo (rolam de lado; alvo de 44 pt).
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final g in GrupoMarco.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(g.icone, size: AppIconSize.xs),
                    label: Text(g == GrupoMarco.todos
                        ? 'Todos (${linha.marcos.length})'
                        : '${g.rotulo} (${linha.conta(g.tipos)})'),
                    selected: g == grupo,
                    onSelected: (_) => aoFiltrar(g),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final f in linha.falhas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CartaoVidro(
              raio: 14,
              padding: const EdgeInsets.all(12),
              tingimento: theme.colorScheme.error,
              child: Row(children: [
                Icon(Icons.cloud_off_rounded, size: AppIconSize.sm, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Não foi possível conferir ${_nomesSecao[f] ?? f} no SIGRH. Puxe para atualizar. '
                      'Código CR-${f.toUpperCase()}.',
                      style: theme.textTheme.bodySmall),
                ),
              ]),
            ),
          ),
        if (filtrados.isEmpty)
          CartaoVidro(
            arte: Arte.de('rh'),
            padding: const EdgeInsets.all(16),
            child: Text(
                linha.marcos.isEmpty
                    ? 'O SIGRH ainda não tem marcos registrados para você. Se faltar algo, procure a '
                        'Diretoria de Recursos Humanos - PMRR.'
                    : 'Nada em "${grupo.rotulo}" no SIGRH. Se faltar algum registro, procure a Diretoria de '
                        'Recursos Humanos - PMRR.',
                style: theme.textTheme.bodyMedium),
          ),
        // A linha vertical só começa no primeiro marco e só termina no último
        // da lista inteira: entre os anos ela segue, ligando a carreira.
        for (final (a, MapEntry(key: ano, value: marcos)) in anos.entries.indexed) ...[
          _Ano(ano: ano, quantos: marcos.length),
          for (final (i, m) in marcos.indexed)
            _Marco(
              marco: m,
              primeiro: a == 0 && i == 0,
              ultimo: a == anos.length - 1 && i == marcos.length - 1,
            ),
        ],
      ],
    );
  }
}

/// O cartão de abertura: arte cheia com os números da carreira.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.linha});
  final LinhaDoTempo linha;

  @override
  Widget build(BuildContext context) {
    final anos = linha.anosNaPmrr;
    final itens = [
      (Icons.military_tech_rounded, linha.conta({'promocao'}), 'promoções'),
      (Icons.menu_book_rounded, linha.conta({'curso'}), 'cursos'),
      (Icons.thumb_up_alt_rounded, linha.conta({'elogio', 'mencao'}), 'elogios e menções'),
      (Icons.workspace_premium_rounded, linha.conta({'medalha', 'condecoracao'}), 'medalhas e condecorações'),
    ];
    return CartaoArte(
      arte: Arte.de('rh'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .22)),
            ),
            child: const Icon(Icons.timeline_rounded, color: Colors.white, size: AppIconSize.md),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sua carreira', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text(anos == null ? 'Como está no SIGRH' : '$anos ${anos == 1 ? 'ano' : 'anos'} de PMRR · como está no SIGRH',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .84))),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (icone, n, rotulo) in itens)
            Semantics(
              label: '$n $rotulo',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: .18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icone, size: AppIconSize.xs, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('$n', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  Text(rotulo, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .84))),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// O ano, como uma pílula sobre a linha vertical.
class _Ano extends StatelessWidget {
  const _Ano({required this.ano, required this.quantos});
  final int ano;
  final int quantos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Semantics(
        header: true,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .35)),
            ),
            child: Text(ano == 0 ? 'Sem data' : '$ano',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 8),
          Text(quantos == 1 ? '1 registro' : '$quantos registros',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: .6))),
        ]),
      ),
    );
  }
}

class _Marco extends StatelessWidget {
  const _Marco({required this.marco, required this.primeiro, required this.ultimo});
  final MarcoCarreira marco;
  final bool primeiro;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = _corTipo(marco.tipo, theme.brightness);
    final linhaCor = theme.colorScheme.onSurface.withValues(alpha: 0.14);
    return Semantics(
      label: '${_nomeTipo(marco.tipo)}, ${marco.semData ? 'sem data' : _data(marco.data)}: ${marco.titulo}'
          '${marco.detalhe != null ? ', ${marco.detalhe}' : ''}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // A linha vertical contínua, com o marcador colorido do tipo.
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(width: 2, height: 14, color: primeiro ? Colors.transparent : linhaCor),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cor.withValues(alpha: .16),
                  border: Border.all(color: cor.withValues(alpha: .55), width: 1.4),
                ),
                child: Icon(_icone(marco.tipo), size: AppIconSize.xs, color: cor),
              ),
              Expanded(child: Container(width: 2, color: ultimo ? Colors.transparent : linhaCor)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: CartaoVidro(
                raio: 14,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(_nomeTipo(marco.tipo).toUpperCase(),
                        style: TextStyle(fontSize: 10.5, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: cor)),
                    const Spacer(),
                    Text(marco.semData ? 'data não registrada' : _data(marco.data),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ]),
                  const SizedBox(height: 4),
                  Text(marco.titulo, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (marco.detalhe != null) ...[
                    const SizedBox(height: 2),
                    Text(marco.detalhe!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Card "Sua carreira" da Início (`home.carreira`): os totais e o marco mais
/// recente; o toque abre a linha do tempo.
class CardCarreira extends StatefulWidget {
  const CardCarreira({super.key});

  @override
  State<CardCarreira> createState() => _CardCarreiraState();
}

class _CardCarreiraState extends State<CardCarreira> {
  bool _falhou = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    if (CarreiraRepositorio.guardadaDe(context.read<Auth>().matricula) != null) return;
    CarreiraRepositorio.emUso.value = null;
    try {
      await repositorioCarreira(context).carregar();
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'inicio', mostrado: false);
      if (mounted) setState(() => _falhou = true);
    } catch (e) {
      registrarErro(FalhaApp.inesperada(CarreiraRepositorio.prefixo, e), tela: 'inicio', mostrado: false);
      if (mounted) setState(() => _falhou = true);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LinhaDoTempo?>(
        valueListenable: CarreiraRepositorio.emUso,
        builder: (context, linha, _) {
          // Sem dados (falhou ou ainda sem nada no SIGRH), o card não ocupa a Início.
          if (linha == null) return _falhou ? const SizedBox.shrink() : const Esqueleto(child: BlocoEsqueleto(altura: 150, raio: 18));
          if (linha.marcos.isEmpty) return const SizedBox.shrink();
          final ultimo = linha.marcos.lastWhere((m) => !m.semData, orElse: () => linha.marcos.last);
          final anos = linha.anosNaPmrr;
          final itens = [
            ('cursos', linha.conta({'curso'})),
            ('elogios', linha.conta({'elogio', 'mencao'})),
            ('medalhas', linha.conta({'medalha', 'condecoracao'})),
            ('promoções', linha.conta({'promocao'})),
          ];
          return CartaoArte(
            arte: Arte.de('rh'),
            padding: kPaddingCartao,
            onTap: () {
              registrar('inicio.card_tocar', chave: 'home.carreira');
              Navigator.of(context).pushNamed(AppRoutes.CARREIRA);
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              CabecalhoCartao(
                icone: Icons.timeline_rounded,
                titulo: 'Sua carreira',
                meta: anos == null ? null : '$anos ${anos == 1 ? 'ano' : 'anos'} de PMRR',
              ),
              const SizedBox(height: 12),
              Row(children: [
                for (final (rotulo, n) in itens)
                  Expanded(child: ParCartao(rotulo: rotulo, valor: '$n')),
              ]),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: 'Mais recente: ',
                    style: TextStyle(color: TomCartao.medio(context)),
                  ),
                  TextSpan(
                    text: ultimo.titulo,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Arte.de('rh').destaque),
                  ),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ]),
          );
        },
      );
}
