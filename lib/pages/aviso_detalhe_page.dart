import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/design/arte_cartao.dart';
import '../models/auth_model.dart';
import '../models/aviso_model.dart';
import '../models/escala_model.dart';
import '../models/svi_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/aviso_rapido.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/vidro.dart';

/// Tela única de um aviso do SIGE (escala, permuta, SVI), aberta pelo toque no
/// push ou na lista de notificações.
///
/// Ordem do contrato com o SIGE (parte 3.3 do documento da frente SIGE):
///  1. o texto do aviso aparece na hora, com o que o app já tem;
///  2. `GET /dispositivo/notificacoes/{id}` traz o texto inteiro e o destino;
///  3. o assunto (escala, permuta, adesão) carrega num bloco à parte. Se ele
///     falhar, só o bloco mostra o erro: o texto do aviso continua na tela;
///  4. o aviso é marcado como lido (`POST .../lida`).
/// Tipo ou tela desconhecida mostra só o texto, nunca erro.
///
/// Sem sessão da intranet, entra sozinha (senha da intranet guardada, depois a
/// do app); se a intranet recusar as duas, pede a senha aqui mesmo, uma vez, e
/// ela fica guardada no cofre do aparelho.
class AvisoDetalhePage extends StatefulWidget {
  final AvisoAberto aviso;
  final EscalaService? service;

  /// Matrícula para entrar na intranet. Nulo: a do militar logado no app.
  final String? matricula;

  const AvisoDetalhePage(
      {super.key, required this.aviso, this.service, this.matricula});

  @override
  State<AvisoDetalhePage> createState() => _AvisoDetalhePageState();
}

/// Falha explicada: o que aconteceu, de quem é e o código que vai para o log.
class FalhaAviso {
  final String codigo;
  final String titulo;
  final String texto;
  final bool precisaEntrar;

  const FalhaAviso(this.codigo, this.titulo, this.texto,
      {this.precisaEntrar = false});

  static const precisa2fa = FalhaAviso(
    'AV-2FA',
    'A intranet pede o código de verificação',
    'Sua conta da intranet usa verificação em duas etapas. Abra Escalas de '
        'Serviço para digitar o código e volte a este aviso.',
    precisaEntrar: true,
  );

  static FalhaAviso precisaMigrar(String? texto) => FalhaAviso(
        'AV-MIGRAR',
        'Atualize sua senha da intranet',
        texto ??
            'A intranet pede uma senha nova antes de mostrar os detalhes. '
                'Abra Escalas de Serviço para criar a senha e volte a este aviso.',
        precisaEntrar: true,
      );

  static bool ehDeLogin(Object e) =>
      e is EscalaServiceException &&
      (e.code == 'NOT_AUTHENTICATED' || e.code == 'UNAUTHORIZED');

  static FalhaAviso de(Object e) {
    if (e is EscalaServiceException) {
      switch (e.code) {
        case 'NOT_AUTHENTICATED':
        case 'UNAUTHORIZED':
          return const FalhaAviso(
            'AV-LOGIN',
            'Entre nas Escalas de Serviço',
            'Os detalhes vêm do sistema da intranet. Entre uma vez em '
                'Escalas de Serviço e volte a este aviso.',
            precisaEntrar: true,
          );
        case 'NOT_FOUND':
          return const FalhaAviso(
            'AV-NAO-ACHADO',
            'Assunto não encontrado',
            'O servidor não achou este assunto para a sua matrícula. Ele pode '
                'ter mudado depois do aviso. Em caso de dúvida, fale com o '
                'escalante.',
          );
        case 'API_HTML_RESPONSE':
          return FalhaAviso('AV-SEM-API', 'Servidor indisponível', e.message);
        case 'TIMEOUT':
          return const FalhaAviso('AV-LENTO', 'O servidor demorou a responder',
              'A intranet não respondeu a tempo. Tente de novo em instantes.');
      }
      final cod = e.code.startsWith('HTTP_')
          ? 'AV-SRV-${e.code.substring(5)}'
          : 'AV-SRV-${e.code}';
      return FalhaAviso(
          cod,
          'O servidor recusou o pedido',
          'A intranet respondeu com erro. O problema é do servidor, não do '
              'seu aparelho. Tente mais tarde.');
    }
    if (e is TimeoutException) {
      return const FalhaAviso('AV-LENTO', 'O servidor demorou a responder',
          'A intranet não respondeu em 15 segundos. Tente de novo em instantes.');
    }
    if (e is SocketException || e is http.ClientException) {
      return const FalhaAviso('AV-REDE', 'Sem conexão',
          'O aparelho não conseguiu falar com a intranet. Confira a internet '
              'e tente de novo.');
    }
    if (e is HandshakeException) {
      return const FalhaAviso('AV-SSL', 'Conexão segura recusada',
          'Confira a data e a hora do aparelho, ou troque de rede Wi-Fi.');
    }
    return FalhaAviso('AV-X-${e.runtimeType}', 'Não foi possível carregar',
        'Algo inesperado aconteceu ao buscar os detalhes. Tente de novo.');
  }
}

