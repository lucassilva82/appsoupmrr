import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/log/registro_log.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../models/auth_model.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import 'servicos_page.dart';

const _chaveRecentes = 'busca_recentes';

/// Busca global (docs/SOUPM_2_2.md §7), aberta pela lupa no topo das abas.
/// O índice é o menu do `app_config`, já filtrado pelo perfil: o que o
/// militar não pode ver não aparece. Sem rede a cada tecla.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    final menu = menuEmUso(RepositorioConfig.atual, gestor: gestor);
    final resultados = buscarFuncoes(menu, _termo);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Buscar'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: _campo,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _termo = v),
              onSubmitted: (v) {
                _registrar(v, buscarFuncoes(menu, v).length);
                _guardarRecente(v);
              },
              decoration: InputDecoration(
                labelText: 'O que você procura?',
                hintText: 'Ex.: holerite, férias, certidão',
                prefixIcon: const Icon(Icons.search, size: AppIconSize.sm),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            if (_termo.trim().isEmpty && _recentes.isNotEmpty) ...[
              Text('BUSCAS RECENTES', style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final r in _recentes)
                  ActionChip(avatar: const Icon(Icons.history, size: AppIconSize.xs), label: Text(r), onPressed: () => _usar(r)),
              ]),
            ],
            if (_termo.trim().isNotEmpty && resultados.isEmpty) ...[
              const SizedBox(height: 24),
              Icon(Icons.search_off_rounded, size: AppIconSize.xl, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text('Não achamos "${_termo.trim()}".', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.FEEDBACK),
                child: const Text('Sugerir esta função'),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ver todos os serviços')),
            ],
            for (final (i, r) in resultados.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LinhaFuncao(
                  item: r.item,
                  caminho: r.area.rotulo,
                  corIcone: Arte.de(r.area.arte).destaque,
                  aoTocar: () {
                    _registrar(_termo, resultados.length);
                    _guardarRecente(_termo);
                    registrar('busca.abrir_resultado', chave: r.item.chave, dados: {'posicao': i});
                    abrirFuncao(context, r.item, origem: 'busca');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
