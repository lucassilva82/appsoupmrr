import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/biometric_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Convite para ativar a biometria
//
// Pergunta uma vez, logo depois do primeiro login com senha, se a pessoa quer
// usar Face ID ou digital nas próximas entradas. Antes disso a única forma de
// ligar era achar o interruptor em Configurações.
//
// O símbolo pulsa devagar enquanto o convite está aberto — é o que os apps de
// banco usam para dizer "encoste aqui" sem escrever. Com movimento reduzido
// ligado no sistema, ele fica parado.
// ─────────────────────────────────────────────────────────────────────────────

/// Mostra o convite e devolve true se a pessoa aceitou ativar.
/// Devolve false sem abrir nada quando o aparelho não tem biometria.
Future<bool> convidarParaBiometria(BuildContext context) async {
  final servico = BiometricService();
  if (!await servico.isBiometricAvailable()) return false;

  final tipos = await servico.getAvailableBiometrics();
  final temRosto = tipos.contains(BiometricType.face);
  if (!context.mounted) return false;

  final aceitou = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Ativar biometria',
    barrierColor: Colors.black.withOpacity(0.62),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curva),
          child: _Convite(temRosto: temRosto),
        ),
      );
    },
  );

  if (aceitou != true) return false;

  // Pede a biometria na hora: ligar sem confirmar deixaria a pessoa trancada
  // fora na próxima entrada se o sensor não reconhecesse.
  return servico.authenticateUser();
}

class _Convite extends StatefulWidget {
  final bool temRosto;
  const _Convite({required this.temRosto});

  @override
  State<_Convite> createState() => _ConviteState();
}

class _ConviteState extends State<_Convite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _pulso.repeat();
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;
    final semMovimento = MediaQuery.of(context).disableAnimations;
    if (semMovimento && _pulso.isAnimating) _pulso.stop();

    final nome = widget.temRosto
        ? (Platform.isIOS ? 'Face ID' : 'reconhecimento facial')
        : (Platform.isIOS ? 'Touch ID' : 'impressão digital');
    final icone =
        widget.temRosto ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Color.alphaBlend(Colors.white.withOpacity(0.10),
                                AppColors.darkCard),
                            Color.alphaBlend(Colors.white.withOpacity(0.04),
                                AppColors.darkCard),
                          ]
                        : [
                            Colors.white.withOpacity(0.96),
                            Colors.white.withOpacity(0.90),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.16)
                        : Colors.white.withOpacity(0.80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.55 : 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SimboloPulsante(
                      controlador: _pulso,
                      cor: primaria,
                      icone: icone,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Entrar com $nome?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nas próximas vezes você entra sem digitar a senha. '
                      'Dá para desligar quando quiser em Configurações.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Ativar'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              theme.colorScheme.onSurface.withOpacity(0.70),
                        ),
                        child: const Text('Agora não'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anel que abre e some em volta do símbolo, repetindo.
class _SimboloPulsante extends StatelessWidget {
  final AnimationController controlador;
  final Color cor;
  final IconData icone;

  const _SimboloPulsante({
    required this.controlador,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: AnimatedBuilder(
        animation: controlador,
        builder: (context, filho) {
          final t = controlador.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Dois anéis defasados: um já saindo enquanto o outro começa.
              for (final atraso in [0.0, 0.5])
                Builder(builder: (_) {
                  final p = (t + atraso) % 1.0;
                  return Opacity(
                    opacity: (1 - p) * 0.35,
                    child: Container(
                      width: 68 + 44 * p,
                      height: 68 + 44 * p,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cor, width: 1.4),
                      ),
                    ),
                  );
                }),
              filho!,
            ],
          );
        },
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cor.withOpacity(0.18),
            border: Border.all(color: cor.withOpacity(0.45), width: 1.5),
          ),
          child: Icon(icone, size: 38, color: cor),
        ),
      ),
    );
  }
}
