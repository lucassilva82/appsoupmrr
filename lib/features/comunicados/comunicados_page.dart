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
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import 'comunicados_repositorio.dart';

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
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Text('Comunicados', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (novos > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(novos == 1 ? '1 novo' : '$novos novos',
                          style:
                              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => abrirCentral(context, origem: 'inicio'),
                    child: const Text('Ver todos ›'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Semantics(
              label: 'Comunicado ${_atual + 1} de ${lista.length}',
              child: GestureDetector(
                onLongPressStart: (_) => setState(() => _segurando = true),
                onLongPressEnd: (_) => setState(() => _segurando = false),
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(220).clamp(220, 300),
                  child: PageView.builder(
                    controller: _paginas,
                    padEnds: false,
                    itemCount: lista.length,
                    onPageChanged: (i) => setState(() => _atual = i),
                    itemBuilder: (context, i) => Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
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
          ]),
        );
      },
    );
  }
}

/// Cartão do carrossel e da central, na anatomia aprovada (§4.2): arte da
/// categoria, categoria em caixa alta, título grande, resumo, pílulas e o
/// rodapé com origem e data.
class CartaoComunicado extends StatelessWidget {
  const CartaoComunicado({super.key, required this.comunicado, required this.aoTocar, this.compacto = false});

  final Comunicado comunicado;
  final VoidCallback aoTocar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = comunicado;
    const branco = Colors.white;
    final suave = Colors.white.withValues(alpha: 0.82);
    return Semantics(
      button: true,
      label: '${c.categoria.nome}. ${c.titulo}. ${c.resumo}'
          '${c.urgente ? '. Urgente' : ''}${c.cienciaPendente ? '. Ciência pendente' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: FundoArte(
            arte: c.categoria.arte,
            tamanhoIcone: compacto ? 72 : 104,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(c.categoria.icone, size: 16, color: suave),
                  Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 8), color: suave),
                  Flexible(
                    child: Text(c.categoria.nome.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: suave)),
                  ),
                  if (!c.lido) ...[
                    const SizedBox(width: 8),
                    _Pilula(texto: 'Novo', cor: Colors.white.withValues(alpha: 0.22)),
                  ],
                ]),
                const SizedBox(height: 10),
                // Título e resumo dividem o espaço que sobra: com fonte grande
                // o resumo encolhe (reticências) em vez de estourar o cartão.
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Flexible(
                      child: FractionallySizedBox(
                        widthFactor: compacto ? 1 : 0.8,
                        child: Text(c.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compacto ? 18 : 22,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: branco)),
                      ),
                    ),
                    if (c.resumo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Flexible(
                        child: FractionallySizedBox(
                          widthFactor: compacto ? 1 : 0.8,
                          child: Text(c.resumo,
                              maxLines: compacto ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: suave)),
                        ),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (c.pilula != null)
                    _Pilula(texto: c.pilula!.texto, icone: c.pilula!.icone, cor: Colors.white.withValues(alpha: 0.18)),
                  if (c.urgente)
                    const _Pilula(texto: 'Urgente', icone: Icons.priority_high_rounded, cor: Color(0xFFB3261E)),
                  if (c.cienciaPendente)
                    const _Pilula(
                        texto: 'Ciência pendente', icone: Icons.pending_actions_outlined, cor: Color(0xFF8A5A00)),
                ]),
                const SizedBox(height: 10),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Text('${c.origem}${c.inicio != null ? ' · ${_data(c.inicio)}' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: suave)),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                    child: const Icon(Icons.arrow_forward_rounded, size: 16, color: branco),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.texto, required this.cor, this.icone});
  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[Icon(icone, size: 12, color: Colors.white), const SizedBox(width: 4)],
          Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );
}

// ── Navegação ────────────────────────────────────────────────────────────────

Future<void> abrirCentral(BuildContext context, {required String origem}) {
  registrar('tela.abrir', chave: _chave, dados: {'de': origem});
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CentralComunicadosPage()));
}

Future<void> abrirComunicado(BuildContext context, Comunicado c, ComunicadosRepositorio repo,
    {required String origem}) {
  registrar('comunicado.ver', chave: _chave, dados: {'id': c.id, 'de': origem});
  return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: origem == 'abertura', builder: (_) => ComunicadoPage(comunicado: c, repositorio: repo)));
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
            if (lista == null) return const Center(child: CircularProgressIndicator());
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
                  Text('Publicações oficiais do Comando e das diretorias para a tropa.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    for (final (f, rotulo) in [
                      (_Filtro.todos, 'Todos'),
                      (_Filtro.naoLidos, 'Não lidos'),
                      (_Filtro.ciencia, 'Ciência pendente'),
                    ])
                      ChoiceChip(
                        label: Text(rotulo),
                        selected: _filtro == f,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  if (_carregando) const LinearProgressIndicator(minHeight: 2),
                  if (filtrada.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(children: [
                        Icon(Icons.campaign_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(lista.isEmpty ? 'Nenhum comunicado no ar agora.' : 'Nada neste filtro.',
                            style: theme.textTheme.bodyMedium),
                      ]),
                    ),
                  for (final c in filtrada)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        height: 184,
                        child: CartaoComunicado(
                          comunicado: c,
                          compacto: true,
                          aoTocar: () {
                            registrar('comunicado.abrir', chave: _chave, dados: {'id': c.id, 'de': 'central'});
                            abrirComunicado(context, c, _repo, origem: 'central');
                          },
                        ),
                      ),
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

// ── Detalhe ──────────────────────────────────────────────────────────────────

class ComunicadoPage extends StatefulWidget {
  const ComunicadoPage({super.key, required this.comunicado, required this.repositorio});
  final Comunicado comunicado;
  final ComunicadosRepositorio repositorio;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _c;
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Comunicado'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SizedBox(
              height: 132,
              child: FundoArte(
                arte: c.categoria.arte,
                tamanhoIcone: 110,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(children: [
                      Icon(c.categoria.icone, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(c.categoria.nome.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(c.titulo, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${c.origem}${c.inicio != null ? ' · ${_data(c.inicio)}' : ''}', style: theme.textTheme.bodySmall),
            if (c.urgente || c.ciencia) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                if (c.urgente) const _Pilula(texto: 'Urgente', cor: Color(0xFFB3261E)),
                if (c.ciencia)
                  _Pilula(
                      texto: c.ciente
                          ? 'Ciência registrada'
                          : c.cienciaPrazo != null
                              ? 'Ciência até ${_data(c.cienciaPrazo)}'
                              : 'Pede ciência',
                      cor: c.ciente ? const Color(0xFF14713B) : const Color(0xFF8A5A00)),
              ]),
            ],
            const SizedBox(height: 16),
            CartaoVidro(
              padding: const EdgeInsets.all(16),
              child: SelectableText(c.texto, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
            ),
            if (c.ciencia) ...[
              const SizedBox(height: 20),
              if (c.ciente)
                Row(children: [
                  Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Você já deu ciência deste comunicado.')),
                ])
              else
                ElevatedButton.icon(
                  onPressed: _enviando ? null : _ciente,
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.task_alt),
                  label: const Text('Estou ciente'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
