import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/log/registro_log.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../core/navegacao/menu_padrao.dart';
import '../../models/auth_model.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/vidro.dart';

/// Menu em uso: o do `app_config` (já filtrado pelo servidor) ou, sem ele,
/// o de reserva igual à carga do banco. Só os itens visíveis.
List<ItemMenu> menuEmUso(AppConfig config, {required bool gestor}) {
  final base = config.menu.isNotEmpty ? config.menu : menuPadrao(gestor: gestor);
  List<ItemMenu> visiveis(List<ItemMenu> l) => [
        for (final i in l)
          if (i.visivel)
            if (i.tipo == 'area')
              i.comFilhos(visiveis(i.filhos))
            else
              i,
      ];
  // Área sem função visível some sozinha (§3.2).
  return visiveis(base)
      .where((a) => a.tipo != 'area' || a.filhos.isNotEmpty)
      .toList();
}

/// Sem acento e sem caixa, para a busca achar "ferias" e "Férias".
String normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : para[i]);
  }
  return b.toString();
}

/// Funções que casam com o [termo] pelo nome, pela descrição ou pelos
/// sinônimos, com o caminho da área. Busca por prefixo de palavra.
List<({ItemMenu item, ItemMenu area})> buscarFuncoes(
    List<ItemMenu> menu, String termo) {
  final t = normalizar(termo.trim());
  if (t.isEmpty) return const [];
  bool casa(String? texto) {
    if (texto == null) return false;
    final n = normalizar(texto);
    if (t.contains(' ')) return n.contains(t);
    return n.split(RegExp(r'[^a-z0-9]+')).any((p) => p.startsWith(t));
  }

  return [
    for (final area in menu)
      for (final f in area.filhos)
        if (casa(f.rotulo) || casa(f.descricao) || f.sinonimos.any(casa))
          (item: f, area: area),
  ];
}

/// A aba Serviços (§3.3): busca fixa no topo e as áreas em cartões com arte.
class ServicosBody extends StatefulWidget {
  const ServicosBody({super.key});

  @override
  State<ServicosBody> createState() => _ServicosBodyState();
}

class _ServicosBodyState extends State<ServicosBody> {
  final _busca = TextEditingController();
  String _termo = '';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _mudouBusca(String v) {
    setState(() => _termo = v);
  }

  void _registrarBusca(String termo, int total) {
    if (termo.trim().length < 2) return;
    registrar(total == 0 ? 'busca.sem_resultado' : 'busca.executar',
        dados: {'termo': termo.trim(), 'total': total});
  }

  @override
  Widget build(BuildContext context) {
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    return ValueListenableBuilder<AppConfig>(
      valueListenable: RepositorioConfig.emUso,
      builder: (context, config, _) {
        final menu = menuEmUso(config, gestor: gestor);
        final resultados = buscarFuncoes(menu, _termo);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _CampoBusca(
                  controle: _busca,
                  aoMudar: _mudouBusca,
                  aoEnviar: (v) =>
                      _registrarBusca(v, buscarFuncoes(menu, v).length),
                ),
              ),
            ),
            if (_termo.trim().isNotEmpty)
              _ListaResultados(
                resultados: resultados,
                termo: _termo,
                aoAbrir: (r, pos) {
                  _registrarBusca(_termo, resultados.length);
                  registrar('busca.abrir_resultado',
                      chave: r.item.chave, dados: {'posicao': pos});
                  abrirFuncao(context, r.item, origem: 'busca');
                },
              )
            else ...[
              if (_maisUsados(menu, config) case final l when l.isNotEmpty)
                SliverToBoxAdapter(child: _LinhaMaisUsados(itens: l)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverLayoutBuilder(builder: (context, c) {
                  final colunas = c.crossAxisExtent >= 600 ? 3 : 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colunas,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => CartaoArea(
                        area: menu[i],
                        aoTocar: () => _abrirArea(context, menu[i]),
                      ),
                      childCount: menu.length,
                    ),
                  );
                }),
              ),
              if (_novidades(menu) case final l when l.isNotEmpty)
                SliverToBoxAdapter(child: _LinhaNovidades(itens: l)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        final ajuda = itemPorChave('atend.ajuda', menu: menu);
                        if (ajuda != null) {
                          abrirFuncao(context, ajuda, origem: 'servicos');
                        } else {
                          Navigator.of(context).pushNamed(AppRoutes.AJUDA_PAGE);
                        }
                      },
                      icon: const Icon(Icons.help_outline_rounded, size: AppIconSize.sm),
                      label: const Text('Não achou o que procurava?'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// "Mais usados" (§3.3): o que o servidor mandou, na ordem dele, só com
  /// as funções que estão no menu deste militar.
  List<({ItemMenu item, ItemMenu area})> _maisUsados(
      List<ItemMenu> menu, AppConfig config) {
    final chaves = config.maisUsados ?? const <String>[];
    final porChave = {
      for (final a in menu)
        for (final f in a.filhos) f.chave: (item: f, area: a),
    };
    return [
      for (final c in chaves)
        if (porChave[c] != null) porChave[c]!,
    ];
  }

  /// "Novidades no SouPMRR" (§3.3): as funções com o selo "Novo".
  List<({ItemMenu item, ItemMenu area})> _novidades(List<ItemMenu> menu) => [
        for (final a in menu)
          for (final f in a.filhos)
            if (f.selo == 'Novo' && !f.bloqueado) (item: f, area: a),
      ];

  void _abrirArea(BuildContext context, ItemMenu area) {
    // Área com uma só função abre a função direto (§3.2).
    if (area.filhos.length == 1) {
      abrirFuncao(context, area.filhos.single);
      return;
    }
    registrar('tela.abrir', chave: area.chave, dados: {'de': 'servicos'});
    Navigator.of(context).push(MaterialPageRoute(
      settings: RouteSettings(name: '/servicos/${area.chave}'),
      builder: (_) => AreaPage(area: area),
    ));
  }
}

/// Faixa de cartões que rola de lado, cada um com a arte da sua área.
class _LinhaNovidades extends StatelessWidget {
  const _LinhaNovidades({required this.itens});

