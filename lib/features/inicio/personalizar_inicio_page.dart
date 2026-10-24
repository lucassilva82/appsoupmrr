import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../pages/home_page.dart' show blocosPadrao;
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/dialogo_confirmacao.dart';
import '../../widgets/vidro.dart';
import '../servicos/servicos_page.dart';
import 'linha_atalhos.dart' show atalhosPadrao;
import 'preferencias_inicio.dart';

const _maxAtalhos = 12;

InicioPreferenciasRepositorio repositorioPreferencias(BuildContext context) {
  final auth = context.read<Auth>();
  return InicioPreferenciasRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}

/// Nome do bloco para o militar.
String nomeBloco(BlocoInicio b) => switch (b.chave) {
      'home.comandantes' => 'Comando',
      'home.anuncio' => 'Comunicados',
      'home.carreira' => 'Sua carreira',
      'home.dicas' => 'Dica',
      'home.pendencias' => 'Suas pendências',
      'home.atalhos' => 'Atalhos',
      'home.contracheque' => 'Contracheque',
      'home.tempo_servico' => 'Tempo de serviço',
      'home.ferias' => 'Plano de férias',
      _ => b.bruto['dados'] is Map ? '${(b.bruto['dados'] as Map)['titulo'] ?? 'Card'}' : 'Card',
    };

/// Personalizar a tela inicial (§4.5): arrastar pela alça, esconder com o
/// interruptor (bloco fixo mostra o cadeado) e escolher até 12 atalhos.
/// Salva no aparelho e no servidor ao tocar em "Concluído".
class PersonalizarInicioPage extends StatefulWidget {
  const PersonalizarInicioPage({super.key, this.repositorio});
  final InicioPreferenciasRepositorio? repositorio;

  @override
  State<PersonalizarInicioPage> createState() => _PersonalizarInicioPageState();
}

