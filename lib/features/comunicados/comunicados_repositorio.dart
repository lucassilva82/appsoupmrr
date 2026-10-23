import 'package:flutter/material.dart';

import '../../core/design/arte_cartao.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/iniciar_log.dart';
import '../../core/rede/api_client.dart';

/// Categoria do comunicado (nome, cor e ícone vêm do painel, §9.1 nº 1).
class CategoriaComunicado {
  const CategoriaComunicado({required this.chave, required this.nome, required this.cor, required this.icone});

  final String chave;
  final String nome;
  final Color cor;
  final IconData icone;

  static const reserva = CategoriaComunicado(
      chave: 'institucional', nome: 'Institucional', cor: Color(0xFF15803D), icone: Icons.campaign_outlined);

  static CategoriaComunicado? deJson(Map j) {
    final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch('${j['cor']}');
    if (m == null || j['chave'] is! String) return null;
    return CategoriaComunicado(
      chave: j['chave'] as String,
      nome: '${j['nome'] ?? j['chave']}',
      cor: Color(int.parse('FF${m.group(1)}', radix: 16)),
      icone: iconePorNome('${j['icone']}') ?? Icons.campaign_outlined,
    );
  }

  /// A arte do cartão sai da cor da categoria: base escura, meio na cor e
  /// destaque claro, como as outras artes (§4.6).
  Arte get arte => Arte(
        Color.lerp(cor, Colors.black, 0.72)!,
        Color.lerp(cor, Colors.black, 0.15)!,
        Color.lerp(cor, Colors.white, 0.55)!,
        [icone, icone, icone],
      );
}

class Comunicado {
  const Comunicado({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.categoria,
    required this.origem,
    this.resumo = '',
    this.pilula,
    this.inicio,
    this.urgente = false,
    this.destaqueAbertura = false,
    this.aberturaAteCiencia = false,
    this.ciencia = false,
    this.cienciaPrazo,
    this.versao = 1,
    this.lido = false,
    this.ciente = false,
    this.icone,
  });

  final int id;
  final String titulo;
  final String resumo;
  final String texto;
  final CategoriaComunicado categoria;
  final String origem;
  final ({IconData icone, String texto})? pilula;
  final DateTime? inicio;
  final bool urgente;
  final bool destaqueAbertura;
  final bool aberturaAteCiencia;
  final bool ciencia;
  final DateTime? cienciaPrazo;
  final int versao;
  final bool lido;
  final bool ciente;

  /// Ícone do assunto, na ilustração do cartão; nulo = o da categoria.
  final IconData? icone;

  IconData get iconeAssunto => icone ?? categoria.icone;

  bool get cienciaPendente => ciencia && !ciente;

  Comunicado copiar({bool? lido, bool? ciente}) => Comunicado(
        id: id,
        titulo: titulo,
        resumo: resumo,
        texto: texto,
        categoria: categoria,
        origem: origem,
        pilula: pilula,
        inicio: inicio,
        urgente: urgente,
        destaqueAbertura: destaqueAbertura,
        aberturaAteCiencia: aberturaAteCiencia,
        ciencia: ciencia,
        cienciaPrazo: cienciaPrazo,
        versao: versao,
        lido: lido ?? this.lido,
        ciente: ciente ?? this.ciente,
        icone: icone,
      );

  static Comunicado deJson(Map j, Map<String, CategoriaComunicado> categorias) {
    final p = j['pilula'];
    return Comunicado(
      id: (j['id'] as num).toInt(),
      titulo: '${j['titulo'] ?? ''}',
      resumo: '${j['resumo'] ?? ''}',
      texto: '${j['texto'] ?? ''}',
      categoria: categorias['${j['categoria']}'] ?? CategoriaComunicado.reserva,
      origem: '${j['origem'] ?? ''}',
      pilula: p is Map && p['texto'] is String
          ? (icone: iconePorNome('${p['icone']}') ?? Icons.event_outlined, texto: p['texto'] as String)
          : null,
      inicio: DateTime.tryParse('${j['inicio']}'),
      urgente: j['urgente'] == true,
      destaqueAbertura: j['destaque_abertura'] == true,
      aberturaAteCiencia: j['abertura_ate_ciencia'] == true,
      ciencia: j['ciencia'] == true,
      cienciaPrazo: DateTime.tryParse('${j['ciencia_prazo']}'),
      versao: (j['versao'] as num?)?.toInt() ?? 1,
      lido: j['lido'] == true,
      ciente: j['ciente'] == true,
      icone: iconePorNome('${j['icone']}'),
    );
  }
}

/// Fala com `sigrh/comunicados.php`. Falha sai como [FalhaApp] com o prefixo
/// CM (CM-REDE, CM-NAO_ENCONTRADO...).
class ComunicadosRepositorio {
  ComunicadosRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/comunicados.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'CM';

  /// Última lista recebida, para a Início e a central mostrarem o mesmo.
  static final emUso = ValueNotifier<List<Comunicado>?>(null);

  Future<Map> _pedir(Map<String, String> campos) async {
    final j = await api.postJson(url, prefixo: prefixo, campos: {'matricula': matricula, 'senha': senhaMd5, ...campos});
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'comunicados.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    return j;
  }

  Future<List<Comunicado>> listar() async {
    final j = await _pedir({'acao': 'listar'});
    final categorias = {
      for (final c in (j['categorias'] as List? ?? const []))
        if (c is Map && CategoriaComunicado.deJson(c) != null) '${c['chave']}': CategoriaComunicado.deJson(c)!,
    };
    final lista = [
      for (final i in (j['itens'] as List? ?? const []))
        if (i is Map && i['id'] is num) Comunicado.deJson(i, categorias),
    ];
    emUso.value = lista;
    return lista;
  }

  Future<void> marcarLido(Comunicado c) async {
    if (c.lido) return;
    await _pedir({'acao': 'lido', 'id': '${c.id}', 'aparelho_id': await aparelhoIdApp()});
    _trocar(c.copiar(lido: true));
  }

  Future<void> darCiencia(Comunicado c) async {
    await _pedir({'acao': 'ciente', 'id': '${c.id}', 'aparelho_id': await aparelhoIdApp()});
    _trocar(c.copiar(lido: true, ciente: true));
  }

  static void _trocar(Comunicado novo) {
    final atual = emUso.value;
    if (atual == null) return;
    emUso.value = [for (final c in atual) c.id == novo.id ? novo : c];
  }
}
