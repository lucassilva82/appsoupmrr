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
import '../core/design/arte_cartao.dart';

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

    return FundoSuave(
        child: Scaffold(
      appBar: const CustomAppBar(title: 'Mapa da Força'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner de efetivo ──────────────────────────────────────────
          _bannerEfetivo(context),

          // ── Campo de busca ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Busca como superfície de vidro, com alvo de 44 pt.
            child: CartaoVidro(
              raio: 14,
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
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded,
                        color: theme.colorScheme.primary, size: AppIconSize.sm),
                    const SizedBox(width: 8),
                    Text(
                      'Pesquisar militar por nome...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── TabBar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Seletor das abas numa superfície de vidro (padrão 2.2), no
            // lugar da caixa cinza feita à mão.
            child: CartaoVidro(
              raio: 12,
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabController,
                // Pílula tingida, no padrão dos chips e da barra inferior.
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(alpha: isDark ? 0.26 : 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: theme.colorScheme.primary,
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
                  Tab(height: 36, text: 'Gráficos'),
                  Tab(height: 36, text: 'Mapa Geral'),
                  Tab(height: 36, text: 'Comandos'),
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
    ));
  }

  // Topo com a arte da área de Gestão (padrão 2.2).
  //
  // SEM NÚMERO À DIREITA, de propósito. Até 29/10/2026 havia "Previsto
  // 3.500 militares", escrito à mão num commit de interface de 12/06/2026 e
  // nunca calculado de nada. Trocá-lo pelo previsto do SIGRH foi tentado e
  // desfeito a pedido do usuário: medido em 30/10/2026, o SIGRH tem só
  // **1.579 das 3.002 vagas autorizadas distribuídas por unidade** (53%), com
  // 6 de 12 comandos e 58 de 304 subunidades sem nenhum lançamento — CPI,
  // DEP, DRH e Corregedoria zerados. Percentual de ocupação sobre isso não
  // mede ocupação: o CPI apareceria sem vaga nenhuma e a ASS MIL TJE com
  // "989% ocupado", que é lançamento faltando lido como excedente.
  //
  // A decisão: enquanto o cadastro estiver incompleto, a tela não mostra
  // previsão. Número redondo escrito à mão era pior; número do banco com
  // metade do cadastro vazio é igualmente ruim, porque **parece** medido.
  // Quando a DRH preencher o SIGRH, o endpoint sigrh/mapa_efetivo.php já
  // está no ar e mede a cobertura (bloco `cobertura`) — é religar a tela.
  Widget _bannerEfetivo(BuildContext context) {
    return TopoArte(
      arte: Arte.de('gestao'),
      icone: Icons.shield_outlined,
      titulo: 'Mapa da Força',
      subtitulo: 'Efetivo e situação dos militares, por comando e unidade.',
      margem: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    );
  }
}
