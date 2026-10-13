import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abertura do app
//
// Ocupa o tempo entre o primeiro frame do Flutter e o app pronto — autologin
// e checagem de versão. Antes era a foto `entradacapa.png` com um spinner no
// meio; agora é a marca entrando.
//
// O fundo é `AppColors.darkBg` chapado, o **mesmo** das telas nativas de
// abertura (LaunchScreen.storyboard e launch_background.xml). É isso que
// elimina o branco entre tocar no ícone e o app aparecer: as três camadas
// nascem da mesma cor, então a troca não tem como piscar.
//
// A animação precisa ficar boa cortada em qualquer ponto, porque o tempo real
// de carregamento varia. Por isso tudo entra por opacidade e deslocamento
// curto, nada que fique estranho pela metade.
// ─────────────────────────────────────────────────────────────────────────────

class AberturaSouPMRR extends StatefulWidget {
  const AberturaSouPMRR({Key? key}) : super(key: key);

  @override
  State<AberturaSouPMRR> createState() => _AberturaSouPMRRState();
}

class _AberturaSouPMRRState extends State<AberturaSouPMRR>
    with TickerProviderStateMixin {
  late final AnimationController _entrada;
  late final AnimationController _brilho;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
    // Separado da entrada: este não termina, varre a marca enquanto o app
    // carrega. Com um controlador só, ou a entrada repetia ou o brilho parava.
    _brilho = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _entrada.value = 1;
    } else if (!_entrada.isAnimating && _entrada.value == 0) {
      _entrada.forward();
      _brilho.repeat();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _brilho.dispose();
    super.dispose();
  }

  /// Entra por opacidade e por um deslocamento curto para cima. Cortada no
  /// meio, continua legível — que é o requisito aqui.
  Widget _surge(double inicio, double fim,
      {required Widget child, double deslocamento = 14, double escala = 1}) {
    final t = CurvedAnimation(
      parent: _entrada,
      curve: Interval(inicio, fim, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (_, filho) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, deslocamento * (1 - t.value)),
          child: Transform.scale(
            scale: escala + (1 - escala) * t.value,
            child: filho,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo atrás do brasão, respirando devagar.
            AnimatedBuilder(
              animation: Listenable.merge([_entrada, _brilho]),
              builder: (_, __) {
                final abre = Curves.easeOut.transform(
                  (_entrada.value / 0.45).clamp(0.0, 1.0),
                );
                final pulso =
                    0.85 + 0.15 * (1 - (_brilho.value - 0.5).abs() * 2);
                return IgnorePointer(
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.acaoClara
                              .withValues(alpha: 0.16 * abre * pulso),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _surge(
                  0.05,
                  0.55,
                  escala: 0.86,
                  deslocamento: 0,
                  child: Image.asset(
                    'assets/imagens/logo_pmrr.png',
                    width: 112,
                    filterQuality: FilterQuality.high,
                  ),
                ),

                const SizedBox(height: 26),

                // A marca, com uma varredura de luz passando por cima.
                _surge(
                  0.30,
                  0.78,
                  child: AnimatedBuilder(
                    animation: _brilho,
                    builder: (_, filho) => ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (r) {
                        // -0.4 .. 1.4 para a luz entrar e sair fora do texto,
                        // em vez de nascer e morrer em cima dele.
                        final p = -0.4 + _brilho.value * 1.8;
                        return LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white,
                            Colors.white.withValues(alpha: 0.72),
                          ],
                          stops: [
                            (p - 0.16).clamp(0.0, 1.0),
                            p.clamp(0.0, 1.0),
                            (p + 0.16).clamp(0.0, 1.0),
                          ],
                        ).createShader(r);
                      },
                      child: filho,
                    ),
                    child: const _Marca(),
                  ),
                ),

                const SizedBox(height: 10),

                _surge(
                  0.55,
                  0.95,
                  child: Text(
                    'Polícia Militar de Roraima',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.6,
                      color: Colors.white.withValues(alpha: 0.46),
                    ),
                  ),
                ),
              ],
            ),

            // Linha de carregamento, bem embaixo. Sem o círculo de sempre: num
            // fundo preto ele vira a única coisa em movimento e rouba a marca.
            Positioned(
              bottom: 72,
              child: _surge(
                0.70,
                1.0,
                deslocamento: 6,
                child: SizedBox(
                  width: 108,
                  height: 2,
                  child: AnimatedBuilder(
                    animation: _brilho,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          Align(
                            alignment: Alignment(
                              -1 + 2 * _brilho.value,
                              0,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 0.4,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.acaoClara,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

/// "Sou" leve, "PMRR" pesado — a mesma leitura do ícone do app.
class _Marca extends StatelessWidget {
  const _Marca({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 38,
          height: 1.0,
          color: Colors.white,
        ),
        children: [
          TextSpan(
            text: 'Sou',
            style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
          ),
          TextSpan(
            text: 'PMRR',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}
