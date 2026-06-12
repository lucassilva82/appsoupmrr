import 'package:flutter/material.dart';
import '../models/militar.dart';

class DadosSituacaoFuncional extends StatefulWidget {
  final Militar militar;
  const DadosSituacaoFuncional({Key? key, required this.militar})
      : super(key: key);

  @override
  State<DadosSituacaoFuncional> createState() => _DadosSituacaoFuncionalState();
}

class _DadosSituacaoFuncionalState extends State<DadosSituacaoFuncional> {
  @override
  void initState() {
    super.initState();
    DateTime _parseDate(String? s) {
      if (s == null) return DateTime.fromMillisecondsSinceEpoch(0);
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    widget.militar.fichaFuncional.alteracoesFuncional.sort(
        (a, b) => _parseDate(b.dataInicio).compareTo(_parseDate(a.dataInicio)));
  }

  String _formatBr(String? s) {
    if (s == null || s.isEmpty) return '—';
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      final reg = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})$');
      final m = reg.firstMatch(s);
      if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
      return s.replaceAll('-', '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lista =
        widget.militar.fichaFuncional.alteracoesFuncional;

    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Sem registros funcionais.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade500)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columnSpacing: 12,
        headingTextStyle: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        dataTextStyle:
            theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        columns: const [
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Situação')),
          DataColumn(label: Text('Início')),
          DataColumn(label: Text('Fim')),
          DataColumn(label: Text('Ativo')),
        ],
        rows: lista.map((alt) {
          return DataRow(
            color: WidgetStateProperty.resolveWith((states) {
              if (alt.ativo) {
                return isDark
                    ? const Color(0xFF0D2B5A).withValues(alpha: 0.4)
                    : const Color(0xFFE3F2FD);
              }
              return null;
            }),
            cells: [
              DataCell(Text(alt.tipoSituacao)),
              DataCell(Text(alt.situacaoFuncional)),
              DataCell(Text(_formatBr(alt.dataInicio))),
              DataCell(Text(_formatBr(alt.dataFim))),
              DataCell(
                alt.ativo
                    ? const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF2E7D32), size: 16)
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

