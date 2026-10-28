import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/log/registro_log.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../core/design/arte_cartao.dart';
import '../../models/auth_model.dart';
import '../../pages/main_shell.dart';
import '../../utils/app_theme.dart';
import '../../widgets/barra_vidro.dart';
import '../../widgets/vidro.dart';
import '../feedback/sugestoes_page.dart';
import 'servicos_page.dart';

const _chaveRecentes = 'busca_recentes';

/// Reserva do "Mais procurados" quando o painel não mandou a lista (§7).
const _maisProcuradosPadrao = ['rh.contracheques', 'rh.certidoes', 'rh.ferias', 'atend.feedback'];

/// Busca global (docs/SOUPM_2_2.md §7), aberta pela lupa no topo das abas e
/// pelo campo de Serviços. O índice é o menu do `app_config`, já filtrado
/// pelo perfil: o que o militar não pode ver não aparece. Sem rede a cada
/// tecla. Desenho do protótipo (`telaBusca`): o campo no lugar da barra,
/// com "Cancelar" no iOS e "×" no Android.
class BuscaPage extends StatefulWidget {
  const BuscaPage({super.key});

  @override
  State<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends State<BuscaPage> {
  final _campo = TextEditingController();
  String _termo = '';
  List<String> _recentes = const [];

  @override
  void initState() {
    super.initState();
    registrar('tela.abrir', chave: 'busca');
    _lerRecentes();
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _lerRecentes() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => _recentes = p.getStringList(_chaveRecentes) ?? const []);
    } catch (_) {}
  }

  Future<void> _guardarRecente(String termo) async {
    final t = termo.trim();
    if (t.length < 2) return;
    final lista = [t, ..._recentes.where((r) => r != t)].take(5).toList();
    setState(() => _recentes = lista);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_chaveRecentes, lista);
    } catch (_) {}
  }

  void _registrar(String termo, int total) {
    if (termo.trim().length < 2) return;
    registrar(total == 0 ? 'busca.sem_resultado' : 'busca.executar', dados: {'termo': termo.trim(), 'total': total});
  }

  void _usar(String termo) {
    _campo.text = termo;
    _campo.selection = TextSelection.collapsed(offset: termo.length);
    setState(() => _termo = termo);
  }

  void _verTodos() {
    Navigator.of(context).pop();
    MainShell.abaPedida.value = 1;
  }

  void _sugerir() {
    registrar('funcao.tocar', chave: 'atend.feedback', dados: {'de': 'busca', 'termo': _termo.trim()});
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SugestoesPage(funcaoSugerida: _termo.trim())));
  }

  @override
  Widget build(BuildContext context) {
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    final config = RepositorioConfig.atual;
    final menu = menuEmUso(config, gestor: gestor);
    final termo = _termo.trim();
    final resultados = buscarFuncoes(menu, termo);

    void abrir(ItemMenu item, int posicao) {
      if (termo.isNotEmpty) {
        _registrar(termo, resultados.length);
        _guardarRecente(termo);
        registrar('busca.abrir_resultado', chave: item.chave, dados: {'posicao': posicao});
      } else {
        registrar('funcao.tocar', chave: item.chave, dados: {'de': 'busca.mais_procurados'});
      }
      abrirFuncao(context, item, origem: 'busca');
    }

    final List<Widget> corpo;
    if (termo.isEmpty) {
      final procurados = [
        for (final k in config.maisProcurados ?? _maisProcuradosPadrao)
          if (itemPorChave(k, menu: menu) case final f?) f,
      ];
      corpo = [
        if (_recentes.isNotEmpty) ...[
          const _Rotulo('Buscas recentes'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _recentes) _ChipRecente(texto: r, aoTocar: () => _usar(r)),
          ]),
        ],
        if (procurados.isNotEmpty) ...[
          const _Rotulo('Mais procurados'),
          _Grupo(children: [
            for (final (i, f) in procurados.indexed)
              _LinhaResultado(item: f, aoTocar: () => abrir(f, i)),
          ]),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
          child: Text(
            'A busca usa nomes, sinônimos e palavras-chave que vêm do painel e só mostra o que o seu perfil pode ver.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62)),
          ),
        ),
      ];
    } else if (resultados.isEmpty) {
      corpo = [_Vazio(termo: termo, aoVerTodos: _verTodos, aoSugerir: _sugerir)];
    } else {
      corpo = [
        _Rotulo('${resultados.length} ${resultados.length == 1 ? 'resultado' : 'resultados'}'),
        _Grupo(children: [
          for (final (i, r) in resultados.indexed)
            _LinhaResultado(
              item: r.item,
              termo: termo,
              subtitulo: r.area.rotulo + (_achadoPorSinonimo(r.item, termo) ? ' · achado por sinônimo' : ''),
              aoTocar: () => abrir(r.item, i),
            ),
        ]),
      ];
    }

    return FundoSuave(
      child: Scaffold(
        body: Column(children: [
          _Cabecalho(
            campo: _campo,
            aoMudar: (v) => setState(() => _termo = v),
            aoEnviar: (v) {
              _registrar(v, buscarFuncoes(menu, v).length);
              _guardarRecente(v);
            },
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 24 + MediaQuery.of(context).padding.bottom),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: corpo,
            ),
          ),
        ]),
      ),
    );
  }
}

/// O termo casou só por um sinônimo (nem o nome nem a descrição têm a
/// palavra): a linha diz isso, como no protótipo.
bool _achadoPorSinonimo(ItemMenu item, String termo) {
  final t = normalizar(termo);
  bool tem(String? s) => s != null && normalizar(s).split(RegExp(r'[^a-z0-9]+')).any((p) => p.startsWith(t));
  return !tem(item.rotulo) && !tem(item.descricao) && item.sinonimos.any(tem);
}

