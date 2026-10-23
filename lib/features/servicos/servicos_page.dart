import 'dart:io';

import 'package:flutter/material.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:projetonovo/features/inicio/linha_atalhos.dart' show rotuloCurto;
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
import 'busca_page.dart';

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

/// Distância de edição (inserir, apagar, trocar uma letra), parando cedo
/// quando passa de [limite].
int distanciaEdicao(String a, String b, {int limite = 2}) {
  if ((a.length - b.length).abs() > limite) return limite + 1;
  var anterior = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final atual = List<int>.filled(b.length + 1, 0)..[0] = i;
    var menor = atual[0];
    for (var j = 1; j <= b.length; j++) {
      final custo = a[i - 1] == b[j - 1] ? 0 : 1;
      atual[j] = [anterior[j] + 1, atual[j - 1] + 1, anterior[j - 1] + custo].reduce((x, y) => x < y ? x : y);
      if (atual[j] < menor) menor = atual[j];
    }
    if (menor > limite) return limite + 1;
    anterior = atual;
  }
  return anterior[b.length];
}

/// Funções que casam com o [termo] pelo nome, pela descrição ou pelos
/// sinônimos, com o caminho da área. Busca por prefixo de palavra; sem
/// nenhum resultado exato, tolera erro de digitação (§7: "contraxeque"):
/// uma letra em palavras de 4 a 7 letras, duas a partir de 8.
List<({ItemMenu item, ItemMenu area})> buscarFuncoes(
    List<ItemMenu> menu, String termo) {
  final t = normalizar(termo.trim());
  if (t.isEmpty) return const [];
  bool casa(String? texto, {required bool tolerante}) {
    if (texto == null) return false;
    final n = normalizar(texto);
    if (t.contains(' ')) return n.contains(t);
    final palavras = n.split(RegExp(r'[^a-z0-9]+'));
    if (!tolerante) return palavras.any((p) => p.startsWith(t));
    if (t.length < 4) return false;
    final limite = t.length >= 8 ? 2 : 1;
    return palavras.any((p) {
      for (var k = t.length - limite; k <= t.length + limite; k++) {
        if (k < 1 || k > p.length) continue;
        if (distanciaEdicao(t, p.substring(0, k), limite: limite) <= limite) return true;
      }
      return false;
    });
  }

  List<({ItemMenu item, ItemMenu area})> passar(bool tolerante) => [
        for (final area in menu)
          for (final f in area.filhos)
            if (casa(f.rotulo, tolerante: tolerante) ||
                casa(f.descricao, tolerante: tolerante) ||
                f.sinonimos.any((s) => casa(s, tolerante: tolerante)))
              (item: f, area: area),
      ];

  final exatos = passar(false);
  return exatos.isNotEmpty ? exatos : passar(true);
}

/// A aba Serviços (§3.3): busca fixa no topo e as áreas em cartões com arte.
class ServicosBody extends StatefulWidget {
  const ServicosBody({super.key});

  @override
  State<ServicosBody> createState() => _ServicosBodyState();
}

