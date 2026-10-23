import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
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
import '../servicos/servicos_page.dart';
import 'feedback_repositorio.dart';

const _maxAnexos = 5;
const _maxBytes = 25 * 1024 * 1024;
const _minTexto = 10;
const _maxTexto = 4000;

/// Repositório com a sessão de agora (matrícula e MD5 da senha, como os
/// outros endpoints até a 2.3).
FeedbackRepositorio repositorioFeedback(BuildContext context) {
  final auth = context.read<Auth>();
  return FeedbackRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}

/// Sugestões e elogios (docs/SOUPM_2_2.md §8.1). Problema técnico não vem
/// para cá: o aviso do topo leva ao chamado.
class SugestoesPage extends StatefulWidget {
  const SugestoesPage({super.key});

  @override
  State<SugestoesPage> createState() => _SugestoesPageState();
}

class _SugestoesPageState extends State<SugestoesPage> {
  final _texto = TextEditingController();
  TipoFeedback? _tipo;
  final _anexos = <PlatformFile>[];
  bool _enviando = false;
  String? _erroCampo;

  @override
  void initState() {
    super.initState();
    registrar('tela.abrir', chave: 'atend.feedback');
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  int get _bytes => _anexos.fold(0, (s, a) => s + a.size);

  Future<void> _escolherAnexos() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.media, allowMultiple: true);
      if (r == null || !mounted) return;
      final novos = [..._anexos, ...r.files.where((f) => f.path != null)];
      if (novos.length > _maxAnexos) {
        avisoAtencao(context, 'No máximo $_maxAnexos anexos', texto: 'Os primeiros $_maxAnexos ficaram.');
      }
      final cortados = novos.take(_maxAnexos).toList();
      if (cortados.fold<int>(0, (s, a) => s + a.size) > _maxBytes) {
        avisoAtencao(context, 'Passou de 25 MB', texto: 'Escolha menos arquivos ou vídeos mais curtos.');
        return;
      }
      setState(() => _anexos
        ..clear()
        ..addAll(cortados));
    } catch (e) {
      debugPrint('[FEEDBACK] FB-ANEXO-ABRIR $e');
      registrarErro(const FalhaApp(
          codigo: 'FB-ANEXO-ABRIR',
          origem: OrigemFalha.aparelho,
          titulo: 'Não foi possível abrir a galeria',
          texto: 'Confira se o app pode acessar as fotos nos ajustes do aparelho.'),
          tela: 'atend.feedback');
      if (mounted) {
        avisoErro(context, 'Não foi possível abrir a galeria',
            texto: 'Confira se o app pode acessar as fotos nos ajustes do aparelho. Código FB-ANEXO-ABRIR.');
      }
    }
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (_tipo == null) {
      setState(() => _erroCampo = null);
      avisoAtencao(context, 'Escolha o tipo da mensagem');
      return;
    }
    if (texto.length < _minTexto) {
      setState(() => _erroCampo = 'Escreva pelo menos $_minTexto caracteres.');
      return;
    }
    setState(() {
      _erroCampo = null;
      _enviando = true;
    });
    try {
      final protocolo = await repositorioFeedback(context).enviar(
        tipo: _tipo!,
        texto: texto,
        anexos: [for (final a in _anexos) (caminho: a.path!, nome: a.name)],
        contexto: {'tela': 'atend.feedback', 'sistema': Platform.operatingSystem},
      );
      registrar('feedback.enviar',
          chave: 'atend.feedback', dados: {'tipo': _tipo!.api, 'anexos': _anexos.length});
      if (!mounted) return;
      avisoSucesso(context, 'Mensagem enviada', texto: 'Protocolo $protocolo. A resposta chega em Minhas mensagens.');
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MinhasMensagensPage()));
    } on FalhaApp catch (f) {
      registrar('feedback.enviar', chave: 'atend.feedback', resultado: 'falhou', codigo: f.codigo);
      registrarErro(f, tela: 'atend.feedback');
      if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = _texto.text.trim().length;
    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: 'Sugestões e elogios', actions: [
          IconButton(
            tooltip: 'Minhas mensagens',
            icon: const Icon(Icons.forum_outlined, color: Colors.white),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MinhasMensagensPage())),
          ),
        ]),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            CartaoVidro(
              raio: 14,
              padding: const EdgeInsets.all(14),
              onTap: () {
                final gestor = context.read<Auth>().isSuperUser;
                final item = itemPorChave('atend.chamados',
                    menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
                if (item != null) abrirFuncao(context, item, origem: 'feedback');
              },
              child: Row(children: [
                Icon(Icons.support_agent_outlined, color: theme.colorScheme.primary, size: AppIconSize.md),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('O app deu erro ou você precisa de suporte? Isso vai por chamado técnico.',
                      style: theme.textTheme.bodyMedium),
                ),
                Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: theme.colorScheme.onSurfaceVariant),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Tipo', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in TipoFeedback.values)
                ChoiceChip(
                  label: Text(t.rotulo),
                  selected: _tipo == t,
                  onSelected: _enviando ? null : (_) => setState(() => _tipo = t),
                ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _texto,
              enabled: !_enviando,
              minLines: 5,
              maxLines: 12,
              maxLength: _maxTexto,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Sua mensagem',
                alignLabelWithHint: true,
                helperText: n < _minTexto ? 'Mínimo de $_minTexto caracteres' : null,
                errorText: _erroCampo,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  _anexos.isEmpty
                      ? 'Anexos (opcional): até $_maxAnexos fotos ou vídeos, 25 MB no total'
                      : '${_anexos.length} de $_maxAnexos anexos · ${(_bytes / 1048576).toStringAsFixed(1)} MB',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton.icon(
                onPressed: _enviando || _anexos.length >= _maxAnexos ? null : _escolherAnexos,
                icon: const Icon(Icons.attach_file_rounded, size: AppIconSize.sm),
                label: const Text('Anexar'),
              ),
            ]),
            for (final a in _anexos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.insert_drive_file_outlined, size: AppIconSize.sm),
                title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Tirar anexo',
                  icon: const Icon(Icons.close_rounded, size: AppIconSize.sm),
                  onPressed: _enviando ? null : () => setState(() => _anexos.remove(a)),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                    : const Text('Enviar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minhas mensagens: o que o militar mandou, a situação e as respostas.
class MinhasMensagensPage extends StatefulWidget {
  const MinhasMensagensPage({super.key});

  @override
  State<MinhasMensagensPage> createState() => _MinhasMensagensPageState();
}

class _MinhasMensagensPageState extends State<MinhasMensagensPage> {
  late Future<List<ResumoFeedback>> _lista;

  @override
  void initState() {
    super.initState();
    _lista = repositorioFeedback(context).listar();
  }

  Future<void> _recarregar() async {
    setState(() => _lista = repositorioFeedback(context).listar());
    await _lista.catchError((_) => <ResumoFeedback>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Minhas mensagens'),
        body: FutureBuilder<List<ResumoFeedback>>(
          future: _lista,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (snap.hasError) {
              final f = snap.error is FalhaApp ? snap.error as FalhaApp : FalhaApp.inesperada('FB', snap.error!);
              registrarErro(f, tela: 'atend.feedback.lista');
              return EstadoErro(falha: f, aoTentar: _recarregar);
            }
            final itens = snap.data!;
            if (itens.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Você ainda não mandou nenhuma sugestão ou elogio.',
                      textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                ),
              );
            }
            return RefreshIndicator.adaptive(
              onRefresh: _recarregar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: itens.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final it = itens[i];
                  return CartaoVidro(
                    raio: 12,
                    padding: const EdgeInsets.all(14),
                    onTap: () async {
                      await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => MensagemDetalhePage(id: it.id)));
                      if (mounted) _recarregar();
                    },
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(it.protocolo,
                            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                        const Spacer(),
                        if (it.respostasNovas > 0)
                          const SeloEstado(texto: 'Novo')
                        else
                          Text(nomeSituacao(it.situacao), style: theme.textTheme.labelMedium),
                      ]),
                      const SizedBox(height: 6),
                      Text(it.tipo?.rotulo ?? 'Mensagem',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(it.trecho, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ]),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A conversa de uma mensagem, com campo para responder enquanto ela não
/// foi encerrada pela equipe.
class MensagemDetalhePage extends StatefulWidget {
  const MensagemDetalhePage({super.key, required this.id});

  final int id;

  @override
  State<MensagemDetalhePage> createState() => _MensagemDetalhePageState();
}

class _MensagemDetalhePageState extends State<MensagemDetalhePage> {
  late Future<DetalheFeedback> _detalhe;
  final _resposta = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _detalhe = repositorioFeedback(context).ver(widget.id);
  }

  @override
  void dispose() {
    _resposta.dispose();
    super.dispose();
  }

  Future<void> _responder() async {
    final t = _resposta.text.trim();
    if (t.isEmpty) return;
    setState(() => _enviando = true);
    try {
      await repositorioFeedback(context).responder(widget.id, t);
      registrar('feedback.responder', chave: 'atend.feedback');
      _resposta.clear();
      if (!mounted) return;
      setState(() => _detalhe = repositorioFeedback(context).ver(widget.id));
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'atend.feedback.detalhe');
      if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Mensagem'),
        body: FutureBuilder<DetalheFeedback>(
          future: _detalhe,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (snap.hasError) {
              final f = snap.error is FalhaApp ? snap.error as FalhaApp : FalhaApp.inesperada('FB', snap.error!);
              registrarErro(f, tela: 'atend.feedback.detalhe');
              return EstadoErro(
                  falha: f,
                  aoTentar: () => setState(() => _detalhe = repositorioFeedback(context).ver(widget.id)));
            }
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(children: [
                  Text(d.resumo.protocolo,
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  const Spacer(),
                  Text(nomeSituacao(d.resumo.situacao), style: theme.textTheme.labelLarge),
                ]),
                const SizedBox(height: 10),
                if (d.aguardaMilitar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CartaoVidro(
                      raio: 12,
                      tingimento: kCorAtencao,
                      padding: const EdgeInsets.all(12),
                      child: const Text('A equipe aguarda a sua resposta.'),
                    ),
                  ),
                _Balao(daEquipe: false, texto: d.texto, anexos: d.anexos),
                for (final m in d.mensagens) _Balao(daEquipe: m.daEquipe, texto: m.texto, anexos: m.anexos),
                const SizedBox(height: 16),
                if (d.encerrado)
                  Text('Esta mensagem foi encerrada. Se tiver outra ideia, mande uma nova sugestão.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                else ...[
                  TextField(
                    controller: _resposta,
                    enabled: !_enviando,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: _maxTexto,
                    decoration: InputDecoration(
                      labelText: 'Responder',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enviando ? null : _responder,
                      child: const Text('Enviar resposta'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Balao extends StatelessWidget {
  const _Balao({required this.daEquipe, required this.texto, required this.anexos});

  final bool daEquipe;
  final String texto;
  final int anexos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: daEquipe ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CartaoVidro(
            raio: 14,
            tingimento: daEquipe ? theme.colorScheme.primary : null,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(daEquipe ? 'Equipe do SouPMRR' : 'Você',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(texto, style: theme.textTheme.bodyMedium),
              if (anexos > 0) ...[
                const SizedBox(height: 4),
                Text('$anexos ${anexos == 1 ? 'anexo' : 'anexos'}',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
