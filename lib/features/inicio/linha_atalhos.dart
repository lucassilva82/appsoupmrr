import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/design/folha_arte.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../servicos/servicos_page.dart';
import '../../widgets/vidro.dart';
import 'personalizar_inicio_page.dart';
import 'preferencias_inicio.dart';

/// Atalhos padrão até o painel mandar os de cada nível (`home.atalhos`).
/// O gestor troca o último pelo Mapa da Força (§4.4).
List<String> atalhosPadrao({required bool gestor}) => [
      'rh.contracheques',
      'rh.certidoes',
      'rh.ferias',
      'rh.ficha',
      'rh.tempo_servico',
      'rh.declaracoes',
      gestor ? 'gestao.mapa_forca' : 'normas.legislacoes',
    ];

/// Acha as funções dos atalhos no menu em uso, com a área de cada uma (para
/// a cor). Atalho de função oculta ou sem acesso some sozinho.
List<({ItemMenu item, ItemMenu area})> resolverAtalhos(
    List<ItemMenu> menu, List<String> chaves) {
  final porChave = {
    for (final a in menu)
      for (final f in a.filhos) ...{
        f.chave: (item: f, area: a),
        for (final ap in f.apelidos) ap: (item: f, area: a),
      },
  };
  return [
    for (final c in chaves)
      if (porChave[c] != null) porChave[c]!,
  ];
}

/// Nome curto de cada função no atalho (protótipo `CURTO`): o rótulo do
/// menu não cabe embaixo de um ícone de 44.
const rotulosCurtos = <String, String>{
  'rh.contracheques': 'Contracheque',
  'rh.ferias': 'Férias',
  'rh.documentos': 'Documentos',
  'rh.certidoes': 'Certidões',
  'atend.feedback': 'Sugestões',
  'rh.tempo_servico': 'Tempo de serviço',
  'normas.legislacoes': 'Legislações',
  'rh.declaracoes': 'Declarações',
  'rh.ficha': 'Minha ficha',
  'gestao.mapa_forca': 'Mapa da Força',
  'atend.chamados': 'Chamados',
};

String rotuloCurto(ItemMenu f) => rotulosCurtos[f.chave] ?? f.rotulo;

/// Quantos atalhos cabem inteiros numa linha. Se o militar tem mais do que
/// cabe, o último lugar vira "Mais" (§4.4: sem atalho cortado).
int atalhosQueCabem(double largura, int total, {double celula = 68}) {
  final cabem = (largura / celula).floor().clamp(1, 12);
  if (total <= cabem) return total;
  return cabem - 1;
}

/// Uma linha só de atalhos, divididos por igual na largura (§4.4).
class LinhaAtalhos extends StatelessWidget {
  const LinhaAtalhos({super.key});

  @override
  Widget build(BuildContext context) {
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    return ListenableBuilder(
      listenable: Listenable.merge(
          [RepositorioConfig.emUso, InicioPreferenciasRepositorio.emUso]),
      builder: (context, _) {
        final config = RepositorioConfig.atual;
        final doMilitar = InicioPreferenciasRepositorio.emUso.value?.atalhos;
        final doPainel = config.bloco('home.atalhos')?.dados;
        final atalhos = resolverAtalhos(
            menuEmUso(config, gestor: gestor),
            doMilitar ??
                (doPainel == null || doPainel.isEmpty
                    ? atalhosPadrao(gestor: gestor)
                    : doPainel));
        if (atalhos.isEmpty) return const SizedBox.shrink();
        // Cabeçalho "Atalhos" com "Editar" e a caixa de vidro com a arte
        // discreta (protótipo `.vidro.atalhos`).
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CabecalhoSecao(
              titulo: 'Atalhos',
              direita: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PersonalizarInicioPage())),
                style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
                child: Text('Editar',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            CartaoVidro(
              padding: EdgeInsets.zero,
              child: Stack(children: [
                ArteDiscreta(arte: Arte.de('cc')),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: LayoutBuilder(builder: (context, c) {
                    final n = atalhosQueCabem(c.maxWidth, atalhos.length);
                    final mais = n < atalhos.length;
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final a in atalhos.take(n))
                            Expanded(
                              child: _Atalho(
                                icone: iconePorChave(a.item.icone),
                                cor: Arte.de(a.area.arte).destaque,
                                rotulo: rotuloCurto(a.item),
                                bloqueado: a.item.bloqueado,
                                aoTocar: () => abrirFuncao(context, a.item,
                                    origem: 'atalho'),
                              ),
                            ),
                          if (mais)
                            Expanded(
                              child: _Atalho(
                                icone: Icons.apps_rounded,
                                cor: Theme.of(context).colorScheme.primary,
                                rotulo: 'Mais',
                                aoTocar: () => _todos(context, atalhos),
                              ),
                            ),
                        ]);
                  }),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  void _todos(BuildContext context, List<({ItemMenu item, ItemMenu area})> l) {
    mostrarFolhaArte<void>(
      context,
      arte: Arte.de('rh'),
      icone: Icons.apps_rounded,
      titulo: 'Atalhos',
      subtitulo: 'Todos os seus atalhos da tela inicial.',
      paddingCorpo: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      corpo: (ctx) => Wrap(runSpacing: 12, children: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PersonalizarInicioPage()));
            },
            icon: const Icon(Icons.edit_outlined, size: AppIconSize.sm),
            label: const Text('Editar atalhos'),
          ),
        ),
        for (final a in l)
          SizedBox(
            width: (MediaQuery.sizeOf(ctx).width - 32) / 4,
            child: _Atalho(
              icone: iconePorChave(a.item.icone),
              cor: Arte.de(a.area.arte).destaque,
              rotulo: a.item.rotulo,
              bloqueado: a.item.bloqueado,
              aoTocar: () {
                Navigator.of(ctx).pop();
                abrirFuncao(context, a.item, origem: 'atalho');
              },
            ),
          ),
      ]),
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho({
    required this.icone,
    required this.cor,
    required this.rotulo,
    required this.aoTocar,
    this.bloqueado = false,
  });

  final IconData icone;
  final Color cor;
  final String rotulo;
  final VoidCallback aoTocar;
  final bool bloqueado;

  static TextStyle _estilo(ThemeData t) => TextStyle(
      fontSize: 10.5,
      height: 1.2,
      letterSpacing: -0.21,
      color: t.colorScheme.onSurface);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: bloqueado ? 0.55 : 1,
      child: Semantics(
        button: true,
        label: rotulo,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icone, color: cor, size: AppIconSize.md),
              ),
              const SizedBox(height: 5),
              // Palavra única longa ("Contracheques") encolhe em vez de
              // quebrar no meio; frase quebra em até duas linhas.
              if (rotulo.contains(' '))
                Text(rotulo,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: _estilo(theme))
              else
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(rotulo, maxLines: 1, style: _estilo(theme))),
            ]),
          ),
        ),
      ),
    );
  }
}
