import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// avisoRapido
//
// Aviso curto que aparece embaixo e some sozinho, no mesmo desenho do
// "Em desenvolvimento" do menu (grid_menu.dart): cartão flutuante com fundo
// levemente tingido, borda fina, ícone num círculo, título e uma linha de
// explicação. Use no lugar do SnackBar padrão do Flutter.
// ─────────────────────────────────────────────────────────────────────────────

void avisoRapido(
  BuildContext context, {
  required String titulo,
  String? texto,
  required IconData icone,
  required Color cor,
  Duration duracao = const Duration(seconds: 3),
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final textoCor = theme.colorScheme.onSurface;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        duration: duracao,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: isDark
            ? Color.alphaBlend(cor.withValues(alpha: 0.10), AppColors.darkCard)
            : Color.alphaBlend(cor.withValues(alpha: 0.08), Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cor.withValues(alpha: 0.25)),
        ),
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: cor, size: AppIconSize.sm),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: textoCor,
                      ),
                    ),
                    if (texto != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        texto,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: textoCor.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
