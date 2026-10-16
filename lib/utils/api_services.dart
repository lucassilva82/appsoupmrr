import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ApiServices {
  static const String baseUrl = 'https://pmrr.online/flutter/sigrh';
  // API de Legislações (externa)
  static const String legislacoesBaseUrl =
      'https://pm.rr.gov.br/api/legislacoes.php';
  // A chave vem do build, nunca do código-fonte. Este repositório é público:
  // uma chave escrita aqui vira pública no instante do push, e continua pública
  // no histórico mesmo depois de removida. Foi o que aconteceu com a chave
  // anterior, versionada em 3522d09.
  //
  // Passe no build:  flutter build apk --dart-define-from-file=env.json
  // O env.json fica fora do git (ver .gitignore e env.example.json).
  //
  // Importante entender o alcance disto: tirar a chave do repositório impede
  // que qualquer pessoa na internet a leia no GitHub. NÃO a torna secreta para
  // quem instala o app — qualquer chave compilada num binário pode ser extraída
  // dele. Enquanto o app falar direto com a API de legislações, essa chave é,
  // na prática, conhecida por quem tiver o APK. A correção definitiva é a API
  // ser chamada pelo nosso backend (pmrr.online), que já autentica o militar,
  // em vez de pelo aplicativo.
  static const String legislacoesApiKey =
      String.fromEnvironment('LEGISLACOES_API_KEY');

  /// Verdadeiro quando o build saiu sem a chave definida. As telas de
  /// Legislações e POPs não funcionam nesse caso, e é melhor dizer isso alto
  /// do que deixar a API responder 401 e parecer instabilidade da rede.
  static bool get semChaveLegislacoes => legislacoesApiKey.isEmpty;

  /// Envia a matrícula e o e-mail via GET ao endpoint `api_update_email.php`
  /// Retorna um Map: {"code": int, "message": String, ...}
  static Future<Map<String, dynamic>> sendEmailConfirmation({
    required String matricula,
    required String email,
  }) async {
    // Monta a URL com parâmetros GET.
    // Os valores são codificados: sem isso, um e-mail com '+'
    // (ex.: nome+pm@gmail.com) chega ao servidor com espaço no lugar do '+'
    // e é recusado como inválido.
    final String url = '$baseUrl/api_update_email.php'
        '?matricula=${Uri.encodeQueryComponent(matricula)}'
        '&email=${Uri.encodeQueryComponent(email)}';

    // Log de debug no Flutter
    debugPrint('[DEBUG] GET -> $url');

    try {
      // Faz a requisição GET
      final response = await http.get(Uri.parse(url));

      // Log de debug: status code
      debugPrint('[DEBUG] Response status: ${response.statusCode}');
      // Log de debug: body
      debugPrint('[DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return data;
        } catch (e) {
          debugPrint('[DEBUG] Erro ao decodificar JSON: $e');
          return {"code": 0, "message": "Erro ao decodificar JSON."};
        }
      } else {
        return {
          "code": 0,
          "message": "Erro HTTP: ${response.statusCode}",
        };
      }
    } catch (e) {
      // Pode ser erro de rede, timeout etc.
      debugPrint('[DEBUG] Exception no GET: $e');
      return {
        "code": 0,
        "message": "Erro de conexão: $e",
      };
    }
  }

  // ================================
  // Recuperação de senha por e-mail
  // ================================

  /// acao: 'solicitar' | 'validar' | 'redefinir'
  ///
  /// Informe o [email] (tela de login) ou a [matricula] (militar já logado,
  /// "Não lembro minha senha atual"): pela matrícula o código vai para o
  /// e-mail confirmado do cadastro.
  static Future<Map<String, dynamic>> recuperarSenha({
    required String acao,
    String? email,
    String? matricula,
    String? codigo,
    String? senhaNovaMd5,
  }) async {
    return _post('recuperar_senha.php', {
      'acao': acao,
      if (matricula != null) 'matricula': matricula else 'email': email ?? '',
      if (codigo != null) 'codigo': codigo,
      if (senhaNovaMd5 != null) 'senha_nova': senhaNovaMd5,
    });
  }

  // ================================
  // Primeiro acesso (sem e-mail)
  // ================================

  /// acao: 'iniciar' | 'trocar_pergunta' | 'responder' |
  ///       'enviar_codigo_email' | 'validar_codigo_email' | 'definir_senha'
  static Future<Map<String, dynamic>> primeiroAcesso({
    required String acao,
    String? cpf,
    String? sessao,
    Map<String, String>? respostas,
    String? senhaNovaMd5,
    List<String>? usadas,
    String? email,
    String? codigo,
    String? atual,
  }) async {
    return _post('primeiro_acesso.php', {
      'acao': acao,
      if (cpf != null) 'cpf': cpf,
      if (sessao != null) 'sessao': sessao,
      if (respostas != null) ...respostas,
      if (senhaNovaMd5 != null) 'senha_nova': senhaNovaMd5,
      if (usadas != null) 'usadas': usadas.join(','),
      if (atual != null) 'atual': atual,
      if (email != null) 'email': email,
      if (codigo != null) 'codigo': codigo,
    });
  }

  /// POST comum aos endpoints de acesso, com tratamento de erro padronizado.
  static Future<Map<String, dynamic>> _post(
    String arquivo,
    Map<String, String> corpo,
  ) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/$arquivo'), body: corpo)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {"code": 0, "message": "Erro HTTP: ${response.statusCode}"};
    } catch (e) {
      debugPrint('[DEBUG] $arquivo: $e');
      return {
        "code": 0,
        "message": "Sem conexão com o servidor. Verifique sua internet."
      };
    }
  }

  /// Troca a senha do militar (a mesma do SIGRH e do SouPMRR).
  /// As senhas vão em MD5 — formato gravado no banco — e por POST,
  /// para não ficarem registradas no log de acesso do servidor.
  static Future<Map<String, dynamic>> alterarSenha({
    required String matricula,
    required String senhaAtualMd5,
    required String senhaNovaMd5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alterar_senha.php'),
        body: {
          'matricula': matricula,
          'senha_atual': senhaAtualMd5,
          'senha_nova': senhaNovaMd5,
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {"code": 0, "message": "Erro HTTP: ${response.statusCode}"};
    } catch (e) {
      debugPrint('[DEBUG] alterarSenha: $e');
      return {"code": 0, "message": "Erro de conexão: $e"};
    }
  }

  /// Consulta a situação do e-mail no endpoint `status_email.php`.
  /// Retorna {"code":1,"verificado":bool,"aguardando":bool,"email":"m****o@x"}.
  /// Diferente do consulta_user.php, não devolve dado sensível.
  static Future<Map<String, dynamic>> checkEmailStatus(String matricula) async {
    final String url = '$baseUrl/status_email.php'
        '?matricula=${Uri.encodeQueryComponent(matricula)}';

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {"code": 0, "message": "Erro HTTP: ${response.statusCode}"};
    } catch (e) {
      debugPrint('[DEBUG] checkEmailStatus: $e');
      return {"code": 0, "message": "Erro de conexão: $e"};
    }
  }

  /// Novo método para verificar se existe um token válido
  static Future<Map<String, dynamic>> checkIfTokenExists(
      String matricula) async {
    final String url = '$baseUrl/verifica_token.php?matricula=$matricula';

    debugPrint('[DEBUG] GET -> $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('[DEBUG] Response status: ${response.statusCode}');
      debugPrint('[DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return data;
        } catch (e) {
          debugPrint('[DEBUG] Erro ao decodificar JSON: $e');
          return {"code": 0, "message": "Erro ao decodificar JSON."};
        }
      } else {
        return {
          "code": 0,
          "message": "Erro HTTP: ${response.statusCode}",
        };
      }
    } catch (e) {
      debugPrint('[DEBUG] Exception no GET: $e');
      return {
        "code": 0,
        "message": "Erro de conexão: $e",
      };
    }
  }

  // ================================
  // Legislações - Consumo da API externa
  // ================================

  // A API de legislações mora fora da nossa infraestrutura (pm.rr.gov.br).
  // As telas de lista já põem 8s na própria chamada; estes limites são a
  // rede de baixo, para os caminhos que não passam por lá — paginação,
  // detalhe e download de PDF. Sem eles, um servidor que aceita a conexão,
  // fecha o TLS e depois não responde (como em 13/10/2026) deixa o toque
  // num documento girando para sempre.
  static const Duration _limiteLegislacoes = Duration(seconds: 12);

  // PDF é arquivo: mais folga, mas ainda com fim.
  static const Duration _limitePdf = Duration(seconds: 30);

  /// Lista legislações com filtros e paginação.
  /// Retorna o JSON completo da API: { ok, meta, data: [...] }
  static Future<Map<String, dynamic>> listarLegislacoes({
    int page = 1,
    int perPage = 20,
    String? q,
    String? visibilidade,
    String? categoriaNome,
    String? tipoNome,
    String? numero,
    String? dataIni,
    String? dataFim,
    String orderBy = 'id',
    String orderDir = 'DESC',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'order_by': orderBy,
      'order_dir': orderDir,
    };
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (visibilidade != null && visibilidade.isNotEmpty) {
      params['visibilidade'] = visibilidade;
    }
    if (categoriaNome != null && categoriaNome.isNotEmpty) {
      params['categoria_nome'] = categoriaNome;
    }
    if (tipoNome != null && tipoNome.isNotEmpty) params['tipo_nome'] = tipoNome;
    if (numero != null && numero.isNotEmpty) params['numero'] = numero;
    if (dataIni != null && dataIni.isNotEmpty) params['data_ini'] = dataIni;
    if (dataFim != null && dataFim.isNotEmpty) params['data_fim'] = dataFim;

    final uri = Uri.parse(legislacoesBaseUrl).replace(queryParameters: params);
    debugPrint('[LEGIS] GET -> $uri');
    if (semChaveLegislacoes) {
      debugPrint('[LEGIS] ATENÇÃO: build sem LEGISLACOES_API_KEY — a API vai recusar.');
    }
    try {
      final res = await http.get(uri, headers: {
        'X-API-KEY': legislacoesApiKey,
        'Accept': 'application/json',
      }).timeout(_limiteLegislacoes);
      debugPrint('[LEGIS] status: ${res.statusCode}');
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('[LEGIS] erro: $e');
      rethrow;
    }
  }

  /// Detalhe de uma legislação.
  static Future<Map<String, dynamic>> detalheLegislacao(int id) async {
    final uri =
        Uri.parse(legislacoesBaseUrl).replace(queryParameters: {'id': '$id'});
    debugPrint('[LEGIS] DETAIL -> $uri');
    try {
      final res = await http.get(uri, headers: {
        'X-API-KEY': legislacoesApiKey,
        'Accept': 'application/json',
      }).timeout(_limiteLegislacoes);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LEGIS] erro detalhe: $e');
      rethrow;
    }
  }

  /// Baixa o PDF da legislação (via action=pdf) e salva em diretório temporário.
  /// Retorna o caminho do arquivo salvo.
  static Future<String> baixarLegislacaoPdf(
      {required int id, String? pdfApiUrl}) async {
    final uri = pdfApiUrl != null && pdfApiUrl.isNotEmpty
        ? Uri.parse(pdfApiUrl)
        : Uri.parse(legislacoesBaseUrl)
            .replace(queryParameters: {'action': 'pdf', 'id': '$id'});
    debugPrint('[LEGIS] PDF -> $uri');
    final res = await http
        .get(uri, headers: {'X-API-KEY': legislacoesApiKey})
        .timeout(_limitePdf);
    if (res.statusCode != 200) {
      throw Exception('Falha ao baixar PDF (HTTP ${res.statusCode})');
    }
    final bytes = res.bodyBytes;
    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, 'legislacao_$id.pdf');
    final f = File(filePath);
    await f.writeAsBytes(bytes);
    return filePath;
  }
}
