import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ambiente_app.dart';
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
import '../servicos/servicos_page.dart';
import 'feedback_repositorio.dart';
import '../../core/design/esqueleto.dart';

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
  const SugestoesPage({super.key, this.funcaoSugerida});

  /// Termo que a busca não achou ("Sugerir esta função", §7): a sugestão
  /// já abre como pedido de função nova, com o termo no texto.
  final String? funcaoSugerida;

  @override
  State<SugestoesPage> createState() => _SugestoesPageState();
}

class _SugestoesPageState extends State<SugestoesPage> {
  final _texto = TextEditingController();
  TipoFeedback? _tipo;
  final _anexos = <PlatformFile>[];
  bool _enviando = false;
  String? _erroCampo;

  /// "Enviar dados do aparelho": modelo, sistema e versão do app vão no
  /// contexto da mensagem (sem senha nem CPF). Ligado por padrão.
  bool _dadosAparelho = true;

  /// Para a linha "Minhas mensagens": quantas enviou e quantas têm resposta.
  late final Future<List<ResumoFeedback>> _resumo = repositorioFeedback(context).listar();

  @override
  void initState() {
    super.initState();
    registrar('tela.abrir', chave: 'atend.feedback');
    final termo = widget.funcaoSugerida?.trim();
    if (termo != null && termo.isNotEmpty) {
      _tipo = TipoFeedback.funcaoNova;
      _texto.text = 'Procurei "$termo" no app e não achei. Gostaria que o SouPMRR tivesse ';
    }
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
      registrarErro(
          const FalhaApp(
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
        contexto: {
          'tela': 'atend.feedback',
          'sistema': Platform.operatingSystem,
          if (_dadosAparelho) ...{
            'aparelho': AmbienteApp.aparelho ?? Platform.operatingSystem,
            'app_versao': AmbienteApp.versao,
            'app_build': AmbienteApp.build,
          },
        },
      );
      registrar('feedback.enviar', chave: 'atend.feedback', dados: {'tipo': _tipo!.api, 'anexos': _anexos.length});
      if (!mounted) return;
      avisoSucesso(context, 'Mensagem enviada', texto: 'Protocolo $protocolo. A resposta chega em Minhas mensagens.');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MinhasMensagensPage()));
    } on FalhaApp catch (f) {
      registrar('feedback.enviar', chave: 'atend.feedback', resultado: 'falhou', codigo: f.codigo);
      registrarErro(f, tela: 'atend.feedback');
      if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _abrirChamados() {
    final gestor = context.read<Auth>().isSuperUser;
    final item = itemPorChave('atend.chamados', menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
    if (item != null) abrirFuncao(context, item, origem: 'feedback');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final n = _texto.text.trim().length;
    Widget rotulo(String t, [String? apoio]) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
          child: Text.rich(
              TextSpan(children: [
                TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (apoio != null) TextSpan(text: ' $apoio', style: TextStyle(color: mudo)),
              ]),
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
        );
    Widget contador(String esq, String dir) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
          child: Row(children: [
            Expanded(child: Text(esq, style: TextStyle(fontSize: 12, color: mudo))),
            Text(dir, style: TextStyle(fontSize: 12, color: mudo)),
          ]),
        );

    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Sugestões e elogios'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Topo com a arte cheia da área (padrão 2.2).
            TopoArte(
              arte: Arte.de('atendimento'),
              icone: Icons.lightbulb_outline_rounded,
              titulo: 'Sugestões e elogios',
              subtitulo:
                  'Ideias de melhoria, funções novas e elogios vão para a equipe do SouPMRR, que lê no painel e responde por aqui.',
              margem: const EdgeInsets.only(bottom: 12),
            ),
            // Faixa informativa (protótipo `.aviso-faixa.info`), no vidro do app.
            CartaoVidro(
              raio: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: _abrirChamados,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.confirmation_number_outlined, color: pri, size: AppIconSize.md),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'O app deu erro ou precisa de suporte?\n',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                          text: 'Isso vai por chamado técnico, no Meus chamados.',
                          style: TextStyle(fontSize: 12.5, color: mudo)),
                    ]),
                    style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            // "Minhas mensagens" com as contagens (protótipo `fb.lista`).
            CartaoVidro(
              raio: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              arte: Arte.de('atendimento'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MinhasMensagensPage())),
              child: Row(children: [
                Icon(Icons.forum_outlined, color: pri, size: AppIconSize.md),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Minhas mensagens',
                        style:
                            TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
                    FutureBuilder<List<ResumoFeedback>>(
                      future: _resumo,
                      builder: (_, snap) {
                        final l = snap.data;
                        final texto = l == null
                            ? 'Suas sugestões e as respostas da equipe'
                            : '${l.length} ${l.length == 1 ? 'enviada' : 'enviadas'}'
                                '${l.any((m) => m.respostasNovas > 0) ? ' · ${l.where((m) => m.respostasNovas > 0).length} com resposta nova' : ''}';
                        return Text(texto, style: TextStyle(fontSize: 12.5, color: mudo));
                      },
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: AppIconSize.sm, color: theme.colorScheme.onSurface.withValues(alpha: .38)),
              ]),
            ),
            rotulo('Sobre o que é?'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (t, icone) in [
                (TipoFeedback.melhoria, Icons.auto_awesome_outlined),
                (TipoFeedback.funcaoNova, Icons.add_box_outlined),
                (TipoFeedback.elogio, Icons.favorite_border_rounded),
              ])
                _ChipTipo(
                  rotulo: t.rotulo,
                  icone: icone,
                  ativo: _tipo == t,
                  aoTocar: _enviando ? null : () => setState(() => _tipo = t),
                ),
            ]),
            rotulo('Conte para a gente'),
            TextField(
              controller: _texto,
              enabled: !_enviando,
              minLines: 5,
              maxLines: 12,
              maxLength: _maxTexto,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'O que você gostaria que o app fizesse?',
                errorText: _erroCampo,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            contador(n < _minTexto ? 'Escreva pelo menos $_minTexto caracteres' : 'Pronto para enviar',
                '${_texto.text.length}/$_maxTexto'),
            rotulo('Prints e vídeos', '(até $_maxAnexos, 25 MB no total)'),
            LayoutBuilder(builder: (context, c) {
              final lado = (c.maxWidth - 16) / 3;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _anexos)
                  _Anexo(
                    lado: lado,
                    arquivo: a,
                    aoTirar: _enviando ? null : () => setState(() => _anexos.remove(a)),
                  ),
                if (_anexos.length < _maxAnexos)
                  SizedBox(
                    width: lado,
                    height: lado,
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: pri.withValues(alpha: .5), width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _enviando ? null : _escolherAnexos,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: pri, size: AppIconSize.lg),
                          const SizedBox(height: 4),
                          Text('Adicionar', style: TextStyle(fontSize: 11, color: pri)),
                        ]),
                      ),
                    ),
                  ),
              ]);
            }),
            contador('${_anexos.length} de $_maxAnexos', '${(_bytes / 1048576).toStringAsFixed(1)} de 25 MB'),
            const SizedBox(height: 12),
            CartaoVidro(
              raio: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              arte: Arte.de('atendimento'),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Enviar dados do aparelho',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        '${_aparelhoLegivel()} · SouPMRR ${AmbienteApp.versao} · tela de origem. Sem senha nem CPF.',
                        style: TextStyle(fontSize: 12.5, color: mudo)),
                  ]),
                ),
                const SizedBox(width: 10),
                Switch.adaptive(
                  value: _dadosAparelho,
                  onChanged: _enviando ? null : (v) => setState(() => _dadosAparelho = v),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: AppIconSize.sm),
                label: const Text('Enviar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "iPhone · iOS 27.1" ou "Android 16": o sistema com a versão, sem o
/// número de build que o `Platform` traz junto.
String _aparelhoLegivel() {
  final v = RegExp(r'\d+(\.\d+)*').firstMatch(Platform.operatingSystemVersion)?.group(0) ?? '';
  return Platform.isIOS ? 'iPhone · iOS $v'.trim() : 'Android $v'.trim();
}

/// Tipo da mensagem em chip (protótipo `.chip`, com ícone; o escolhido fica
/// com o fundo da primária).
class _ChipTipo extends StatelessWidget {
  const _ChipTipo({required this.rotulo, required this.icone, required this.ativo, required this.aoTocar});
  final String rotulo;
  final IconData icone;
  final bool ativo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    final cor = ativo ? pri : theme.colorScheme.onSurface;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: ativo,
      child: Material(
        color: ativo ? pri.withValues(alpha: .16) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: ativo ? Colors.transparent : theme.colorScheme.onSurface.withValues(alpha: .12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icone, size: AppIconSize.xs, color: cor),
                const SizedBox(width: 6),
                Text(rotulo,
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: ativo ? FontWeight.w600 : FontWeight.w400, color: cor)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anexo em miniatura (protótipo `.anexo`): a foto, ou o ícone do vídeo com
/// o nome, e o "×" para tirar.
class _Anexo extends StatelessWidget {
  const _Anexo({required this.lado, required this.arquivo, required this.aoTirar});
  final double lado;
  final PlatformFile arquivo;
  final VoidCallback? aoTirar;

  static const _imagens = {'jpg', 'jpeg', 'png', 'heic', 'heif', 'gif', 'webp'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final imagem = _imagens.contains((arquivo.extension ?? '').toLowerCase()) && arquivo.path != null;
    return SizedBox(
      width: lado,
      height: lado,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: .05),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: .10)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: imagem
                ? Image.file(File(arquivo.path!), fit: BoxFit.cover, cacheWidth: 300)
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.movie_outlined, size: AppIconSize.lg, color: mudo),
                      Text(arquivo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: mudo)),
                    ]),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: 'Tirar ${arquivo.name}',
              excludeSemantics: true,
              child: Material(
                color: const Color(0x8C000000),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: aoTirar,
                  child: const SizedBox(
                      width: 28, height: 28, child: Icon(Icons.close_rounded, size: 16, color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
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
              return const EsqueletoLista();
            }
            if (snap.hasError) {
              final f = snap.error is FalhaApp ? snap.error as FalhaApp : FalhaApp.inesperada('FB', snap.error!);
              registrarErro(f, tela: 'atend.feedback.lista');
              return EstadoErro(falha: f, aoTentar: _recarregar);
            }
            final itens = snap.data!;
            // Topo com a arte cheia da área (padrão 2.2).
            final topo = TopoArte(
              arte: Arte.de('atendimento'),
              icone: Icons.forum_outlined,
              titulo: 'Minhas mensagens',
              subtitulo: 'Suas sugestões e elogios, a situação de cada um e as respostas da equipe.',
              margem: const EdgeInsets.only(bottom: 16),
            );
            if (itens.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  topo,
                  CartaoVidro(
                    raio: 16,
                    padding: const EdgeInsets.all(16),
                    arte: Arte.de('atendimento'),
                    child: Text('Você ainda não mandou nenhuma sugestão ou elogio.',
                        textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                  ),
                ],
              );
            }
            return RefreshIndicator.adaptive(
              onRefresh: _recarregar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: itens.length + 1,
                separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 8),
                itemBuilder: (context, i) {
                  if (i == 0) return topo;
                  final it = itens[i - 1];
                  return CartaoVidro(
                    raio: 12,
                    padding: const EdgeInsets.all(14),
                    onTap: () async {
                      await Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => MensagemDetalhePage(id: it.id)));
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
              return const EsqueletoLista();
            }
            if (snap.hasError) {
              final f = snap.error is FalhaApp ? snap.error as FalhaApp : FalhaApp.inesperada('FB', snap.error!);
              registrarErro(f, tela: 'atend.feedback.detalhe');
              return EstadoErro(
                  falha: f, aoTentar: () => setState(() => _detalhe = repositorioFeedback(context).ver(widget.id)));
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
                      tingimento: corAtencao(Theme.of(context)),
                      padding: const EdgeInsets.all(12),
                      child: const Text('A equipe aguarda a sua resposta.'),
                    ),
                  ),
                _Balao(daEquipe: false, texto: d.texto, anexos: d.anexos),
                for (final m in d.mensagens) ...[
                  _Balao(daEquipe: m.daEquipe, texto: m.texto, anexos: m.anexos),
                  if (m.abrirChamado)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.support_agent_outlined, size: AppIconSize.sm),
                        label: const Text('Abrir chamado técnico'),
                        onPressed: () {
                          registrar('funcao.tocar', chave: 'atend.chamados', dados: {'origem': 'feedback'});
                          final gestor = context.read<Auth>().isSuperUser;
                          final item =
                              itemPorChave('atend.chamados', menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
                          if (item != null) abrirFuncao(context, item, origem: 'feedback');
                        },
                      ),
                    ),
                ],
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
                    decoration: const InputDecoration(labelText: 'Responder'),
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
