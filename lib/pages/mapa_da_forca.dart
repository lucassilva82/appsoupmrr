// =================  lib/pages/mapadaforca_page.dart  =================
import 'package:flutter/material.dart';
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import '../widgets/widget_graficos.dart';
import '../widgets/widget_mapa_geral.dart';
import '../widgets/widget_grandes_comandos.dart';

class MapadaforcaPage extends StatefulWidget {
  const MapadaforcaPage({super.key});

  @override
  State<MapadaforcaPage> createState() => _MapadaforcaPageState();
}

class _MapadaforcaPageState extends State<MapadaforcaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryBlue = AppColors.blue;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Mapa da Força'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner de efetivo ──────────────────────────────────────────
          _bannerEfetivo(context, isDark),

          const SizedBox(height: 12),

          // ── Campo de busca ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetalhesMapaForcaPage(
                        dadosBusca: MapBuscaDetalhesModel(
                          idSituacao: '',
                          descricao: '— Busca Geral',
                          postoGraduacao: [],
                          quantidade: '',
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surface
                        : const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFDDE6F5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded,
                          color: primaryBlue.withValues(alpha: 0.7), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Pesquisar militar por nome...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── TabBar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface
                    : const Color(0xFFF2F6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFDDE6F5),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.55),
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Gráficos'),
                  Tab(text: 'Mapa Geral'),
                  Tab(text: 'Comandos'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Conteúdo dinâmico ──────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                WidgetGraficos(),
                WidgetMapaGeral(),
                WidgetGrandesComandos(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerEfetivo(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF002154)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: isDark ? 0.20 : 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Efetivo Total Previsto',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Text(
                '3.500 Militares',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
