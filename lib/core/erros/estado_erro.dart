import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'falha_app.dart';

/// Erro no lugar do conteúdo (docs/SOUPM_2_2.md §9.1): o que aconteceu, de
/// quem é o problema, o que fazer, o botão certo e o código. A tela de erro
/// com a viatura chega no acabamento (fase 6); o conteúdo é este.
class EstadoErro extends StatelessWidget {
  const EstadoErro({super.key, required this.falha, this.aoTentar});

  final FalhaApp falha;
  final VoidCallback? aoTentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: AppIconSize.xl, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(falha.titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(falha.deQuem,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Text(falha.texto, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          if (aoTentar != null && falha.acao == AcaoFalha.tentarDeNovo) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
          ],
          const SizedBox(height: 10),
          SelectableText('Código ${falha.codigo}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
