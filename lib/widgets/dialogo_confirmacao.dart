import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// dialogoConfirmacao
//
// Caixa de confirmação no padrão visual do SouPMRR 2.0, para substituir o
// AlertDialog padrão do Flutter: cantos arredondados, ícone em destaque,
// botões lado a lado e entrada animada.
//
// Retorna true quando o usuário confirma.
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> dialogoConfirmacao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String textoConfirmar,
  String textoCancelar = 'Cancelar',
  IconData icone = Icons.help_outline_rounded,
  Color cor = AppColors.blue,
}) async {
  final resultado = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: titulo,
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curva),
          child: _Cartao(
            titulo: titulo,
            mensagem: mensagem,
            textoConfirmar: textoConfirmar,
            textoCancelar: textoCancelar,
            icone: icone,
            cor: cor,
          ),
        ),
      );
    },
  );

  return resultado ?? false;
}

class _Cartao extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final String textoConfirmar;
  final String textoCancelar;
  final IconData icone;
  final Color cor;

  const _Cartao({
    required this.titulo,
    required this.mensagem,
    required this.textoConfirmar,
    required this.textoCancelar,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        // Um diálogo flutua sobre o scrim: não há conteúdo atrás para o vidro
        // desfocar. Por isso ele tem desfoque próprio e um fundo bem mais
        // opaco que os cartões — a 5% ficava transparente a ponto de sumir.
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cor.withOpacity(0.12),
                  ),
                  child: Icon(icone, size: 32, color: cor),
                ),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mensagem,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withOpacity(0.70),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFD7E0EC),
                            ),
                            foregroundColor:
                                theme.colorScheme.onSurface.withOpacity(0.75),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            textoCancelar,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            textoConfirmar,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
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
