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
  final dias = DateTime(d.year, d.month, d.day).difference(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0)).inDays;
  if (dias < 0) return 'Prazo vencido';
  if (dias == 0) return 'Vence hoje';
  if (dias == 1) return 'Vence amanhã';
  return 'Vence em $dias dias';
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
        if (s == null || s.ligados == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Text('Suas pendências', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (s.itens.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _Contador(s.itens.length),
                  ],
                  const Spacer(),
                  if (s.itens.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        registrar('tela.abrir', chave: _chave, dados: {'de': 'inicio'});
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PendenciasPage()));
                      },
                      child: const Text('Ver todas ›'),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CartaoVidro(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: s.itens.isEmpty
                    ? const _SemPendencias()
                    : Column(children: [
                        for (final (i, p) in s.itens.take(3).indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 52),
                          LinhaPendencia(pendencia: p, aoTocar: () => abrirPendencia(context, p, origem: 'inicio')),
                        ],
                      ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
      child: Text('$n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
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

/// Linha de 48 pt: ícone, o quê, sistema e prazo, e o selo Obrigatória
/// (vermelho) ou Lembrete (azul). Cor nunca sozinha: o selo diz em texto.
class LinhaPendencia extends StatelessWidget {
  const LinhaPendencia({super.key, required this.pendencia, required this.aoTocar});
  final Pendencia pendencia;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = pendencia;
    final escuro = theme.brightness == Brightness.dark;
    final corSelo = p.erro != null
        ? theme.colorScheme.onSurfaceVariant
        : p.obrigatoria
            ? (escuro ? const Color(0xFFFF9E9E) : const Color(0xFFB3261E))
            : theme.colorScheme.primary;
    final apoio = [p.sistema, _prazo(p.prazo), if (p.erro != null) p.erro!].where((e) => e.isNotEmpty).join(' · ');
    return InkWell(
      onTap: aoTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(p.erro != null ? Icons.sync_problem_outlined : iconePorNome(p.icone) ?? Icons.pending_actions_outlined,
                size: AppIconSize.sm, color: corSelo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(p.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                if (apoio.isNotEmpty) Text(apoio, style: theme.textTheme.bodySmall),
              ]),
            ),
            if (p.erro == null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    border: Border.all(color: corSelo.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(8)),
                child: Text(p.obrigatoria ? 'Obrigatória' : 'Lembrete',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: corSelo)),
              ),
            ],
          ]),
        ),
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
                  Text('O que falta você fazer em algum sistema da PMRR.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  if (s.itens.isEmpty) const CartaoVidro(child: _SemPendencias()),
                  for (final (titulo, lista) in [('Obrigatórias', obrig), ('Lembretes', lembretes)])
                    if (lista.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(titulo.toUpperCase(),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                      CartaoVidro(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          for (final (i, p) in lista.indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: 52),
                            p.dispensavel
                                ? Dismissible(
                                    key: ValueKey('${p.tipo}|${p.referencia}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Text('Dispensar', style: TextStyle(color: theme.colorScheme.primary)),
                                    ),
                                    onDismissed: (_) => _dispensar(p),
                                    child: LinhaPendencia(pendencia: p, aoTocar: () => abrirPendencia(context, p, origem: 'lista')),
                                  )
                                : LinhaPendencia(pendencia: p, aoTocar: () => abrirPendencia(context, p, origem: 'lista')),
                          ],
                        ]),
                      ),
                    ],
                  if (lembretes.any((p) => p.dispensavel))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('Deslize um lembrete para a esquerda para dispensar.', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
