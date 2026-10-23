import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/arte_cartao.dart';
import '../../core/erros/estado_erro.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import '../pendencias/pendencias_repositorio.dart';
import 'comunicados_repositorio.dart';
import '../../core/design/esqueleto.dart';

const _chave = 'com.central';

ComunicadosRepositorio repositorioComunicados(BuildContext context) {
  final auth = context.read<Auth>();
  return ComunicadosRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}

const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
String _data(DateTime? d) => d == null ? '' : '${d.day} ${_meses[d.month - 1]}';

// ── Bloco da Início: carrossel (§4.2) ────────────────────────────────────────

/// Carrossel dos comunicados no ar. Some quando não há nenhum (ou quando a
/// leitura falha: o erro vai para o log com o código, e a Início segue).
class BlocoComunicados extends StatefulWidget {
  const BlocoComunicados({super.key, this.repositorio});

  /// Só para testes; na tela vem da sessão.
  final ComunicadosRepositorio? repositorio;

  @override
  State<BlocoComunicados> createState() => _BlocoComunicadosState();
}

class _BlocoComunicadosState extends State<BlocoComunicados> {
  static const _intervalo = Duration(milliseconds: 6500);
  final _paginas = PageController(viewportFraction: 0.86);
  Timer? _timer;
  int _atual = 0;
  bool _segurando = false;
  late final ComunicadosRepositorio _repo = widget.repositorio ?? repositorioComunicados(context);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _repo.listar();
      if (mounted) _abrirDestaque(lista);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'inicio', mostrado: false);
    } catch (e) {
      registrarErro(FalhaApp.inesperada(ComunicadosRepositorio.prefixo, e), tela: 'inicio', mostrado: false);
    }
  }

  /// O destaque de abertura aparece uma vez por comunicado e versão; se o
  /// painel pediu "até dar ciência", volta enquanto ela faltar.
  Future<void> _abrirDestaque(List<Comunicado> lista) async {
    final c = lista.where((c) => c.destaqueAbertura).firstOrNull;
    if (c == null) return;
    final marca = 'comunicado_abertura_${c.id}_${c.versao}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final repetir = c.aberturaAteCiencia && c.cienciaPendente;
      if (prefs.getBool(marca) == true && !repetir) return;
      await prefs.setBool(marca, true);
    } catch (_) {/* sem preferências, mostra mesmo assim */}
    if (!mounted) return;
    await abrirComunicado(context, c, _repo, origem: 'abertura');
    registrar('comunicado.popup_fechar', chave: _chave, dados: {'id': c.id});
  }

  void _agendar(int total) {
    _timer?.cancel();
    if (total < 2 || _segurando || MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer(_intervalo, () {
      if (!mounted || !_paginas.hasClients) return;
      final prox = (_atual + 1) % total;
      _paginas.animateToPage(prox, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<List<Comunicado>?>(
      valueListenable: ComunicadosRepositorio.emUso,
      builder: (context, lista, _) {
        if (lista == null || lista.isEmpty) return const SizedBox.shrink();
        if (_atual >= lista.length) _atual = 0;
        _agendar(lista.length);
        final novos = lista.where((c) => !c.lido).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CabecalhoSecao(
              titulo: 'Comunicados',
              pilula: novos > 0 ? (novos == 1 ? '1 novo' : '$novos novos') : null,
              verTodos: () => abrirCentral(context, origem: 'inicio'),
            ),
          ),
          Semantics(
            label: 'Comunicado ${_atual + 1} de ${lista.length}',
            child: GestureDetector(
              onLongPressStart: (_) => setState(() => _segurando = true),
              onLongPressEnd: (_) => setState(() => _segurando = false),
              child: SizedBox(
                height: MediaQuery.textScalerOf(context).scale(236).clamp(236, 310),
                child: PageView.builder(
                  controller: _paginas,
                  padEnds: false,
                  itemCount: lista.length,
                  onPageChanged: (i) => setState(() => _atual = i),
                  itemBuilder: (context, i) => Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
                    // O cartão que não está na frente fica menor e mais
                    // apagado (protótipo: escala .95, opacidade .72).
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      scale: i == _atual ? 1 : .95,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: i == _atual ? 1 : .72,
                        child: CartaoComunicado(
                          comunicado: lista[i],
                          aoTocar: () {
                            registrar('comunicado.abrir', chave: _chave, dados: {'id': lista[i].id, 'de': 'inicio'});
                            abrirComunicado(context, lista[i], _repo, origem: 'inicio');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Pontos: pequenos no desenho, área de toque de 44 pt (§4.2).
          SizedBox(
            height: 22,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < lista.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _atual ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: i == _atual ? 0.55 : 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Cartão do carrossel e da central, na anatomia aprovada (§4.2; medidas do
/// protótipo `.com-card`): vidro tingido pela cor da categoria, brilho no
/// canto, a ilustração de duas folhas de vidro com o ícone do assunto sobre
/// um anel de luz, categoria em caixa alta, título grande, resumo, pílulas e
/// o rodapé com origem, data e a seta.
class CartaoComunicado extends StatelessWidget {
  const CartaoComunicado({super.key, required this.comunicado, required this.aoTocar, this.compacto = false});

  final Comunicado comunicado;
  final VoidCallback aoTocar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = comunicado;
    final cor = c.categoria.cor;
    final claro = Color.lerp(cor, Colors.white, .45)!;
    const branco = Colors.white;
    final raio = BorderRadius.circular(24);
    return Semantics(
      button: true,
      label: '${c.categoria.nome}. ${c.titulo}. ${c.resumo}'
          '${c.urgente ? '. Urgente' : ''}${c.cienciaPendente ? '. Ciência pendente' : ''}',
      excludeSemantics: true,
      child: FundoComunicado(
        cor: cor,
        raio: raio,
        icone: c.iconeAssunto,
        comIlustracao: !compacto,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(c.categoria.icone, size: 20, color: branco.withValues(alpha: .92)),
                  Container(
                      width: 1,
                      height: 17,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: branco.withValues(alpha: .28)),
                  Flexible(
                    child: Text(c.categoria.nome.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11.5, letterSpacing: 1.84, fontWeight: FontWeight.w600, color: claro)),
                  ),
                  if (!c.lido) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: .42),
                        border: Border.all(color: cor.withValues(alpha: .6)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('NOVO',
                          style: TextStyle(
                              fontSize: 10.5, letterSpacing: .42, fontWeight: FontWeight.w600, color: branco)),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                // Título e resumo dividem o espaço que sobra: com fonte grande
                // o resumo encolhe (reticências) em vez de estourar o cartão.
                Expanded(
                  child: FractionallySizedBox(
                    widthFactor: compacto ? 1 : 0.62,
                    alignment: Alignment.topLeft,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Flexible(
                        child: Text(c.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compacto ? 18 : 22,
                                height: 1.12,
                                letterSpacing: -.44,
                                fontWeight: FontWeight.w700,
                                color: branco)),
                      ),
                      if (c.resumo.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Flexible(
                          child: Text(c.resumo,
                              maxLines: compacto ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5, height: 1.3, color: Color(0xC7E2E8FF))),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (c.pilula != null)
                    _Pilula(
                        texto: c.pilula!.texto,
                        icone: c.pilula!.icone,
                        fundo: branco.withValues(alpha: .06),
                        borda: branco.withValues(alpha: .22),
                        cor: branco),
                  if (c.cienciaPendente)
                    const _Pilula(
                        texto: 'Ciência pendente',
                        icone: Icons.edit_note_rounded,
                        fundo: Color(0x1FFFC968),
                        borda: Color(0x80FFC968),
                        cor: Color(0xFFFFD892)),
                  if (c.urgente)
                    const _Pilula(
                        texto: 'Urgente',
                        icone: Icons.priority_high_rounded,
                        fundo: Color(0x29E5484D),
                        borda: Color(0x99FF9E9E),
                        cor: Color(0xFFFFB4B4)),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: cor.withValues(alpha: .32)))),
                  child: Row(children: [
                    Expanded(
                      child: Text('${c.origem}${c.inicio != null ? ' · ${_data(c.inicio)}' : ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: claro)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, border: Border.all(color: branco.withValues(alpha: .3))),
                      child: const Icon(Icons.arrow_forward_rounded, size: 20, color: branco),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// O fundo dos comunicados (protótipo `.cc-bg`): degradê da cor da
/// categoria sobre o escuro, brilho no canto, a ilustração de vidro e o véu
/// embaixo. Serve ao cartão do carrossel e ao topo do comunicado aberto.
class FundoComunicado extends StatelessWidget {
  const FundoComunicado({
    super.key,
    required this.cor,
    required this.icone,
    required this.child,
    this.raio = BorderRadius.zero,
    this.comIlustracao = true,
    this.ilustracaoTopo = 34,
    this.ilustracaoDireita = 10,
    this.borda = true,
  });

  final Color cor;
  final IconData icone;
  final Widget child;
  final BorderRadius raio;
  final bool comIlustracao;
  final double ilustracaoTopo;
  final double ilustracaoDireita;
  final bool borda;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        border: borda ? Border.all(color: cor.withValues(alpha: .48)) : null,
        // linear-gradient(160deg, cor misturada ao fundo escuro)
        gradient: LinearGradient(
          begin: const Alignment(-0.34, -1),
          end: const Alignment(0.34, 1),
          colors: [Color.lerp(cor, const Color(0xFF0B1220), .72)!, Color.lerp(cor, const Color(0xFF060B14), .88)!],
        ),
      ),
      child: ClipRRect(
        borderRadius: raio,
        child: Stack(children: [
          // radial-gradient(110% 85% at 100% 0%, cor .46, 0 58%)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1, -1),
                  radius: 1.1,
                  stops: const [0, .58],
                  colors: [cor.withValues(alpha: .46), cor.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          if (comIlustracao)
            Positioned(
                top: ilustracaoTopo,
                right: ilustracaoDireita,
                width: 100,
                height: 120,
                child: _Ilustracao(cor: cor, icone: icone)),
          // Véu embaixo: linear-gradient(transparente 28%, preto .66).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [.28, 1],
                  colors: [Color(0x00000000), Color(0xA8000000)],
                ),
              ),
            ),
          ),
          child,
        ]),
      ),
    );
  }
}

/// A ilustração de vidro do cartão: anel de luz, uma folha de trás
/// inclinada para a esquerda e a da frente, com o ícone do assunto e duas
/// linhas de "texto".
class _Ilustracao extends StatelessWidget {
  const _Ilustracao({required this.cor, required this.icone});
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final vidro = BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Color.lerp(cor, Colors.white, .1)!.withValues(alpha: .72)),
      gradient: LinearGradient(
        begin: const Alignment(-0.34, -1),
        end: const Alignment(0.34, 1),
        colors: [
          Color.lerp(cor, Colors.white, .15)!.withValues(alpha: .55),
          Color.lerp(cor, Colors.white, .1)!.withValues(alpha: .2),
        ],
      ),
    );
    return ExcludeSemantics(
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: -28,
          top: -34,
          width: 150,
          height: 150,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
              gradient: RadialGradient(
                center: const Alignment(.4, -.5),
                stops: const [0, .66],
                colors: [cor.withValues(alpha: .42), cor.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Positioned(
          left: -2,
          top: 10,
          width: 74,
          height: 91,
          child: Opacity(
            opacity: .5,
            child: Transform.rotate(angle: -9 * 3.14159 / 180, child: DecoratedBox(decoration: vidro)),
          ),
        ),
        Positioned(
          left: 22,
          top: 2,
          width: 77,
          height: 97,
          child: Transform.rotate(
            angle: 6 * 3.14159 / 180,
            child: DecoratedBox(
              decoration: vidro.copyWith(boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .35),
                    offset: const Offset(0, 14),
                    blurRadius: 30,
                    spreadRadius: -6),
              ]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icone, size: 40, color: Colors.white.withValues(alpha: .9)),
                const SizedBox(height: 4),
                Container(
                    width: 41,
                    height: 8,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .32), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 3),
                Container(
                    width: 28,
                    height: 6,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .32), borderRadius: BorderRadius.circular(2))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.texto, required this.fundo, required this.borda, required this.cor, this.icone});
  final String texto;
  final Color fundo;
  final Color borda;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration:
            BoxDecoration(color: fundo, border: Border.all(color: borda), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[Icon(icone, size: 16, color: cor), const SizedBox(width: 6)],
          Text(texto, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: cor)),
        ]),
      );
}

// ── Navegação ────────────────────────────────────────────────────────────────

Future<void> abrirCentral(BuildContext context, {required String origem}) {
  registrar('tela.abrir', chave: _chave, dados: {'de': origem});
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CentralComunicadosPage()));
}

/// O comunicado abre como um cartão por cima da tela (protótipo
/// `.com-modal`): cresce e aparece em 400 ms; sem animação com "Reduzir
/// movimento". Cobre também a barra de abas.
Future<void> abrirComunicado(BuildContext context, Comunicado c, ComunicadosRepositorio repo,
    {required String origem}) {
  registrar('comunicado.ver', chave: _chave, dados: {'id': c.id, 'de': origem});
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Fechar comunicado',
    barrierColor: const Color(0x6B000000),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, __, ___) => ComunicadoPage(comunicado: c, repositorio: repo, origem: origem),
    transitionBuilder: (ctx, a, _, filho) {
      if (MediaQuery.disableAnimationsOf(ctx)) return filho;
      final curva = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curva,
        child: ScaleTransition(scale: Tween<double>(begin: .92, end: 1).animate(curva), child: filho),
      );
    },
  );
}

// ── Central (com.central) ────────────────────────────────────────────────────

class CentralComunicadosPage extends StatefulWidget {
  const CentralComunicadosPage({super.key, this.repositorio});
  final ComunicadosRepositorio? repositorio;

  @override
  State<CentralComunicadosPage> createState() => _CentralComunicadosPageState();
}

enum _Filtro { todos, naoLidos, ciencia }

class _CentralComunicadosPageState extends State<CentralComunicadosPage> {
  late final ComunicadosRepositorio _repo = widget.repositorio ?? repositorioComunicados(context);
  FalhaApp? _falha;
  bool _carregando = false;
  _Filtro _filtro = _Filtro.todos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _falha = null;
    });
    try {
      await _repo.listar();
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    } catch (e) {
      final f = FalhaApp.inesperada(ComunicadosRepositorio.prefixo, e);
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Comunicados'),
        body: ValueListenableBuilder<List<Comunicado>?>(
          valueListenable: ComunicadosRepositorio.emUso,
          builder: (context, lista, _) {
            if (_falha != null && lista == null) return EstadoErro(falha: _falha!, aoTentar: _carregar);
            if (lista == null) return const EsqueletoLista();
            final filtrada = switch (_filtro) {
              _Filtro.todos => lista,
              _Filtro.naoLidos => lista.where((c) => !c.lido).toList(),
              _Filtro.ciencia => lista.where((c) => c.cienciaPendente).toList(),
            };
            return RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                    child: Text(
                        'Comunicados oficiais do Comando e das diretorias. Os que abriram como aviso na entrada do app também ficam aqui.',
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (f, rotulo) in [
                      (_Filtro.todos, 'Todos'),
                      (_Filtro.naoLidos, 'Não lidos'),
                      (_Filtro.ciencia, 'Ciência pendente'),
                    ])
                      _ChipFiltro(rotulo: rotulo, ativo: _filtro == f, aoTocar: () => setState(() => _filtro = f)),
                  ]),
                  const SizedBox(height: 12),
                  if (_carregando) const LinearProgressIndicator(minHeight: 2),
                  CartaoVidro(
                    raio: 16,
                    padding: EdgeInsets.zero,
                    child: filtrada.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
                            child: Center(
                              child: Text(
                                  lista.isEmpty ? 'Nenhum comunicado no ar agora.' : 'Nenhum comunicado neste filtro.',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .62))),
                            ),
                          )
                        : Column(children: [
                            for (final c in filtrada)
                              _LinhaComunicado(
                                comunicado: c,
                                aoTocar: () {
                                  registrar('comunicado.abrir', chave: _chave, dados: {'id': c.id, 'de': 'central'});
                                  abrirComunicado(context, c, _repo, origem: 'central');
                                },
                              ),
                          ]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Filtro da central (protótipo `.chip`, ativo em `aria-pressed`).
class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({required this.rotulo, required this.ativo, required this.aoTocar});
  final String rotulo;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: ativo,
      child: Material(
        color: ativo ? pri.withValues(alpha: .16) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: ativo ? Colors.transparent : theme.colorScheme.onSurface.withValues(alpha: .12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(rotulo,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                      color: ativo ? pri : theme.colorScheme.onSurface)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha da central: miniatura com a cor da categoria, título (negrito se
/// não lido), resumo e as etiquetas (protótipo, central de comunicados).
class _LinhaComunicado extends StatelessWidget {
  const _LinhaComunicado({required this.comunicado, required this.aoTocar});
  final Comunicado comunicado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = comunicado;
    final escuro = theme.brightness == Brightness.dark;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final ok = escuro ? const Color(0xFF6EE7A0) : const Color(0xFF14713B);
    final d = c.inicio;
    String dois(int n) => n.toString().padLeft(2, '0');
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 56,
            height: 56,
            child: FundoComunicado(
              cor: c.categoria.cor,
              icone: c.iconeAssunto,
              comIlustracao: false,
              raio: BorderRadius.circular(14),
              child: Center(child: Icon(c.iconeAssunto, color: Colors.white, size: AppIconSize.md)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.titulo,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: c.lido ? FontWeight.w500 : FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
              if (c.resumo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(c.resumo, style: TextStyle(fontSize: 12.5, color: mudo)),
                ),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _Selo(c.categoria.nome, cor: mudo, fundo: theme.colorScheme.onSurface.withValues(alpha: .06)),
                if (c.urgente) _Selo('Urgente', cor: theme.colorScheme.error),
                if (c.ciencia) c.ciente ? _Selo('Ciente', cor: ok) : const _Selo('Ciência pendente', cor: kCorAtencao),
                if (d != null) Text('${dois(d.day)}/${dois(d.month)}', style: TextStyle(fontSize: 12.5, color: mudo)),
              ]),
            ]),
          ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Icon(Icons.chevron_right_rounded,
                  size: AppIconSize.sm, color: theme.colorScheme.onSurface.withValues(alpha: .38)),
            ),
        ]),
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo(this.texto, {required this.cor, this.fundo});
  final String texto;
  final Color cor;
  final Color? fundo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: fundo ?? cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor, height: 1.5)),
      );
}

