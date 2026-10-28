import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/erros/estado_erro.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import '../comunicados/comunicados_page.dart';
import '../servicos/servicos_page.dart';
import 'pendencias_repositorio.dart';
import '../../core/design/esqueleto.dart';

const _chave = 'pend.lista';

PendenciasRepositorio repositorioPendencias(BuildContext context) {
  final auth = context.read<Auth>();
  return PendenciasRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}

String _prazo(DateTime? d) {
  if (d == null) return '';
  final hoje = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  final dias = DateTime(d.year, d.month, d.day).difference(hoje).inDays;
  final data = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  if (dias < 0) return 'Prazo $data · vencido';
  if (dias == 0) return 'Prazo $data · vence hoje';
  if (dias == 1) return 'Prazo $data · falta 1 dia';
  return 'Prazo $data · faltam $dias dias';
}

/// Abre o que resolve a pendência. Sem destino (ou destino que o militar não
/// pode abrir) não abre tela vazia: explica, com o código quando houver.
Future<void> abrirPendencia(BuildContext context, Pendencia p, {required String origem}) async {
  registrar('pendencia.abrir', chave: p.destino, dados: {'tipo': p.tipo, 'de': origem}, codigo: p.erro);
  if (p.erro != null) {
    avisoAtencao(context, 'Não foi possível conferir ${p.sistema}', texto: 'Tente de novo mais tarde. Código ${p.erro}.');
    return;
  }
  final destino = p.destino;
  if (destino == null) {
    avisoInfo(context, p.titulo, texto: p.texto);
    return;
  }
  if (destino == 'com.central') return abrirCentral(context, origem: 'pendencia');
  final gestor = context.read<Auth>().isSuperUser;
  final item = itemPorChave(destino, menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
  if (item == null) {
    avisoAtencao(context, 'Função indisponível',
        texto: 'A função que resolve esta pendência não está disponível para você agora. Código MD-${destino.toUpperCase()}-RESTRITO.');
    return;
  }
  await abrirFuncao(context, item, origem: 'pendencia');
}

// ── Bloco da Início ──────────────────────────────────────────────────────────

/// "Suas pendências" (§4.3): até 3 itens, obrigatórias primeiro. Com nenhum
/// tipo ligado no painel o bloco não aparece; com tipos ligados e nada
/// pendente, mostra "Sem pendências".
class BlocoPendencias extends StatefulWidget {
  const BlocoPendencias({super.key, this.repositorio});
  final PendenciasRepositorio? repositorio;

  @override
  State<BlocoPendencias> createState() => _BlocoPendenciasState();
}

class _BlocoPendenciasState extends State<BlocoPendencias> {
  late final PendenciasRepositorio _repo = widget.repositorio ?? repositorioPendencias(context);

  @override
  void initState() {
    super.initState();
    _carregar();
    PendenciasRepositorio.revisao.addListener(_carregar);
  }

  @override
  void dispose() {
    PendenciasRepositorio.revisao.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      await _repo.listar();
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'inicio', mostrado: false);
    } catch (e) {
      registrarErro(FalhaApp.inesperada(PendenciasRepositorio.prefixo, e), tela: 'inicio', mostrado: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<SituacaoPendencias?>(
      valueListenable: PendenciasRepositorio.emUso,
      builder: (context, s, _) {
        // O bloco fica sempre (pedido do usuário, 28/10/2026): o militar vê
        // que foi conferido, em vez de um bloco que some. Só não aparece
        // antes da primeira resposta — aí ainda não há o que afirmar, e
        // desenhar "Sem pendências" para depois trocar seria pior.
        if (s == null) return const SizedBox.shrink();
        final obrigatorias = s.itens.where((p) => p.obrigatoria).length;
        final corPilula = obrigatorias > 0
            ? (theme.brightness == Brightness.dark ? const Color(0xFFFF9E9E) : const Color(0xFFB3261E))
            : theme.colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CabecalhoSecao(
              titulo: 'Suas pendências',
              pilula: s.itens.isEmpty ? null : '${s.itens.length}',
              corPilula: corPilula,
              textoVer: 'Ver todas',
              verTodos: s.itens.isEmpty
                  ? null
                  : () {
                      registrar('tela.abrir', chave: _chave, dados: {'de': 'inicio'});
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PendenciasPage()));
                    },
            ),
            CartaoVidro(
              padding: EdgeInsets.zero,
              child: Stack(children: [
                ArteDiscreta(arte: Arte.de('pe')),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: s.itens.isEmpty
                      ? const _SemPendencias()
                      : Column(children: [
                          for (final (i, p) in s.itens.take(3).indexed) ...[
                            if (i > 0)
                              Divider(height: 1, thickness: 1, color: theme.colorScheme.onSurface.withValues(alpha: .10)),
                            LinhaPendencia(pendencia: p, aoTocar: () => abrirPendencia(context, p, origem: 'inicio')),
                          ],
                        ]),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _SemPendencias extends StatelessWidget {
  const _SemPendencias();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(Icons.task_alt, size: AppIconSize.sm, color: Arte.de('fe').destaque),
        const SizedBox(width: 12),
        Text('Sem pendências', style: theme.textTheme.bodyMedium),
      ]),
    );
  }
}

/// Linha da pendência (protótipo `.pend .linha`): ícone num quadrado de 36
/// tingido, o quê, o prazo (ou o texto) e, embaixo, o selo Obrigatória ou
/// Lembrete com o sistema de origem. Cor nunca sozinha: o selo diz em texto.
class LinhaPendencia extends StatelessWidget {
  const LinhaPendencia({super.key, required this.pendencia, required this.aoTocar, this.fim});
  final Pendencia pendencia;
  final VoidCallback aoTocar;

  /// O que vai no fim da linha; nulo = a seta. Na lista completa: o cadeado
  /// da obrigatória ou o "Dispensar" do lembrete (protótipo `linhaPend`).
  final Widget? fim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = pendencia;
    final escuro = theme.brightness == Brightness.dark;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final vermelho = escuro ? const Color(0xFFFF9E9E) : const Color(0xFFB3261E);
    final corIcone = p.erro != null
        ? mudo
        : p.obrigatoria
            ? vermelho
            : theme.colorScheme.primary;
    final linha2 = p.erro != null
        ? 'Não foi possível conferir · ${p.erro}'
        : (p.prazo != null ? _prazo(p.prazo) : (p.texto ?? ''));
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: corIcone.withValues(alpha: p.obrigatoria ? .14 : .20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                p.erro != null ? Icons.sync_problem_outlined : iconePorNome(p.icone) ?? Icons.pending_actions_outlined,
                size: AppIconSize.sm,
                color: corIcone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, height: 1.35, color: theme.colorScheme.onSurface)),
              if (linha2.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(linha2, style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo)),
                ),
              if (p.erro == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.obrigatoria
                            ? vermelho.withValues(alpha: .14)
                            : theme.colorScheme.onSurface.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(p.obrigatoria ? 'Obrigatória' : 'Lembrete',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: p.obrigatoria ? vermelho : mudo)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(p.sistema,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: mudo)),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          fim ?? Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: .45)),
        ]),
      ),
    );
  }
}

