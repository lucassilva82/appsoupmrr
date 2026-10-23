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
    if (url.host.startsWith('intranet.') && url.path.contains('/api/v1/')) {
      return _responderIntranet(url, req);
    }
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

/// Campos de texto de um corpo multipart (os anexos são ignorados: no modo
/// vitrine nada sai do aparelho).
Map<String, String> _camposMultipart(http.Request req) {
  final corpo = utf8.decode(req.bodyBytes, allowMalformed: true);
  return {
    // Campo com acento ganha cabeçalhos próprios (content-type) antes do valor.
    for (final m in RegExp(r'name="([a-z_]+)"\r\n(?:[^\r\n]+\r\n)*\r\n([\s\S]*?)\r\n--')
        .allMatches(corpo))
      m.group(1)!: m.group(2)!,
  };
}

// Sugestões e elogios do militar fictício, guardados só na memória.
final _feedbacks = <Map<String, Object>>[
  {
    'id': 1,
    'protocolo': 'FB-2026-00001',
    'tipo': 'funcao_nova',
    'texto': 'Seria bom ver as escalas do mês num calendário.',
    'situacao': 'em_analise',
    'aguarda_militar': true,
    'criado_em': '2026-10-20T09:12:00-04:00',
    'mensagens': <Map<String, Object>>[
      {'autor': 'equipe', 'texto': 'Boa ideia! O calendário seria do mês inteiro ou só da semana?',
       'criado_em': '2026-10-21T14:30:00-04:00', 'anexos': 0, 'lida': false},
    ],
  },
];

// Comunicados fictícios do modo vitrine (§4.2), com leitura em memória.
final _comLidos = <int>{};
final _comCientes = <int>{};

Object _comunicados(Map<String, String> c) {
  final id = int.tryParse(c['id'] ?? '');
  switch (c['acao']) {
    case 'lido':
      if (id != null) _comLidos.add(id);
      return {'code': 1};
    case 'ciente':
      if (id != null) {
        _comLidos.add(id);
        _comCientes.add(id);
      }
      return {'code': 1, 'ciente_em': DateTime.now().toIso8601String()};
  }
  final hoje = DateTime.now();
  Map<String, Object?> item(int id, String titulo, String resumo, String categoria, String origem,
          {bool urgente = false, bool ciencia = false, Map<String, String>? pilula}) =>
      {
        'id': id, 'titulo': titulo, 'resumo': resumo, 'categoria': categoria, 'origem': origem,
        'texto': '$resumo.\n\nTexto fictício do modo vitrine, para conferir o desenho da central de '
            'comunicados. Nenhum dado aqui é real.',
        'inicio': hoje.subtract(Duration(days: id)).toIso8601String(), 'urgente': urgente, 'ciencia': ciencia,
        'versao': 1, 'lido': _comLidos.contains(id), 'ciente': _comCientes.contains(id),
        if (pilula != null) 'pilula': pilula,
      };
  return {
    'code': 1,
    'categorias': [
      {'chave': 'operacao', 'nome': 'Operação', 'cor': '#1D4ED8', 'icone': 'local_police'},
      {'chave': 'saude', 'nome': 'Saúde', 'cor': '#0F766E', 'icone': 'health_and_safety'},
      {'chave': 'instrucao', 'nome': 'Instrução', 'cor': '#A15C07', 'icone': 'menu_book'},
    ],
    'itens': [
      item(1, 'Operação Eleições 2026', 'Escala especial para o 2º turno em todo o estado', 'operacao',
          'Comando-Geral', urgente: true, ciencia: true, pilula: {'icone': 'calendar_month', 'texto': 'Até 30/10'}),
      item(2, 'Outubro Rosa', 'Exames preventivos na Diretoria de Saúde', 'saude', 'Diretoria de Saúde'),
      item(3, 'Instrução de tiro', 'Novas turmas abertas para novembro', 'instrucao', 'Diretoria de Ensino'),
    ],
  };
}

