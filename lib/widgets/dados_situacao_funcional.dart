import 'package:flutter/material.dart';
import '../models/militar.dart';
import '../utils/app_theme.dart';

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

  // Botão de texto do tema (alvo de 44 pt), sem caixa própria.
  Widget _toggleButton({
    required String label,
    required bool expanded,
    required ThemeData theme,
    double bottomPadding = 0,
    double topPadding = 4,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: TextButton(
        onPressed: _toggle,
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: AppIconSize.sm),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final aoFundo = theme.colorScheme.onSurface;
    // Verde de "ativo" nos pares do DESIGN §3 (4,5:1 nos dois temas).
    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;
    final lista = widget.militar.fichaFuncional.alteracoesFuncional;

    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Sem registros funcionais.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: aoFundo.withValues(alpha: 0.6))),
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
            theme: theme,
            bottomPadding: 8,
          ),

        ...visible.asMap().entries.map((entry) {
          final i = entry.key;
          final alt = entry.value;
          final isAtivo = alt.ativo;
          final isLast = i == visible.length - 1 && (!hasMore || _expanded);

          // Item de nível 2 dentro da caixa da seção: sem superfície própria
          // (DESIGN §3b). A linha do tempo à esquerda é a guia; o ativo é
          // marcado pelo ponto e pelo selo verdes, não por uma caixa.
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Linha do tempo ──────────────────────────────────────
                ExcludeSemantics(
                  child: SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAtivo
                                ? verde
                                : aoFundo.withValues(alpha: 0.25),
                            border: Border.all(
                              color: isAtivo
                                  ? verde.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: aoFundo.withValues(alpha: 0.12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ── Registro ─────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
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
                                  color: verde.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: verde.withValues(alpha: 0.40)),
                                ),
                                child: Text(
                                  'Ativo',
                                  style: TextStyle(
                                    color: verde,
                                    fontSize: 11,
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
                            color: aoFundo.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(Icons.calendar_today_outlined,
                                  size: AppIconSize.xxs,
                                  color: aoFundo.withValues(alpha: 0.5)),
                            ),
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
                                  semanticsLabel: 'até',
                                  style: TextStyle(
                                      color: aoFundo.withValues(alpha: 0.4),
                                      fontSize: 11)),
                            ),
                            Text(
                              _formatBr(alt.dataFim),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: aoFundo.withValues(alpha: 0.65),
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
            theme: theme,
          ),
      ],
    );
  }
}
