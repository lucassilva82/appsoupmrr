import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';

import '../models/auth_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import '../view/second_screen.dart';

class Contracheque extends StatefulWidget {
  Contracheque({Key? key}) : super(key: key);

  @override
  _ContrachequeState createState() => _ContrachequeState();

  String _anoSelecionado = DateTime.now().year.toString();
  late List<MesesContracheque> mesesContracheque;
}

class _ContrachequeState extends State<Contracheque> {
  final DadosSql dadosSql = DadosSql();

  List<int> get listaAnos {
    final anoAtual = DateTime.now().year;
    return List.generate(anoAtual - 2019, (i) => anoAtual - i);
  }

  Future<List<MesesContracheque>> _buscaDadosSql(String ano) async {
    final auth = Provider.of<Auth>(context, listen: false);
    widget.mesesContracheque =
        await dadosSql.listaMesesContracheque(auth.cpf!, ano);
    return widget.mesesContracheque;
  }

  /// Agrupa a lista por mês (chave = "mes_ano"), preservando a ordem
  List<MapEntry<String, List<MesesContracheque>>> _groupByMonth(
      List<MesesContracheque> lista) {
    final Map<String, List<MesesContracheque>> map = {};
    for (final item in lista) {
      final key = '${item.mes}_${item.ano}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map.entries.toList();
  }

  /// Verifica se o item é do mês/ano atual (para exibir o badge NOVO).
  bool _isThisMonth(MesesContracheque item) {
    final now = DateTime.now();
    return item.mes == now.month.toString() && item.ano == now.year.toString();
  }

  String _capitalizeFolha(String folha) {
    return folha
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(title: 'Contracheques'),
      floatingActionButton: _ShimmerFab(
        onTap: () {
          final auth = Provider.of<Auth>(context, listen: false);
          Navigator.of(context).pushNamed(
            AppRoutes.CONTRACHEQUE_GRAFICO_PAGE,
            arguments: {
              'cpf': auth.cpf!,
              'ano': widget._anoSelecionado,
            },
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seletor de ano — continuação visual do AppBar ─────────────
          _buildYearBar(isDark),

          // ── Lista agrupada ────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<MesesContracheque>>(
              future: _buscaDadosSql(widget._anoSelecionado),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.blue),
                  );
                }
                if (snapshot.hasError) return SecondScreen();
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isDark);
                }
                return _buildGroupedList(snapshot.data!, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Seletor de anos no estilo do restante do app ────────────────────
  Widget _buildYearBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8EDF5),
          ),
        ),
      ),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: listaAnos.map((ano) {
            final anoStr = ano.toString();
            final isSelected = anoStr == widget._anoSelecionado;
            return GestureDetector(
              onTap: () => setState(() => widget._anoSelecionado = anoStr),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.blue
                      : (isDark
                          ? const Color(0xFF21262D)
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.blue
                        : (isDark
                            ? const Color(0xFF30363D)
                            : Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  anoStr,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Lista agrupada por mês ────────────────────────────────────────────
  Widget _buildGroupedList(List<MesesContracheque> lista, bool isDark) {
    final groups = _groupByMonth(lista);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final entry = groups[i];
        final items = entry.value;
        final mesExtenso = items.first.mesExtenso;
        return _buildMonthGroup(mesExtenso, items, isDark, ctx);
      },
    );
  }

  // ── Grupo de um mês ───────────────────────────────────────────────────
  Widget _buildMonthGroup(String mesExtenso, List<MesesContracheque> items,
      bool isDark, BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do mês
          Row(
            children: [
              Text(
                mesExtenso,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 0.3,
                ),
              ),
              if (items.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} folhas',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white12 : Colors.black12,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Cards do mês
          ...items.map((item) => _buildPayslipCard(item, isDark, ctx)),
        ],
      ),
    );
  }

  // ── Card de cada contracheque ─────────────────────────────────────────
  Widget _buildPayslipCard(
      MesesContracheque item, bool isDark, BuildContext ctx) {
    final isAtivo = item.tipo == 'A';
    final accentColor = isAtivo ? AppColors.blue : const Color(0xFFE67E00);

    final primaryText = item.tipo == 'A'
        ? _capitalizeFolha(item.relacaoTrabalho)
        : _capitalizeFolha(
            item.folha.isNotEmpty ? item.folha : item.relacaoTrabalho);

    final badgeLabel = isAtivo ? 'Ativo' : item.tipo;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            item.cpf = Provider.of<Auth>(ctx, listen: false).cpf!;
            Navigator.of(ctx)
                .pushNamed(AppRoutes.PAGE_VIEW_CONTRACHEQUE, arguments: item);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2128) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF30363D) : const Color(0xFFE8EDF5),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            // clipBehavior garante que a stripe lateral respeita o borderRadius
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Stripe lateral colorida ──────────────────────
                  Container(width: 3, color: accentColor),
                  // ── Conteúdo do card ─────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          // Ícone do tipo de folha
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Texto principal
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        primaryText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ),
                                    if (_isThisMonth(item)) ...[
                                      const SizedBox(width: 6),
                                      const _NovoBadge(),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mat. ${item.matricula}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Badge tipo
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white24
                                : Colors.black.withValues(alpha: 0.15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Nenhum contracheque em ${widget._anoSelecionado}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge pulsante "NOVO" ────────────────────────────────────────────────────
class _NovoBadge extends StatefulWidget {
  const _NovoBadge();

  @override
  State<_NovoBadge> createState() => _NovoBadgeState();
}

class _NovoBadgeState extends State<_NovoBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'NOVO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

// ── FAB Shimmer ────────────────────────────────────────────────────────────
class _ShimmerFab extends StatefulWidget {
  final VoidCallback onTap;
  const _ShimmerFab({required this.onTap});

  @override
  State<_ShimmerFab> createState() => _ShimmerFabState();
}

class _ShimmerFabState extends State<_ShimmerFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pos = _ctrl.value * 4.0 - 1.5;
        // Sombra fica FORA do clip para seguir o shape arredondado
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: isDark ? 0.45 : 0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                splashColor: Colors.white.withValues(alpha: 0.18),
                highlightColor: Colors.white.withValues(alpha: 0.08),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF0D2137),
                              AppColors.blue,
                              const Color(0xFF42A5F5),
                            ]
                          : [
                              AppColors.navy,
                              AppColors.blue,
                              const Color(0xFF64B5F6),
                            ],
                      stops: const [0.0, 0.55, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(pos - 0.7, -0.5),
                        end: Alignment(pos + 0.7, 0.5),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        const Text(
                          'Análise Salarial',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
