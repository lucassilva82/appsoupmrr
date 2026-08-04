import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/store.dart';
import '../models/escala_model.dart';
import '../models/svi_model.dart';

// ── Exceção tipada do serviço ─────────────────────────────────────────────────
class EscalaServiceException implements Exception {
  final String code;
  final String message;
  const EscalaServiceException(this.code, this.message);

  @override
  String toString() => 'EscalaServiceException($code): $message';
}

class EscalaLoginResult {
  final bool precisaMigrarSenha;
  final String? mensagemMigracao;

  const EscalaLoginResult({
    required this.precisaMigrarSenha,
    this.mensagemMigracao,
  });
}

// ── Serviço principal ─────────────────────────────────────────────────────────
class EscalaService {
  static const _baseUrlProd = 'https://intranet.pmrr.online/api/v1';
  static const _baseUrlDev = 'https://intranet.gitpmrr.com/api/v1';
  static const _baseUrlDevPrefixed =
      'https://intranet.gitpmrr.com/intranet/api/v1';
  static const _phpHostDev = 'https://intranet.gitpmrr.com';
  static const _phpHostProd = 'https://intranet.pmrr.online';
  static const _apiBaseUrlFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const _storageKey = 'escalaJwt';
  static const _kCacheMinhasEscalas = 'escalaMinhasCache';

  String get _base {
    final envBase = _normalizeBase(_apiBaseUrlFromEnv);
    if (envBase.isNotEmpty) return envBase;
    return kReleaseMode ? _baseUrlProd : _baseUrlDev;
  }

  String get _phpHost {
    final host = Uri.tryParse(_activeBase)?.host.toLowerCase() ?? '';
    return host.contains('gitpmrr.com') ? _phpHostDev : _phpHostProd;
  }

  String get _activeBase => _baseOverride ?? _base;

  String? _token;
  DateTime? _expiresAt;
  String? _phpSession;
  bool _sessionOnlyAuth = false;
  String? _baseOverride;
  int _traceSeq = 0;

  String _nextTrace() =>
      '${DateTime.now().millisecondsSinceEpoch}-${++_traceSeq}';