/// O campo no lugar da barra (protótipo `.cab-int` da busca).
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.campo, required this.aoMudar, required this.aoEnviar});

  final TextEditingController campo;
  final ValueChanged<String> aoMudar;
  final ValueChanged<String> aoEnviar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = Platform.isIOS;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .45);
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ios ? 12 : 28),
      borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: .10)),
    );
    final cabeca = Padding(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, ios ? 4 : 8, 8),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: ios ? 44 : 56,
            child: TextField(
              controller: campo,
              autofocus: true,
              onChanged: aoMudar,
              onSubmitted: aoEnviar,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 15.5),
              decoration: InputDecoration(
                hintText: 'Buscar no SouPMRR',
                hintStyle: TextStyle(fontSize: 15.5, color: mudo),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.onSurface.withValues(alpha: .06),
                contentPadding: EdgeInsets.symmetric(vertical: ios ? 12 : 18),
                prefixIcon: Icon(Icons.search, size: AppIconSize.sm, color: mudo),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: campo,
                  builder: (_, v, __) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.cancel_rounded, size: AppIconSize.sm),
                          color: mudo,
                          onPressed: () {
                            campo.clear();
                            aoMudar('');
                          },
                        ),
                ),
                border: borda,
                enabledBorder: borda,
                focusedBorder: borda,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (ios)
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Cancelar'),
          )
        else
          IconButton(
            tooltip: 'Fechar a busca',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
      ]),
    );
    if (!ios) return cabeca;
    return Stack(children: [const Positioned.fill(child: FundoBarraVidro()), cabeca]);
  }
}

/// Rótulo de seção (protótipo `.rot`): pequeno e em caixa alta no iOS;
/// frase em 14 no Android.
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final ios = Platform.isIOS;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        ios ? texto.toUpperCase() : texto,
        style: ios
            ? TextStyle(fontSize: 11, letterSpacing: .9, fontWeight: FontWeight.w600, color: cor)
            : TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cor),
      ),
    );
  }
}

class _ChipRecente extends StatelessWidget {
  const _ChipRecente({required this.texto, required this.aoTocar});

  final String texto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Buscar de novo: $texto',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: .12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: AppIconSize.xs, color: theme.colorScheme.onSurface.withValues(alpha: .62)),
                const SizedBox(width: 6),
                Text(texto, style: const TextStyle(fontSize: 13.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uma superfície de vidro para a lista inteira (protótipo `.vidro.grupo`).
class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CartaoVidro(
      raio: 16,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

/// Linha de função (protótipo `linhaFunc`): ícone num quadrado tingido,
/// nome (com o termo marcado), apoio e o selo de estado.
class _LinhaResultado extends StatelessWidget {
  const _LinhaResultado({required this.item, required this.aoTocar, this.termo, this.subtitulo});

  final ItemMenu item;
  final VoidCallback aoTocar;
  final String? termo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    final apagada = item.bloqueado;
    final apoio = subtitulo ?? item.descricao;
    return InkWell(
      onTap: aoTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Opacity(
              opacity: apagada ? .45 : 1,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: pri.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                child: Icon(iconePorChave(item.icone), size: AppIconSize.sm, color: pri),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                  Opacity(
                    opacity: apagada ? .45 : 1,
                    child: Text.rich(
                      _marcado(item.rotulo, termo, pri),
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  if (item.selo != null) SeloEstado(texto: item.selo!),
                ]),
                if (apoio != null && apoio.isNotEmpty)
                  Opacity(
                    opacity: apagada ? .45 : 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(apoio,
                          style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
                    ),
                  ),
              ]),
            ),
            if (Platform.isIOS)
              Icon(Icons.chevron_right_rounded,
                  size: AppIconSize.sm, color: theme.colorScheme.onSurface.withValues(alpha: .38)),
          ]),
        ),
      ),
    );
  }
}

/// Marca a primeira ocorrência do termo no nome (protótipo `mark`): fundo
/// da primária a 26%, sem trocar a cor do texto.
TextSpan _marcado(String texto, String? termo, Color pri) {
  final t = termo == null ? '' : normalizar(termo.trim().split(RegExp(r'\s+')).first);
  final i = t.isEmpty ? -1 : normalizar(texto).indexOf(t);
  if (i < 0) return TextSpan(text: texto);
  return TextSpan(children: [
    TextSpan(text: texto.substring(0, i)),
    TextSpan(text: texto.substring(i, i + t.length), style: TextStyle(backgroundColor: pri.withValues(alpha: .26))),
    TextSpan(text: texto.substring(i + t.length)),
  ]);
}

/// Sem resultado (protótipo `.vazio`): o que buscou, o que fazer e as duas
/// saídas, "Ver todos os serviços" e "Sugerir esta função".
class _Vazio extends StatelessWidget {
  const _Vazio({required this.termo, required this.aoVerTodos, required this.aoSugerir});

  final String termo;
  final VoidCallback aoVerTodos;
  final VoidCallback aoSugerir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 30, 10, 0),
      child: Column(children: [
        Icon(Icons.search_off_rounded, size: AppIconSize.xl, color: mudo),
        const SizedBox(height: 10),
        Text('Não achamos "$termo"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text('Confira a grafia ou veja todos os serviços. Se a função não existe, peça para a equipe.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: mudo)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: aoVerTodos, child: const Text('Ver todos os serviços')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: aoSugerir,
            icon: const Icon(Icons.add_comment_outlined, size: AppIconSize.sm),
            label: const Text('Sugerir esta função'),
          ),
        ),
      ]),
    );
  }
}
