import 'package:flutter/material.dart';
import '../models/militar.dart';

/// Formata datas do banco (YYYY-MM-DD) para o padrão BR DD/MM/AAAA.
String _fmtDataBr(String? s) {
  if (s == null || s.trim().isEmpty) return '';
  final v = s.trim();
  try {
    final d = DateTime.parse(v);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    final m = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})').firstMatch(v);
    if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
    return v;
  }
}

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
        _row(theme, 'Incorporação', _fmtDataBr(militar.dataIncorporacao),
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