  final List<({ItemMenu item, ItemMenu area})> itens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escala = MediaQuery.textScalerOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Semantics(
          header: true,
          child: Text('Novidades no SouPMRR',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
      SizedBox(
        height: escala.scale(56) + 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final r = itens[i];
            return SizedBox(
              width: 220,
              child: Semantics(
                button: true,
                label: '${r.item.rotulo}, novo. ${r.item.descricao ?? ''}',
                excludeSemantics: true,
                child: FundoArte(
                  arte: Arte.de(r.area.arte),
                  tamanhoIcone: 64,
                  raio: 16,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => abrirFuncao(context, r.item, origem: 'novidades'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(iconePorChave(r.item.icone), color: Colors.white, size: AppIconSize.md),
                            const Spacer(),
                            const SeloEstado(texto: 'Novo', sobreArte: true),
                          ]),
                          const Spacer(),
                          Text(r.item.rotulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          if (r.item.descricao != null)
                            Text(r.item.descricao!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12, height: 1.2)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

/// Linha de círculos que rola de lado, como os destaques do Instagram.
class _LinhaMaisUsados extends StatelessWidget {
  const _LinhaMaisUsados({required this.itens});

  final List<({ItemMenu item, ItemMenu area})> itens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text('Mais usados',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ),
      SizedBox(
        height: MediaQuery.textScalerOf(context).scale(34) + 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final r = itens[i];
            final arte = Arte.de(r.area.arte);
            return Semantics(
              button: true,
              label: r.item.rotulo,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => abrirFuncao(context, r.item, origem: 'mais_usados'),
                child: SizedBox(
                  width: 72,
                  child: Column(children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [arte.base, arte.meio],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        border: Border.all(color: arte.destaque, width: 2),
                      ),
                      child: Icon(iconePorChave(r.item.icone),
                          color: Colors.white, size: AppIconSize.md),
                    ),
                    const SizedBox(height: 4),
                    // Palavra única encolhe em vez de quebrar no meio.
                    if (r.item.rotulo.contains(' '))
                      Text(r.item.rotulo,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(letterSpacing: 0, height: 1.15))
                    else
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(r.item.rotulo,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(letterSpacing: 0))),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca(
      {required this.controle, required this.aoMudar, required this.aoEnviar});

  final TextEditingController controle;
  final ValueChanged<String> aoMudar;
  final ValueChanged<String> aoEnviar;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controle,
      onChanged: aoMudar,
      onSubmitted: aoEnviar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar serviço (ex.: holerite, férias)',
        prefixIcon: const Icon(Icons.search, size: AppIconSize.sm),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controle,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close, size: AppIconSize.sm),
                  onPressed: () {
                    controle.clear();
                    aoMudar('');
                  },
                ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ListaResultados extends StatelessWidget {
  const _ListaResultados(
      {required this.resultados, required this.termo, required this.aoAbrir});

  final List<({ItemMenu item, ItemMenu area})> resultados;
  final String termo;
  final void Function(({ItemMenu item, ItemMenu area}) r, int posicao) aoAbrir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (resultados.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverToBoxAdapter(
          child: Column(children: [
            Icon(Icons.search_off_rounded,
                size: AppIconSize.xl, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('Não achamos "${termo.trim()}".',
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tente outra palavra ou veja todas as áreas apagando a busca.',
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ]),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverList.separated(
        itemCount: resultados.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final r = resultados[i];
          return LinhaFuncao(
            item: r.item,
            caminho: r.area.rotulo,
            corIcone: Arte.de(r.area.arte).destaque,
            aoTocar: () => aoAbrir(r, i),
          );
        },
      ),
    );
  }
}

/// Cartão de uma área, com a arte dela, o ícone num quadrado de vidro, o
/// nome e a quantidade de serviços. Texto branco sobre véu escuro.
class CartaoArea extends StatelessWidget {
  const CartaoArea({super.key, required this.area, required this.aoTocar});

  final ItemMenu area;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final n = area.filhos.length;
    final novidade = area.filhos.any((f) => f.selo == 'Novo');
    final contagem = '$n ${n == 1 ? 'serviço' : 'serviços'}${novidade ? ' · com novidade' : ''}';
    return Semantics(
      button: true,
      label: '${area.rotulo}, $contagem',
      excludeSemantics: true,
      child: FundoArte(
        arte: Arte.de(area.arte),
        tamanhoIcone: 84,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: Icon(iconePorChave(area.icone),
                        color: Colors.white, size: AppIconSize.md),
                  ),
                  const Spacer(),
                  Text(area.rotulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(contagem,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dentro da área: cartão grande com a arte e as funções em ladrilhos de
/// 2 colunas (3 no iPad), com o selo de estado no canto.
class AreaPage extends StatelessWidget {
  const AreaPage({super.key, required this.area});

  final ItemMenu area;

  @override
  Widget build(BuildContext context) {
    final arte = Arte.de(area.arte);
    return FundoSuave(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(area.rotulo),
        ),
        body: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: FundoArte(
                  arte: arte,
                  tamanhoIcone: 110,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(area.rotulo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        if (area.descricao != null)
                          Text(area.descricao!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(builder: (context, c) {
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: c.crossAxisExtent >= 600 ? 3 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // Segue o tamanho de fonte do aparelho (Dynamic Type).
                  mainAxisExtent:
                      MediaQuery.textScalerOf(context).scale(116) + 36,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _LadrilhoFuncao(
                    item: area.filhos[i],
                    cor: arte.destaque,
                  ),
                  childCount: area.filhos.length,
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

class _LadrilhoFuncao extends StatelessWidget {
  const _LadrilhoFuncao({required this.item, required this.cor});

  final ItemMenu item;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: item.bloqueado ? 0.55 : 1,
      child: Semantics(
        button: true,
        label: [item.rotulo, if (item.selo != null) item.selo!].join(', '),
        excludeSemantics: true,
        child: CartaoVidro(
          raio: 16,
          padding: const EdgeInsets.all(12),
          onTap: () => abrirFuncao(context, item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(iconePorChave(item.icone), color: cor, size: AppIconSize.lg),
                const Spacer(),
                if (item.selo != null) SeloEstado(texto: item.selo!),
              ]),
              const SizedBox(height: 10),
              Text(item.rotulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (item.descricao != null) ...[
                const SizedBox(height: 2),
                Flexible(
                  child: Text(item.descricao!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de função (busca, listas): 52 pt, ícone, nome, caminho e selo.
class LinhaFuncao extends StatelessWidget {
  const LinhaFuncao({
    super.key,
    required this.item,
    required this.aoTocar,
    this.caminho,
    this.corIcone,
  });

  final ItemMenu item;
  final VoidCallback aoTocar;
  final String? caminho;
  final Color? corIcone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: item.bloqueado ? 0.55 : 1,
      child: CartaoVidro(
        raio: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: aoTocar,
        child: Row(children: [
          Icon(iconePorChave(item.icone),
              color: corIcone ?? theme.colorScheme.primary,
              size: AppIconSize.md),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.rotulo,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (caminho != null)
                  Text('$caminho › ${item.rotulo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (item.selo != null) SeloEstado(texto: item.selo!),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: AppIconSize.sm, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// Selo curto de estado: Em breve, Manutenção, Novo…
class SeloEstado extends StatelessWidget {
  const SeloEstado({super.key, required this.texto, this.sobreArte = false});

  final String texto;

  /// Sobre a arte colorida dos cartões: pílula branca com texto escuro.
  final bool sobreArte;

  @override
  Widget build(BuildContext context) {
    final novo = texto.toLowerCase() == 'novo';
    if (sobreArte) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8)),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy)),
      );
    }
    // Tons do DESIGN §3 por tema: o verde e o âmbar fortes não fecham 4,5:1
    // sobre o vidro escuro.
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final cor = novo
        ? (escuro ? const Color(0xFF6EE7A0) : const Color(0xFF14713B))
        : (escuro ? const Color(0xFFFFC233) : const Color(0xFF8A5A00));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
    );
  }
}
