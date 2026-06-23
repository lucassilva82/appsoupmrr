import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../pages/confirm_email.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

class BiometricAuthPage extends StatefulWidget {
  const BiometricAuthPage({Key? key}) : super(key: key);

  @override
  State<BiometricAuthPage> createState() => _BiometricAuthPageState();
}

class _BiometricAuthPageState extends State<BiometricAuthPage> {
  bool _hasModalBeenShown = false;
  bool _isModalOpen = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    debugPrint("[LOG] BiometricAuthPage initState");

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
    if (_isModalOpen) {
      debugPrint("[LOG] _showBiometricModal: modal já aberto – ignorando");
      return;
    }
    _isModalOpen = true;

    debugPrint("[LOG] _showBiometricModal: Opening modal");
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BiometricBottomSheet(localAuth: _localAuth),
    );

    _isModalOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    debugPrint(
      "[LOG] BiometricAuthPage build. biometricModalShown=${auth.biometricModalShown}",
    );

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── Fundo idêntico à tela de login ───────────────────────────
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

            // ── Branding visível acima do modal ──────────────────────────
            SafeArea(
              child: Align(
                alignment: const Alignment(0, -0.62),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
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
                    const SizedBox(height: 14),
                    const Text(
                      'SouPMRR',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Polícia Militar de Roraima',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.60),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BottomSheet — Autenticação Facial/Biométrica  (design v2.0)
// ─────────────────────────────────────────────────────────────────────────────
class _BiometricBottomSheet extends StatefulWidget {
  final LocalAuthentication localAuth;
  const _BiometricBottomSheet({Key? key, required this.localAuth})
      : super(key: key);

  @override
  State<_BiometricBottomSheet> createState() => __BiometricBottomSheetState();
}

class __BiometricBottomSheetState extends State<_BiometricBottomSheet>
    with TickerProviderStateMixin {
  bool isLoading = false;
  bool downloadError = false;
  File? localFile;

  // Animação de pulso no avatar (igual ao Stories do Instagram)
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Animation<double> _pulseAnim = Tween<double>(begin: 1.0, end: 1.10)
      .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  // Entrada suave do painel
  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fadeAnim =
      Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _enterCtrl, curve: const Interval(0, 0.7)),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkLocalOrDownload());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Carrega a foto do militar ─────────────────────────────────────────────
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

  // ── Autentica e faz login ─────────────────────────────────────────────────
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
        if (mounted)
          Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_PAGE);
      }
    } catch (_) {
      if (mounted)
        Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_PAGE);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Avatar com anel de gradiente pulsante ─────────────────────────────────
  Widget _buildAvatar(Auth auth, bool isDark) {
    const double size = 118;

    Widget inner;
    if (localFile != null) {
      inner = Image.file(localFile!,
          fit: BoxFit.cover, alignment: Alignment.topCenter);
    } else if (!downloadError && auth.image != null && auth.image!.isNotEmpty) {
      inner = const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.lightBlue));
    } else {
      inner = Icon(Icons.account_circle_rounded,
          size: 62, color: isDark ? Colors.grey[500] : Colors.grey[400]);
    }

    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.lightBlue, AppColors.blue, AppColors.navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(3.5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.darkCard : Colors.white,
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(child: SizedBox.expand(child: inner)),
        ),
      ),
    );
  }

  // ── Chip de informação (matrícula / CPF) ──────────────────────────────────
  Widget _infoChip(
      {required String label, required String value, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600]),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // ── Botão primário com gradiente ──────────────────────────────────────────
  Widget _primaryButton(
      {required VoidCallback? onTap,
      required String label,
      required IconData icon}) {
    return AnimatedOpacity(
      opacity: isLoading ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.lightBlue, AppColors.blue, AppColors.navy],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withOpacity(0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white24,
            child: SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Tokens de cores respeitando o tema do app
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final handleColor = isDark ? AppColors.darkBorder : const Color(0xFFDDE3EA);
    final dividerColor =
        isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 40,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Handle ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // ── Conteúdo rolável ──────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 28,
                      right: 28,
                      top: 10,
                      bottom: bottomInset + 28,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),

                        // Avatar
                        _buildAvatar(auth, isDark),
                        const SizedBox(height: 20),

                        // Saudação
                        Text(
                          'Bem-vindo de volta',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          auth.nomeMilitar ?? 'Usuário',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Chips de matrícula e CPF
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _infoChip(
                              label: 'Matrícula',
                              value: auth.matricula ?? '—',
                              isDark: isDark,
                            ),
                            _infoChip(
                              label: 'CPF',
                              value: auth.cpf ?? '—',
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // Divider sutil
                        Divider(color: dividerColor, thickness: 1, height: 1),
                        const SizedBox(height: 32),

                        // Ícone de facial + instrução
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: isLoading
                              ? Column(
                                  key: const ValueKey('loading'),
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: AppColors.blue
                                            .withOpacity(isDark ? 0.18 : 0.09),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(18),
                                      child: const CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.blue),
                                    ),
                                    const SizedBox(height: 16),
                                    _BlinkingText(
                                      text: 'Autenticando...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.blue,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('idle'),
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: AppColors.blue
                                            .withOpacity(isDark ? 0.18 : 0.09),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.face_retouching_natural_rounded,
                                        size: 36,
                                        color: AppColors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Autenticação Facial',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Toque em "Acessar" e olhe\npara a câmera do seu dispositivo.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: textSecondary,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 40),

                        // Botão primário — Acessar
                        _primaryButton(
                          onTap: isLoading ? null : _authenticateAndLogin,
                          label: 'Acessar SouPMRR',
                          icon: Icons.face_retouching_natural_rounded,
                        ),

                        const SizedBox(height: 14),

                        // Botão secundário — Trocar usuário
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: dividerColor, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    // Fecha o modal primeiro
                                    Navigator.of(context).pop();
                                    // Limpa todos os dados e notifica:
                                    // AuthOrHome responde exibindo AuthPage
                                    await auth.clearAllCacheData();
                                  },
                            icon: Icon(Icons.swap_horiz_rounded,
                                color: textSecondary, size: 20),
                            label: Text(
                              'Entrar com outros dados',
                              style: TextStyle(
                                fontSize: 15,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Rodapé
                        Text(
                          'v2.0 • SouPMRR',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: textSecondary.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Texto piscante durante autenticação
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _BlinkingText({Key? key, required this.text, required this.style})
      : super(key: key);

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<Color?> _colorAnim = ColorTween(
    begin: widget.style.color ?? AppColors.blue,
    end: AppColors.lightBlue,
  ).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (_, __) => Text(widget.text,
          style: widget.style.copyWith(color: _colorAnim.value)),
    );
  }
}
