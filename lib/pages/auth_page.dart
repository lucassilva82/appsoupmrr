import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design/fundo_circuito.dart';
import '../models/auth_model.dart';
import '../utils/app_routes.dart';
import '../widgets/abertura_soupmrr.dart';
import '../widgets/auth_form.dart';
import '../widgets/versao_app.dart';

/// Tela de login da 2.2 (pedido do usuário, 24/10/2026).
///
/// O fundo é a mesma linguagem dos cards com arte do app (degradê
/// azul-marinho, brilho, trilhas de circuito com pulsos de luz e ícones
/// grandes apagados), no lugar da foto. Cada plataforma no seu padrão:
/// - iOS: marca no alto, cartão de vidro com os campos agrupados;
/// - Android: marca na arte do topo e uma folha do Material 3 que sobe com
///   o formulário.
/// Com o teclado aberto, nada é empurrado de qualquer jeito: a marca encolhe
/// e o rodapé some, e o formulário acompanha o teclado com a mesma curva.
class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  /// Montagem da tela: marca, formulário e rodapé, em sequência.
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  static const _curvaTeclado = Curves.easeOutCubic;
  static const _tempoTeclado = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _entrada.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quem pediu menos movimento recebe a tela pronta.
    if (MediaQuery.disableAnimationsOf(context)) _entrada.value = 1;
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  double _trecho(double inicio, double fim, {Curve curva = Curves.easeOutCubic}) =>
      curva.transform(((_entrada.value - inicio) / (fim - inicio)).clamp(0.0, 1.0));

  /// A peça entra subindo e acendendo no trecho [inicio]–[fim] da entrada.
  Widget _surge(double inicio, double fim, Widget filho, {double deslocamento = 24}) => AnimatedBuilder(
        animation: _entrada,
        builder: (_, f) {
          final t = _trecho(inicio, fim);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, deslocamento * (1 - t)), child: f),
          );
        },
        child: filho,
      );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    if (auth.isAuth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE),
      );
    }
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final aberto = teclado > 0;

    // A tela é sempre escura: ícones claros na barra de status.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: FundoCircuito.base,
        // O teclado é tratado aqui, com animação própria: sem isto o Scaffold
        // encolhe a tela de uma vez e tudo "pula" para cima.
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          const Positioned.fill(child: FundoCircuito()),
          Platform.isAndroid ? _android(context, teclado, aberto) : _ios(context, teclado, aberto),
        ]),
      ),
    );
  }

  // ── Marca e rodapé (comuns) ───────────────────────────────────────────────

  Widget _marca(bool aberto, double largura) => AnimatedBuilder(
        animation: _entrada,
        builder: (_, __) => AnimatedContainer(
          duration: _tempoTeclado,
          curve: _curvaTeclado,
          // Com o teclado, a marca encolhe para caber o formulário inteiro.
          width: aberto ? largura * 0.5 : largura,
          child: MarcaSouPMRR(
            largura: aberto ? largura * 0.5 : largura,
            progresso: _trecho(0.0, 0.62, curva: Curves.linear),
            corrente: _trecho(0.62, 0.95, curva: Curves.easeInOutSine),
          ),
        ),
      );

  Widget _lema(bool aberto) => AnimatedSize(
        duration: _tempoTeclado,
        curve: _curvaTeclado,
        child: aberto
            ? const SizedBox(width: double.infinity)
            : _surge(
                0.45,
                0.8,
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'POLÍCIA MILITAR DE RORAIMA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                deslocamento: 10,
              ),
      );

  /// Os três brasões, cada um no seu tamanho, e a versão.
  Widget _rodape(bool aberto) => AnimatedSize(
        duration: _tempoTeclado,
        curve: _curvaTeclado,
        child: aberto
            ? const SizedBox(width: double.infinity)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _surge(
                        0.62,
                        0.9,
                        const _Marca(
                            arquivo: 'assets/imagens/brasao_governo_rr.png', altura: 42, rotulo: 'Governo de Roraima')),
                    _divisor(),
                    _surge(
                        0.68,
                        0.94,
                        const _Marca(
                            arquivo: 'assets/imagens/logo_pmrr.png', altura: 44, rotulo: 'Polícia Militar de Roraima')),
                    _divisor(),
                    _surge(
                        0.74,
                        1.0,
                        const _Marca(
                            arquivo: 'assets/imagens/logo_dti_marca.png',
                            altura: 34,
                            rotulo: 'Departamento de Tecnologia da Informação')),
                  ],
                ),
                const SizedBox(height: 10),
                _surge(
                  0.8,
                  1.0,
                  TextoVersao(
                    formato: (v) => v.isEmpty ? 'DTI/PMRR' : 'Versão $v · DTI/PMRR',
                    estilo: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), letterSpacing: .4),
                  ),
                  deslocamento: 8,
                ),
              ]),
      );

  Widget _divisor() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.white.withValues(alpha: 0.16),
      );

  // ── iOS ───────────────────────────────────────────────────────────────────

  Widget _ios(BuildContext context, double teclado, bool aberto) {
    final larguraMarca = (MediaQuery.sizeOf(context).width * 0.62).clamp(200.0, 300.0);
    return SafeArea(
      child: AnimatedPadding(
        duration: _tempoTeclado,
        curve: _curvaTeclado,
        // Acima do teclado, descontando a área segura que ele já cobre.
        padding: EdgeInsets.only(bottom: math.max(0, teclado - MediaQuery.paddingOf(context).bottom)),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(children: [
                      AnimatedSize(
                        duration: _tempoTeclado,
                        curve: _curvaTeclado,
                        child: SizedBox(height: aberto ? 4 : math.max(12, c.maxHeight * 0.06)),
                      ),
                      _marca(aberto, larguraMarca),
                      _lema(aberto),
                      SizedBox(height: aberto ? 14 : 30),
                      _surge(
                        0.3,
                        0.75,
                        CartaoVidroEntrada(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Entrar',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('Use a matrícula e a senha do SouPMRR.',
                                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.72))),
                            const SizedBox(height: 18),
                            const AuthForm(),
                          ]),
                        ),
                        deslocamento: 36,
                      ),
                      SizedBox(height: aberto ? 8 : 28),
                      _rodape(aberto),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Android ───────────────────────────────────────────────────────────────

  Widget _android(BuildContext context, double teclado, bool aberto) {
    final mq = MediaQuery.of(context);
    final larguraMarca = (mq.size.width * 0.58).clamp(190.0, 280.0);
    return Column(children: [
      // Topo: a marca sobre a arte. Com o teclado, encolhe.
      SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: _tempoTeclado,
          curve: _curvaTeclado,
          height: aberto ? 96 : mq.size.height * 0.30,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _marca(aberto, larguraMarca),
              _lema(aberto),
            ]),
          ),
        ),
      ),
      // A folha do Material 3, que sobe com o formulário.
      Expanded(
        child: _surge(
          0.25,
          0.7,
          // Folha de vidro, a mesma linguagem do cartão do iPhone: desfoca o
          // fundo de circuito em vez de tapar com um bloco preto.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      const Color(0xFF16396B).withValues(alpha: 0.18),
                      const Color(0xFF0A1C3A).withValues(alpha: 0.30),
                    ],
                  ),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.20))),
                ),
                child: AnimatedPadding(
                  duration: _tempoTeclado,
                  curve: _curvaTeclado,
                  padding: EdgeInsets.only(bottom: teclado),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + (aberto ? 0 : mq.padding.bottom)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Alça da folha.
                          Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                          const Text('Entrar no SouPMRR',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Use a matrícula e a senha do SouPMRR.',
                              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.72))),
                          const SizedBox(height: 20),
                          const AuthForm(material: true),
                          SizedBox(height: aberto ? 0 : 20),
                          _rodape(aberto),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          deslocamento: 60,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Um brasão do rodapé, com o nome para o leitor de tela.
class _Marca extends StatelessWidget {
  const _Marca({required this.arquivo, required this.altura, required this.rotulo});
  final String arquivo;
  final double altura;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: rotulo,
        child: Image.asset(arquivo, height: altura, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      );
}
