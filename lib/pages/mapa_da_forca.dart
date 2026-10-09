// =================  lib/pages/mapadaforca_page.dart  =================
import 'package:flutter/material.dart';
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import '../widgets/widget_graficos.dart';
import '../widgets/widget_mapa_geral.dart';
import '../widgets/widget_grandes_comandos.dart';
import '../widgets/vidro.dart';

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

          const SizedBox(height: 8),

          // ── Campo de busca ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
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
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surface
                        : const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFDDE6F5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search_rounded,
                          color: primaryBlue.withValues(alpha: 0.7), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Pesquisar militar por nome...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
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

          const SizedBox(height: 10),

          // ── TabBar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: isDark ? 0.06 : 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                // Pílula tingida, no padrão dos chips e da barra inferior.
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(alpha: isDark ? 0.26 : 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.45),
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.55),
                labelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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

          const SizedBox(height: 8),

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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CartaoDestaque(
        raio: 14,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined,
                color: theme.colorScheme.primary, size: 19),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Efetivo Total Previsto',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '3.500 Militares',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
