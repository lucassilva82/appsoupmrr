import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../widgets/auth_form.dart';
import '../utils/app_routes.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);

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
              child: Image.asset(
                'assets/imagens/rodape_marcas.png',
                fit: BoxFit.fitWidth,
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
                      Text(
                        'POLÍCIA MILITAR DE RORAIMA',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.70),
                          letterSpacing: 3.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Spacer(flex: 1),

                      // ── Glassmorphism card de login ────────────────────
                      Padding(
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

                      const Spacer(flex: 2),

                      const SizedBox(height: 10),
                      Text(
                        'v2.0 — DTI/PMRR',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                          letterSpacing: 0.5,
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
