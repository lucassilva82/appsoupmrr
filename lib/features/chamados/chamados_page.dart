import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/erros/estado_erro.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import 'chamados_api.dart';
import '../../core/design/esqueleto.dart';

const _chave = 'atend.chamados';
const _maxAnexos = 5;
const _maxBytes = 25 * 1024 * 1024;

ChamadosApi apiChamados(BuildContext context) {
  final auth = context.read<Auth>();
  return ChamadosApi(api: ApiClient(), matricula: auth.matricula ?? '', senhaApp: auth.password ?? '');
}

String _data(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Erro com o botão certo: senha da intranet recusada pede a senha uma vez.
class _ErroChamados extends StatelessWidget {
  const _ErroChamados({required this.falha, required this.api, required this.aoTentar});
  final FalhaApp falha;
  final ChamadosApi api;
  final VoidCallback aoTentar;

  Future<void> _pedirSenha(BuildContext context) async {
    final ctrl = TextEditingController();
    final senha = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Senha da intranet'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Senha da intranet'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Entrar')),
        ],
      ),
    );
    if (senha == null || senha.isEmpty || !context.mounted) return;
    try {
      await api.entrar(senhaDigitada: senha);
      aoTentar();
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (context.mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    }
  }

  @override
  Widget build(BuildContext context) => falha.codigo == 'CH-SENHA'
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: AppIconSize.xl, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(falha.titulo, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(falha.texto, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _pedirSenha(context), child: const Text('Informar a senha da intranet')),
              const SizedBox(height: 8),
              Text('Código ${falha.codigo}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        )
      : EstadoErro(falha: falha, aoTentar: aoTentar);
}

// ── Meus chamados ────────────────────────────────────────────────────────────

enum _Filtro { abertos, aguardando, encerrados }

class MeusChamadosPage extends StatefulWidget {
  const MeusChamadosPage({super.key, this.api});
  final ChamadosApi? api;

  @override
  State<MeusChamadosPage> createState() => _MeusChamadosPageState();
}

class _MeusChamadosPageState extends State<MeusChamadosPage> {
  late final ChamadosApi _api = widget.api ?? apiChamados(context);
  List<ResumoChamado>? _lista;
  FalhaApp? _falha;
  _Filtro _filtro = _Filtro.abertos;

  @override
  void initState() {
    super.initState();
    registrar('chamado.lista_ver', chave: _chave);
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    try {
      final l = await _api.meus();
      if (mounted) setState(() => _lista = l);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    } catch (e) {
      final f = FalhaApp.inesperada(ChamadosApi.prefixo, e);
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
  }

  Future<void> _novo() async {
    final aberto = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => NovoChamadoPage(api: _api)));
    if (aberto == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lista = _lista;
    final grupos = {
      _Filtro.abertos: lista?.where((c) => !c.encerrado).toList() ?? const <ResumoChamado>[],
      _Filtro.aguardando: lista?.where((c) => c.aguardandoVoce).toList() ?? const <ResumoChamado>[],
      _Filtro.encerrados: lista?.where((c) => c.encerrado).toList() ?? const <ResumoChamado>[],
    };
    final visiveis = grupos[_filtro]!;
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Meus chamados'),
        floatingActionButton: Platform.isAndroid && _falha == null
            ? FloatingActionButton.extended(onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Novo chamado'))
            : null,
        body: _falha != null && lista == null
            ? _ErroChamados(falha: _falha!, api: _api, aoTentar: _carregar)
            : lista == null
                ? const EsqueletoLista()
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      children: [
                        // Topo com a arte cheia da área (padrão 2.2).
                        TopoArte(
                          arte: Arte.de('atendimento'),
                          icone: Icons.confirmation_number_outlined,
                          titulo: 'Meus chamados',
                          subtitulo: RepositorioConfig.atual.textoChamados('topo') ??
                              'Suporte técnico do DTI pelo SISCHAMADOS. O atendimento continua na intranet.',
                          margem: const EdgeInsets.only(bottom: 14),
                        ),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          for (final (f, rotulo) in [
                            (_Filtro.abertos, 'Em aberto'),
                            (_Filtro.aguardando, 'Aguardando você'),
                            (_Filtro.encerrados, 'Encerrados'),
                          ])
                            ChoiceChip(
                              label: Text('$rotulo (${grupos[f]!.length})'),
                              selected: _filtro == f,
                              onSelected: (_) => setState(() => _filtro = f),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        if (!Platform.isAndroid)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ElevatedButton.icon(
                                onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Novo chamado')),
                          ),
                        if (visiveis.isEmpty)
                          CartaoVidro(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            arte: Arte.de('atendimento'),
                            child: Column(children: [
                              Icon(Icons.support_agent_outlined, size: AppIconSize.xl, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text(
                                  lista.isEmpty
                                      ? RepositorioConfig.atual.textoChamados('lista_vazia') ??
                                          'Você ainda não abriu nenhum chamado.'
                                      : 'Nada neste filtro.',
                                  textAlign: TextAlign.center),
                            ]),
                          ),
                        if (visiveis.isNotEmpty)
                          CartaoVidro(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(children: [
                              for (final (i, c) in visiveis.indexed) ...[
                                if (i > 0) const Divider(height: 1, indent: 16),
                                ListTile(
                                  minVerticalPadding: 10,
                                  title: Text(c.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${c.protocolo} · ${c.assunto}\n${c.situacao} · ${_data(c.atualizadoEm ?? c.abertoEm)}'),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    registrar('chamado.ver', chave: _chave, dados: {'id': c.id});
                                    Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => ChamadoPage(api: _api, resumo: c)));
                                  },
                                ),
                              ],
                            ]),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ── Detalhe ──────────────────────────────────────────────────────────────────

class ChamadoPage extends StatefulWidget {
  const ChamadoPage({super.key, required this.api, required this.resumo});
  final ChamadosApi api;
  final ResumoChamado resumo;

  @override
  State<ChamadoPage> createState() => _ChamadoPageState();
}

class _ChamadoPageState extends State<ChamadoPage> {
  DetalheChamado? _d;
  FalhaApp? _falha;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    try {
      final d = await widget.api.ver(widget.resumo.id);
      if (mounted) setState(() => _d = d);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _d;
    final r = d?.resumo ?? widget.resumo;
    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: r.protocolo),
        body: _falha != null && d == null
            ? _ErroChamados(falha: _falha!, api: widget.api, aoTentar: _carregar)
            : RefreshIndicator(
                onRefresh: _carregar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(r.titulo, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${r.assunto} · aberto em ${_data(r.abertoEm)}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, children: [
                      Chip(label: Text(r.situacao), visualDensity: VisualDensity.compact),
                      if (r.prioridade != null) Chip(label: Text('Prioridade ${r.prioridade}'), visualDensity: VisualDensity.compact),
                    ]),
                    if (r.aguardandoVoce) ...[
                      const SizedBox(height: 8),
                      CartaoVidro(
                        tingimento: AppColors.gold,
                        padding: const EdgeInsets.all(12),
                        child: const Text('A equipe do DTI aguarda a sua resposta. Por enquanto, responda pelo '
                            'SISCHAMADOS na intranet; responder pelo app chega na próxima atualização.'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (d == null)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else ...[
                      CartaoVidro(
                          padding: const EdgeInsets.all(14),
                          arte: Arte.de('atendimento'),
                          child: SelectableText(d.descricao)),
                      for (final c in d.dados.entries)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${c.key}: ${c.value}', style: theme.textTheme.bodySmall),
                        ),
                      const SizedBox(height: 16),
                      Text('CONVERSA', style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      if (d.mensagens.isEmpty) const Text('Ainda sem resposta da equipe.'),
                      for (final m in d.mensagens)
                        Align(
                          alignment: m.minha ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: CartaoVidro(
                                raio: 14,
                                tingimento: m.minha ? theme.colorScheme.primary : null,
                                padding: const EdgeInsets.all(12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m.minha ? 'Você' : 'Equipe do DTI',
                                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(m.texto),
                                  if (m.quando != null)
                                    Text(_data(m.quando), style: theme.textTheme.bodySmall),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Novo chamado (3 passos) ──────────────────────────────────────────────────

class NovoChamadoPage extends StatefulWidget {
  const NovoChamadoPage({super.key, required this.api, this.tituloInicial, this.descricaoInicial});
  final ChamadosApi api;

  /// Vindo de uma tela de erro ou do "Preciso de ajuda": já preenchido.
  final String? tituloInicial;
  final String? descricaoInicial;

  @override
  State<NovoChamadoPage> createState() => _NovoChamadoPageState();
}

class _NovoChamadoPageState extends State<NovoChamadoPage> {
  List<GrupoAssuntos>? _catalogo;
  FalhaApp? _falha;
  int _passo = 0;
  GrupoAssuntos? _grupo;
  Assunto? _assunto;
  late final _titulo = TextEditingController(text: widget.tituloInicial ?? '');
  late final _descricao = TextEditingController(text: widget.descricaoInicial ?? '');
  final Map<String, TextEditingController> _campos = {};
  final Map<String, String> _selecoes = {};
  final List<({String caminho, String nome, int bytes})> _anexos = [];
  Map<String, String> _errosCampo = const {};
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    try {
      final c = await widget.api.catalogo();
      if (mounted) setState(() => _catalogo = c);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
  }

  Map<String, String> get _valoresCampos => {
        for (final c in _assunto?.campos ?? const <CampoAssunto>[])
          if ((c.tipo == 'select' ? _selecoes[c.chave] : _campos[c.chave]?.text.trim())?.isNotEmpty ?? false)
            c.chave: (c.tipo == 'select' ? _selecoes[c.chave] : _campos[c.chave]!.text.trim())!,
      };

  String? _validarPasso2() {
    final erros = <String, String>{};
    if (_titulo.text.trim().length < 5) erros['titulo'] = 'Descreva o assunto em pelo menos 5 caracteres.';
    if (_descricao.text.trim().length < 15) erros['descricao'] = 'Detalhe o que está acontecendo em pelo menos 15 caracteres.';
    final valores = _valoresCampos;
    for (final c in _assunto!.campos) {
      if (c.obrigatorio && !valores.containsKey(c.chave)) erros['campos.${c.chave}'] = 'Preencha ${c.rotulo}.';
    }
    if (_assunto!.requerAnexo && _anexos.isEmpty) {
      erros['anexos'] = _assunto!.instrucaoAnexo ?? 'Este assunto pede ao menos um arquivo.';
    }
    setState(() => _errosCampo = erros);
    return erros.isEmpty ? null : erros.values.first;
  }

  Future<void> _anexar() async {
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.media);
      if (r == null) return;
      final total = _anexos.fold<int>(0, (s, a) => s + a.bytes);
      var soma = total;
      for (final f in r.files) {
        if (f.path == null) continue;
        if (_anexos.length >= _maxAnexos) break;
        if (soma + f.size > _maxBytes) {
          if (mounted) avisoAtencao(context, 'Arquivos grandes demais', texto: 'O limite é 25 MB no total. Código CH-ANEXO-GRANDE.');
          break;
        }
        soma += f.size;
        _anexos.add((caminho: f.path!, nome: f.name, bytes: f.size));
      }
      setState(() {});
    } catch (e) {
      registrarErro(FalhaApp.inesperada(ChamadosApi.prefixo, e), tela: _chave);
      if (mounted) avisoErro(context, 'Não foi possível abrir a galeria', texto: 'Tente de novo. Código CH-GALERIA.');
    }
  }

  Future<void> _abrir() async {
    setState(() => _enviando = true);
    try {
      final r = await widget.api.abrir(
        assuntoId: _assunto!.id,
        titulo: _titulo.text.trim(),
        descricao: _descricao.text.trim(),
        campos: _valoresCampos,
        anexos: [for (final a in _anexos) (caminho: a.caminho, nome: a.nome)],
      );
      registrar('chamado.abrir', chave: _chave, dados: {'assunto': _assunto!.id, 'anexos': _anexos.length});
      if (_anexos.isNotEmpty) registrar('chamado.anexo_enviar', chave: _chave, dados: {'quantos': _anexos.length});
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.task_alt),
          title: Text('Chamado ${r.protocolo} aberto'),
          content: Text('Situação: ${r.situacao}. ${RepositorioConfig.atual.textoChamados('confirmacao') ?? 'Você acompanha por Meus chamados e recebe aviso quando a equipe responder.'}'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Acompanhar'))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      registrar('chamado.abrir', chave: _chave, resultado: 'falhou', codigo: f.codigo);
      if (f is FalhaCampos) setState(() => _errosCampo = f.detalhes);
      if (!mounted) return;
      // Falha de rede depois de enviar pode ter aberto o chamado: não repete sozinho.
      final talvez = f.codigo == 'CH-LENTO' || f.codigo == 'CH-FORA';
      avisoErro(context, f.titulo,
          texto: talvez
              ? 'A conexão caiu durante o envio. Confira em Meus chamados se ele foi aberto antes de tentar de novo. Código ${f.codigo}.'
              : '${f.texto} Código ${f.codigo}.');
      if (f is FalhaCampos) setState(() => _passo = 1);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _passo1(ThemeData theme) {
    final cat = _catalogo!;
    if (_grupo == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('Sobre o que é o chamado?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            for (final g in cat)
              CartaoVidro(
                onTap: () => setState(() => _grupo = g),
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.support_agent_outlined, color: theme.colorScheme.primary),
                  const Spacer(),
                  Text(g.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  Text('${g.assuntos.length} assuntos', style: theme.textTheme.bodySmall),
                ]),
              ),
          ],
        ),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextButton.icon(onPressed: () => setState(() => _grupo = null), icon: const Icon(Icons.arrow_back), label: Text(_grupo!.nome)),
      CartaoVidro(
        padding: const EdgeInsets.symmetric(vertical: 4),
        arte: Arte.de('atendimento'),
        child: Column(children: [
          for (final (i, a) in _grupo!.assuntos.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(a.nome),
              subtitle: a.descricao == null ? null : Text(a.descricao!, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() {
                _assunto = a;
                _passo = 1;
              }),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _passo2(ThemeData theme) {
    final a = _assunto!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${_grupo?.nome ?? ''} › ${a.nome}', style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      TextField(
        controller: _titulo,
        maxLength: 80,
        decoration: InputDecoration(labelText: 'Título', errorText: _errosCampo['titulo']),
      ),
      TextField(
        controller: _descricao,
        minLines: 4,
        maxLines: 8,
        decoration: InputDecoration(labelText: 'O que está acontecendo?', errorText: _errosCampo['descricao']),
      ),
      for (final c in a.campos) ...[
        const SizedBox(height: 12),
        if (c.tipo == 'select')
          DropdownButtonFormField<String>(
            initialValue: _selecoes[c.chave],
            decoration: InputDecoration(
                labelText: c.rotulo + (c.obrigatorio ? '' : ' (opcional)'),
                helperText: c.ajuda,
                errorText: _errosCampo['campos.${c.chave}']),
            items: [for (final o in c.opcoes) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => setState(() => _selecoes[c.chave] = v ?? ''),
          )
        else
          TextField(
            controller: _campos.putIfAbsent(c.chave, TextEditingController.new),
            keyboardType: c.tipo == 'number' ? TextInputType.number : c.tipo == 'date' ? TextInputType.datetime : null,
            maxLines: c.tipo == 'textarea' ? 4 : 1,
            decoration: InputDecoration(
                labelText: c.rotulo + (c.obrigatorio ? '' : ' (opcional)'),
                helperText: c.ajuda ?? (c.exemplo == null ? null : 'Exemplo: ${c.exemplo}'),
                errorText: _errosCampo['campos.${c.chave}']),
          ),
      ],
      const SizedBox(height: 16),
      Text('Anexos (${_anexos.length} de $_maxAnexos, até 25 MB no total)', style: theme.textTheme.titleSmall),
      if (a.instrucaoAnexo != null) Text(a.instrucaoAnexo!, style: theme.textTheme.bodySmall),
      if (_errosCampo['anexos'] != null)
        Text(_errosCampo['anexos']!, style: TextStyle(color: theme.colorScheme.error)),
      for (final (i, x) in _anexos.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file),
          title: Text(x.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${(x.bytes / 1024 / 1024).toStringAsFixed(1)} MB'),
          trailing: IconButton(
              tooltip: 'Tirar anexo', icon: const Icon(Icons.close), onPressed: () => setState(() => _anexos.removeAt(i))),
        ),
      if (_anexos.length < _maxAnexos)
        OutlinedButton.icon(onPressed: _anexar, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Anexar foto ou vídeo')),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () {
          if (_validarPasso2() == null) setState(() => _passo = 2);
        },
        child: const Text('Revisar'),
      ),
    ]);
  }

  Widget _passo3(ThemeData theme) {
    final a = _assunto!;
    final valores = _valoresCampos;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Confira antes de abrir', style: theme.textTheme.titleMedium),
      const SizedBox(height: 10),
      CartaoVidro(
        padding: const EdgeInsets.all(14),
        arte: Arte.de('atendimento'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_grupo?.nome ?? ''} › ${a.nome}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(_titulo.text.trim(), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(_descricao.text.trim()),
          for (final v in valores.entries) Text('${a.campos.firstWhere((c) => c.chave == v.key).rotulo}: ${v.value}'),
          if (_anexos.isNotEmpty) Text('${_anexos.length} anexo(s)'),
          if (a.prioridade != null) ...[
            const SizedBox(height: 6),
            Text('Prioridade ${a.prioridade}${a.prazoHoras == null ? '' : ' · primeira resposta em até ${a.prazoHoras} h'}',
                style: theme.textTheme.bodySmall),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _enviando ? null : _abrir,
        child: _enviando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Abrir chamado'),
      ),
      TextButton(onPressed: _enviando ? null : () => setState(() => _passo = 1), child: const Text('Corrigir')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _passo == 0 && _grupo == null,
      onPopInvokedWithResult: (saiu, _) {
        if (saiu) return;
        setState(() {
          if (_passo > 0) {
            _passo--;
          } else {
            _grupo = null;
          }
        });
      },
      child: FundoSuave(
        child: Scaffold(
          appBar: CustomAppBar(title: 'Novo chamado · ${_passo + 1} de 3'),
          body: _falha != null && _catalogo == null
              ? _ErroChamados(falha: _falha!, api: widget.api, aoTentar: _carregar)
              : _catalogo == null
                  ? const EsqueletoLista()
                  : switch (_passo) {
                      0 => _passo1(theme),
                      1 => _passo2(theme),
                      _ => _passo3(theme),
                    },
        ),
      ),
    );
  }
}
