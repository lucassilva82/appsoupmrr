import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ApiServices {
  static const String baseUrl = 'https://pmrr.net/flutter/sigrh';
  // API de Legislações (externa)
  static const String legislacoesBaseUrl =
      'https://pm.rr.gov.br/api/legislacoes.php';
  static const String legislacoesApiKey = 'pMrrGIT_9f2Kx7QvL4nA1cZ8tY6uE3wB';

  /// Envia a matrícula e o e-mail via GET ao endpoint `api_update_email.php`
  /// Retorna um Map: {"code": int, "message": String, ...}
  static Future<Map<String, dynamic>> sendEmailConfirmation({
    required String matricula,
    required String email,
  }) async {
    // Monta a URL com parâmetros GET
    final String url =
        '$baseUrl/api_update_email.php?matricula=$matricula&email=$email';

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
    try {
      final res = await http.get(uri, headers: {
        'X-API-KEY': legislacoesApiKey,
        'Accept': 'application/json',
      });
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
      });
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
    final res = await http.get(uri, headers: {'X-API-KEY': legislacoesApiKey});
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
