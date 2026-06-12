import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_form.dart';
import '../utils/app_routes.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final Uri _whatsUrl = Uri.parse(
    'whatsapp://send?phone=5595981003190'
    '&text=${Uri.encodeComponent("Olá, preciso de ajuda com o SouPMRR!")}',
  );
  final Uri _playStoreUrl = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.whatsapp',
  );
  final Uri _appStoreUrl = Uri.parse(
    'https://apps.apple.com/app/whatsapp-messenger/id310633997',
  );

  Future<void> _openWhatsApp() async {
    final Uri loja = Platform.isIOS ? _appStoreUrl : _playStoreUrl;
    try {
      if (await canLaunchUrl(_whatsUrl)) {
        await launchUrl(_whatsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(loja, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(loja, mode: LaunchMode.externalApplication);
    }
  }

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
                  gradient: LinearGradient(
                    colors: [
                      Color(0xCC000D1A),
                      Color(0xEE001233),
                    ],
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
                      const Spacer(flex: 2),

                      // Brasão / logo
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/imagens/entradacapa.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Título
                      const Text(
                        'SouPMRR',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Polícia Militar de Roraima',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.65),
                          letterSpacing: 1.5,
                        ),
                      ),

                      const Spacer(flex: 1),

                      // ── Glassmorphism card de login ────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.20),
                                  width: 1,
                                ),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(24, 28, 24, 28),
                              child: AuthForm(),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── Suporte WhatsApp ───────────────────────────────
                      GestureDetector(
                        onTap: _openWhatsApp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFF25D366).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/imagens/whatsapp.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.support_agent,
                                  color: Color(0xFF25D366),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Suporte SouPMRR',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'v2.0 • PMRR',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      const SizedBox(height: 24),
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
