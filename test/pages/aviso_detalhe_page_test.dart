// Tela do aviso do SIGE: o texto aparece sempre, o assunto carrega à parte e
// tipo desconhecido nunca vira erro (roteiro da parte 7 do documento do SIGE,
// com dados fictícios).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/models/aviso_model.dart';
import 'package:projetonovo/models/escala_model.dart';
import 'package:projetonovo/models/svi_model.dart';
import 'package:projetonovo/pages/aviso_detalhe_page.dart';
import 'package:projetonovo/services/escala_service.dart';

class _ServicoFalso extends EscalaService {
  Map<String, dynamic>? aviso;
  Object? falhaAviso;
  Object? falhaAssunto;
  Map<String, dynamic>? escala;
  Map<String, dynamic>? permuta;
  final lidos = <int>[];
  final ciencias = <int>[];
  final pedidos = <String>[];

  // Entrada na intranet
  ResultadoEntrada entrada = const ResultadoEntrada(EntradaIntranet.ok);
  String? senhaCerta;
  int entradasAuto = 0;
  final senhasDigitadas = <String>[];

  @override
  Future<ResultadoEntrada> entrarSozinho(
      {required String matricula, String? senhaApp}) async {
    entradasAuto++;
    if (entrada.tipo == EntradaIntranet.ok) falhaAviso = null;
    return entrada;
  }

  @override
  Future<EscalaLoginResult> login(String matricula, String senha,
      {String? codigo2fa}) async {
    senhasDigitadas.add(senha);
    if (senha != senhaCerta) {
      throw const EscalaServiceException('INVALID_CREDENTIALS', 'invalida');
    }
    falhaAviso = null;
    return const EscalaLoginResult(precisaMigrarSenha: false);
  }

  @override
  Future<AvisoDetalhe> getAviso(int notificacaoId) async {
    pedidos.add('aviso/$notificacaoId');
    if (falhaAviso != null) throw falhaAviso!;
    return AvisoDetalhe.fromJson(aviso!);
  }

  @override
  Future<void> marcarAvisoLido(int notificacaoId) async =>
      lidos.add(notificacaoId);

  @override
  Future<EscalaModel> getEscalaDetalhe(int id) async {
    pedidos.add('escala/$id');
    if (falhaAssunto != null) throw falhaAssunto!;
    return EscalaModel.fromJson(escala!);
  }

  @override
  Future<PermutaModel> getPermuta(int permutaId) async {
    pedidos.add('permuta/$permutaId');
    return PermutaModel.fromJson(permuta!);
  }

  @override
  Future<SviAdesaoModel?> getSviAdesao() async {
    pedidos.add('svi/adesao');
    return SviAdesaoModel.fromJson({'status': 'suspensa', 'ativa': false});
  }

  @override
  Future<Map<String, dynamic>> registrarCiencia(int id) async {
    ciencias.add(id);
    escala = {...escala!, 'tem_ciencia': true, 'ciencia_em_br': '20/10 21:30'};
    return {};
  }
}

Map<String, dynamic> _aviso(String tipo, Map<String, dynamic> destino) => {
      'id': 1158,
      'titulo': 'Aviso completo do servidor',
      'corpo': 'Corpo completo, sem corte, vindo do servidor.',
      'tipo_evento': tipo,
      'criado_em_br': '20/10/2026 21:28',
      'lida': false,
      'destino': destino,
    };

const _escalaPublicada = {
  'escala_id': 346,
  'escala_status': 'PUBLICADA',
  'data_escala': '20/10/2026',
  'data_escala_iso': '2026-10-20',
  'tipo_servico': 'Evento / Operação / Missão',
  'guarnicao_nome': 'RP 002',
  'horario_ini': '07:00',
  'horario_fim': '19:00',
  'funcao_nome': 'Motorista',
  'tem_ciencia': false,
  'tem_impossibilidade': false,
  'situacao_militar': 'ESCALADO',
  'somente_leitura': false,
};