// ── Lista completa (pend.lista) ──────────────────────────────────────────────

class PendenciasPage extends StatefulWidget {
  const PendenciasPage({super.key, this.repositorio});
  final PendenciasRepositorio? repositorio;

  @override
  State<PendenciasPage> createState() => _PendenciasPageState();
}

class _PendenciasPageState extends State<PendenciasPage> {
  late final PendenciasRepositorio _repo = widget.repositorio ?? repositorioPendencias(context);
  FalhaApp? _falha;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    try {
      await _repo.listar();
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    } catch (e) {
      final f = FalhaApp.inesperada(PendenciasRepositorio.prefixo, e);
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
  }

  Future<void> _dispensar(Pendencia p) async {
    try {
      await _repo.dispensar(p);
      registrar('pendencia.dispensar', chave: p.destino, dados: {'tipo': p.tipo});
      if (mounted) avisoSucesso(context, 'Lembrete dispensado', texto: 'Ele volta se o prazo ficar perto.');
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      registrar('pendencia.dispensar', resultado: 'falhou', codigo: f.codigo, dados: {'tipo': p.tipo});
      if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Suas pendências'),
        body: ValueListenableBuilder<SituacaoPendencias?>(
          valueListenable: PendenciasRepositorio.emUso,
          builder: (context, s, _) {
            if (_falha != null && s == null) return EstadoErro(falha: _falha!, aoTentar: _carregar);
            if (s == null) return const EsqueletoLista();
            final obrig = s.itens.where((p) => p.obrigatoria).toList();
            final lembretes = s.itens.where((p) => !p.obrigatoria).toList();
            return RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Topo com a arte cheia da área (padrão 2.2).
                  TopoArte(
                    arte: Arte.de('pe'),
                    icone: Icons.pending_actions_outlined,
                    titulo: 'Suas pendências',
                    subtitulo:
                        'Cada sistema da PMRR informa o que falta você fazer. As obrigatórias só saem daqui quando forem resolvidas.',
                    margem: const EdgeInsets.only(bottom: 6),
                  ),
                  if (s.itens.isEmpty) ...[
                    const SizedBox(height: 10),
                    CartaoVidro(arte: Arte.de('pe'), child: const _SemPendencias()),
                  ],
                  for (final (titulo, lista) in [('Obrigatórias', obrig), ('Lembretes', lembretes)])
                    if (lista.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                        child: Text(titulo.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: .9,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary)),
                      ),
                      CartaoVidro(
                        raio: 16,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        arte: Arte.de('pe'),
                        child: Column(children: [
                          for (final p in lista)
                            LinhaPendencia(
                              pendencia: p,
                              aoTocar: () => abrirPendencia(context, p, origem: 'lista'),
                              fim: p.obrigatoria
                                  ? Tooltip(
                                      message: 'Obrigatória: só some quando for resolvida',
                                      child: Icon(Icons.lock_outline_rounded,
                                          size: AppIconSize.xs,
                                          color: theme.colorScheme.onSurface.withValues(alpha: .45)),
                                    )
                                  : p.dispensavel
                                      ? TextButton(
                                          onPressed: () => _dispensar(p),
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(44, 44),
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          child: const Text('Dispensar'),
                                        )
                                      : const SizedBox.shrink(),
                            ),
                        ]),
                      ),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