class _PersonalizarInicioPageState extends State<PersonalizarInicioPage> {
  late final InicioPreferenciasRepositorio _repo = widget.repositorio ?? repositorioPreferencias(context);
  late List<BlocoInicio> _blocos;
  late Set<String> _escondidos;
  late List<String> _atalhos;
  bool _mudou = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    registrar('tela.abrir', chave: 'apar.tema', dados: {'tela': 'personalizar_inicio'});
    _montar(InicioPreferenciasRepositorio.emUso.value);
  }

  void _montar(PreferenciasInicio? pref) {
    final config = RepositorioConfig.atual;
    final doPainel = config.home ?? blocosPadrao();
    final porChave = {for (final b in doPainel) b.chave: b};
    // A ordem atual, com os escondidos também (para voltarem de onde saíram).
    final todos = ordenarBlocos(doPainel, pref == null ? null : PreferenciasInicio(blocos: [
      for (final b in pref.blocos) (chave: b.chave, visivel: true),
    ]));
    _blocos = [for (final c in todos) porChave[c]!];
    _escondidos = {
      for (final b in pref?.blocos ?? const <({String chave, bool visivel})>[])
        if (!b.visivel && (porChave[b.chave]?.escondivel ?? false)) b.chave,
    };
    final gestor = context.read<Auth>().isSuperUser;
    final doPainelAtalhos = config.bloco('home.atalhos')?.dados;
    _atalhos = [...pref?.atalhos ?? (doPainelAtalhos == null || doPainelAtalhos.isEmpty ? atalhosPadrao(gestor: gestor) : doPainelAtalhos)];
  }

  Future<void> _concluir() async {
    if (!_mudou) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _salvando = true);
    final pref = PreferenciasInicio(
      blocos: [for (final b in _blocos) (chave: b.chave, visivel: !_escondidos.contains(b.chave))],
      atalhos: _atalhos,
    );
    try {
      await _repo.salvar(pref);
      registrar('inicio.personalizar', dados: {
        'ordem': [for (final b in _blocos) b.chave],
        'escondidos': _escondidos.toList(),
        'atalhos': _atalhos.length,
      });
      if (mounted) avisoSucesso(context, 'Tela inicial atualizada');
    } on FalhaApp catch (f) {
      // Ficou no aparelho; só não foi para o servidor.
      registrarErro(f, tela: 'personalizar_inicio', mostrado: true);
      if (mounted) {
        avisoAtencao(context, 'Guardado só neste aparelho',
            texto: 'O servidor não recebeu agora; em outro aparelho a Início fica como antes. Código ${f.codigo}.');
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restaurar() async {
    final ok = await dialogoConfirmacao(context,
        titulo: 'Restaurar o padrão da PMRR?',
        mensagem: 'A ordem dos blocos, os escondidos e os atalhos voltam a ser os do padrão.',
        textoConfirmar: 'Restaurar');
    if (ok != true || !mounted) return;
    try {
      await _repo.restaurar();
      registrar('inicio.personalizar', dados: {'restaurar': true});
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'personalizar_inicio', mostrado: false);
    }
    if (!mounted) return;
    setState(() {
      _montar(null);
      _mudou = false;
    });
    avisoSucesso(context, 'Padrão da PMRR restaurado');
  }

  Future<void> _adicionarAtalho() async {
    final config = RepositorioConfig.atual;
    final menu = menuEmUso(config, gestor: context.read<Auth>().isSuperUser);
    final opcoes = [
      for (final area in menu)
        for (final f in area.filhos)
          if (f.tipo == 'funcao' && !_atalhos.contains(f.chave)) (item: f, area: area),
    ];
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _EscolherAtalho(opcoes: opcoes),
    );
    if (escolhido == null) return;
    setState(() {
      _atalhos.add(escolhido);
      _mudou = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menu = menuEmUso(RepositorioConfig.atual, gestor: context.read<Auth>().isSuperUser);
    final nomes = {for (final a in menu) for (final f in a.filhos) f.chave: (f, a)};
    return PopScope(
      canPop: !_salvando,
      child: FundoSuave(
        child: Scaffold(
          appBar: CustomAppBar(title: 'Personalizar início', actions: [
            TextButton(onPressed: _salvando ? null : _concluir, child: const Text('Concluído')),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text('Arraste pela alça para mudar a ordem e use o interruptor para esconder. '
                  'Os blocos com cadeado são fixos.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              CartaoVidro(
                padding: const EdgeInsets.symmetric(vertical: 4),
                arte: Arte.de('rh'),
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (de, para) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (para > de) para--;
                      _blocos.insert(para, _blocos.removeAt(de));
                      _mudou = true;
                    });
                  },
                  children: [
                    for (final (i, b) in _blocos.indexed)
                      _LinhaBloco(
                        key: ValueKey(b.chave),
                        indice: i,
                        total: _blocos.length,
                        nome: nomeBloco(b),
                        fixo: !b.escondivel,
                        visivel: !_escondidos.contains(b.chave),
                        aoMudar: (v) => setState(() {
                          v ? _escondidos.remove(b.chave) : _escondidos.add(b.chave);
                          _mudou = true;
                        }),
                        aoMover: (para) => setState(() {
                          _blocos.insert(para, _blocos.removeAt(i));
                          _mudou = true;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text('ATALHOS (${_atalhos.length} de $_maxAtalhos)', style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1))),
                if (_atalhos.length < _maxAtalhos)
                  TextButton.icon(onPressed: _adicionarAtalho, icon: const Icon(Icons.add), label: const Text('Adicionar')),
              ]),
              CartaoVidro(
                padding: const EdgeInsets.symmetric(vertical: 4),
                arte: Arte.de('rh'),
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (de, para) => setState(() {
                    if (para > de) para--;
                    _atalhos.insert(para, _atalhos.removeAt(de));
                    _mudou = true;
                  }),
                  children: [
                    for (final c in _atalhos)
                      ListTile(
                        key: ValueKey('atalho-$c'),
                        leading: Icon(iconePorChave(nomes[c]?.$1.icone), color: Arte.de(nomes[c]?.$2.arte).destaque),
                        title: Text(nomes[c]?.$1.rotulo ?? c),
                        subtitle: nomes[c] == null ? const Text('Indisponível para você agora') : null,
                        trailing: IconButton(
                          tooltip: 'Tirar dos atalhos',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() {
                            _atalhos.remove(c);
                            _mudou = true;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _salvando ? null : _restaurar,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restaurar o padrão da PMRR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaBloco extends StatelessWidget {
  const _LinhaBloco({super.key, required this.indice, required this.total, required this.nome, required this.fixo,
      required this.visivel, required this.aoMudar, required this.aoMover});

  final int indice;
  final int total;
  final String nome;
  final bool fixo;
  final bool visivel;
  final ValueChanged<bool> aoMudar;
  final ValueChanged<int> aoMover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Leitor de tela e teclado: a alça aceita "subir" e "descer" (§4.5).
    return Semantics(
      customSemanticsActions: {
        if (indice > 0) const CustomSemanticsAction(label: 'Subir'): () => aoMover(indice - 1),
        if (indice < total - 1) const CustomSemanticsAction(label: 'Descer'): () => aoMover(indice + 1),
      },
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: indice,
          child: const SizedBox(width: 44, height: 44, child: Icon(Icons.drag_handle_rounded)),
        ),
        title: Text(nome, style: TextStyle(color: visivel ? null : theme.colorScheme.onSurfaceVariant)),
        subtitle: fixo ? const Text('Fixo') : (visivel ? null : const Text('Escondido')),
        trailing: fixo
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.lock_outline, size: AppIconSize.sm, color: theme.colorScheme.onSurfaceVariant),
              )
            : Switch(value: visivel, onChanged: aoMudar),
      ),
    );
  }
}

class _EscolherAtalho extends StatefulWidget {
  const _EscolherAtalho({required this.opcoes});
  final List<({ItemMenu item, ItemMenu area})> opcoes;

  @override
  State<_EscolherAtalho> createState() => _EscolherAtalhoState();
}

class _EscolherAtalhoState extends State<_EscolherAtalho> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final termo = normalizar(_busca);
    final lista = [
      for (final o in widget.opcoes)
        if (termo.isEmpty || normalizar('${o.item.rotulo} ${o.item.descricao ?? ''} ${o.item.sinonimos.join(' ')}').contains(termo)) o,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Buscar função', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final o in lista)
                ListTile(
                  leading: Icon(iconePorChave(o.item.icone), color: Arte.de(o.area.arte).destaque),
                  title: Text(o.item.rotulo),
                  subtitle: Text(o.area.rotulo),
                  onTap: () => Navigator.of(context).pop(o.item.chave),
                ),
              if (lista.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhuma função com esse nome.'))),
            ]),
          ),
        ]),
      ),
    );
  }
}