Future<void> _abrir(WidgetTester tester, _ServicoFalso s,
    {int? id = 1158, String? tipo, int? ref}) async {
  await tester.pumpWidget(MaterialApp(
    home: AvisoDetalhePage(
      service: s,
      matricula: '1234567',
      aviso: AvisoAberto(
        notificacaoId: id,
        titulo: 'Texto do push (cortado)',
        corpo: 'Texto local do aviso.',
        tipoEvento: tipo,
        referenciaId: ref,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('escala publicada: texto do servidor, bloco e Dar ciência',
      (tester) async {
    final s = _ServicoFalso()
      ..aviso = _aviso('publicada', {
        'tela': 'escala',
        'id': 346,
        'acoes': ['ciencia', 'impossibilidade'],
        'somente_leitura': false,
      })
      ..escala = Map.of(_escalaPublicada);
    await _abrir(tester, s, tipo: 'publicada');

    expect(find.text('Aviso completo do servidor'), findsOneWidget);
    expect(find.text('Corpo completo, sem corte, vindo do servidor.'),
        findsOneWidget);
    expect(find.text('RP 002'), findsOneWidget);
    expect(s.lidos, [1158]);

    await tester.tap(find.text('Dar ciência'));
    await tester.pumpAndSettle();
    expect(s.ciencias, [346]);
    expect(find.text('Dar ciência'), findsNothing);
    expect(find.text('Dada em 20/10 21:30'), findsOneWidget);
  });

  testWidgets('escala cancelada: somente leitura, sem botões', (tester) async {
    final s = _ServicoFalso()
      ..aviso = _aviso('cancelada', {
        'tela': 'escala',
        'id': 338,
        'acoes': [],
        'somente_leitura': true,
      })
      ..escala = {
        ..._escalaPublicada,
        'escala_id': 338,
        'escala_status': 'CANCELADA',
        'situacao_militar': 'ESCALA_CANCELADA',
        'somente_leitura': true,
        'mensagem': 'Esta escala foi cancelada. Você NÃO precisa comparecer.',
      };
    await _abrir(tester, s, tipo: 'cancelada');

    expect(find.text('Escala (somente leitura)'), findsOneWidget);
    expect(find.textContaining('NÃO precisa comparecer'), findsOneWidget);
    expect(find.text('Dar ciência'), findsNothing);
    expect(find.text('Ver escala completa'), findsNothing);
  });

  testWidgets('permuta: abre a permuta (E2), não a escala', (tester) async {
    final s = _ServicoFalso()
      ..aviso = _aviso('permuta_solicitada', {
        'tela': 'permuta',
        'id': 10,
        'acoes': [],
        'somente_leitura': true,
        'escala_id': 346,
      })
      ..permuta = {
        'permuta_id': 10,
        'escala_id': 346,
        'tipo': 'SUBSTITUICAO',
        'situacao': 'PENDENTE',
        'situacao_texto': 'Aguardando decisão do escalante',
        'data_servico': '20/10/2026',
        'solicitante': 'SD QPCPM FICTICIO',
        'ja_na_escala': false,
        'mensagem': 'A decisão é do escalante.',
      };
    await _abrir(tester, s, tipo: 'permuta_solicitada');

    expect(s.pedidos, ['aviso/1158', 'permuta/10']);
    expect(find.text('Substituição'), findsOneWidget);
    expect(find.text('Aguardando decisão do escalante'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('adesão SVI suspensa mostra a situação', (tester) async {
    final s = _ServicoFalso()
      ..aviso = _aviso('svi_suspensao',
          {'tela': 'svi_adesao', 'id': null, 'acoes': ['ver_adesao']});
    await _abrir(tester, s, tipo: 'svi_suspensao');
    expect(find.text('Sua adesão ao SVI'), findsOneWidget);
    expect(find.text('Suspensa'), findsOneWidget);
  });

  testWidgets('tela e tipo desconhecidos: só o texto, sem erro',
      (tester) async {
    final s = _ServicoFalso()
      ..aviso = _aviso('tipo_inventado', {
        'tela': 'tela_que_nao_existe',
        'id': 5,
        'assunto': {'modulo': 'escala_periodo', 'id': 5},
      });
    await _abrir(tester, s, tipo: 'tipo_inventado');
    expect(find.text('Aviso completo do servidor'), findsOneWidget);
    expect(find.textContaining('Não foi possível'), findsNothing);
    expect(s.pedidos, ['aviso/1158']);
  });

  testWidgets('sem rede: o texto local fica e o bloco explica com código',
      (tester) async {
    final s = _ServicoFalso()
      ..falhaAviso = const SocketException('sem rota');
    await _abrir(tester, s, tipo: 'publicada');
    expect(find.text('Texto do push (cortado)'), findsOneWidget);
    expect(find.text('Texto local do aviso.'), findsOneWidget);
    expect(find.text('Não foi possível carregar os detalhes'), findsOneWidget);
    expect(find.text('Código: AV-REDE'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('API sem /api/v1 (HTML 404): mensagem clara, não "retornou HTML"',
      (tester) async {
    final s = _ServicoFalso()
      ..falhaAviso = const EscalaServiceException('API_HTML_RESPONSE',
          'Servidor da intranet indisponível ou sem a API do app neste endereço (HTTP 404). (ES-SEM-API-404)');
    await _abrir(tester, s, tipo: 'publicada');
    expect(find.text('Código: AV-SEM-API'), findsOneWidget);
    expect(find.textContaining('HTML'), findsNothing);
  });

  testWidgets('sem sessão da intranet: entra sozinho e mostra os detalhes',
      (tester) async {
    final s = _ServicoFalso()
      ..falhaAviso =
          const EscalaServiceException('NOT_AUTHENTICATED', 'Login necessário')
      ..aviso = _aviso('publicada', {
        'tela': 'escala',
        'id': 346,
        'acoes': ['ciencia'],
        'somente_leitura': false,
      })
      ..escala = Map.of(_escalaPublicada);
    await _abrir(tester, s, tipo: 'publicada');
    expect(s.entradasAuto, 1);
    expect(find.text('RP 002'), findsOneWidget);
    expect(find.textContaining('Não foi possível'), findsNothing);
    expect(find.text('Senha da intranet'), findsNothing);
  });

  testWidgets('intranet recusa a senha do app: pede a senha uma vez',
      (tester) async {
    final s = _ServicoFalso()
      ..falhaAviso =
          const EscalaServiceException('NOT_AUTHENTICATED', 'Login necessário')
      ..entrada = const ResultadoEntrada(EntradaIntranet.precisaSenha)
      ..senhaCerta = 'certa'
      ..aviso = _aviso('cancelada', {
        'tela': 'escala',
        'id': 338,
        'acoes': [],
        'somente_leitura': true,
      })
      ..escala = {..._escalaPublicada, 'somente_leitura': true};
    await _abrir(tester, s, tipo: 'cancelada');

    expect(find.text('Texto local do aviso.'), findsOneWidget);
    expect(find.text('Senha da intranet'), findsOneWidget);
    expect(find.text('Matrícula 1234567'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'errada');
    await tester.tap(find.text('Entrar e ver os detalhes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AV-SENHA'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'certa');
    await tester.tap(find.text('Entrar e ver os detalhes'));
    await tester.pumpAndSettle();
    expect(s.senhasDigitadas, ['errada', 'certa']);
    expect(find.text('Senha da intranet'), findsNothing);
    expect(find.text('Escala (somente leitura)'), findsOneWidget);
  });

  testWidgets('intranet pede verificação em duas etapas', (tester) async {
    final s = _ServicoFalso()
      ..falhaAviso =
          const EscalaServiceException('UNAUTHORIZED', 'Sessão expirada')
      ..entrada = const ResultadoEntrada(EntradaIntranet.precisa2fa);
    await _abrir(tester, s, tipo: 'publicada');
    expect(find.text('Código: AV-2FA'), findsOneWidget);
    expect(find.text('Abrir Escalas de Serviço'), findsOneWidget);
  });

  testWidgets('push antigo sem notificacao_id abre a escala pelo tipo',
      (tester) async {
    final s = _ServicoFalso()..escala = Map.of(_escalaPublicada);
    await _abrir(tester, s, id: null, tipo: 'escalado', ref: 346);
    expect(s.pedidos, ['escala/346']);
    expect(find.text('Texto local do aviso.'), findsOneWidget);
    expect(find.text('RP 002'), findsOneWidget);
    expect(s.lidos, isEmpty);
  });

  test('AvisoAberto.doPush lê o data do FCM (tudo texto)', () {
    final a = AvisoAberto.doPush({
      'route': '/escalas',
      'titulo': 'Escala CANCELADA — 28/12',
      'mensagem': 'Texto inteiro',
      'tipo_evento': 'cancelada',
      'referencia_id': '338',
      'notificacao_id': '1159',
    });
    expect(a.notificacaoId, 1159);
    expect(a.referenciaId, 338);
    expect(a.tipoEvento, 'cancelada');
    expect(AvisoAberto.ehDoSige({'route': '/certidoes-page'}), isFalse);
    expect(AvisoAberto.ehDoSige({'notificacao_id': '1'}), isTrue);
  });
}
