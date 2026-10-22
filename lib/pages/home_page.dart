import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projetonovo/widgets/HomeContrachequeCard.dart';
import 'package:projetonovo/widgets/HomePlanoFeriasCard.dart';
import 'package:projetonovo/widgets/anuncio_institucional.dart';
import 'package:projetonovo/widgets/card_tempo_servico.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/features/inicio/faixa_comando.dart';
import 'package:projetonovo/features/inicio/linha_atalhos.dart';
import 'package:projetonovo/widgets/vidro.dart';
import 'package:projetonovo/widgets/widget_dicas_app.dart';

/// Ordem dos blocos: a do painel, ou a padrão do app (§4).
List<String> blocosDaInicio(AppConfig config) => config.home == null
    ? const [
        'home.comandantes',
        'home.anuncio',
        'home.dicas',
        'home.pendencias',
        'home.atalhos',
        'home.contracheque',
        'home.tempo_servico',
        'home.ferias',
      ]
    : [for (final b in [...config.home!]..sort((x, y) => x.ordem.compareTo(y.ordem))) b.chave];

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

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // O anúncio de abertura respeita o bloco desligado no painel.
      if (mounted && RepositorioConfig.atual.blocoLigado('home.anuncio')) {
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
        'home.dicas' => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: WidgetDicasApp()),
        'home.atalhos' => const Padding(
            padding: EdgeInsets.only(top: 12), child: LinhaAtalhos()),
        'home.contracheque' => const _Card(HomeContrachequeCard()),
        'home.tempo_servico' => _Card(CardTempoServico()),
        'home.ferias' => const _Card(HomePlanoFeriasCard()),
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
          // ── Blocos na ordem do painel (§4); sem `home`, a do app ──────
          ValueListenableBuilder<AppConfig>(
            valueListenable: RepositorioConfig.emUso,
            builder: (context, config, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final chave in blocosDaInicio(config))
                  if (_bloco(chave) case final w?) w,
              ],
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