Object _feedback(Map<String, String> c) {
  Map<String, Object> resumo(Map<String, Object> f) => {
        'id': f['id']!, 'protocolo': f['protocolo']!, 'tipo': f['tipo']!,
        'trecho': f['texto']!, 'situacao': f['situacao']!, 'criado_em': f['criado_em']!,
        'respostas_novas': (f['mensagens']! as List)
            .where((m) => (m as Map)['autor'] == 'equipe' && m['lida'] == false).length,
      };
  switch (c['acao']) {
    case 'enviar':
      final id = _feedbacks.length + 1;
      final protocolo = 'FB-2026-${id.toString().padLeft(5, '0')}';
      _feedbacks.insert(0, {
        'id': id, 'protocolo': protocolo, 'tipo': c['tipo'] ?? 'melhoria', 'texto': c['texto'] ?? '',
        'situacao': 'recebido', 'aguarda_militar': false,
        'criado_em': DateTime.now().toIso8601String(), 'mensagens': <Map<String, Object>>[],
      });
      return {'code': 1, 'id': id, 'protocolo': protocolo};
    case 'listar':
      return {'code': 1, 'itens': [for (final f in _feedbacks) resumo(f)]};
    case 'ver' || 'responder':
      final f = _feedbacks.where((f) => '${f['id']}' == c['id']).firstOrNull;
      if (f == null) {
        return {'code': 0, 'erro': 'NAO_ENCONTRADO', 'message': 'Não achamos essa mensagem na sua conta.'};
      }
      final msgs = f['mensagens']! as List<Map<String, Object>>;
      if (c['acao'] == 'responder') {
        msgs.add({'autor': 'militar', 'texto': c['texto'] ?? '', 'criado_em': DateTime.now().toIso8601String(),
                  'anexos': 0, 'lida': true});
        f['aguarda_militar'] = false;
        return {'code': 1};
      }
      for (final m in msgs) {
        m['lida'] = true;
      }
      return {
        'code': 1,
        'feedback': {...resumo(f), 'texto': f['texto']!, 'aguarda_militar': f['aguarda_militar']!, 'anexos': 0},
        'mensagens': [for (final m in msgs) {...m}..remove('lida')],
      };
  }
  return {'code': 0, 'erro': 'DADOS_INVALIDOS', 'message': 'Ação inválida.'};
}

