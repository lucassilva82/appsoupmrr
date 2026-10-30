import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import 'guarda_dono.dart';
import 'operar_api.dart';

/// O módulo Operações: o app de campo do Operar dentro do Sou PM.
///
/// O conteúdo é a tela do Operar, com o desenho dele — isto aqui é a moldura.
/// O que esta tela faz de próprio: pega o token de aparelho, **planta-o no
/// `localStorage` do Operar antes de a página rodar** (daí o
/// `AT_DOCUMENT_START`) e concede câmera e GPS só para a origem dele.
///
/// Se o token não vier, a tela abre do mesmo jeito: o Operar mostra o próprio
/// login, que funciona com matrícula, CPF e senha da operação. Decisão do
/// Lucas em 29/10/2026 — falha de login automático não pode deixar o militar
/// de fora no dia da operação.
class OperacoesPage extends StatefulWidget {
  const OperacoesPage({super.key, this.sessao, this.caminho = '/app/'});

  /// Nulo quando a tela é aberta por rota (menu, atalho): ela mesma resolve a
  /// sessão do login atual. O card da Início já tem a dele e a passa pronta.
  final SessaoOperar? sessao;

  /// Caminho dentro do Operar. O padrão é o app de campo; o card da Início
  /// pode abrir direto numa tela (`/app/?abrir=...`).
  final String caminho;

  @override
  State<OperacoesPage> createState() => _OperacoesPageState();
}

class _OperacoesPageState extends State<OperacoesPage> {
  static const _chaveLog = OperarApi.chaveLog;

  /// A origem do Operar. Tudo fora dela abre no navegador do sistema.
  static final Uri _origem = Uri.parse(urlOperar);

  bool _preparando = true;
  SessaoOperar? _sessao;
  String? _token;