  String _clip(String text, [int max = 220]) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  String _normalizeBase(String base) {
    final b = base.trim();
    if (b.isEmpty) return '';
    var normalized = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    if (!normalized.contains('/api/v1')) normalized = '$normalized/api/v1';
    return normalized;
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      final k = key.toLowerCase();
      if (k == 'authorization' || k == 'cookie') {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  Map<String, String> _sanitizeResponseHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      final k = key.toLowerCase();
      if (k == 'set-cookie' || k == 'www-authenticate') {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  String _sanitizeBodyPreview(String? body) {
    if (body == null || body.isEmpty) return '';
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final clean = Map<String, dynamic>.from(parsed);
        for (final k in const [
          'senha',
          'codigo_2fa',
          'nova_senha',
          'confirmar_senha',
          'token'
        ]) {
          if (clean.containsKey(k)) clean[k] = '***';
        }
        return _clip(jsonEncode(clean), 200);
      }
    } catch (_) {
      // Se não for JSON, só clipa para evitar estourar log.
    }
    return _clip(body.replaceAll('\n', ' '), 200);
  }

  void _log(String trace, String message) {
    debugPrint('[EscalaService][$trace] $message');
  }

  void _logResponse(String trace, String step, http.Response resp) {
    final ct = resp.headers['content-type'] ?? 'n/a';
    final location = resp.headers['location'];
    final sanitizedRespHeaders = _sanitizeResponseHeaders(resp.headers);
    final bodyBytes = resp.bodyBytes.length;
    _log(
      trace,
      '$step status=${resp.statusCode} ct=$ct '
      '${location != null ? 'location=$location ' : ''}'
      'bytes=$bodyBytes '
      'respHeaders=${_clip(sanitizedRespHeaders.toString(), 400)} '
      'body=${_clip(resp.body.replaceAll('\n', ' '), 520)}',
    );
  }

  Future<void> _persistCurrentStoreSnapshot() async {
    final hasAnyState = (_token != null && _token!.isNotEmpty) ||
        _sessionOnlyAuth ||
        (_phpSession != null && _phpSession!.isNotEmpty) ||
        _baseOverride != null;
    if (!hasAnyState) return;

    await Store.saveString(
      _storageKey,
      jsonEncode({
        'token': _token ?? '',
        'expires': (_expiresAt ?? DateTime.now().add(const Duration(hours: 8)))
            .toIso8601String(),
        if (_phpSession != null) 'phpSession': _phpSession,
        'sessionOnlyAuth': _sessionOnlyAuth,
        if (_baseOverride != null) 'baseOverride': _baseOverride,
      }),
    );
  }

  Future<void> _setBaseOverride(String? value,
      {String? trace, String? reason}) async {
    if (_baseOverride == value) return;
    _baseOverride = value;
    if (trace != null) {
      _log(trace,
          'base override atualizado para ${_baseOverride ?? '(none)'} ${reason ?? ''}');
    }
    try {
      await _persistCurrentStoreSnapshot();
    } catch (_) {}
  }

  // ── Token storage ───────────────────────────────────────────────────────────
  Future<void> _loadTokenFromStore() async {
    if (_token != null) return;
    try {
      final raw = await Store.getString(_storageKey);
      if (raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _token = map['token'] as String?;
      final exp = map['expires'] as String?;
      if (exp != null) _expiresAt = DateTime.tryParse(exp);
      _phpSession = map['phpSession'] as String?;
      _sessionOnlyAuth = map['sessionOnlyAuth'] == true;
      _baseOverride = map['baseOverride'] as String?;

      // Migração de compatibilidade: após correção no servidor,
      // prioriza base DEV sem prefixo para evitar 404 persistente.
      if (_baseOverride == _baseUrlDevPrefixed) {
        _baseOverride = _baseUrlDev;
        try {
          await _persistCurrentStoreSnapshot();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _persistToken(String token, String expiresAt) async {
    _token = token;
    _expiresAt = DateTime.tryParse(expiresAt);
    _sessionOnlyAuth = false;
    await Store.saveString(
      _storageKey,
      jsonEncode({
        'token': token,
        'expires': expiresAt,
        if (_phpSession != null) 'phpSession': _phpSession,
        'sessionOnlyAuth': false,
        if (_baseOverride != null) 'baseOverride': _baseOverride,
      }),
    );
  }

  Future<void> _persistSessionOnlyAuth() async {
    _token = null;
    _expiresAt = DateTime.now().add(const Duration(hours: 8));
    _sessionOnlyAuth = true;
    await Store.saveString(
      _storageKey,
      jsonEncode({
        'token': '',
        'expires': _expiresAt!.toIso8601String(),
        if (_phpSession != null) 'phpSession': _phpSession,
        'sessionOnlyAuth': true,
        if (_baseOverride != null) 'baseOverride': _baseOverride,
      }),
    );
  }

  Future<void> clearToken() async {
    _token = null;
    _expiresAt = null;
    _phpSession = null;
    _sessionOnlyAuth = false;
    _baseOverride = null;
    await Store.remove(_storageKey);
  }

  bool get _isTokenNearExpiry {
    if (_expiresAt == null) return true;
    return _expiresAt!.difference(DateTime.now()).inMinutes < 120;
  }

  // ── Headers autenticados ────────────────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    await _loadTokenFromStore();
    if (_sessionOnlyAuth && (_phpSession == null || _phpSession!.isEmpty)) {
      _sessionOnlyAuth = false;
      throw const EscalaServiceException(
          'NOT_AUTHENTICATED', 'Sessão web inválida. Faça login novamente.');
    }
    if (!_sessionOnlyAuth && (_token == null || _token!.isEmpty)) {
      throw const EscalaServiceException(
          'NOT_AUTHENTICATED', 'Login necessário');
    }
    if (!_sessionOnlyAuth && _isTokenNearExpiry) {
      try {
        await _refreshToken();
      } catch (_) {
        // continua com token antigo; 401 será tratado na chamada
      }
    }
    return {
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_phpSession != null && _phpSession!.isNotEmpty)
        'Cookie': _phpSession!,
    };
  }

  bool _isLikelyHtml(http.Response resp) {
    final ct = resp.headers['content-type']?.toLowerCase() ?? '';
    final bodyStart = resp.body.trimLeft();
    return ct.contains('text/html') ||
        bodyStart.startsWith('<!DOCTYPE html>') ||
        bodyStart.startsWith('<html');
  }

  String? _extractHtmlTitle(String html) {
    final m =
        RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true)
            .firstMatch(html);
    return m?.group(1)?.trim();
  }

  // ── Helper: parse seguro de JSON ────────────────────────────────────────────
  /// Lança [EscalaServiceException] com código HTTP se o corpo não for JSON.
  Map<String, dynamic> _parseJson(http.Response resp, {String context = ''}) {
    if (resp.statusCode >= 300 && resp.statusCode < 400) {
      final location = resp.headers['location'] ?? 'n/a';
      throw EscalaServiceException(
        'API_REDIRECT',
        'API respondeu redirect HTTP ${resp.statusCode} '
            '(${context.isNotEmpty ? context : 'sem contexto'}) para $location',
      );
    }

    final ct = resp.headers['content-type'] ?? '';
    final isJson = ct.contains('application/json') ||
        ct.contains('text/json') ||
        resp.body.trimLeft().startsWith('{') ||
        resp.body.trimLeft().startsWith('[');

    if (!isJson) {
      final prefix = resp.body.substring(0, resp.body.length.clamp(0, 160));
      debugPrint('[EscalaService] Resposta não-JSON (${resp.statusCode}) '
          '${context.isNotEmpty ? '[$context] ' : ''}'
          'ct=$ct base=$_activeBase sessionOnly=$_sessionOnlyAuth '
          'prefix=${prefix.replaceAll('\n', ' ')}');

      if (_isLikelyHtml(resp)) {
        final title = _extractHtmlTitle(resp.body);
        final isIntranetPage = title != null &&
            (title.toLowerCase().contains('intranet') ||
                title.toLowerCase().contains('início') ||
                title.toLowerCase().contains('inicio'));
        throw EscalaServiceException(
          'API_HTML_RESPONSE',
          isIntranetPage
              ? 'A autenticação web funcionou, mas a API de escalas retornou uma página HTML da intranet em vez de JSON. Ambiente ainda não compatível com o módulo.'
              : 'Servidor retornou HTML em vez de JSON para o módulo de escalas.',
        );
      }

      throw EscalaServiceException(
        'HTTP_${resp.statusCode}',
        'Servidor indisponível (código ${resp.statusCode}). '
            'Verifique sua conexão ou tente novamente.',
      );
    }

    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      // Detecta PHP fatal error / warning: content-type diz JSON mas
      // corpo começa com tag HTML (ex: <br /> <b>Fatal error</b>...).
      final bodyStart = resp.body.trimLeft();
      if (bodyStart.startsWith('<')) {
        final info = _parsephpError(resp.body);
        debugPrint('══════════════════════════════════════════════');
        debugPrint('[EscalaService] ❌ ERRO NO SERVIDOR PHP');
        debugPrint('[EscalaService]   context : $context');
        debugPrint('[EscalaService]   url     : $_activeBase');
        debugPrint('[EscalaService]   status  : ${resp.statusCode}');
        debugPrint(
            '[EscalaService]   ct      : ${resp.headers['content-type']}');
        debugPrint('[EscalaService]   nivel   : ${info['level']}');
        debugPrint('[EscalaService]   tipo    : ${info['type']}');
        debugPrint('[EscalaService]   msg     : ${info['message']}');
        debugPrint('[EscalaService]   arquivo : ${info['file']}');
        debugPrint('[EscalaService]   linha   : ${info['line']}');
        debugPrint(
            '[EscalaService]   body    : ${_clip(bodyStart.replaceAll('\n', ' '), 600)}');
        debugPrint('══════════════════════════════════════════════');
        throw EscalaServiceException(
          'SERVER_ERROR',
          'Erro interno no servidor (${info['level']}: ${info['message']}). '
              'Arquivo: ${info['file']} linha ${info['line']}.',
        );
      }
      throw const EscalaServiceException(
        'PARSE_ERROR',
        'Resposta inválida do servidor.',
      );
    }
  }

  /// Extrai tipo, mensagem, arquivo e linha de um PHP error/warning/notice.
  /// Formato esperado: `<br /> <b>Fatal error</b>: Uncaught TypeError: ... in file.php:123`
  Map<String, String> _parsephpError(String body) {
    final plain =
        body.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll('&gt;', '>');

    // Nível: Fatal error / Warning / Notice / Deprecated
    final levelMatch = RegExp(
            r'(Fatal error|Warning|Notice|Deprecated|Parse error)',
            caseSensitive: false)
        .firstMatch(plain);
    final level = levelMatch?.group(1) ?? 'Unknown';

    // Tipo de exceção: ex. "Uncaught TypeError:"
    final typeMatch =
        RegExp(r'Uncaught\s+(\w+Exception|\w+Error):').firstMatch(plain);
    final type = typeMatch?.group(1) ?? '';

    // Mensagem principal: tudo entre o nível e "in /path"
    final msgMatch = RegExp(
            r'(?:Fatal error|Warning|Notice|Deprecated|Parse error)\s*:\s*(?:Uncaught\s+(?:\w+Exception|\w+Error):\s*)?(.*?)\s+in\s+/',
            caseSensitive: false,
            dotAll: true)
        .firstMatch(plain);
    final msg = msgMatch?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ??
        plain.substring(0, plain.length.clamp(0, 120));

    // Arquivo e linha: "in /home/.../File.php:154"
    final fileMatch = RegExp(r'in\s+(/[^\s:]+\.php):(\d+)').firstMatch(plain);
    final file = fileMatch?.group(1)?.split('/').last ?? 'desconhecido';
    final line = fileMatch?.group(2) ?? '?';

    return {
      'level': level,
      'type': type,
      'message': msg,
      'file': file,
      'line': line,
    };
  }

  /// Extrai código e mensagem de erro de forma segura, independente do formato.
  /// Suporta: `error` como String, como Map{code,message}, ou campo `message` solto.
  ({String code, String message}) _extractError(
      Map<String, dynamic> body, String fallbackCode) {
    final err = body['error'];
    if (err is Map) {
      return (
        code: err['code']?.toString() ?? fallbackCode,
        message: err['message']?.toString() ?? 'Erro desconhecido.',
      );
    }
    if (err is String && err.isNotEmpty) {
      return (code: err, message: body['message']?.toString() ?? err);
    }
    return (
      code: fallbackCode,
      message: body['message']?.toString() ?? 'Erro desconhecido.',
    );
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Remove formatação da matrícula, mantendo apenas dígitos.
  String _cleanMatricula(String matricula) =>
      matricula.replaceAll(RegExp(r'[^0-9]'), '');

  String _formatMatriculaForPhp(String cleanMatricula) {
    if (cleanMatricula.length == 6) {
      return '${cleanMatricula.substring(0, 2)}.${cleanMatricula.substring(2, 5)}-${cleanMatricula.substring(5)}';
    }
    return cleanMatricula;
  }

  String? _extractPhpSession(String rawCookieHeader) {
    final m = RegExp(r'PHPSESSID=([^;,\s]+)').firstMatch(rawCookieHeader);
    if (m == null) return null;
    return 'PHPSESSID=${m.group(1)}';
  }

  bool _isSessionGateResponse(Map<String, dynamic> body, int statusCode) {
    if (statusCode != 401) return false;
    final err = body['error']?.toString().toLowerCase();
    final login = body['login']?.toString();
    return err == 'unauthenticated' &&
        (login?.contains('/auth/login.php') ?? false);
  }

  Future<void> _acquirePhpSession(String cleanMatricula, String senha) async {
    final trace = _nextTrace();
    final phpMatricula = _formatMatriculaForPhp(cleanMatricula);
    _log(trace, 'php auth start host=$_phpHost mat=$phpMatricula');
    final req = http.Request(
      'POST',
      Uri.parse('$_phpHost/auth/valida_user.php'),
    )
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..headers['Accept'] = 'text/html,application/xhtml+xml'
      ..headers['Referer'] = '$_phpHost/auth/login.php'
      ..body = 'matricula=${Uri.encodeComponent(phpMatricula)}'
          '&password=${Uri.encodeComponent(senha)}'
          '&next=${Uri.encodeComponent('/public/index.php')}';

    final streamed = await req.send().timeout(const Duration(seconds: 15));
    final setCookie = streamed.headers['set-cookie'] ?? '';
    final session = _extractPhpSession(setCookie);
    _log(
      trace,
      'php auth response status=${streamed.statusCode} '
      'location=${streamed.headers['location'] ?? 'n/a'} '
      'set-cookie=${_clip(setCookie, 180)}',
    );

    if (session == null) {
      _log(trace, 'php auth failed: PHPSESSID ausente');
      throw const EscalaServiceException(
        'PHP_AUTH_FAILED',
        'Não foi possível autenticar no portal da intranet.',
      );
    }

    _phpSession = session;
    _log(trace, 'php auth ok session=$_phpSession');
  }

  Future<http.Response> _apiLoginRequest(
    String cleanMatricula,
    String senha, {
    String? codigo2fa,
  }) {
    final payload = <String, dynamic>{
      'matricula': cleanMatricula,
      'senha': senha,
      if (codigo2fa != null && codigo2fa.isNotEmpty) 'codigo_2fa': codigo2fa,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_phpSession != null && _phpSession!.isNotEmpty)
        'Cookie': _phpSession!,
    };

    return _sendRequest(
      method: 'POST',
      uri: Uri.parse('$_activeBase/auth/login'),
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));
  }

  Future<http.Response> _sendRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final trace = _nextTrace();
    final sw = Stopwatch()..start();
    _log(
      trace,
      'HTTP send method=$method url=$uri headers=${_sanitizeHeaders(headers)} '
      'body=${_sanitizeBodyPreview(body)}',
    );
    final req = http.Request(method, uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll(headers);
    if (body != null) req.body = body;
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    sw.stop();
    _log(
        trace,
        'HTTP done method=$method url=$uri '
        'timeMs=${sw.elapsedMilliseconds} status=${resp.statusCode} '
        'ct=${resp.headers['content-type'] ?? 'n/a'} '
        'respHeaders=${_clip(_sanitizeResponseHeaders(resp.headers).toString(), 360)} '
        'bodyPreview=${_clip(resp.body.replaceAll('\n', ' '), 360)}');
    return resp;
  }

  // Removido: _canTryDevPrefixedFallback — URL com prefixo /intranet/ não existe
  // no servidor e sempre retorna 404. A migração já garante que _baseOverride
  // aponte para a URL correta.

  bool get _isDevIntranetBase =>
      Uri.tryParse(_activeBase)?.host.toLowerCase() == 'intranet.gitpmrr.com';

  /// Retorna fallback SOMENTE quando base ativa ainda é a URL morta com
  /// prefixo /intranet/ (estado legado persistido antes da correção do servidor).
  /// Nunca mais navega de _baseUrlDev → _baseUrlDevPrefixed.
  String? _nextDevFallbackTarget(http.Response resp) {
    if (!_isDevIntranetBase) return null;

    // Migração defensiva: se ainda na URL com prefixo (estado legado),
    // qualquer resposta inválida reverte para a URL correta.
    if (_activeBase == _baseUrlDevPrefixed &&
        (_isLikelyHtml(resp) || resp.statusCode == 404)) {
      return _baseUrlDev;
    }

    return null;
  }

  Future<http.Response> _getWithFallback(
      String path, Map<String, String> headers,
      {String? trace}) async {
    if (trace != null) {
      _log(trace, 'GET start path=$path base=$_activeBase');
    }
    var resp = await _sendRequest(
      method: 'GET',
      uri: Uri.parse('$_activeBase$path'),
      headers: headers,
    ).timeout(const Duration(seconds: 15));

    // Migração defensiva: se ainda na URL legada com /intranet/ (estado
    // persistido antes da correção do servidor), reverte para URL correta.
    final devFallback = _nextDevFallbackTarget(resp);
    if (devFallback != null) {
      if (trace != null) {
        _log(trace, 'GET URL legada detectada, revertendo para $devFallback');
      }
      await _setBaseOverride(devFallback,
          trace: trace, reason: '(migração da URL legada)');
      resp = await _sendRequest(
        method: 'GET',
        uri: Uri.parse('$_activeBase$path'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
    }

    if (trace != null) {
      _log(trace,
          'GET end path=$path baseFinal=$_activeBase status=${resp.statusCode}');
    }

    return resp;
  }

  Future<http.Response> _postWithFallback(
      String path, Map<String, String> headers, Map<String, dynamic> payload,
      {String? trace}) async {
    if (trace != null) {
      _log(trace, 'POST start path=$path base=$_activeBase');
    }
    var resp = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('$_activeBase$path'),
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    // Migração defensiva: se ainda na URL legada com /intranet/.
    final devFallback = _nextDevFallbackTarget(resp);
    if (devFallback != null) {
      if (trace != null) {
        _log(trace, 'POST URL legada detectada, revertendo para $devFallback');
      }
      await _setBaseOverride(devFallback,
          trace: trace, reason: '(migração da URL legada)');
      resp = await _sendRequest(
        method: 'POST',
        uri: Uri.parse('$_activeBase$path'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
    }

    if (trace != null) {
      _log(trace,
          'POST end path=$path baseFinal=$_activeBase status=${resp.statusCode}');
    }

    return resp;
  }

  Future<EscalaLoginResult> login(String matricula, String senha,
      {String? codigo2fa}) async {
    final trace = _nextTrace();
    final cleanMat = _cleanMatricula(matricula);

    // Garante estado limpo antes de qualquer requisição de login.
    // O estado legado (sessionOnly/phpSession) pode fazer o servidor
    // receber um Cookie que aciona caminhos de código com bugs no banco.
    _sessionOnlyAuth = false;
    _phpSession = null;

    _log(trace,
        'login start mat=$cleanMat base=$_activeBase has2fa=${codigo2fa != null && codigo2fa.isNotEmpty}');

    var resp = await _apiLoginRequest(
      cleanMat,
      senha,
      codigo2fa: codigo2fa,
    );

    _logResponse(trace, 'login api', resp);

    // Migração defensiva: se ainda na URL legada com /intranet/ (estado
    // persistido antes da correção do servidor), reverte para URL correta.
    final loginFallback = _nextDevFallbackTarget(resp);
    if (loginFallback != null) {
      await _setBaseOverride(loginFallback,
          trace: trace,
          reason: '(login fallback bidirecional por HTML/404 em DEV)');
      resp = await _apiLoginRequest(
        cleanMat,
        senha,
        codigo2fa: codigo2fa,
      );
      _logResponse(trace, 'login api alt-base-2', resp);
    }

    if (_isLikelyHtml(resp)) {
      // Ambiente legado/transição: /api/v1/auth/login pode responder
      // com a página HTML da intranet quando a sessão já está válida.
      // Nesse caso seguimos no modo "session only" para o módulo Escalas.
      if (_phpSession == null || _phpSession!.isEmpty) {
        await _acquirePhpSession(cleanMat, senha);
      }
      await _persistSessionOnlyAuth();
      _log(trace,
          'login em modo sessionOnlyAuth=true (HTML no endpoint de login)');
      return const EscalaLoginResult(
        precisaMigrarSenha: false,
        mensagemMigracao: null,
      );
    }

    var body = _parseJson(resp, context: 'login');

    if (_isSessionGateResponse(body, resp.statusCode)) {
      await _acquirePhpSession(cleanMat, senha);
      resp = await _apiLoginRequest(
        cleanMat,
        senha,
        codigo2fa: codigo2fa,
      );
      _logResponse(trace, 'login api com sessao php', resp);

      // Ambiente de transição: sessão PHP válida, mas endpoint JWT ainda
      // redireciona para página HTML da intranet.
      if (_isLikelyHtml(resp)) {
        await _persistSessionOnlyAuth();
        _log(
            trace, 'login em modo sessionOnlyAuth=true (HTML apos sessao PHP)');
        return const EscalaLoginResult(
          precisaMigrarSenha: false,
          mensagemMigracao: null,
        );
      }

      body = _parseJson(resp, context: 'login-pos-php-session');
    }

    if (resp.statusCode == 403) {
      final e = _extractError(body, 'FORBIDDEN');
      if (e.code == 'REQUIRES_2FA') {
        _log(trace, 'login requires 2FA');
        throw const EscalaServiceException(
            'REQUIRES_2FA', 'Código 2FA obrigatório');
      }
    }

    if (resp.statusCode != 200 || body['success'] != true) {
      final e = _extractError(body, 'LOGIN_ERROR');
      _log(trace, 'login erro code=${e.code} msg=${e.message}');
      throw EscalaServiceException(e.code, e.message);
    }

    final data = body['data'] as Map<String, dynamic>;
    await _persistToken(
      data['token'] as String,
      data['expires_at'] as String,
    );
    _log(trace,
        'login sucesso tokenPersistido expires=${data['expires_at']} migrarSenha=${data['precisa_migrar_senha'] == true}');

    return EscalaLoginResult(
      precisaMigrarSenha: data['precisa_migrar_senha'] == true,
      mensagemMigracao: data['mensagem_migracao']?.toString(),
    );
  }

  Future<void> migrarSenha(String novaSenha, String confirmarSenha) async {
    await _post('/auth/migrar-senha', {
      'nova_senha': novaSenha,
      'confirmar_senha': confirmarSenha,
    });
  }

  Future<void> _refreshToken() async {
    if (_sessionOnlyAuth || _token == null || _token!.isEmpty) return;
    final trace = _nextTrace();
    try {
      final headers = <String, String>{
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_phpSession != null && _phpSession!.isNotEmpty)
          'Cookie': _phpSession!,
      };
      final resp = await _sendRequest(
        method: 'POST',
        uri: Uri.parse('$_activeBase/auth/refresh'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      _logResponse(trace, 'refresh', resp);

      if (resp.statusCode != 200) return;
      Map<String, dynamic> body;
      try {
        body = _parseJson(resp, context: 'refresh');
      } catch (_) {
        return;
      }
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        await _persistToken(
          data['token'] as String,
          data['expires_at'] as String,
        );
      }
    } catch (e) {
      _log(trace, 'refresh exception=$e');
    }
  }

  // ── HTTP helpers ────────────────────────────────────────────────────────────
  Future<dynamic> _get(String path) async {
    final trace = _nextTrace();
    final headers = await _authHeaders();
    _log(trace,
        'GET start path=$path base=$_activeBase sessionOnly=$_sessionOnlyAuth hasCookie=${_phpSession != null && _phpSession!.isNotEmpty}');
    _log(trace,
        'GET headers auth=${headers.containsKey('Authorization')} cookie=${headers.containsKey('Cookie')} sessionOnly=$_sessionOnlyAuth');
    final resp = await _getWithFallback(path, headers, trace: trace);
    _logResponse(trace, 'GET $path', resp);

    if (resp.statusCode == 401) {
      throw const EscalaServiceException(
          'UNAUTHORIZED', 'Sessão expirada. Faça login novamente.');
    }

    Map<String, dynamic> body;
    try {
      body = _parseJson(resp, context: 'GET $path');
    } on EscalaServiceException catch (e) {
      if (e.code == 'API_HTML_RESPONSE' &&
          !headers.containsKey('Authorization') &&
          !_sessionOnlyAuth) {
        _log(trace,
            'GET HTML sem Authorization e fora de session-only: limpando sessão web e convertendo para UNAUTHORIZED');
        _sessionOnlyAuth = false;
        _phpSession = null;
        throw const EscalaServiceException(
            'UNAUTHORIZED', 'Sessão expirada. Faça login novamente.');
      }
      rethrow;
    }
    if (body['success'] != true) {
      final e = _extractError(body, 'API_ERROR');
      _log(trace, 'GET erro code=${e.code} msg=${e.message}');
      throw EscalaServiceException(e.code, e.message);
    }
    _log(trace, 'GET sucesso path=$path');
    return body['data'];
  }

  Future<dynamic> _post(String path, Map<String, dynamic> payload) async {
    final trace = _nextTrace();
    final headers = await _authHeaders();
    _log(trace,
        'POST start path=$path base=$_activeBase payloadKeys=${payload.keys.join(',')} sessionOnly=$_sessionOnlyAuth');
    _log(trace,
        'POST headers auth=${headers.containsKey('Authorization')} cookie=${headers.containsKey('Cookie')} sessionOnly=$_sessionOnlyAuth');
    final resp = await _postWithFallback(path, headers, payload, trace: trace);
    _logResponse(trace, 'POST $path', resp);

    if (resp.statusCode == 401) {
      throw const EscalaServiceException(
          'UNAUTHORIZED', 'Sessão expirada. Faça login novamente.');
    }

    Map<String, dynamic> body;
    try {
      body = _parseJson(resp, context: 'POST $path');
    } on EscalaServiceException catch (e) {
      if (e.code == 'API_HTML_RESPONSE' &&
          !headers.containsKey('Authorization') &&
          !_sessionOnlyAuth) {
        _log(trace,
            'POST HTML sem Authorization e fora de session-only: limpando sessão web e convertendo para UNAUTHORIZED');
        _sessionOnlyAuth = false;
        _phpSession = null;
        throw const EscalaServiceException(
            'UNAUTHORIZED', 'Sessão expirada. Faça login novamente.');
      }
      rethrow;
    }
    if (body['success'] != true) {
      final e = _extractError(body, 'API_ERROR');
      _log(trace, 'POST erro code=${e.code} msg=${e.message}');
      throw EscalaServiceException(e.code, e.message);
    }
    _log(trace, 'POST sucesso path=$path');
    return body['data'];
  }

  // ── Endpoints de Escala ─────────────────────────────────────────────────────
  Future<EscalaModel?> getProximaEscala() async {
    final data = await _get('/escala/proxima');
    if (data is Map<String, dynamic>) {
      final proxima = data['proxima'];
      if (proxima is Map<String, dynamic>) {
        return EscalaModel.fromJson(proxima);
      }
      if (data['escala_id'] != null) {
        return EscalaModel.fromJson(data);
      }
      return null;
    }
    return null;
  }

  Future<List<EscalaModel>> getMinhasEscalas() async {
    final data = await _get('/escala/minhas-escalas');
    List<dynamic> list = const [];
    if (data is Map<String, dynamic>) {
      list = data['escalas'] as List<dynamic>? ?? const [];
    } else if (data is List<dynamic>) {
      list = data;
    }
    final escalas = list
        .map((e) => EscalaModel.fromJson(e as Map<String, dynamic>))
        .toList();
    // Cache local: guarda a última lista válida para uso offline / quando o
    // backend ficar indisponível (HTTP 500).
    try {
      await Store.saveString(_kCacheMinhasEscalas, jsonEncode(list));
    } catch (_) {}
    return escalas;
  }

  /// Lê a última lista de escalas cacheada localmente. Retorna lista vazia se
  /// não houver cache ou se ele estiver corrompido.
  Future<List<EscalaModel>> getMinhasEscalasCache() async {
    try {
      final raw = await Store.getString(_kCacheMinhasEscalas);
      if (raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(EscalaModel.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<EscalaModel> getEscalaDetalhe(int id) async {
    final data = await _get('/escala/$id');
    return EscalaModel.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> registrarCiencia(int id) async {
    final data = await _post('/escala/$id/ciencia', {});
    return data as Map<String, dynamic>;
  }

  Future<void> registrarImpossibilidade(
      int id, int tipoId, String? observacao) async {
    await _post('/escala/$id/impossibilidade', {
      'tipo_id': tipoId,
      if (observacao != null && observacao.isNotEmpty) 'observacao': observacao,
    });
  }

  Future<List<EscalaImpossibilidadeTipo>> getTiposImpossibilidade() async {
    final data = await _get('/escala/impossibilidade/tipos');
    List<dynamic> list = const [];
    if (data is Map<String, dynamic>) {
      list = data['tipos'] as List<dynamic>? ?? const [];
    } else if (data is List<dynamic>) {
      list = data;
    }
    return list
        .map((e) =>
            EscalaImpossibilidadeTipo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Endpoints de SVI (Serviço Voluntário Interno) ──────────────────────────────

  /// GET /svi/adesao — status da adesão SVI do militar autenticado.
  Future<SviAdesaoModel?> getSviAdesao() async {
    final data = await _get('/svi/adesao');
    if (data is Map<String, dynamic>) {
      return SviAdesaoModel.fromJson(data);
    }
    return null;
  }

  /// POST /svi/adesao/assinar — aderir ao SVI pelo app.
  Future<void> assinarSvi() async {
    await _post('/svi/adesao/assinar', {});
  }

  /// POST /svi/adesao/cancelar — cancelar adesão SVI.
  Future<void> cancelarSvi() async {
    await _post('/svi/adesao/cancelar', {});
  }

  /// GET /svi/termo — texto do termo de adesão SVI.
  Future<SviTermoModel> getSviTermo() async {
    final data = await _get('/svi/termo');
    return SviTermoModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Auto-escalação SVI (vagas para voluntários) ─────────────────────────────

  /// GET /svi/escalas-disponiveis — escalas SVI publicadas com vagas
  /// compatíveis com o posto/graduação do militar autenticado.
  Future<SviEscalasDisponiveisResult> getSviEscalasDisponiveis() async {
    final data = await _get('/svi/escalas-disponiveis');
    if (data is Map<String, dynamic>) {
      return SviEscalasDisponiveisResult.fromJson(data);
    }
    // Alguns backends podem retornar diretamente a lista de escalas.
    if (data is List<dynamic>) {
      return SviEscalasDisponiveisResult(
        temAdesao: true,
        escalas: data
            .whereType<Map<String, dynamic>>()
            .map(SviEscalaDisponivelModel.fromJson)
            .toList(),
      );
    }
    return const SviEscalasDisponiveisResult(temAdesao: false, escalas: []);
  }

  /// GET /svi/escalas/{id}/slots — slots detalhados de uma escala SVI, com
  /// `guarnicao_id` + `funcao_id`, campo `disponivel` e restrições por slot.
  Future<SviEscalaSlotsResult> getSviEscalaSlots(int escalaId) async {
    final data = await _get('/svi/escalas/$escalaId/slots');
    if (data is Map<String, dynamic>) {
      return SviEscalaSlotsResult.fromJson(data);
    }
    if (data is List<dynamic>) {
      return SviEscalaSlotsResult(
        escalaId: escalaId,
        aberta: true,
        temAdesao: true,
        slots: data
            .whereType<Map<String, dynamic>>()
            .map(SviSlotModel.fromJson)
            .toList(),
      );
    }
    return SviEscalaSlotsResult(
      escalaId: escalaId,
      aberta: true,
      temAdesao: true,
      slots: const [],
    );
  }

  /// POST /svi/auto-escalar — candidatar-se a uma vaga SVI.
  ///
  /// Toda a validação (13 regras) é server-side. Em caso de erro, o backend
  /// devolve uma mensagem em português que é propagada via
  /// [EscalaServiceException] (o `code` traz o motivo, ex.: `TETO_SVI`).
  /// Retorna a mensagem de sucesso da API.
  Future<String> autoEscalarSvi({
    required int escalaId,
    required int guarnicaoId,
    required int funcaoId,
  }) async {
    final data = await _post('/svi/auto-escalar', {
      'escala_id': escalaId,
      'guarnicao_id': guarnicaoId,
      'funcao_id': funcaoId,
    });
    if (data is Map<String, dynamic>) {
      return data['mensagem']?.toString() ?? 'Candidatura registrada.';
    }
    return 'Candidatura registrada.';
  }

  /// GET /svi/meus-voluntarios — histórico dos serviços em que o militar
  /// se candidatou (mais recente primeiro).
  Future<List<SviVoluntarioModel>> getSviMeusVoluntarios() async {
    final data = await _get('/svi/meus-voluntarios');
    List<dynamic> list = const [];
    if (data is Map<String, dynamic>) {
      list = data['escalas'] as List<dynamic>? ?? const [];
    } else if (data is List<dynamic>) {
      list = data;
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(SviVoluntarioModel.fromJson)
        .toList();
  }

  // ── Endpoint de Perfil Consolidado ──────────────────────────────────────

  /// GET /perfil/resumo — próxima escala + adesão SVI +
  /// notificações pendentes + horas SVI do mês.
  Future<PerfilResumoModel> getPerfilResumo() async {
    final data = await _get('/perfil/resumo');
    return PerfilResumoModel.fromJson(data as Map<String, dynamic>);
  }
}
