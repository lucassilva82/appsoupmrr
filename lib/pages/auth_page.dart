import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../widgets/auth_form.dart';
import '../widgets/versao_app.dart';
import '../utils/app_routes.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  // Entrada encadeada: cada peça aparece um pouco depois da anterior, no
  // mesmo controlador. É o que dá a sensação de "montagem" dos apps atuais,
  // em vez de a tela inteira surgir de uma vez.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// Um trecho do controlador, com fade e deslocamento para cima.
  Widget _surge(
    double inicio,
    double fim, {
    required Widget child,
    double deslocamento = 28,
  }) {
    final curva = CurvedAnimation(
      parent: _entrada,
      curve: Interval(inicio, fim, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curva,
      builder: (_, filho) => Opacity(
        opacity: curva.value,
        child: Transform.translate(
          offset: Offset(0, deslocamento * (1 - curva.value)),
          child: filho,
        ),
      ),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _entrada.forward();
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);

    // Quem pediu menos movimento no sistema recebe a tela já montada.
    if (MediaQuery.of(context).disableAnimations && !_entrada.isCompleted) {
      _entrada.value = 1;
    }

    if (auth.isAuth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── Fundo: imagem com overlay escuro ──────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/imagens/entradacapa.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  // Escurece o meio da tela, onde fica o formulário, e alivia
                  // na base para os brasões do rodapé ficarem legíveis.
                  gradient: LinearGradient(
                    colors: [
                      Color(0x33000D1A), // topo — imagem bem visível
                      Color(0x99001233), // meio — contraste do formulário
                      Color(0xB3001233),
                      Color(0x4D001233), // base — brasões aparecem
                    ],
                    stops: [0.0, 0.42, 0.72, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Faixa de marcas ───────────────────────────────────────────
            // A imagem de fundo usa cover e, em telas estreitas, cortava as
            // laterais da faixa. Aqui ela é desenhada inteira, na largura.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                // Base azul: cobre o trecho do fundo que ficava cortado e
                // dá um encontro limpo com a foto.
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00001233),
                      Color(0xCC00183D),
                      Color(0xFF001E4A),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
                padding: const EdgeInsets.only(top: 26),
                child: ShaderMask(
                  // A faixa aparece em degradê, sem emenda com a imagem.
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white, Colors.white],
                    stops: [0.0, 0.55, 1.0],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/imagens/rodape_marcas.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),

            // ── Conteúdo central ──────────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: size.height - MediaQuery.of(context).padding.top,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Texto institucional — abaixo do SouPMRR da imagem
                      _surge(
                        0.0,
                        0.45,
                        deslocamento: 16,
                        child: Text(
                          'POLÍCIA MILITAR DE RORAIMA',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.70),
                            letterSpacing: 3.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const Spacer(flex: 1),

                      // ── Glassmorphism card de login ────────────────────
                      _surge(
                        0.25,
                        0.85,
                        child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.16),
                                    Colors.white.withOpacity(0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.22),
                                  width: 1,
                                ),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              child: AuthForm(),
                            ),
                          ),
                        ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      const SizedBox(height: 10),
                      _surge(
                        0.6,
                        1.0,
                        deslocamento: 12,
                        child: TextoVersao(
                        formato: (v) =>
                            v.isEmpty ? 'DTI/PMRR' : 'v$v — DTI/PMRR',
                        estilo: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                          letterSpacing: 0.5,
                        ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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