  /// O logout do Sou PM deixou marca: esvaziar o armazém do Operar antes de a
  /// página dele rodar, mesmo que o militar que volta seja o mesmo.
  bool _limparArmazem = false;
  FalhaApp? _falhaToken;
  InAppWebViewController? _web;
  bool _carregandoPagina = true;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    // Antes de qualquer coisa: a marca do logout. Ela vale mesmo quando o
    // token falha depois — a guarda roda sozinha.
    _limparArmazem = await SessaoOperar.consumirMarcaDeLimpeza();
    try {
      _sessao = widget.sessao ?? await SessaoOperar.doLoginAtual();
      final t = await _sessao?.token();
      if (!mounted) return;
      setState(() {
        _token = t;
        _preparando = false;
      });
    } on FalhaApp catch (f) {
      // Sem token o módulo não fecha: o Operar pede o login dele.
      registrar('operacoes.abrir', chave: _chaveLog, resultado: 'falhou', codigo: f.codigo);
      if (!mounted) return;
      setState(() {
        _falhaToken = f;
        _preparando = false;
      });
    }
  }

  /// A guarda de dono e, quando há token, o plantio dele onde o app do Operar
  /// o procura.
  ///
  /// O Operar guarda tudo com `JSON.stringify` sob o prefixo `e26.`, então o
  /// valor vai codificado — gravar a string crua faria o `JSON.parse` dele
  /// falhar e o militar cairia no primeiro acesso. O sinal `e26.soupm` não vem
  /// daqui: o `?soupm=1` da URL é o próprio app dele que o grava.
  UnmodifiableListView<UserScript> _scriptsIniciais(String? token, String? matricula) {
    return UnmodifiableListView([
      // A guarda vem primeiro e vai SEMPRE, com token ou sem: é ela que
      // garante que a página não abre com dado de outro militar.
      UserScript(
        source: guardaDeDonoJs(
          matricula: matricula,
          token: token,
          forcar: _limparArmazem,
        ),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      if (token != null && matricula != null)
        UserScript(
          source: 'try{'
              'window.localStorage.setItem("e26.token", ${jsonEncode(jsonEncode(token))});'
              'window.localStorage.setItem("e26.matricula", ${jsonEncode(jsonEncode(matricula))});'
              '}catch(e){}',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      UserScript(
        source: _pontePonte,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      ),
    ]);
  }

  /// A ponte de download.
  ///
  /// Por que não dá para deixar o WebView baixar: o Operar entrega PDF e
  /// planilha de dois jeitos que o download nativo não alcança — por `blob:`,
  /// que ele não sabe buscar, e por rota que exige o token no `Authorization`,
  /// que ele não manda. Então o arquivo é buscado AQUI DENTRO, com o token do
  /// aparelho, e entregue ao Flutter em base64.
  ///
  /// ES5 de propósito: roda no mesmo motor do app do Operar.
  static const _pontePonte = r'''
(function(){
  if (window.__soupmPonte) { return; }
  window.__soupmPonte = 1;
  function token() {
    try { return JSON.parse(window.localStorage.getItem('e26.token') || 'null'); }
    catch (e) { return null; }
  }
  function entregar(nome, tipo, b64) {
    try { window.flutter_inappwebview.callHandler('baixarOperar', nome, tipo, b64); }
    catch (e) { /* sem ponte: nada a fazer */ }
  }
  /* filename*=UTF-8''nome%20com%20acento  ou  filename="nome.pdf" */
  function doCabecalho(cd) {
    if (!cd) { return ''; }
    var m = /filename\*\s*=\s*UTF-8''([^;]+)/i.exec(cd);
    if (m) { try { return decodeURIComponent(m[1]); } catch (e) { return m[1]; } }
    m = /filename\s*=\s*"([^"]+)"/i.exec(cd) || /filename\s*=\s*([^;]+)/i.exec(cd);
    return m ? m[1].replace(/^\s+|\s+$/g, '') : '';
  }
  /* `doLink`: o nome veio do atributo download, escolhido pelo app do Operar.
     Sem isso veio do palpite do WebView, que no Android é o último pedaço da
     URL — e aí o bilhete vira nome de arquivo. */
  window.__soupmBaixar = function (url, nome, doLink) {
    var op = {}, t = token();
    if (t && url.indexOf('blob:') !== 0) { op.headers = { 'Authorization': 'Bearer ' + t }; }
    fetch(url, op).then(function (r) {
      if (!r.ok) { throw 0; }
      // O servidor do Operar manda o nome de verdade no Content-Disposition,
      // em todas as rotas de arquivo. Ele ganha do palpite do WebView, que no
      // Android salvava o PDF como "A4-gnnuF1RM0z_4O_glQov-l.pdf" — o
      // bilhete da URL, que não diz nada a ninguém. Só o `download=` do link
      // ganha do cabeçalho: ali o nome foi escolhido pelo app do Operar.
      if (!nome || !doLink) {
        var h = doCabecalho(r.headers.get('content-disposition'));
        if (h) { nome = h; }
      }
      return r.blob();
    }).then(function (b) {
      var fr = new FileReader();
      fr.onloadend = function () {
        var s = String(fr.result || ''), i = s.indexOf(',');
        entregar(nome || '', b.type || '', i < 0 ? '' : s.slice(i + 1));
      };
      fr.onerror = function () { entregar(nome || '', '', ''); };
      fr.readAsDataURL(b);
    })['catch'](function () { entregar(nome || '', '', ''); });
  };
  document.addEventListener('click', function (e) {
    var n = e.target;
    while (n && n.tagName !== 'A') { n = n.parentNode; }
    if (!n || !n.getAttribute) { return; }
    if (!n.hasAttribute('download')) { return; }
    var h = n.getAttribute('href') || '';
    if (!h) { return; }
    e.preventDefault();
    window.__soupmBaixar(h, n.getAttribute('download'), true);
  }, true);
}());
''';

  /// Recebe o arquivo da ponte, grava e abre a folha de compartilhar — de lá o
  /// militar salva, abre no leitor de PDF ou manda adiante.
  ///
  /// Ao depurar isto, NÃO imprima o base64 com `debugPrint`: ele corta a linha
  /// perto de 1024 caracteres, e o arquivo vai parecer truncado ou corrompido
  /// quando o problema é só o log. Use o tamanho (`b64.length`) ou grave em
  /// arquivo. Por isso aqui só o número de bytes vai para o registro.
  Future<void> _receberArquivo(List<dynamic> args) async {
    final nome = args.isNotEmpty ? '${args[0]}' : '';
    final tipo = args.length > 1 ? '${args[1]}' : '';
    final b64 = args.length > 2 ? '${args[2]}' : '';
    if (b64.isEmpty) {
      registrar('operacoes.baixar', chave: _chaveLog, resultado: 'falhou', codigo: 'OP-BAIXAR');
      if (mounted) {
        avisoErro(context, 'Não foi possível baixar',
            texto: 'O arquivo não veio completo. Tente de novo com sinal melhor.');
      }
      return;
    }
    // Gravar e compartilhar são passos diferentes e falham por motivos
    // diferentes. Juntos num `catch` só, uma folha de compartilhar que não
    // abre virava "libere espaço" — manda o militar mexer no armazenamento
    // por um problema que não é dele.
    final File arquivo;
    try {
      final bytes = base64Decode(b64);
      final pasta = await getTemporaryDirectory();
      arquivo = File('${pasta.path}/${_nomeLimpo(nome, tipo)}');
      await arquivo.writeAsBytes(bytes, flush: true);
      registrar('operacoes.baixar', chave: _chaveLog, dados: {'bytes': bytes.length});
    } catch (e) {
      registrar('operacoes.baixar', chave: _chaveLog, resultado: 'falhou',
          codigo: 'OP-GRAVAR', dados: {'erro': '$e'});
      if (mounted) {
        avisoErro(context, 'Não foi possível guardar o arquivo',
            texto: 'O aparelho não deixou gravar. Libere espaço e tente de novo.');
      }
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(arquivo.path, mimeType: tipo.isEmpty ? null : tipo)],
        sharePositionOrigin: _origemDaFolha(),
      );
    } catch (e) {
      registrar('operacoes.baixar', chave: _chaveLog, resultado: 'falhou',
          codigo: 'OP-ABRIR', dados: {'erro': '$e'});
      if (mounted) {
        avisoErro(context, 'O arquivo baixou, mas não deu para abrir',
            texto: 'Tente de novo; se insistir, abra pelo navegador.');
      }
    }
  }

  /// Pede ao SISTEMA a permissão que a WebView está pedindo à página.
  ///
  /// São duas permissões em camadas, e é fácil ver só uma. Dizer GRANT ao
  /// pedido da página não dá câmera nem GPS nenhum se o app em si não tiver a
  /// permissão do Android — o WebView não pode mais do que o app que o
  /// hospeda, e o plugin não pede por conta própria. No Android isso aparecia
  /// como "Câmera indisponível" dentro do Operar, sem nenhum diálogo do
  /// sistema, porque não havia o que negar: ninguém tinha perguntado.
  ///
  /// No iPhone o sistema pergunta sozinho na primeira vez, então lá o
  /// `request()` volta concedido sem diálogo nosso e nada muda.
  ///
  /// Negada de vez (`permanentlyDenied`), não insiste: quem decide é o
  /// militar, nas Configurações do aparelho.
  Future<bool> _permissaoDoSistema(Permission permissao) async {
    try {
      if (await permissao.isGranted) return true;
      final r = await permissao.request();
      if (!r.isGranted) {
        registrar('operacoes.permissao', chave: _chaveLog, resultado: 'falhou',
            codigo: 'OP-PERMISSAO', dados: {'qual': '$permissao', 'estado': '$r'});
      }
      return r.isGranted;
    } catch (e) {
      registrar('operacoes.permissao', chave: _chaveLog, resultado: 'falhou',
          codigo: 'OP-PERMISSAO', dados: {'erro': '$e'});
      return false;
    }
  }

  /// Origem do popover que o iOS exige no `UIActivityViewController`. Sem
  /// ela, a folha de compartilhar não abre: `sharePositionOrigin: argument
  /// must be set`. No Android o parâmetro é ignorado, então vai sempre.
  ///
  /// Quando o `RenderBox` não serve, o retângulo é o pé da tela — nunca nulo,
  /// porque nulo é justamente o que o iOS recusa.
  Rect _origemDaFolha() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
    final t = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(t.width / 2 - 1, t.height - 1, 2, 2);
  }

  /// Nome seguro para o sistema de arquivos, com extensão quando o Operar não
  /// manda uma (acontece nos `blob:`).
  static String _nomeLimpo(String nome, String tipo) {
    var n = nome.replaceAll(RegExp(r'[^\w .\-]'), '_').trim();
    if (n.isEmpty) n = 'arquivo';
    if (!n.contains('.')) {
      n += switch (tipo) {
        'application/pdf' => '.pdf',
        'image/jpeg' => '.jpg',
        'image/png' => '.png',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => '.xlsx',
        _ => '',
      };
    }
    return n;
  }

  bool _daCasa(WebUri? u) => u != null && u.host == _origem.host;

  @override
  Widget build(BuildContext context) {
    // O "voltar" do Android tem de andar para trás DENTRO do Operar antes de
    // fechar o módulo: as telas dele são pilha própria, e sair no primeiro
    // toque faria o militar perder o lugar onde estava.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) async {
        if (saiu) return;
        final nav = Navigator.of(context);
        if (await _web?.canGoBack() ?? false) {
          await _web?.goBack();
          return;
        }
        if (mounted) nav.pop();
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Operações'),
        body: _preparando ? const _Preparando() : _corpo(context),
      ),
    );
  }

  Widget _corpo(BuildContext context) {
    final alvo = WebUri('$urlOperar${widget.caminho}'
        '${widget.caminho.contains('?') ? '&' : '?'}soupm=1');
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: alvo),
          initialUserScripts:
              _scriptsIniciais(_token, _sessao?.api.matricula),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            // Obrigatório: o token do aparelho mora no localStorage do Operar.
            // Sem isto o militar cai no primeiro acesso a cada abertura.
            domStorageEnabled: true,
            supportZoom: false,
            useOnDownloadStart: true,
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            geolocationEnabled: true,
            allowsInlineMediaPlayback: true,
            transparentBackground: true,
            // iPhone: o par do WKAppBoundDomains do Info.plist. É o que libera
            // a Cache API para o Operar, e com ela o "Guardar para ver sem
            // sinal" — a ordem de operações e a escala abertas no campo, sem
            // rede. Em troca, esta WebView só navega para os domínios
            // declarados lá; não é perda, porque qualquer outro endereço já
            // ia para o navegador do sistema (shouldOverrideUrlLoading).
            // No Android o campo é ignorado.
            limitsNavigationsToAppBoundDomains: true,
          ),
          onWebViewCreated: (c) {
            _web = c;
            c.addJavaScriptHandler(
              handlerName: 'baixarOperar',
              callback: (args) => _receberArquivo(args),
            );
          },
          onLoadStop: (_, __) {
            if (mounted) setState(() => _carregandoPagina = false);
          },
          onReceivedError: (_, __, erro) {
            if (!mounted) return;
            setState(() => _carregandoPagina = false);
            registrar('operacoes.pagina', chave: _chaveLog, resultado: 'falhou',
                codigo: 'OP-PAGINA', dados: {'tipo': '${erro.type}'});
          },
          // Câmera (foto de alteração, atestado, viatura) só para o Operar.
          // O microfone não entra: a chamada de voz dele depende de um
          // servidor TURN que ainda não existe.
          onPermissionRequest: (_, pedido) async {
            if (!_daCasa(pedido.origin is String ? WebUri('${pedido.origin}') : null) &&
                !'${pedido.origin}'.contains(_origem.host)) {
              return PermissionResponse(
                  resources: pedido.resources, action: PermissionResponseAction.DENY);
            }
            final ok = await _permissaoDoSistema(Permission.camera);
            return PermissionResponse(
              resources: pedido.resources,
              action: ok ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY,
            );
          },
          // GPS: é o "Cheguei" do militar no posto.
          onGeolocationPermissionsShowPrompt: (_, origem) async {
            if (!origem.contains(_origem.host)) {
              return GeolocationPermissionShowPromptResponse(
                  origin: origem, allow: false, retain: true);
            }
            final ok = await _permissaoDoSistema(Permission.locationWhenInUse);
            return GeolocationPermissionShowPromptResponse(
                origin: origem, allow: ok, retain: ok);
          },
          shouldOverrideUrlLoading: (_, acao) async {
            final u = acao.request.url;
            if (_daCasa(u)) return NavigationActionPolicy.ALLOW;
            if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationActionPolicy.CANCEL;
          },
          // Download que o WebView tentaria sozinho (sem passar pelo clique
          // que a ponte intercepta): manda pela mesma ponte, para o pedido
          // levar o token do aparelho.
          onDownloadStartRequest: (_, pedido) async {
            final url = jsonEncode('${pedido.url}');
            final nome = jsonEncode(pedido.suggestedFilename ?? '');
            await _web?.evaluateJavascript(
                source: 'window.__soupmBaixar && window.__soupmBaixar($url, $nome, false);');
          },
        ),
        if (_carregandoPagina) const _Preparando(),
        if (_falhaToken != null) _AvisoLoginManual(falha: _falhaToken!),
      ],
    );
  }

  @override
  void dispose() {
    _web = null;
    super.dispose();
  }
}

class _Preparando extends StatelessWidget {
  const _Preparando();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: AppIconSize.xl,
          height: AppIconSize.xl,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}

/// Faixa discreta quando o login automático falhou: o Operar vai pedir o login
/// dele, e o militar precisa entender por quê antes de digitar.
class _AvisoLoginManual extends StatelessWidget {
  const _AvisoLoginManual({required this.falha});

  final FalhaApp falha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: CartaoVidro(
        raio: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: AppIconSize.sm, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Entre com a sua matrícula, o CPF e a senha da operação. '
                'O acesso automático não respondeu (${falha.codigo}).',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
