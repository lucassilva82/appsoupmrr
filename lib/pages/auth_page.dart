import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_model.dart';
import '../widgets/auth_form.dart';
import '../utils/app_routes.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoadingLogin = false;

  /* ------------------------------------------------------------
   * URLs fixas
   * ---------------------------------------------------------- */
  final Uri _whatsUrl = Uri.parse(
    'whatsapp://send?phone=5595981003190'
    '&text=${Uri.encodeComponent("Olá, preciso de ajuda!")}',
  );

  final Uri _playStoreUrl = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.whatsapp',
  );

  final Uri _appStoreUrl = Uri.parse(
    'https://apps.apple.com/app/whatsapp-messenger/id310633997',
  );

  /* ------------------------------------------------------------
   * Abre WhatsApp ou leva para a loja
   * ---------------------------------------------------------- */
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

    /* Auto-redirect se já logado */
    if (auth.isAuth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE),
      );
    }

    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: w,
        height: h,
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.fill,
            image: AssetImage('assets/imagens/entradacapa.png'),
          ),
          gradient: LinearGradient(
            colors: [
              Color(0xFFC5E4F2),
              Color(0xFF002154),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            /* Formulário ou loading */
            Center(
              child: _isLoadingLogin
                  ? const CircularProgressIndicator.adaptive()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        AuthForm(),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),

            /* Botão WhatsApp */
            Positioned(
              bottom: h * 0.10,
              right: w * 0.30,
              child: GestureDetector(
                onTap: _openWhatsApp,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/imagens/whatsapp.png',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Suporte SouPMRR',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