http.Response _json(Object corpo) => http.Response.bytes(
      utf8.encode(jsonEncode(corpo)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Object? _responder(Uri url, http.Request req) {
  final arquivo = url.pathSegments.last;
  switch (arquivo) {
    // O log do modo vitrine não vai a lugar nenhum: o militar é fictício.
    case 'log.php':
      return {'code': 1, 'aceitos': 0, 'recusados': 0};
    case 'feedback.php':
      return _feedback(_camposMultipart(req));
    case 'comunicados.php':
      return _comunicados(req.bodyFields);
    // Como em produção até a comparação ser aprovada: o PDF sai do aparelho.
    case 'contracheque_pdf.php':
      return {'code': 0, 'erro': 'DESLIGADO', 'message': 'PDF pela API ainda desligado.'};
    // Sem menu: o app usa o menu do código, como na loja (fase 1 da 2.2).
    case 'app_config.php':
      return {
        'code': 1,
        'versao_config': 1,
        'sessao': 'ok',
        'versao': {
          'android': {'minima': '2.1.5', 'recomendada': '2.1.5'},
          'ios': {'minima': '2.1.5', 'recomendada': '2.1.5'},
        },
        'rede': {'timeout_s': 15},
        'comunicados': {'fonte': 'api'},
        // Sem `menu`: vale o de reserva do app, igual à carga do banco.
        'servicos': {
          'mais_usados': ['rh.contracheques', 'rh.certidoes', 'rh.ferias', 'normas.legislacoes'],
        },
      };
    case 'login.php':
      return {
        'code': 1,
        'email': 'stives.silva@exemplo.com.br',
        'email_confirmado': true,
      };
    case 'buscapormatricula.php':
      return {
        'result': [_militar]
      };
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
    case 'primeiro_acesso.php':
      return _primeiroAcesso(req.bodyFields['acao']);
    case 'recuperar_senha.php':
      // Qualquer código de 6 dígitos serve: nenhum e-mail é enviado.
      return switch (req.bodyFields['acao']) {
        'solicitar' => {'code': 1, 'email': _emailMascarado},
        'validar' || 'redefinir' => {'code': 1},
        _ => null,
      };
  }
  return null;
}

// ── Primeiro acesso e recuperação de senha (vídeo tutorial) ─────────────────
// Mesmo formato das respostas do primeiro_acesso.php e do recuperar_senha.php.
// Na primeira vez o militar não tem e-mail e cadastra um; depois disso, um
// novo Primeiro acesso já pula direto para a senha, como no servidor.

const _emailMascarado = 's**********a@exemplo.com.br';
var _temEmail = false;

Object? _primeiroAcesso(String? acao) => switch (acao) {
      'iniciar' => {
          'code': 1,
          'sessao': 'vitrine',
          'perguntas': _perguntas,
        },
      'trocar_pergunta' => {
          'code': 1,
          'pergunta': {
            'id': 'nascimento',
            'pergunta': 'Qual é a sua data de nascimento?',
            'opcoes': ['02/08/1994', '17/01/1990', '25/11/1996', '09/05/1992'],
          },
        },
      'responder' => {
          'code': 1,
          'tem_email': _temEmail,
          'email': _temEmail ? _emailMascarado : '',
        },
      'enviar_codigo_email' => {'code': 1, 'email': _emailMascarado},
      'validar_codigo_email' => () {
          _temEmail = true;
          return {'code': 1};
        }(),
      'definir_senha' => {
          'code': 1,
          'matricula': vitrineMatricula,
          'matriculas': {'segad_nova': '1234567-8-01', 'segad_antiga': ''},
          'email_enviado': _temEmail,
        },
      _ => null,
    };

const _perguntas = [
  {
    'id': 'nome',
    'pergunta': 'Qual é o seu nome?',
    'opcoes': [
      'MARCOS OLIVEIRA',
      'STIVES SILVA',
      'RAFAEL COSTA',
      'JOÃO PEREIRA'
    ],
  },
  {
    'id': 'matricula',
    'pergunta': 'Qual é a sua matrícula PMRR?',
    'ajuda': 'É o antigo cadastro PM, o mesmo número que você usa para '
        'entrar no aplicativo.',
    'opcoes': ['1198432', '1305577', vitrineMatricula, '1089213'],
  },
  {
    'id': 'nome_mae',
    'pergunta': 'Qual é o nome da sua mãe?',
    'opcoes': ['ANA SOUZA', 'MARIA DA SILVA', 'JOANA LIMA', 'RITA ALVES'],
  },
  {
    'id': 'incorporacao',
    'pergunta': 'Qual é a sua data de incorporação?',
    'ajuda': 'A data em que você entrou na corporação.',
    'opcoes': ['04/02/2015', '20/07/2021', '11/03/2019', '30/09/2017'],
  },
];

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
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
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
      'titulo': 'Certidão Administrativa de Tempo de Serviço Militar Estadual',
      'titulo_curto': 'Tempo de Serviço',
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
      'titulo_curto': 'Vínculo Funcional',
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
      'titulo_curto': 'Comportamento',
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
  Map<String, String> c(
      String tipo, String titulo, String curto, String codigo, int dias) {
    final gerada = hoje.subtract(Duration(days: dias));
    return {
      'tipo': tipo,
      'titulo': titulo,
      'titulo_curto': curto,
      'codigo': codigo,
      'gerado_em': gerada.toIso8601String(),
      'valido_ate': gerada.add(const Duration(days: 30)).toIso8601String(),
      'url_verificacao': '',
      'nome_arquivo': '$codigo.pdf',
      'email_mascarado': 's***s@exemplo.com.br',
    };
  }

  return [
    c(
        'tempo_servico',
        'Certidão Administrativa de Tempo de Serviço Militar Estadual',
        'Tempo de Serviço',
        'CTS-7K2M9Q',
        0),
    c('vinculo_funcional', 'Certidão de Vínculo Funcional', 'Vínculo Funcional',
        'CVF-3H8T4P', 6),
  ];
}

// ── API da intranet (SIGE): escalas, permuta e avisos ───────────────────────
//
// Os avisos 9001 a 9010 seguem o roteiro da parte 7 do documento do SIGE, com
// as respostas de exemplo da parte 4 (nomes fictícios). O 9011 simula o
// endereço sem a API (página HTML de 404, como em produção hoje).

bool _vitrineCiencia346 = false;

http.Response _intranetJson(Object corpo, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(corpo)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _ok(Object data) =>
    _intranetJson({'success': true, 'data': data});

http.Response _naoAchado() => _intranetJson({
      'success': false,
      'error': {'code': 'NOT_FOUND', 'message': 'Nao encontrado'}
    }, 404);

Map<String, Object?> _escala346() => {
      'escala_id': 346,
      'escala_status': 'PUBLICADA',
      'data_escala': '22/10/2026',
      'data_escala_iso': '2026-10-22',
      'tipo_servico': 'Evento / Operação / Missão',
      'guarnicao_nome': 'RP 002',
      'horario_ini': '07:00',
      'horario_fim': '19:00',
      'funcao_nome': 'Motorista',
      'horas': '12',
      'local_assuncao': 'Quartel do Comando-Geral',
      'uniforme': 'Uniforme 4º A',
      'tem_ciencia': _vitrineCiencia346,
      'ciencia_em_br': _vitrineCiencia346 ? '21/10/2026 09:41' : null,
      'tem_impossibilidade': false,
      'situacao_militar': 'ESCALADO',
      'somente_leitura': false,
      'composicao': [],
    };

const _escala338 = {
  'escala_id': 338,
  'escala_status': 'CANCELADA',
  'data_escala': '28/12/2026',
  'data_escala_iso': '2026-12-28',
  'tipo_servico': 'Escala de Serviço',
  'guarnicao_nome': null,
  'horario_ini': '07:00',
  'horario_fim': '19:00',
  'funcao_nome': '',
  'uniforme': 'Uniforme 4º A',
  'tem_ciencia': false,
  'tem_impossibilidade': false,
  'situacao_militar': 'ESCALA_CANCELADA',
  'somente_leitura': true,
  'mensagem': 'Esta escala foi cancelada. Você NÃO precisa comparecer.',
};

const _escala347 = {
  'escala_id': 347,
  'escala_status': 'PUBLICADA',
  'data_escala': '25/10/2026',
  'data_escala_iso': '2026-10-25',
  'tipo_servico': 'Escala de Serviço',
  'horario_ini': '19:00',
  'horario_fim': '07:00',
  'funcao_nome': '',
  'tem_ciencia': false,
  'tem_impossibilidade': false,
  'situacao_militar': 'REMOVIDO',
  'somente_leitura': true,
  'mensagem':
      'Você foi removido desta escala. Em caso de dúvida, fale com o escalante.',
};

/// id → (tipo_evento, título, corpo, destino)
final Map<int, List<Object?>> _avisosSige = {
  9001: [
    'publicada',
    'Escalado em 22/10 — Evento',
    'Você foi escalado para 22/10/2026, das 07:00 às 19:00, na guarnição RP 002 (Motorista). Dê ciência no app.',
    {
      'tela': 'escala',
      'id': 346,
      'acoes': ['ciencia', 'impossibilidade'],
      'somente_leitura': false,
      'escala_id': 346,
      'situacao_militar': 'ESCALADO'
    }
  ],
  9002: [
    'aprovada',
    'Escalado em 22/10 e escala aprovada',
    'Você foi escalado para 22/10/2026 e a escala foi aprovada pelo comandante.',
    {
      'tela': 'escala',
      'id': 346,
      'acoes': ['ciencia'],
      'somente_leitura': false,
      'escala_id': 346,
      'situacao_militar': 'ESCALADO'
    }
  ],
  9003: [
    'ciencia_lembrete',
    'Ciência pendente — escala de amanhã',
    'Você ainda não deu ciência da escala de 22/10/2026. O serviço começa às 07:00.',
    {
      'tela': 'escala',
      'id': 346,
      'acoes': ['ciencia'],
      'somente_leitura': false,
      'escala_id': 346,
      'situacao_militar': 'ESCALADO'
    }
  ],
  9004: [
    'permuta_solicitada',
    'Permuta solicitada — 22/10',
    'SD QPCPM FICTÍCIO pediu que você o substitua no dia 22/10. Procure o escalante para confirmar.',
    {
      'tela': 'permuta',
      'id': 10,
      'acoes': [],
      'somente_leitura': true,
      'escala_id': 346
    }
  ],
  9005: [
    'cancelada',
    'Escala CANCELADA — 28/12',
    'A escala de 28/12/2026 foi cancelada. Você não precisa comparecer.',
    {
      'tela': 'escala',
      'id': 338,
      'acoes': [],
      'somente_leitura': true,
      'escala_id': 338,
      'situacao_militar': 'ESCALA_CANCELADA'
    }
  ],
  9006: [
    'removido',
    'Você foi removido — 25/10',
    'Você foi retirado da escala de 25/10/2026. Em caso de dúvida, fale com o escalante.',
    {
      'tela': 'escala',
      'id': 347,
      'acoes': [],
      'somente_leitura': true,
      'escala_id': 347,
      'situacao_militar': 'REMOVIDO'
    }
  ],
  9007: [
    'svi_voluntarios_80',
    'Últimas 2 vagas — SVI 30/10',
    'A escala SVI de 30/10/2026 está quase completa: restam 2 vagas para voluntários.',
    {
      'tela': 'svi_vagas',
      'id': 501,
      'acoes': ['ver_vagas'],
      'somente_leitura': true,
      'escala_id': 501
    }
  ],
  9008: [
    'svi_suspensao',
    'SVI suspenso',
    'Seu SVI está suspenso até 21/11/2026 (falta em 20/10).',
    {
      'tela': 'svi_adesao',
      'id': null,
      'acoes': ['ver_adesao'],
      'somente_leitura': true
    }
  ],
  9009: [
    'teste',
    'Push de teste',
    'Este é um aviso de teste enviado pelo painel do SIGE.',
    {'tela': 'aviso', 'id': null, 'acoes': [], 'somente_leitura': true}
  ],
  9010: [
    'tipo_inventado',
    'Aviso de um tipo novo',
    'O SIGE criou um tipo de aviso que esta versão do app não conhece. O texto aparece inteiro, sem erro.',
    {
      'tela': 'tela_nova',
      'id': 5,
      'acoes': [],
      'somente_leitura': true,
      'assunto': {'modulo': 'escala_periodo', 'id': 5}
    }
  ],
  9011: [
    'publicada',
    'Escalado em 22/10 (endereço sem API)',
    'Este aviso simula o app apontando para um endereço onde a API da intranet não existe.',
    null
  ],
};

http.Response _responderIntranet(Uri url, http.Request req) {
  final caminho = url.path.split('/api/v1/').last;
  final post = req.method == 'POST';
  final expira =
      DateTime.now().add(const Duration(hours: 12)).toIso8601String();
  debugPrint('[VITRINE] intranet ${req.method} $caminho');

  if (caminho == 'auth/login' || caminho == 'auth/refresh') {
    return _ok({'token': 'vitrine', 'expires_at': expira});
  }
  final aviso =
      RegExp(r'^dispositivo/notificacoes/(\d+)(/lida)?$').firstMatch(caminho);
  if (aviso != null) {
    final id = int.parse(aviso.group(1)!);
    final a = _avisosSige[id];
    if (a == null) return _naoAchado();
    if (id == 9011) {
      return http.Response(
          '<!DOCTYPE html><html><head><title>404 Not Found'
          '</title></head><body>Not Found</body></html>',
          404,
          headers: {'content-type': 'text/html'});
    }
    if (post) return _ok({'ok': true, 'ja_lida': false});
    return _ok({
      'id': id,
      'tipo_evento': a[0],
      'titulo': a[1],
      'corpo': a[2],
      'destino': a[3],
      'criado_em_br': '21/10/2026 09:30',
      'lida': false,
    });
  }
  if (caminho == 'escala/permuta/10') {
    return _ok({
      'permuta_id': 10,
      'escala_id': 346,
      'tipo': 'SUBSTITUICAO',
      'situacao': 'PENDENTE',
      'situacao_texto': 'Aguardando decisão do escalante',
      'meu_papel': 'substituto',
      'data_servico': '22/10/2026',
      'tipo_servico': 'Evento / Operação / Missão',
      'guarnicao': 'RP 002',
      'turno': {'horario_ini': '07:00', 'horario_fim': '19:00'},
      'solicitante': 'SD QPCPM FICTÍCIO',
      'titular': 'SD QPCPM FICTÍCIO',
      'ja_na_escala': false,
      'somente_leitura': true,
      'mensagem':
          'A decisão é do escalante. Procure o escalante para confirmar a substituição.',
    });
  }
  if (caminho == 'escala/346/ciencia' && post) {
    _vitrineCiencia346 = true;
    return _ok({'ok': true});
  }
  switch (caminho) {
    case 'escala/346':
      return _ok(_escala346());
    case 'escala/338':
      return _ok(_escala338);
    case 'escala/347':
      return _ok(_escala347);
    case 'escala/minhas-escalas':
      return _ok({
        'escalas': [_escala346()]
      });
    case 'escala/proxima':
      return _ok({'proxima': _escala346()});
    case 'svi/adesao':
      return _ok({'status': 'suspensa', 'ativa': false, 'horas_mes': 0});
    case 'svi/escalas-disponiveis':
      return _ok({'tem_adesao': true, 'escalas': []});
  }
  return _intranetJson({'erro': 'Endpoint nao encontrado'}, 404);
}

/// Avisos do SIGE na lista, como a Cloud Function grava no Firestore.
List<NotificationModel> _avisosSigeNaLista(DateTime agora) => [
      for (final e in _avisosSige.entries)
        NotificationModel(
          id: 'sige${e.key}',
          title: e.value[1]! as String,
          body: e.value[2]! as String,
          timestamp: agora.subtract(Duration(minutes: 9020 - e.key)),
          clicked: false,
          route: '/escalas',
          tipoEvento: e.value[0]! as String,
          referenciaId: '346',
          notificacaoId: '${e.key}',
        ),
    ];

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
    n(
        'v4',
        'Plano de férias publicado',
        'Seu plano de férias de 2026 já está no app. A 2ª parcela começa em 21/12.',
        const Duration(days: 9)),
    n(
        'v3',
        'Contracheque disponível',
        'O contracheque de ${_mesesNome[(agora.month + 10) % 12].toLowerCase()} já pode ser consultado.',
        const Duration(days: 3)),
    n(
        'v2',
        'Certidão emitida',
        'Sua Certidão de Tempo de Serviço foi emitida e vale por 30 dias. Uma cópia em PDF foi enviada para o seu e-mail.',
        const Duration(hours: 2),
        lida: false),
    ..._avisosSigeNaLista(agora),
  ];
}
