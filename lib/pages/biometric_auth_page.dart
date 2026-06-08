import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../pages/confirm_email.dart';
import '../utils/app_routes.dart';

class BiometricAuthPage extends StatefulWidget {
  const BiometricAuthPage({Key? key}) : super(key: key);

  @override
  State<BiometricAuthPage> createState() => _BiometricAuthPageState();
}

class _BiometricAuthPageState extends State<BiometricAuthPage> {
  bool _hasModalBeenShown = false; // já existia
  bool _isModalOpen = false; // NOVO: cadeado anti-duplicação
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    debugPrint("[LOG] BiometricAuthPage initState");

    /// Espera o primeiro frame para ter um [context] estável
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<Auth>(context, listen: false);

      debugPrint(
        "[LOG] Checking biometric conditions: "
        "useBiometrics=${auth.useBiometrics}, "
        "isAuth=${auth.isAuth}, "
        "biometricModalShown=${auth.biometricModalShown}",
      );

      if (auth.useBiometrics &&
          !auth.isAuth &&
          !auth.biometricModalShown &&
          !_hasModalBeenShown) {
        // marca antes para rebuilds subsequentes já enxergarem a flag
        auth.biometricModalShown = true;
        _hasModalBeenShown = true;

        debugPrint("[LOG] Conditions met: showing biometric modal");
        _showBiometricModal();
      } else {
        debugPrint("[LOG] Conditions not met: not showing biometric modal");
      }
    });
  }

  Future<void> _showBiometricModal() async {
    // ---------- bloqueia chamadas concorrentes ----------
    if (_isModalOpen) {
      debugPrint("[LOG] _showBiometricModal: modal já aberto – ignorando");
      return;
    }
    _isModalOpen = true;

    debugPrint("[LOG] _showBiometricModal: Opening modal");
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // evita conflitos com navegadores aninhados
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.35,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromARGB(255, 191, 229, 246),
                  Color.fromARGB(255, 14, 101, 233),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: _BiometricBottomSheet(localAuth: _localAuth),
          ),
        );
      },
    );

    // ---------- libera para futuras chamadas ----------
    _isModalOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    debugPrint(
      "[LOG] BiometricAuthPage build. biometricModalShown=${auth.biometricModalShown}",
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/imagens/entradacapa.png'),
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------
///  BottomSheet de autenticação biométrica
/// ------------------------------------------------------------------
class _BiometricBottomSheet extends StatefulWidget {
  final LocalAuthentication localAuth;

  const _BiometricBottomSheet({
    Key? key,
    required this.localAuth,
  }) : super(key: key);

  @override
  State<_BiometricBottomSheet> createState() => __BiometricBottomSheetState();
}

class __BiometricBottomSheetState extends State<_BiometricBottomSheet> {
  bool isLoading = false;
  bool downloadError = false;
  File? localFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocalOrDownload();
    });
  }

  Future<void> _checkLocalOrDownload() async {
    final auth = Provider.of<Auth>(context, listen: false);

    if (auth.localImagePath != null && auth.localImagePath!.isNotEmpty) {
      final f = File(auth.localImagePath!);
      if (await f.exists()) {
        setState(() => localFile = f);
        return;
      }
    }

    final success = await auth.downloadUserProfileImage();
    if (success && auth.localImagePath != null) {
      final f = File(auth.localImagePath!);
      if (await f.exists()) {
        setState(() => localFile = f);
        return;
      }
    }

    setState(() => downloadError = true);
  }

  Future<void> _authenticateAndLogin() async {
    final auth = Provider.of<Auth>(context, listen: false);
    setState(() => isLoading = true);

    try {
      final didAuthenticate = await widget.localAuth.authenticate(
        localizedReason: 'Autentique-se para continuar',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        if (auth.matricula != null && auth.password != null) {
          await auth.loginSemNotificar(auth.matricula!, auth.password!);
          auth.finalizarLogin();

          if (mounted) Navigator.of(context).pop();

          if (auth.activationCode == null || auth.activationCode!.isEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfirmEmailScreen()),
            );
          } else {
            Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE);
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_PAGE);
        }
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_PAGE);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildProfileImage(Auth auth) {
    final width = MediaQuery.of(context).size.width;
    final double imageSize = width * 0.15;

    if (localFile != null) {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.file(
            localFile!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      );
    } else if (!downloadError && auth.image != null && auth.image!.isNotEmpty) {
      return SizedBox(
        width: imageSize,
        height: imageSize,
        child: const Center(child: CircularProgressIndicator()),
      );
    } else {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.account_circle, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final width = MediaQuery.of(context).size.width;
    final double baseFontSize = width * 0.04;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileImage(auth),
            SizedBox(height: width * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Olá, ",
                  style: TextStyle(
                    fontSize: baseFontSize * 1.1,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "${auth.nomeMilitar ?? 'Usuário'}",
                  style: TextStyle(
                    fontSize: baseFontSize * 1.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: width * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Matrícula: ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: baseFontSize * 0.9,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  "${auth.matricula ?? ''}",
                  style: TextStyle(
                    fontSize: baseFontSize * 0.9,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(width: width * 0.05),
                Text(
                  "CPF: ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: baseFontSize * 0.9,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  "${auth.cpf ?? ''}",
                  style: TextStyle(
                    fontSize: baseFontSize * 0.9,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            SizedBox(height: width * 0.05),
            if (isLoading)
              Column(
                children: [
                  const CircularProgressIndicator.adaptive(),
                  SizedBox(height: width * 0.02),
                  _BlinkingText(
                    text: "Autenticando...",
                    style: TextStyle(
                      fontSize: baseFontSize * 0.9,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    padding: EdgeInsets.symmetric(vertical: width * 0.03),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    auth.clearAllCacheData();
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .pushReplacementNamed(AppRoutes.AUTH_PAGE);
                  },
                  child: Text(
                    'Entrar com outros dados',
                    style: TextStyle(
                      fontSize: baseFontSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: width * 0.025),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 63, 87, 248),
                    padding: EdgeInsets.symmetric(vertical: width * 0.03),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _authenticateAndLogin,
                  child: Text(
                    'Acessar SouPMRR',
                    style: TextStyle(
                      fontSize: baseFontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: width * 0.03),
          ],
        ),
      ),
    );
  }
}

/// Texto piscante usado enquanto autentica.
class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _BlinkingText({
    Key? key,
    required this.text,
    required this.style,
  }) : super(key: key);

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  late final Animation<Color?> _colorAnim = ColorTween(
    begin: widget.style.color ?? Colors.white,
    end: Colors.blueAccent,
  ).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (_, __) => Text(
        widget.text,
        style: widget.style.copyWith(color: _colorAnim.value),
      ),
    );
  }
}
