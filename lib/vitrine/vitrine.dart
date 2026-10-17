// Modo vitrine: o app inteiro com um militar fictício, para as capturas de
// tela das lojas. Liga só na compilação:
//
//   flutter build ios --simulator --debug --dart-define=VITRINE=true
//
// Sem a flag, `modoVitrine` é uma constante falsa e nada daqui roda (o
// compilador nem leva os dados para o binário da loja).
//
// Tudo que vem do SIGRH é respondido aqui, em memória: nenhuma senha, matrícula
// ou CPF de verdade é usado e nada é gravado no servidor nem no Firestore.
// Matrícula e senha do login podem ser quaisquer valores.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';

import '../models/notification_model.dart';

const bool modoVitrine = bool.fromEnvironment('VITRINE');

/// Nome que aparece em todas as telas.
const vitrineNome = 'STIVES DA SILVA';
const vitrineMatricula = '1234567';

/// Endereços do SIGRH que podem ir ao servidor de verdade: só leitura de
/// dados públicos (comandantes da corporação).
const _liberados = ['/mapadaforca/listacomandos.php'];

/// Cliente HTTP do modo vitrine (ver `http.runWithClient` no main).
http.Client clienteVitrine() {
  final real = IOClient();
  return MockClient((req) async {
    final url = req.url;
    final ehSigrh = url.host.endsWith('pmrr.online') &&
        url.path.contains('/flutter/sigrh/');
    if (!ehSigrh || _liberados.any(url.path.endsWith)) {
      final resp = await real.send(http.Request(req.method, url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes);
      return http.Response.fromStream(resp);
    }

    final resposta = _responder(url, req);
    if (resposta == null) {
      debugPrint('[VITRINE] sem dado fictício: ${req.method} ${url.path}');
      return _json({'code': 0, 'message': 'Indisponível no modo vitrine.'});
    }
    return _json(resposta);
  });
}

http.Response _json(Object corpo) => http.Response.bytes(
      utf8.encode(jsonEncode(corpo)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Object? _responder(Uri url, http.Request req) {
  final arquivo = url.pathSegments.last;
  switch (arquivo) {
    case 'login.php':
      return {
        'code': 1,
        'email': 'stives.silva@exemplo.com.br',
        'email_confirmado': true,
      };
    case 'buscapormatricula.php':
      return {'result': [_militar]};
    case 'buscasituacaofuncional.php':
      return [];
    case 'listamesescontracheque_new.php':
      return _mesesContracheque(url.queryParameters['ano']);
    case 'listamesescontracheque.php':
      return [];
    case 'exibecontracheque_new.php':
      return _contracheque(url.queryParameters['mesExtenso'] ?? '');
    case 'listar_policial_iper.php':
      return {'code': 1, 'result': []};
    case 'buscaplanodeferias.php':
      return {'code': 1, 'result': _ferias};
    case 'autoemissao.php':
      return req.bodyFields['acao'] == 'painel' ? _painelCertidoes : null;
  }
  return null;
}

// ── Militar ─────────────────────────────────────────────────────────────────

const _militar = {
  'sigrh': vitrineMatricula,
  'incorporacao': '2019-03-11',
  'quadro': 'QPPM',
  'matricula': vitrineMatricula,
  'postograduacao': 'SD',
  'qra': 'STIVES',
  'grupo': 'PRAÇA',
  'nivel': '10',
  'id_posto': '13',
  'nomecompleto': vitrineNome,
  'imagemurl': 'https://rh.pmrr.online/_lib/file/img//wc2/pix_db/',
  'cpf': '00000000000',
  'subu_descricao': '1º BPM',
  'muni_nome': 'Boa Vista',
  'muni_cod': '0',
  'bair_cod': '0',
  'bair_nome': '',
  'rua_cod': '0',
  'concat': '',
  'numero': '',
  'cep': '',
  'telefone': null,
};

// ── Contracheque ────────────────────────────────────────────────────────────

const _mesesNome = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho',
  'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// Folhas até o mês passado do ano pedido.
List<Map<String, String>> _mesesContracheque(String? ano) {
  final hoje = DateTime.now();
  final a = int.tryParse(ano ?? '') ?? hoje.year;
  final ultimo = a < hoje.year ? 12 : hoje.month - 1;
  return [
    for (var m = ultimo; m >= 1; m--)
      {
        'mes': '$m',
        'mes_extenso': _mesesNome[m - 1],
        'relacaotrabalho': 'MILITAR',
        'folha': 'FOLHA NORMAL',
        'cpf': '00000000000',
        'matricula': '$vitrineMatricula-0-01',
      },
  ];
}

Map<String, Object> _contracheque(String mesExtenso) {
  Map<String, String> rubrica(String tipo, String nome, String valor) => {
        'matricula': '$vitrineMatricula-0-01',
        'matriculalegado': '',
        'mes_extenso': mesExtenso,
        'unidade_organizacional': 'MILITAR',
        'folha': 'FOLHA NORMAL',
        'tiporubrica': tipo,
        'descricaorubrica': nome,
        'provento': tipo == 'P' ? valor : '0,00',
        'desconto': tipo == 'D' ? valor : '0,00',
        'parcelas': '',
      };
  return {
    'code': 1,
    'data': [
      rubrica('P', 'SUBSIDIO EFETIVO', '5.486,42'),
      rubrica('P', 'AUX ALIMENTACAO', '500,00'),
      rubrica('P', 'INDENIZACAO RISCO DE VIDA', '1.500,00'),
      rubrica('D', 'IRRF', '742,18'),
      rubrica('D', 'IPER - PREVIDENCIA', '767,20'),
    ],
  };
}

// ── Plano de férias ─────────────────────────────────────────────────────────

const _ferias = [
  {
    'nome': vitrineNome,
    'prev_feri_antecipado': 'A',
    'ano_base_nome': '2026',
    'frac_int': '0',
    '1p_inicio': '2026-07-06',
    '1p_fim': '2026-07-20',
    '2p_inicio': '2026-12-21',
    '2p_fim': '2027-01-04',
  },
  {
    'nome': vitrineNome,
    'prev_feri_antecipado': 'A',
    'ano_base_nome': '2025',
    'frac_int': '1',
    'prev_feri_inicio': '2025-08-04',
    'prev_feri_final': '2025-09-02',
  },
];

// ── Certidões ───────────────────────────────────────────────────────────────

const _etapasFinais = ['Assinatura digital', 'Cópia por e-mail'];

const _painelCertidoes = {
  'code': 1,
  'tipos': [
    {
      'tipo': 'tempo_servico',
      'titulo': 'Certidão de Tempo de Serviço',
      'descricao':
          'Tempo de efetivo serviço na PMRR, ano a ano, e tempo averbado.',
      'icone': 'tempo',
      'disponivel': true,
      'situacao': 'disponivel',
      'etapas': ['Tempo de serviço', ..._etapasFinais],
    },
    {
      'tipo': 'vinculo_funcional',
      'titulo': 'Certidão de Vínculo Funcional',
      'descricao': 'Comprova que você é policial militar, com posto, quadro '
          'e data de inclusão.',
      'icone': 'escudo',
      'disponivel': true,
      'situacao': 'disponivel',
      'etapas': ['Dados funcionais', ..._etapasFinais],
    },
    {
      'tipo': 'comportamento',
      'titulo': 'Certidão de Comportamento',
      'descricao': 'Seu comportamento atual, o histórico de classificação e '
          'as punições registradas.',
      'icone': 'medalha',
      'disponivel': true,
      'situacao': 'disponivel',
      'etapas': ['Comportamento', ..._etapasFinais],
    },
  ],
  'declaracao': {
    'versao': 1,
    'texto': 'Declaro que as informações serão usadas para fins legais.',
  },
  'validade_dias': 30,
  'servico': {'ativo': true},
  'textos': {},
  'historico': [],
};

/// Certidões já emitidas que aparecem em "Minhas certidões".
List<Map<String, String>> certidoesVitrine() {
  final hoje = DateTime.now();
  Map<String, String> c(String tipo, String titulo, String codigo, int dias) {
    final gerada = hoje.subtract(Duration(days: dias));
    return {
      'tipo': tipo,
      'titulo': titulo,
      'codigo': codigo,
      'gerado_em': gerada.toIso8601String(),
      'valido_ate': gerada.add(const Duration(days: 30)).toIso8601String(),
      'url_verificacao': '',
      'nome_arquivo': '$codigo.pdf',
      'email_mascarado': 's***s@exemplo.com.br',
    };
  }

  return [
    c('tempo_servico', 'Certidão de Tempo de Serviço', 'CTS-7K2M9Q', 0),
    c('vinculo_funcional', 'Certidão de Vínculo Funcional', 'CVF-3H8T4P', 6),
  ];
}

// ── Notificações ────────────────────────────────────────────────────────────

List<NotificationModel> notificacoesVitrine() {
  final agora = DateTime.now();
  NotificationModel n(String id, String titulo, String corpo, Duration ha,
          {bool lida = true}) =>
      NotificationModel(
        id: id,
        title: titulo,
        body: corpo,
        timestamp: agora.subtract(ha),
        clicked: lida,
      );

  // Mais antigas primeiro, como vem do Firestore.
  return [
    n('v4', 'Plano de férias publicado',
        'Seu plano de férias de 2026 já está no app. A 2ª parcela começa em 21/12.',
        const Duration(days: 9)),
    n('v3', 'Contracheque disponível',
        'O contracheque de ${_mesesNome[(agora.month + 10) % 12].toLowerCase()} já pode ser consultado.',
        const Duration(days: 3)),
    n('v2', 'Certidão emitida',
        'Sua Certidão de Tempo de Serviço foi emitida e vale por 30 dias. Uma cópia em PDF foi enviada para o seu e-mail.',
        const Duration(hours: 2),
        lida: false),
  ];
}