class _ServicosBodyState extends State<ServicosBody> {
  @override
  Widget build(BuildContext context) {
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    return ValueListenableBuilder<AppConfig>(
      valueListenable: RepositorioConfig.emUso,
      builder: (context, config, _) {
        final menu = menuEmUso(config, gestor: gestor);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _CampoBusca(
                  aoTocar: () {
                    registrar('tela.abrir', chave: 'busca', dados: {'de': 'servicos'});
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuscaPage()));
                  },
                ),
              ),
            ),
            ...[
              if (_maisUsados(menu, config) case final l when l.isNotEmpty)
                SliverToBoxAdapter(child: _LinhaMaisUsados(itens: l)),
              SliverToBoxAdapter(
                child: _TituloSecao('Áreas',
                    direita: '${menu.length} ${menu.length == 1 ? 'área' : 'áreas'}'),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(builder: (context, c) {
                    // 2 colunas (3 no iPad), cartões de 136; a área que sobra
                    // sozinha na última linha ocupa a largura toda, com 112
                    // (protótipo `.sv-area`, §3.3).
                    final colunas = c.maxWidth >= 600 ? 3 : 2;
                    final largura = (c.maxWidth - 10 * (colunas - 1)) / colunas;
                    final sobra = menu.length % colunas;
                    return Wrap(spacing: 10, runSpacing: 10, children: [
                      for (final (i, a) in menu.indexed)
                        SizedBox(
                          width: sobra == 1 && i == menu.length - 1 ? c.maxWidth : largura,
                          height: sobra == 1 && i == menu.length - 1 ? 112 : 136,
                          child: CartaoArea(area: a, aoTocar: () => _abrirArea(context, a)),
                        ),
                    ]);
                  }),
                ),
              ),
              if (_novidades(menu) case final l when l.isNotEmpty)
                SliverToBoxAdapter(child: _LinhaNovidades(itens: l)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _NaoAchou(aoTocar: () {
                    final ajuda = itemPorChave('atend.ajuda', menu: menu);
                    if (ajuda != null) {
                      abrirFuncao(context, ajuda, origem: 'servicos');
                    } else {
                      Navigator.of(context).pushNamed(AppRoutes.AJUDA_PAGE);
                    }
                  }),
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

/// Título de seção de Serviços (protótipo `.sv-sec`): 18 em negrito e, à
/// direita, um apoio em cinza ("5 áreas").
class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.titulo, {this.direita});
  final String titulo;
  final String? direita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(titulo,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.18, color: theme.colorScheme.onSurface)),
          ),
        ),
        if (direita != null)
          Text(direita!,
              style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.62))),
      ]),
    );
  }
}

/// "Não achou o que procurava?" (protótipo `.sv-ajuda`): linha de vidro que
/// abre o "Preciso de ajuda".
class _NaoAchou extends StatelessWidget {
  const _NaoAchou({required this.aoTocar});
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    return CartaoVidro(
      onTap: aoTocar,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: pri.withValues(alpha: .2), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.help_outline_rounded, size: AppIconSize.md, color: pri),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Não achou o que procurava?',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
            Text('Conte o que precisa e encaminhamos',
                style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: .45)),
      ]),
    );
  }
}

/// Faixa de cartões que rola de lado, cada um com a arte da sua área
/// (protótipo `.sv-novo`: 232 × 112).
class _LinhaNovidades extends StatelessWidget {
  const _LinhaNovidades({required this.itens});

  final List<({ItemMenu item, ItemMenu area})> itens;

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _TituloSecao('Novidades no SouPMRR'),
      SizedBox(
        height: escala.scale(112),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final r = itens[i];
            return SizedBox(
              width: 232,
              child: Semantics(
                button: true,
                label: '${r.item.rotulo}, novo. ${r.item.descricao ?? ''}',
                excludeSemantics: true,
                child: FundoArte(
                  arte: Arte.de(r.area.arte),
                  formato: FormatoArte.area,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => abrirFuncao(context, r.item, origem: 'novidades'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SeloEstado(texto: 'Novo', sobreArte: true),
                          const Spacer(),
                          Text(r.item.rotulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15, height: 1.2, fontWeight: FontWeight.w700)),
                          if (r.item.descricao != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(r.item.descricao!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5, height: 1.35)),
                            ),
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
    ]);
  }
}

/// Linha de círculos que rola de lado, como os destaques do Instagram
/// (protótipo `.sv-bola`): anel de 64 (colorido quando a função é nova),
/// miolo na cor do fundo e o ícone num círculo tingido de 53.
class _LinhaMaisUsados extends StatelessWidget {
  const _LinhaMaisUsados({required this.itens});

  final List<({ItemMenu item, ItemMenu area})> itens;