class _AvisoDetalhePageState extends State<AvisoDetalhePage> {
  late final EscalaService _service = widget.service ?? EscalaService();

  late String _titulo = widget.aviso.titulo;
  late String _corpo = widget.aviso.corpo;
  String? _quando;
  AvisoDestino? _destino;

  bool _carregando = false;
  FalhaAviso? _falha;

  // Entrada na intranet
  bool _tentouEntrar = false;
  bool _pedirSenha = false;
  bool _entrando = false;
  String? _erroSenha;
  final _senhaCtrl = TextEditingController();
  String? _matriculaApp;
  String? _senhaApp;

  EscalaModel? _escala;
  PermutaModel? _permuta;
  SviAdesaoModel? _adesao;
  bool _enviandoCiencia = false;

  void _log(String msg) => debugPrint('[AVISO] $msg');

  @override
  void initState() {
    super.initState();
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      _matriculaApp = auth.matricula;
      _senhaApp = auth.password;
    } catch (_) {
      // Sem Auth na árvore (testes): usa só a matrícula do widget.
    }
    _log('aviso.abrir id=${widget.aviso.notificacaoId} '
        'tipo=${widget.aviso.tipoEvento} ref=${widget.aviso.referenciaId}');
    _carregar();
  }

  @override
  void dispose() {
    _senhaCtrl.dispose();
    super.dispose();
  }

  String get _matricula => widget.matricula ?? _matriculaApp ?? '';

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _falha = null;
      _pedirSenha = false;
    });
    try {
      final id = widget.aviso.notificacaoId;
      if (id != null) {
        final det = await _service.getAviso(id);
        if (!mounted) return;
        setState(() {
          if (det.titulo.isNotEmpty) _titulo = det.titulo;
          if (det.corpo.isNotEmpty) _corpo = det.corpo;
          _quando = det.criadoEmBr;
          _destino = det.destino;
        });
        _log('aviso.ver id=$id destino=${det.destino.telaRaw}');
        if (!det.lida) _marcarLido(id);
      } else {
        _destino = AvisoDestino.peloTipo(
            widget.aviso.tipoEvento, widget.aviso.referenciaId);
      }
      await _carregarAssunto();
      if (!mounted) return;
      setState(() => _carregando = false);
    } catch (e) {
      if (FalhaAviso.ehDeLogin(e)) return _semSessao();
      final f = FalhaAviso.de(e);
      _log('aviso.falhou ${f.codigo} id=${widget.aviso.notificacaoId} '
          'tipo=${widget.aviso.tipoEvento} detalhe=$e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _falha = f;
      });
    }
  }

  /// Sem sessão da intranet (ou vencida): entra sozinho uma vez; se não der,
  /// pede a senha.
  Future<void> _semSessao() async {
    if (_tentouEntrar) {
      _log('aviso.login pedir_senha (sessão recusada de novo)');
      if (mounted) {
        setState(() {
          _carregando = false;
          _pedirSenha = true;
        });
      }
      return;
    }
    _tentouEntrar = true;
    final r = await _service.entrarSozinho(
        matricula: _matricula, senhaApp: _senhaApp);
    _log('aviso.login_auto ${r.tipo.name}');
    if (!mounted) return;
    switch (r.tipo) {
      case EntradaIntranet.ok:
        return _carregar();
      case EntradaIntranet.precisaSenha:
        setState(() {
          _carregando = false;
          _pedirSenha = true;
        });
      case EntradaIntranet.precisa2fa:
        setState(() {
          _carregando = false;
          _falha = FalhaAviso.precisa2fa;
        });
      case EntradaIntranet.precisaMigrar:
        setState(() {
          _carregando = false;
          _falha = FalhaAviso.precisaMigrar(r.mensagemMigracao);
        });
      case EntradaIntranet.falhou:
        final f = FalhaAviso.de(r.erro ?? 'sem detalhe');
        _log('aviso.falhou ${f.codigo} (entrada automática) detalhe=${r.erro}');
        setState(() {
          _carregando = false;
          _falha = f;
        });
    }
  }

  Future<void> _entrarComSenha() async {
    final senha = _senhaCtrl.text;
    if (senha.isEmpty) {
      setState(() => _erroSenha = 'Digite a senha da intranet.');
      return;
    }
    setState(() {
      _entrando = true;
      _erroSenha = null;
    });
    try {
      final r = await _service.login(_matricula, senha);
      _log('aviso.login_manual ok migrar=${r.precisaMigrarSenha}');
      if (!mounted) return;
      _senhaCtrl.clear();
      if (r.precisaMigrarSenha) {
        setState(() {
          _entrando = false;
          _pedirSenha = false;
          _falha = FalhaAviso.precisaMigrar(r.mensagemMigracao);
        });
        return;
      }
      setState(() => _entrando = false);
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      if (e is EscalaServiceException && e.code == 'REQUIRES_2FA') {
        setState(() {
          _entrando = false;
          _pedirSenha = false;
          _falha = FalhaAviso.precisa2fa;
        });
        return;
      }
      final servidor = e is! EscalaServiceException ||
          e.code.startsWith('HTTP_') ||
          const {'API_HTML_RESPONSE', 'SERVER_ERROR', 'INTERNAL_ERROR',
                  'PARSE_ERROR', 'API_REDIRECT', 'TIMEOUT'}
              .contains(e.code);
      final f = servidor ? FalhaAviso.de(e) : null;
      _log('aviso.login_manual falhou ${f?.codigo ?? 'AV-SENHA'} detalhe=$e');
      setState(() {
        _entrando = false;
        _erroSenha = f == null
            ? 'A intranet não aceitou esta senha. Confira e tente de novo. '
                '(AV-SENHA)'
            : '${f.texto} (${f.codigo})';
      });
    }
  }

  Future<void> _carregarAssunto() async {
    final d = _destino;
    if (d == null) return;
    switch (d.tela) {
      case TelaDestino.escala:
        final esc = await _service.getEscalaDetalhe(d.id!);
        if (mounted) setState(() => _escala = esc);
        break;
      case TelaDestino.permuta:
        final p = await _service.getPermuta(d.id!);
        if (mounted) setState(() => _permuta = p);
        break;
      case TelaDestino.sviAdesao:
        final a = await _service.getSviAdesao();
        if (mounted) setState(() => _adesao = a);
        break;
      case TelaDestino.sviVagas:
      case TelaDestino.aviso:
        break;
    }
  }

  Future<void> _marcarLido(int id) async {
    try {
      await _service.marcarAvisoLido(id);
      _log('aviso.lido id=$id');
    } catch (e) {
      // Não lido no servidor não impede nada na tela: só registra.
      _log('aviso.lido falhou ${FalhaAviso.de(e).codigo} id=$id detalhe=$e');
    }
  }

  Future<void> _darCiencia() async {
    final esc = _escala;
    if (esc == null) return;
    setState(() => _enviandoCiencia = true);
    try {
      await _service.registrarCiencia(esc.escalaId);
      _log('escala.ciencia ok escala=${esc.escalaId}');
      final atual = await _service.getEscalaDetalhe(esc.escalaId);
      if (!mounted) return;
      setState(() {
        _escala = atual;
        _enviandoCiencia = false;
      });
      avisoSucesso(context, 'Ciência registrada');
    } catch (e) {
      final f = FalhaAviso.de(e);
      _log('escala.ciencia falhou ${f.codigo} escala=${esc.escalaId} detalhe=$e');
      if (!mounted) return;
      setState(() => _enviandoCiencia = false);
      avisoErro(context, 'Ciência não registrada',
          texto: '${f.texto} (${f.codigo})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FundoSuave(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const FundoBarraVidro(),
          title: const Text('Aviso'),
        ),
        body: RefreshIndicator(
          onRefresh: _carregar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _cartaoTexto(context),
              const SizedBox(height: 10),
              _blocoAssunto(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartaoTexto(BuildContext context) {
    final theme = Theme.of(context);
    final quando = _quando ?? _formatar(widget.aviso.recebidoEm);
    return CartaoVidro(
      padding: const EdgeInsets.all(16),
      // Arte discreta (padrão 2.2) só no cartão do aviso.
      arte: Arte.de('institucional'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(_iconeDoTipo(widget.aviso.tipoEvento),
                    size: AppIconSize.md, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 10),
              if (quando != null)
                Text(
                  quando,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            _titulo,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_corpo.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              _corpo,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _blocoAssunto(BuildContext context) {
    final theme = Theme.of(context);
    if (_carregando && _escala == null && _permuta == null && _adesao == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pedirSenha) return _blocoSenha(context);
    final f = _falha;
    if (f != null) return _blocoFalha(context, f);

    switch (_destino?.tela) {
      case TelaDestino.escala:
        return _escala == null ? const SizedBox.shrink() : _blocoEscala(context);
      case TelaDestino.permuta:
        return _permuta == null
            ? const SizedBox.shrink()
            : _blocoPermuta(context);
      case TelaDestino.sviVagas:
        return CartaoVidro(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Vagas do SVI', style: _rotulo(theme)),
              const SizedBox(height: 8),
              Text('Veja as vagas abertas a voluntários e candidate-se.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.SVI_ESCALAS),
                child: const Text('Ver vagas'),
              ),
            ],
          ),
        );
      case TelaDestino.sviAdesao:
        return _adesao == null ? const SizedBox.shrink() : _blocoAdesao(context);
      case TelaDestino.aviso:
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _blocoSenha(BuildContext context) {
    final theme = Theme.of(context);
    return CartaoVidro(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Entre na intranet', style: _rotulo(theme)),
          const SizedBox(height: 8),
          Text(
            'Os detalhes vêm do sistema da intranet, e a sua senha de lá é '
            'diferente da senha do app. Digite-a uma vez: ela fica guardada '
            'com segurança neste aparelho.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_matricula.isNotEmpty)
            Text('Matrícula $_matricula',
                style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          TextField(
            controller: _senhaCtrl,
            obscureText: true,
            enabled: !_entrando,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _entrarComSenha(),
            decoration: InputDecoration(
              labelText: 'Senha da intranet',
              errorText: _erroSenha,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _entrando ? null : _entrarComSenha,
            child: Text(_entrando ? 'Entrando…' : 'Entrar e ver os detalhes'),
          ),
        ],
      ),
    );
  }

  Widget _blocoFalha(BuildContext context, FalhaAviso f) {
    final theme = Theme.of(context);
    return CartaoVidro(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.error_outline_rounded,
                    size: AppIconSize.sm, color: theme.colorScheme.error),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Não foi possível carregar os detalhes',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(f.titulo,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(f.texto, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('Código: ${f.codigo}',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
          const SizedBox(height: 14),
          if (f.precisaEntrar)
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).pushNamed(AppRoutes.ESCALAS);
                if (mounted) _carregar();
              },
              child: const Text('Abrir Escalas de Serviço'),
            )
          else
            OutlinedButton(
              onPressed: _carregar,
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }

  Widget _blocoEscala(BuildContext context) {
    final theme = Theme.of(context);
    final e = _escala!;
    final leitura = e.somenteLeitura || (_destino?.somenteLeitura ?? false);
    final podeCiencia = !leitura &&
        !e.temCiencia &&
        (_destino == null ||
            _destino!.acoes.isEmpty ||
            _destino!.acoes.contains('ciencia'));
    final lembrete = widget.aviso.tipoEvento == 'ciencia_lembrete';

    return CartaoVidro(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(leitura ? 'Escala (somente leitura)' : 'Sua escala',
              style: _rotulo(theme)),
          const SizedBox(height: 10),
          if (podeCiencia && lembrete) ...[
            Text('Você ainda não deu ciência desta escala.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 10),
          ],
          _par(theme, 'Data', e.dataEscala),
          _par(theme, 'Serviço', e.tipoServico),
          _par(theme, 'Guarnição', e.guarnicaoNome),
          _par(theme, 'Função', e.funcaoNome),
          if (e.horarioIni.isNotEmpty)
            _par(theme, 'Horário', '${e.horarioIni} às ${e.horarioFim}'),
          _par(theme, 'Local de assunção', e.localAssuncao),
          _par(theme, 'Uniforme', e.uniforme),
          if (e.temCiencia)
            _par(theme, 'Ciência',
                e.cienciaEmBr != null ? 'Dada em ${e.cienciaEmBr}' : 'Dada'),
          if (e.mensagem != null && e.mensagem!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(e.mensagem!, style: theme.textTheme.bodyMedium),
          ],
          if (podeCiencia) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _enviandoCiencia ? null : _darCiencia,
              child: Text(_enviandoCiencia ? 'Registrando…' : 'Dar ciência'),
            ),
          ],
          if (!leitura) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.ESCALA_DETALHE,
                arguments: {
                  'escalaId': e.escalaId,
                  'escala': e,
                  'service': _service,
                },
              ),
              child: const Text('Ver escala completa'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _blocoPermuta(BuildContext context) {
    final theme = Theme.of(context);
    final p = _permuta!;
    return CartaoVidro(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.ehSubstituicao ? 'Substituição' : 'Permuta',
              style: _rotulo(theme)),
          const SizedBox(height: 10),
          _par(theme, 'Situação', p.situacaoTexto),
          _par(theme, 'Pedida por', p.solicitante),
          _par(theme, 'Titular', p.titular),
          _par(theme, 'Data do serviço', p.dataServico),
          _par(theme, 'Serviço', p.tipoServico),
          _par(theme, 'Guarnição', p.guarnicao),
          if (p.horarioIni != null)
            _par(theme, 'Horário', '${p.horarioIni} às ${p.horarioFim ?? '?'}'),
          const SizedBox(height: 6),
          Text(
            p.mensagem ??
                'A decisão é do escalante. Procure o escalante para confirmar.',
            style: theme.textTheme.bodyMedium,
          ),
          if (p.jaNaEscala && p.escalaId != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.ESCALA_DETALHE,
                arguments: {'escalaId': p.escalaId, 'service': _service},
              ),
              child: const Text('Ver escala'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _blocoAdesao(BuildContext context) {
    final theme = Theme.of(context);
    final a = _adesao!;
    final situacao = switch (a.status) {
      SviAdesaoStatus.ativa => 'Ativa',
      SviAdesaoStatus.pendente => 'Pendente',
      SviAdesaoStatus.suspensa => 'Suspensa',
      SviAdesaoStatus.cancelada => 'Cancelada',
      SviAdesaoStatus.semAdesao => 'Sem adesão',
      SviAdesaoStatus.desconhecido =>
        a.statusRaw.isEmpty ? 'Não informada' : a.statusRaw,
    };
    return CartaoVidro(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sua adesão ao SVI', style: _rotulo(theme)),
          const SizedBox(height: 10),
          _par(theme, 'Situação', situacao),
          if (a.horasMes > 0) _par(theme, 'Horas no mês', '${a.horasMes} h'),
        ],
      ),
    );
  }

  TextStyle? _rotulo(ThemeData theme) => theme.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: theme.colorScheme.primary,
      );

  Widget _par(ThemeData theme, String rotulo, String? valor) {
    if (valor == null || valor.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(rotulo,
                style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          ),
          Expanded(child: Text(valor, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  static String? _formatar(DateTime? d) {
    if (d == null) return null;
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }

  static IconData _iconeDoTipo(String? tipo) {
    switch (tipo) {
      case 'cancelada':
        return Icons.event_busy_rounded;
      case 'removido':
        return Icons.person_remove_rounded;
      case 'permuta_solicitada':
        return Icons.swap_horiz_rounded;
      case 'ciencia_lembrete':
        return Icons.task_alt_rounded;
      case 'publicada':
      case 'escalado':
      case 'aprovada':
        return Icons.event_available_rounded;
      default:
        if (tipo != null && tipo.startsWith('svi_')) {
          return Icons.more_time_rounded;
        }
        return Icons.notifications_rounded;
    }
  }
}
