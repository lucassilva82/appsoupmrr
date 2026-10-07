import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../widgets/auth_form.dart';
import 'primeiro_acesso_page.dart';
import 'recuperar_senha_page.dart';
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
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF001233)
                                    .withOpacity(0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.14),
                                  width: 1,
                                ),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 22, 20, 22),
                              child: AuthForm(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Acessos alternativos ──────────────────────────
                      // Fora do cartão e discretos: são saídas de exceção.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AcessoLink(
                            texto: 'Esqueci a senha',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RecuperarSenhaPage(),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 11,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 14),
                            color: Colors.white24,
                          ),
                          _AcessoLink(
                            texto: 'Primeiro acesso',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrimeiroAcessoPage(),
                              ),
                            ),
                          ),
                        ],
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

// ── Link discreto de acesso alternativo ─────────────────────────────────────
class _AcessoLink extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _AcessoLink({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          texto,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
