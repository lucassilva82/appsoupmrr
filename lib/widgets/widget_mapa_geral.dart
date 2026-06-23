// lib/widgets/widget_mapa_geral.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/utils/app_theme.dart';

class WidgetMapaGeral extends StatefulWidget {
  const WidgetMapaGeral({super.key});
  @override
  State<WidgetMapaGeral> createState() => _WidgetMapaGeralState();
}

class _WidgetMapaGeralState extends State<WidgetMapaGeral> {
  late Future<List<Situacao>> _future;

  final List<String> _siglas = [
    'CEL',
    'TC',
    'MAJ',
    'CAP',
    '1º TEN',
    '2º TEN',
    'ASP',
    'CHO-CAD IV',
    'SUB TEN',
    '1º SGT',
    '2º SGT',
    '3º SGT',
    'AL SGT',
    'CB',
    'AL CB',
    'SD',
    'AL SD',
  ];
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = _siglas.toSet();
    _future = _fetch();
  }

  Future<List<Situacao>> _fetch() async {
    if (_sel.isEmpty) return [];
    Uri uri;
    if (_sel.length == _siglas.length) {
      uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/mapadaforca/listarsituacao.php');
    } else {
      final qs =
          _sel.map((s) => 'posto[]=${Uri.encodeQueryComponent(s)}').join('&');
      uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/mapadaforca/listarsituacao.php?$qs');
    }
    final r = await http.get(uri);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['result'] as List)
        .map((e) => Situacao.fromJson(e))
        .where((e) => e.quantidade > 0)
        .toList();
  }

  void _toggleChip(String sig, bool v) {
    setState(() {
      v ? _sel.add(sig) : _sel.remove(sig);
      _future = _fetch();
    });
  }

  void _toggleTodos() {
    setState(() {
      _sel.length == _siglas.length ? _sel.clear() : _sel = _siglas.toSet();
      _future = _fetch();
    });
  }

  Widget _filterSection(ThemeData theme, bool isDark) {
    final allSel = _sel.length == _siglas.length;
    final split = (_siglas.length / 2).ceil();
    final row1 = _siglas.take(split).toList();
    final row2 = _siglas.skip(split).toList();

    Widget chip(String sig) {
      final selected = _sel.contains(sig);
      return FilterChip(
        label: Text(sig),
        selected: selected,
        onSelected: (v) => _toggleChip(sig, v),
        selectedColor: AppColors.blue,
        checkmarkColor: Colors.white,
        backgroundColor:
            isDark ? theme.colorScheme.surface : const Color(0xFFF2F6FF),
        side: BorderSide(
          color: selected
              ? AppColors.blue
              : isDark
                  ? const Color(0xFF30363D)
                  : const Color(0xFFDDE6F5),
        ),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? Colors.white
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggleTodos,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: allSel
                        ? AppColors.blue
                        : isDark
                            ? theme.colorScheme.surface
                            : const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: allSel
                          ? AppColors.blue
                          : isDark
                              ? const Color(0xFF30363D)
                              : const Color(0xFFDDE6F5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allSel
                            ? Icons.clear_all_rounded
                            : Icons.select_all_rounded,
                        size: 14,
                        color: allSel
                            ? Colors.white
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        allSel ? 'Limpar' : 'Todos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: allSel
                              ? Colors.white
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Filtros',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: row1
                  .map((sig) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: chip(sig)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: row2
                  .map((sig) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: chip(sig)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listItem(Situacao d, int i, int total, ThemeData theme, bool isDark) {
    final rawPct = total <= 0 ? 0.0 : d.quantidade / total;
    final pct = rawPct.clamp(0.0, 1.0);
    final visualPct = d.quantidade > 0 && pct < 0.05 ? 0.05 : pct;
    final pctText = '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';
    final isEven = i.isEven;
    return Material(
      color: isEven
          ? Colors.transparent
          : (isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.015)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalhesMapaForcaPage(
              dadosBusca: MapBuscaDetalhesModel(
                idSituacao: d.id.toString(),
                descricao: d.descricao,
                postoGraduacao: _sel.toList(),
                quantidade: d.quantidade.toString(),
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  d.descricao,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pctText,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: AppColors.blue
                            .withValues(alpha: isDark ? 0.14 : 0.10),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: visualPct,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.lightBlue,
                                  AppColors.blue.withValues(alpha: 0.95),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.quantidade.toString(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.lightBlue : AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterSection(theme, isDark),
        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
        if (_sel.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_off_rounded,
                      size: 36,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 10),
                  Text('Selecione um posto ou graduação.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      )),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: FutureBuilder<List<Situacao>>(
              future: _future,
              builder: (c, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                }
                if (s.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 32,
                            color: Colors.redAccent.withValues(alpha: 0.7)),
                        const SizedBox(height: 8),
                        Text('Erro ao carregar dados.',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                final list = s.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Text('Nenhum resultado.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                  );
                }
                final total = list.fold<int>(0, (t, e) => t + e.quantidade);
                return Column(
                  children: [
                    // Cabeçalho
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: isDark
                          ? AppColors.navy.withValues(alpha: 0.7)
                          : AppColors.blue,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Situação Funcional',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3)),
                          ),
                          Text('Efetivo',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    // Lista
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: theme.dividerColor.withValues(alpha: 0.2),
                        ),
                        itemBuilder: (_, i) =>
                            _listItem(list[i], i, total, theme, isDark),
                      ),
                    ),
                    // Rodapé total
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.navy.withValues(alpha: 0.78)
                              : AppColors.blue,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('TOTAL',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(total.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class Situacao {
  final int id;
  final String descricao;
  final int quantidade;
  Situacao(
      {required this.id, required this.descricao, required this.quantidade});
  factory Situacao.fromJson(Map<String, dynamic> j) => Situacao(
        id: j['id_situacao'] as int,
        descricao: j['descricao_situacao'] as String,
        quantidade: j['quantidade'] as int,
      );
}
