import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:projetonovo/core/design/arte_cartao.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projetonovo/widgets/HomeContrachequeCard.dart';
import 'package:projetonovo/widgets/HomePlanoFeriasCard.dart';
import 'package:projetonovo/widgets/card_tempo_servico.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/features/comunicados/comunicados_page.dart';
import 'package:projetonovo/core/ambiente_app.dart';
import 'package:projetonovo/features/inicio/card_painel.dart';
import 'package:projetonovo/features/versao/tela_atualizacao.dart';
import 'package:projetonovo/features/inicio/personalizar_inicio_page.dart';
import 'package:projetonovo/features/inicio/preferencias_inicio.dart';
import 'package:projetonovo/features/inicio/edicao_inicio.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/log/registro_log.dart';
import 'package:projetonovo/widgets/aviso_rapido.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/features/pendencias/pendencias_page.dart';
import 'package:projetonovo/features/inicio/faixa_comando.dart';
import 'package:projetonovo/features/inicio/linha_atalhos.dart';
import 'package:projetonovo/widgets/vidro.dart';
import 'package:projetonovo/widgets/widget_dicas_app.dart';
import '../widgets/faixa_sem_conexao.dart';

/// Blocos da Início sem o painel (§4): a ordem padrão do app. Comando,
/// Comunicados e Suas pendências são fixos (o militar não esconde).
List<BlocoInicio> blocosPadrao() => [
      for (final (i, c) in const [
        'home.comandantes',
        'home.anuncio',
        'home.dicas',
        'home.pendencias',
        'home.atalhos',
        'home.contracheque',
        'home.tempo_servico',
        'home.ferias',
      ].indexed)
        BlocoInicio(
            chave: c,
            ordem: (i + 1) * 10,
            escondivel: !const {'home.comandantes', 'home.anuncio', 'home.pendencias'}.contains(c)),
    ];

/// Ordem dos blocos: a do painel (ou a padrão do app) com a escolha do militar.
List<String> blocosDaInicio(AppConfig config, [PreferenciasInicio? pref]) =>
    ordenarBlocos(config.home ?? blocosPadrao(), pref);

class _Card extends StatelessWidget {
  const _Card(this.child);
  final Widget child;

  // Os cards de dado são cards com arte, escuros nos dois temas: as cores
  // que eles tiram do tema precisam ser as de sobre a arte.
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Theme(data: temaSobreArte(Theme.of(context)), child: child),
      );
}

// ── HomeBody ─────────────────────────────────────────────────────────────────
// Conteúdo da aba "Início" dentro do MainShell.
// Não tem Scaffold — o appBar e o bottomNavBar são do MainShell.
class HomeBody extends StatefulWidget {
  const HomeBody({Key? key}) : super(key: key);

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // preserva estado ao trocar de aba

  PreferenciasInicio? _prefServidor;

  // ── Modo de edição na própria Início (§4.5) ────────────────────────────
  // Segurar um bloco entra em edição: os blocos tremem, cada um ganha o
  // botão de esconder e dá para arrastar ali mesmo, sem sair da tela. A tela
  // "Personalizar início" continua existindo — é por lá que se mexe nos
  // atalhos e se restaura o padrão.
  bool _editando = false;
  bool _salvando = false;
  bool _mudou = false;
  List<BlocoInicio> _blocosEdicao = const [];
  Set<String> _escondidosEdicao = {};

  void _entrarEdicao() {
    if (_editando) return;
    final m = montarEdicao(
      RepositorioConfig.atual.home ?? blocosPadrao(),
      InicioPreferenciasRepositorio.emUso.value,
    );
    HapticFeedback.mediumImpact();
    registrar('inicio.editar_abrir', dados: {'blocos': m.blocos.length});
    setState(() {
      _editando = true;
      _mudou = false;
      _blocosEdicao = m.blocos;
      _escondidosEdicao = m.escondidos;
    });
  }

  /// Usa `onReorderItem`, não o `onReorder` antigo: ele já entrega o índice
  /// de destino com a remoção descontada, e a conta na mão era fonte de erro
  /// de um item ao arrastar para baixo.
  void _reordenar(int de, int para) {
    setState(() {
      final lista = [..._blocosEdicao];
      lista.insert(para, lista.removeAt(de));
      _blocosEdicao = lista;
      _mudou = true;
    });
    HapticFeedback.selectionClick();
  }

