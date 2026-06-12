import 'package:flutter/material.dart';
import '../models/militar.dart';

class DadosPrincipal extends StatelessWidget {
  final Militar militar;
  const DadosPrincipal({Key? key, required this.militar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
            theme,
            'Posto / Graduação',
            '${militar.postoGraduacao} ${militar.quadro}',
            Icons.military_tech_outlined),
        _row(
            theme, 'Nome Completo', militar.nomeCompleto, Icons.person_outline),
        _row(theme, 'Lotação', militar.subUnidade, Icons.apartment_outlined),
        _row(theme, 'Incorporação', militar.dataIncorporacao,
            Icons.calendar_today_outlined),
        _row(theme, 'Matrícula SEGAD', militar.matRhNova,
            Icons.fingerprint_outlined),
        _row(theme, 'Matrícula PMRR', militar.matricula, Icons.badge_outlined),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
