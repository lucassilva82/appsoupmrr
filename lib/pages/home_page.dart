import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projetonovo/widgets/HomeContrachequeCard.dart';
import 'package:projetonovo/widgets/HomePlanoFeriasCard.dart';
import 'package:projetonovo/widgets/anuncio_institucional.dart';
import 'package:projetonovo/widgets/card_tempo_servico.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/features/comunicados/comunicados_page.dart';
import 'package:projetonovo/core/ambiente_app.dart';
import 'package:projetonovo/features/inicio/card_painel.dart';
import 'package:projetonovo/features/versao/tela_atualizacao.dart';
import 'package:projetonovo/features/inicio/personalizar_inicio_page.dart';
import 'package:projetonovo/features/inicio/preferencias_inicio.dart';
import 'package:projetonovo/features/pendencias/pendencias_page.dart';
import 'package:projetonovo/features/inicio/faixa_comando.dart';
import 'package:projetonovo/features/inicio/linha_atalhos.dart';
import 'package:projetonovo/widgets/vidro.dart';
import 'package:projetonovo/widgets/widget_dicas_app.dart';

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

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: child,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // O anúncio de abertura respeita o bloco desligado no painel.
      // Com a central pela API, o destaque de abertura vem do BlocoComunicados.
      final config = RepositorioConfig.atual;
      if (mounted && config.blocoLigado('home.anuncio') && config.fonteComunicados != 'api') {
        AnuncioInstitucional.mostrarSeAtivo(context);
      }
    });
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
        'home.dicas' => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: WidgetDicasApp()),
        'home.atalhos' => const Padding(
            padding: EdgeInsets.only(top: 12), child: LinhaAtalhos()),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FundoSuave(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                for (final chave in blocosDaInicio(RepositorioConfig.atual, InicioPreferenciasRepositorio.emUso.value))
                  if (_bloco(chave) case final w?) w,
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

          // ── Rodapé DTI ───────────────────────────────────────────────────
          // A arte é um bloco navy fechado e virava um retângulo no fim da
          // tela. Aqui ela perde opacidade e as quatro bordas somem em
          // degradê, então encosta no fundo sem desenhar uma caixa.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Opacity(
              opacity: 0.55,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.30, 0.70, 1.0],
                ).createShader(rect),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.18, 0.82, 1.0],
                  ).createShader(rect),
                  child: Image.asset(
                    'assets/imagens/dti.jpeg',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
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