  void _alternarVisivel(BlocoInicio b) {
    if (!b.escondivel) {
      avisoInfo(context, 'Este bloco não pode ser escondido');
      return;
    }
    setState(() {
      _escondidosEdicao.contains(b.chave)
          ? _escondidosEdicao.remove(b.chave)
          : _escondidosEdicao.add(b.chave);
      _mudou = true;
    });
    HapticFeedback.selectionClick();
  }

  /// Sai da edição. Só fala com o servidor se algo mudou; a escolha já vale
  /// no aparelho antes disso, então falha de rede não desfaz nada.
  Future<void> _concluirEdicao() async {
    if (!_mudou) {
      setState(() => _editando = false);
      return;
    }
    setState(() => _salvando = true);
    final atual = InicioPreferenciasRepositorio.emUso.value;
    final pref = PreferenciasInicio(
      blocos: [
        for (final b in _blocosEdicao)
          (chave: b.chave, visivel: !_escondidosEdicao.contains(b.chave)),
      ],
      atalhos: atual?.atalhos,
    );
    try {
      await repositorioPreferencias(context).salvar(pref);
      registrar('inicio.editar_concluir', dados: {
        'ordem': [for (final b in _blocosEdicao) b.chave],
        'escondidos': _escondidosEdicao.toList(),
      });
      if (mounted) avisoSucesso(context, 'Tela inicial atualizada');
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'inicio_edicao', mostrado: true);
      if (mounted) {
        avisoAtencao(context, 'Guardado só neste aparelho',
            texto: 'A ordem vale aqui, mas não foi para o servidor. ${f.codigo}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
          _editando = false;
        });
      }
    }
  }

  /// A Início do militar: a do servidor (no app_config) vence; sem ela, a
  /// guardada no aparelho. Relê quando chega um app_config novo.
  void _carregarPreferencias() {
    final doServidor = RepositorioConfig.atual.preferencias;
    if (_prefServidor != null && identical(doServidor, _prefServidor)) return;
    _prefServidor = doServidor;
    repositorioPreferencias(context).carregar(doServidor);
  }

  @override
  void dispose() {
    RepositorioConfig.emUso.removeListener(_carregarPreferencias);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _carregarPreferencias();
      RepositorioConfig.emUso.addListener(_carregarPreferencias);
    });
    _requestPermissions();
    // O comunicado de abertura (inclusive no modo cartaz) vem do
    // BlocoComunicados; o anúncio do Firestore ficou só para as 2.1.x.
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      await Permission.storage.request();
      if (sdkInt >= 30) {
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      debugPrint('getPermissions error: $e');
    }
  }

  /// Cada bloco com o espaço de baixo dele (§15.2: 12 entre blocos).
  /// Bloco que esta versão ainda não desenha (comunicados, pendências)
  /// devolve nulo.
  Widget? _bloco(String chave) => switch (chave) {
        'home.comandantes' => FaixaComando(),
        'home.pendencias' => const BlocoPendencias(),
        'home.anuncio' when RepositorioConfig.atual.fonteComunicados == 'api' => const BlocoComunicados(),
        'home.dicas' => WidgetDicasApp(),
        'home.atalhos' => const LinhaAtalhos(),
        'home.contracheque' => const _Card(HomeContrachequeCard()),
        'home.tempo_servico' => _Card(CardTempoServico()),
        'home.ferias' => const _Card(HomePlanoFeriasCard()),
        _ when chave.startsWith('home.livre.') =>
          switch (RepositorioConfig.atual.bloco(chave)) {
            final b? when CardPainel.desenha(b) => CardPainel(bloco: b),
            _ => null,
          },
        _ => null,
      };

  // ── Peças do modo de edição ───────────────────────────────────────────

  /// Barra do topo: diz em que modo o militar está e como sair.
  Widget _barraEdicao() => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.dashboard_customize_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Segure e arraste para reordenar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              if (_salvando)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                TextButton(
                  onPressed: _concluirEdicao,
                  child: const Text('Concluído',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      );

  /// O lugar de um bloco escondido. Não desenha o bloco de verdade: além de
  /// pesar (alguns consultam a API ao nascer), o que o militar precisa ver
  /// aqui é só o nome e como trazer de volta.
  Widget _fantasma(BlocoInicio b) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(Icons.visibility_off_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nomeBloco(b),
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
                Text('Escondido',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ),
      );

  /// Botão redondo no canto do bloco: tira, traz de volta, ou avisa que o
  /// bloco é fixo. Fica fora do tremor para continuar fácil de acertar.
  Widget _selo(BlocoInicio b, bool escondido) {
    final tema = Theme.of(context);
    final fixo = !b.escondivel;
    final icone = fixo
        ? Icons.lock_outline
        : escondido
            ? Icons.add
            : Icons.remove;
    final cor = fixo
        ? tema.colorScheme.onSurface.withValues(alpha: 0.45)
        : escondido
            ? AppColors.blue
            : tema.colorScheme.error;
    return Semantics(
      button: !fixo,
      label: fixo
          ? '${nomeBloco(b)}: bloco fixo'
          : escondido
              ? 'Mostrar ${nomeBloco(b)}'
              : 'Esconder ${nomeBloco(b)}',
      child: Material(
        color: tema.colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _alternarVisivel(b),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icone, size: 17, color: cor),
          ),
        ),
      ),
    );
  }

  Widget _itemEdicao(BlocoInicio b, int i) {
    final escondido = _escondidosEdicao.contains(b.chave);
    final desenhado = _bloco(b.chave);
    // Bloco que esta versão do app não desenha (comunicados pelo Firestore,
    // por exemplo) não aparece na Início nem aqui. Guarda o lugar na ordem,
    // sem ocupar espaço — chamá-lo de "Escondido" seria mentira: o militar
    // não o escondeu.
    if (!escondido && desenhado == null) {
      return SizedBox.shrink(key: ValueKey(b.chave));
    }
    final conteudo = escondido ? _fantasma(b) : desenhado!;
    return Padding(
      key: ValueKey(b.chave),
      padding: EdgeInsets.zero,
      // Pegar pelo toque longo, e não no toque simples: em edição a lista
      // continua rolando normalmente, que é o que se espera num cartão da
      // largura da tela.
      child: ReorderableDelayedDragStartListener(
        index: i,
        child: BlocoTremendo(
          tremendo: true,
          semente: i,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              conteudo,
              Positioned(left: 20, top: 2, child: _selo(b, escondido)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corpoEdicao() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barraEdicao(),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 6, bottom: 28),
              buildDefaultDragHandles: false,
              itemCount: _blocosEdicao.length,
              onReorderItem: _reordenar,
              itemBuilder: (context, i) => _itemEdicao(_blocosEdicao[i], i),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_editando) return FundoSuave(child: _corpoEdicao());

    return FundoSuave(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        // O fim passa da barra de abas de vidro (a altura dela vem no MediaQuery).
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sem conexão: o que aparece é o guardado (§5.3)
          const FaixaSemConexao(),

          // ── Versão recomendada (§10.2): cartão dispensável, uma vez por versão
          ValueListenableBuilder<AppConfig>(
            valueListenable: RepositorioConfig.emUso,
            builder: (context, config, _) =>
                config.situacaoVersao(AmbienteApp.plataforma, AmbienteApp.versao) == SituacaoVersao.recomendada
                    ? CartaoVersaoRecomendada(recomendada: config.versoes[AmbienteApp.plataforma]!.recomendada)
                    : const SizedBox.shrink(),
          ),

          // ── Blocos na ordem do painel (§4); sem `home`, a do app ──────
          ListenableBuilder(
            listenable: Listenable.merge([RepositorioConfig.emUso, InicioPreferenciasRepositorio.emUso]),
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 12 entre um bloco e outro (protótipo `.pilha`, §15.2).
                for (final chave in blocosDaInicio(RepositorioConfig.atual, InicioPreferenciasRepositorio.emUso.value))
                  if (_bloco(chave) case final w?)
                    // Segurar entra em edição, como na tela do iOS. Para quem
                    // usa leitor de tela o gesto não serve, então a mesma
                    // ação vai no menu de ações do bloco.
                    Semantics(
                      customSemanticsActions: {
                        const CustomSemanticsAction(label: 'Editar a tela inicial'):
                            _entrarEdicao,
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onLongPress: _entrarEdicao,
                        child: Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
                      ),
                    ),
              ],
            ),
          ),

          // ── Personalizar (§4.5) ──────────────────────────────────────────
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PersonalizarInicioPage())),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Personalizar início'),
            ),
          ),

          const SizedBox(height: 8),

          // Texto do rodapé editado no painel (soupm_config 'textos').
          if (RepositorioConfig.atual.texto('rodape_inicio') case final r?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(r,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62))),
            ),
        ],
          ),
        ),
      );
  }
}

// ── HomePage ──────────────────────────────────────────────────────────────────
// Mantida por compatibilidade com rotas existentes.
// Redireciona para o MainShell (que contém o HomeBody na aba 0).
class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const HomeBody();
  }
}
