import 'package:flutter/material.dart';

import '../models/militar.dart';
import '../utils/app_routes.dart';

class DadosEndereco extends StatelessWidget {
  final Militar militar;
  const DadosEndereco({Key? key, required this.militar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = militar.endereco;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(theme, 'Município', e.municipio?.nome ?? '—',
            Icons.location_city_outlined),
        _row(theme, 'Rua / Número',
            '${e.rua?.nome ?? '—'}, Nº ${e.numero ?? '—'}', Icons.map_outlined),
        _row(theme, 'Bairro', e.bairro?.nome ?? '—',
            Icons.holiday_village_outlined),
        _row(theme, 'CEP', e.cep ?? '—', Icons.local_post_office_outlined),
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
                  value,
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