  static const _anelNovo = SweepGradient(
    startAngle: 0,
    endAngle: 6.2832,
    transform: GradientRotation(3.665),
    colors: [
      Color(0xFF4FD8F0), Color(0xFF2E7FBF), Color(0xFF7C6CF2), //
      Color(0xFFE5487F), Color(0xFFFFB300), Color(0xFF4FD8F0),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    final fundo = theme.brightness == Brightness.dark ? const Color(0xFF03050A) : theme.colorScheme.surface;
    final escala = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _TituloSecao('Mais usados'),
      SizedBox(
        height: 64 + 6 + escala.scale(14),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final r = itens[i];
            final novo = r.item.selo == 'Novo';
            return Semantics(
              button: true,
              label: novo ? '${r.item.rotulo}, novo' : r.item.rotulo,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => abrirFuncao(context, r.item, origem: 'mais_usados'),
                child: SizedBox(
                  width: 76,
                  child: Column(children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: novo ? null : theme.colorScheme.onSurface.withValues(alpha: .14),
                        gradient: novo ? _anelNovo : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fundo,
                          border: Border.all(color: fundo, width: 3),
                        ),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: pri.withValues(alpha: .2)),
                          child: Icon(iconePorChave(r.item.icone), color: pri, size: 26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(rotuloCurto(r.item),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, height: 1.2, letterSpacing: -0.11, color: theme.colorScheme.onSurface)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// O campo de Serviços é um botão: abre a busca (protótipo `.campo-busca`,
/// 44 de altura, raio 12; no Android, 56 e raio 28).
class _CampoBusca extends StatelessWidget {
  const _CampoBusca({required this.aoTocar});

  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = Platform.isIOS;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final raio = BorderRadius.circular(ios ? 12 : 28);
    return Semantics(
      button: true,
      label: 'Buscar serviço, função ou assunto',
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.onSurface.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: .10)),
        ),
        child: InkWell(
          borderRadius: raio,
          onTap: aoTocar,
          child: SizedBox(
            height: ios ? 44 : 56,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ios ? 12 : 16),
              child: Row(children: [
                Icon(Icons.search, size: AppIconSize.sm, color: mudo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Buscar serviço, função ou assunto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.5, color: mudo)),
                ),
              ]),
            ),
          ),
        ),
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
        formato: FormatoArte.area,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: Icon(iconePorChave(area.icone), color: Colors.white, size: AppIconSize.sm),
                  ),
                  const Spacer(),
                  Text(area.rotulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(contagem,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5, height: 1.35)),
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
        appBar: CustomAppBar(title: area.rotulo),
        body: CustomScrollView(slivers: [
          // Cartão grande da área (protótipo `.sv-hero`): 164 de altura,
          // ícone num quadrado de vidro de 44, nome de 21 e a descrição.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(164),
                child: FundoArte(
                  arte: arte,
                  formato: FormatoArte.area,
                  tamanhoIcone: 120,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: Icon(iconePorChave(area.icone), color: Colors.white, size: AppIconSize.md),
                        ),
                        const Spacer(),
                        Text(area.rotulo,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 21, height: 1.2, fontWeight: FontWeight.w700)),
                        if (area.descricao != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(area.descricao!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82), fontSize: 13, height: 1.35)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Ladrilhos em 2 colunas (3 no iPad), 10 entre eles; cada linha
          // cresce até o ladrilho mais alto dela (como o grid do protótipo).
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(builder: (context, c) {
              final colunas = c.crossAxisExtent >= 600 ? 3 : 2;
              final linhas = <List<ItemMenu>>[
                for (var i = 0; i < area.filhos.length; i += colunas)
                  area.filhos.sublist(i, (i + colunas).clamp(0, area.filhos.length)),
              ];
              return SliverList.separated(
                itemCount: linhas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var j = 0; j < colunas; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(
                        child: j < linhas[i].length
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 127),
                                child: _LadrilhoFuncao(item: linhas[i][j], cor: arte.destaque),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ]),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

/// Ladrilho de função (protótipo `.sv-tile`): vidro, ícone num quadrado de
/// 38 tingido pela cor da área, nome de 14, descrição de duas linhas e o
/// selo no canto. Bloqueada fica apagada.
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
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: cor.withValues(alpha: .18), borderRadius: BorderRadius.circular(12)),
                  child: Icon(iconePorChave(item.icone), color: cor, size: AppIconSize.sm),
                ),
                const SizedBox(height: 10),
                Text(item.rotulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14, height: 1.25, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                if (item.descricao != null) ...[
                  const SizedBox(height: 4),
                  Text(item.descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, height: 1.3, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
                ],
              ],
            ),
            if (item.selo != null) Positioned(top: 0, right: 0, child: SeloEstado(texto: item.selo!)),
          ]),
        ),
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
    // Protótipo `.selo`: fundo de 14% e o texto na cor, sem borda. Sobre a
    // arte o fundo é sempre escuro, então valem os tons claros.
    final escuro = sobreArte || Theme.of(context).brightness == Brightness.dark;
    final cor = novo
        ? (escuro ? const Color(0xFF6EE7A0) : const Color(0xFF14713B))
        : (escuro ? const Color(0xFFFFC233) : const Color(0xFF8A5A00));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor)),
    );
  }
}