// ── Detalhe ──────────────────────────────────────────────────────────────────

class ComunicadoPage extends StatefulWidget {
  const ComunicadoPage({super.key, required this.comunicado, required this.repositorio, this.origem = 'inicio'});
  final Comunicado comunicado;
  final ComunicadosRepositorio repositorio;

  /// De onde abriu: da central, "Ver todos" só fecha o cartão.
  final String origem;

  @override
  State<ComunicadoPage> createState() => _ComunicadoPageState();
}

class _ComunicadoPageState extends State<ComunicadoPage> {
  late Comunicado _c = widget.comunicado;
  bool _enviando = false;
  final _aberto = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.repositorio.marcarLido(_c).then((_) {
      if (mounted) setState(() => _c = _c.copiar(lido: true));
    }).catchError((Object e) {
      // Marcar lido não é essencial: a falha vai para o log e a leitura segue.
      registrarErro(e is FalhaApp ? e : FalhaApp.inesperada(ComunicadosRepositorio.prefixo, e),
          tela: _chave, mostrado: false);
    });
  }

  @override
  void dispose() {
    registrar('tela.sair',
        chave: _chave, dados: {'id': _c.id, 'segundos': DateTime.now().difference(_aberto).inSeconds});
    super.dispose();
  }

  Future<void> _ciente() async {
    setState(() => _enviando = true);
    try {
      await widget.repositorio.darCiencia(_c);
      registrar('comunicado.ciencia', chave: _chave, dados: {'id': _c.id, 'versao': _c.versao});
      PendenciasRepositorio.algoMudou();
      if (!mounted) return;
      setState(() => _c = _c.copiar(lido: true, ciente: true));
      avisoSucesso(context, 'Ciência registrada');
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      registrar('comunicado.ciencia', chave: _chave, resultado: 'falhou', codigo: f.codigo, dados: {'id': _c.id});
      if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    }
    if (mounted) setState(() => _enviando = false);
  }

  void _verTodos() {
    final nav = Navigator.of(context);
    nav.pop();
    if (widget.origem != 'central') abrirCentral(nav.context, origem: 'comunicado');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _c;
    final escuro = theme.brightness == Brightness.dark;
    final cor = c.categoria.cor;
    final claro = Color.lerp(cor, Colors.white, .45)!;
    const branco = Colors.white;
    final mq = MediaQuery.of(context);
    final ok = escuro ? const Color(0xFF6EE7A0) : const Color(0xFF14713B);
    final paragrafos = c.texto.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty);

    final topo = FundoComunicado(
      cor: cor,
      icone: c.iconeAssunto,
      borda: false,
      ilustracaoTopo: 60,
      ilustracaoDireita: 16,
      child: Container(
        constraints: const BoxConstraints(minHeight: 250),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cor.withValues(alpha: .40)))),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: IntrinsicHeight(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Row(children: [
                Icon(c.categoria.icone, size: 20, color: branco.withValues(alpha: .92)),
                Container(
                    width: 1,
                    height: 17,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: branco.withValues(alpha: .28)),
                Flexible(
                  child: Text(c.categoria.nome.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, letterSpacing: 1.84, fontWeight: FontWeight.w600, color: claro)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: .66,
              child: Text(c.titulo,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22, height: 1.12, letterSpacing: -.44, fontWeight: FontWeight.w700, color: branco)),
            ),
            const SizedBox(height: 14),
            const Spacer(),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (c.pilula != null)
                _Pilula(
                    texto: c.pilula!.texto,
                    icone: c.pilula!.icone,
                    fundo: branco.withValues(alpha: .06),
                    borda: branco.withValues(alpha: .22),
                    cor: branco),
              if (c.ciencia)
                c.ciente
                    ? const _Pilula(
                        texto: 'Ciência registrada',
                        icone: Icons.task_alt_rounded,
                        fundo: Color(0x1F6EE7A0),
                        borda: Color(0x806EE7A0),
                        cor: Color(0xFF9FF0C0))
                    : _Pilula(
                        texto: c.cienciaPrazo != null ? 'Ciência até ${_data(c.cienciaPrazo)}' : 'Ciência pendente',
                        icone: Icons.edit_note_rounded,
                        fundo: const Color(0x1FFFC968),
                        borda: const Color(0x80FFC968),
                        cor: const Color(0xFFFFD892)),
              if (c.urgente)
                const _Pilula(
                    texto: 'Urgente',
                    icone: Icons.priority_high_rounded,
                    fundo: Color(0x29E5484D),
                    borda: Color(0x99FF9E9E),
                    cor: Color(0xFFFFB4B4)),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cor.withValues(alpha: .32)))),
              child: Text('${c.origem}${c.inicio != null ? ' · ${_data(c.inicio)}' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: claro)),
            ),
          ]),
        ),
      ),
    );

    final corpo = <Widget>[
      for (final p in paragrafos)
        SelectableText(p, style: TextStyle(fontSize: 15.5, height: 1.5, color: theme.colorScheme.onSurface)),
      if (c.ciencia)
        if (c.ciente)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: ok.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.verified_rounded, size: AppIconSize.sm, color: ok),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Ciência registrada',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ok))),
            ]),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kCorAtencao.withValues(alpha: .12),
              border: Border.all(color: kCorAtencao.withValues(alpha: .35)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.edit_note_rounded, color: kCorAtencao),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'O Comando pede que você confirme a leitura. A confirmação fica registrada com data e hora.',
                    style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface)),
              ),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: _enviando ? null : _ciente,
            icon: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: AppIconSize.sm),
            label: const Text('Estou ciente'),
          ),
        ],
      TextButton(onPressed: _verTodos, child: const Text('Ver todos os comunicados')),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(10, mq.padding.top + 8, 10, mq.padding.bottom + 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: escuro ? const Color(0xFF10161F) : Colors.white,
            elevation: 12,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: c.titulo,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                  child: Stack(children: [
                    topo,
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Semantics(
                        button: true,
                        label: 'Fechar comunicado',
                        excludeSemantics: true,
                        child: Material(
                          color: const Color(0x6B000000),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(Icons.close_rounded, size: AppIconSize.sm, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  sliver: SliverList.separated(
                    itemCount: corpo.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => corpo[i],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
