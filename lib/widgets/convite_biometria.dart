import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/biometric_service.dart';
import '../core/log/registro_log.dart';
import 'dialogo_confirmacao.dart';
import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';
import 'aviso_rapido.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Convite para ativar a biometria
//
// Pergunta uma vez, logo depois do primeiro login com senha, se a pessoa quer
// usar Face ID ou digital nas próximas entradas. Antes disso a única forma de
// ligar era achar o interruptor no Perfil.
//
// O símbolo pulsa devagar enquanto o convite está aberto — é o que os apps de
// banco usam para dizer "encoste aqui" sem escrever. Com movimento reduzido
// ligado no sistema, ele fica parado.
// ─────────────────────────────────────────────────────────────────────────────

/// Verdadeiro do envio do login até o convite de biometria fechar. A Início
/// já aparece por trás nesse intervalo; o comunicado de abertura espera
/// isto ficar falso para não abrir por baixo do convite.
final entradaEmAndamento = ValueNotifier<bool>(false);

/// Mostra o convite e devolve true se a pessoa aceitou ativar.
/// Devolve false sem abrir nada quando o aparelho não tem biometria.
Future<bool> convidarParaBiometria(BuildContext context) async {
  final servico = BiometricService();
  if (!await servico.isBiometricAvailable()) return false;

  final tipos = await servico.getAvailableBiometrics();
  // No iOS, só é Touch ID quando o sistema diz que é digital: a lista vem
  // vazia em alguns casos (simulador, rosto ainda não cadastrado) e quase
  // todo iPhone em uso tem Face ID. No Android, rosto só quando ele diz.
  final temRosto = tipos.contains(BiometricType.face) ||
      (Platform.isIOS && !tipos.contains(BiometricType.fingerprint));
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
          // Abre sobre o login (fundo escuro de circuito): sempre no tema
          // escuro, mesmo com o aparelho no claro.
          child: Theme(
            data: AppTheme.build(isDark: true, isSuperUser: false),
            child: _Convite(temRosto: temRosto),
          ),
        ),
      );
    },
  );

  if (aceitou != true) return false;

  // Pede a biometria na hora: ligar sem confirmar deixaria a pessoa trancada
  // fora na próxima entrada se o sensor não reconhecesse.
  final r = await servico.confirmar(motivo: 'Confirme que é você para ligar o ${BiometricService.nome}');
  final f = r.falha;
  if (f != null) {
    registrarErro(f, tela: 'login');
    if (context.mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
  }
  registrar('conta.biometria_ligar', resultado: r.ok ? 'ok' : (f == null ? 'cancelado' : 'falhou'), codigo: f?.codigo);
  return r.ok;
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
    final primaria = theme.colorScheme.primary;
    final semMovimento = MediaQuery.of(context).disableAnimations;
    if (semMovimento && _pulso.isAnimating) _pulso.stop();

    final nome = widget.temRosto
        ? (Platform.isIOS ? 'Face ID' : 'reconhecimento facial')
        : (Platform.isIOS ? 'Touch ID' : 'impressão digital');
    final icone =
        widget.temRosto ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded;

    // O mesmo vidro com a arte discreta das outras janelas do app
    // (CaixaDialogo): antes esta tinha uma superfície própria, sem a arte.
    return CaixaDialogo(
      arte: Arte.de('rh'),
      topo: _SimboloPulsante(controlador: _pulso, cor: primaria, icone: icone),
      titulo: 'Entrar com $nome?',
      mensagem: 'Nas próximas vezes você entra sem digitar a senha. '
          'Dá para desligar quando quiser em Perfil › ${Platform.isIOS ? 'Face ID' : 'Biometria'}.',
      corpo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ativar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.70),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Agora não'),
        ),
      ]),
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
