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
  static const int _previewCount = 3;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();

    DateTime parseDate(String? s) {
      if (s == null) return DateTime.fromMillisecondsSinceEpoch(0);
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    widget.militar.fichaFuncional.alteracoesFuncional.sort(
        (a, b) => parseDate(b.dataInicio).compareTo(parseDate(a.dataInicio)));
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

  void _toggle() => setState(() => _expanded = !_expanded);

  Widget _toggleButton({
    required String label,
    required bool expanded,
    required bool isDark,
    required ThemeData theme,
    double bottomPadding = 0,
    double topPadding = 8,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF21262D)
                : theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lista = widget.militar.fichaFuncional.alteracoesFuncional;

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

    final visible = _expanded ? lista : lista.take(_previewCount).toList();
    final hidden = lista.length - _previewCount;
    final hasMore = lista.length > _previewCount;

    return Column(
      children: [
        // ── Botão recolher no topo (só quando expandido) ─────────────────
        if (hasMore && _expanded)
          _toggleButton(
            label: 'Recolher',
            expanded: true,
            isDark: isDark,
            theme: theme,
            bottomPadding: 8,
          ),

        ...visible.asMap().entries.map((entry) {
          final i = entry.key;
          final alt = entry.value;
          final isAtivo = alt.ativo;
          final isLast = i == visible.length - 1 && (!hasMore || _expanded);

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Timeline ────────────────────────────────────────────
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAtivo
                              ? const Color(0xFF2E7D32)
                              : (isDark
                                  ? const Color(0xFF444D56)
                                  : Colors.grey.shade300),
                          border: Border.all(
                            color: isAtivo
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isDark
                                ? const Color(0xFF30363D)
                                : Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // ── Card do registro ─────────────────────────────────────
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: isAtivo
                          ? (isDark
                              ? const Color(0xFF0D2B5A).withValues(alpha: 0.4)
                              : const Color(0xFFE8F5E9))
                          : (isDark
                              ? const Color(0xFF21262D)
                              : const Color(0xFFF8F9FA)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAtivo
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                            : (isDark
                                ? const Color(0xFF30363D)
                                : const Color(0xFFE8E8E8)),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                alt.situacaoFuncional,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (isAtivo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Ativo',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alt.tipoSituacao,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              _formatBr(alt.dataInicio),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('→',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3),
                                      fontSize: 11)),
                            ),
                            Text(
                              _formatBr(alt.dataFim),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // ── Botão expandir/recolher (baixo) ──────────────────────────────
        if (hasMore)
          _toggleButton(
            label: _expanded
                ? 'Ver menos'
                : 'Ver mais $hidden registro${hidden > 1 ? 's' : ''}',
            expanded: _expanded,
            isDark: isDark,
            theme: theme,
          ),
      ],
    );
  }
}
