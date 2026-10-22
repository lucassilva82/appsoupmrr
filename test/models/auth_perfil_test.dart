// A abertura automática do app usava só a cópia dos dados do militar guardada
// no aparelho: o nome de guerra trocado no SIGRH (CB FELICIANO → CB F. JÚNIOR,
// 21/10/2026) só aparecia depois de sair e entrar de novo. Estes testes travam
// a atualização em segundo plano a cada abertura.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/sessao/sessao.dart';
import 'package:projetonovo/data/store.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:projetonovo/models/endereco.dart';
import 'package:projetonovo/models/ficha_funcional.dart';
import 'package:projetonovo/models/militar.dart';
import 'package:projetonovo/services/dados_sql.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../apoio/cofre_memoria.dart';

class _SigrhFalso extends DadosSql {
  _SigrhFalso(this.resposta);
  final FutureOr<Militar?> Function() resposta;
  int chamadas = 0;

  @override
  Future<Militar?> buscarMilitarBancoByMatricula(String matricula) async {
    chamadas++;
    return resposta();
  }
}

Militar _militar(
        {String qra = 'F. JÚNIOR',
        String posto = 'CB',
        String idPosto = '12'}) =>
    Militar(
      matricula: '000001',
      matRhNova: '000001',
      postoGraduacao: posto,
      qra: qra,
      grupo: 'USUARIO',
      nivel: '10',
      idPosto: idPosto,
      cpf: '12345678909',
      nomeCompleto: 'FULANO FICTICIO DA SILVA',
      imageUrl: 'https://exemplo.invalid/foto.jpg',
      subUnidade: '1ª CIA',
      endereco: Endereco(null, null, null, null, null),
      dataIncorporacao: '2015-01-01',
      quadro: 'QPPM',
      fichaFuncional: FichaFuncional(),
    );

Future<Auth> _sessaoGuardada(DadosSql sigrh) async {
  SharedPreferences.setMockInitialValues({});
  await Store.saveMap('userData', {
    'matricula': '000001',
    'password': 'x',
    'nome': 'CB FELICIANO',
    'nomeCompleto': 'FULANO FICTICIO DA SILVA',
    'cpf': '12345678909',
    'dataIncorporacao': '2015-01-01',
    'image': 'https://exemplo.invalid/foto.jpg',
    'autorizado': 'true',
    'expireDate':
        DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
    'nivel': '10',
    'idPosto': '12',
  });
  final auth = Auth(dadosSql: sigrh);
  await auth.tryAutoLogin();
  return auth;
}

void main() {
  setUp(() => Sessao.instancia = Sessao(cofre: CofreMemoria()));

  TestWidgetsFlutterBinding.ensureInitialized();

  test('nome de guerra trocado no SIGRH aparece sem sair da conta', () async {
    final sigrh = _SigrhFalso(() => _militar());
    final auth = await _sessaoGuardada(sigrh);
    expect(
        auth.nomeMilitar, 'CB FELICIANO'); // abre na hora com a cópia guardada

    await auth.atualizarPerfilEmSegundoPlano();

    expect(sigrh.chamadas, 1);
    expect(auth.nomeMilitar, 'CB F. JÚNIOR');
    final guardado = await Store.getMap('userData');
    expect(guardado['nome'], 'CB F. JÚNIOR'); // vale também na próxima abertura
  });

  test('promoção atualiza posto e regra de acesso', () async {
    final sigrh = _SigrhFalso(
        () => _militar(posto: '3º SGT', idPosto: '7', qra: 'FELICIANO'));
    final auth = await _sessaoGuardada(sigrh);
    await auth.atualizarPerfilEmSegundoPlano();
    expect(auth.nomeMilitar, '3º SGT FELICIANO');
    expect(auth.idPosto, 7);
  });

  test('sem internet mantém a cópia guardada e não derruba nada', () async {
    final sigrh = _SigrhFalso(() => throw const SocketException('sem rede'));
    final auth = await _sessaoGuardada(sigrh);
    await auth.atualizarPerfilEmSegundoPlano();
    expect(auth.nomeMilitar, 'CB FELICIANO');
    expect(auth.autorizado, isTrue);
  });

  test('SIGRH sem dados não apaga o que já estava guardado', () async {
    final sigrh = _SigrhFalso(() => null);
    final auth = await _sessaoGuardada(sigrh);
    await auth.atualizarPerfilEmSegundoPlano();
    expect(auth.nomeMilitar, 'CB FELICIANO');
  });

  test('sem sessão não consulta o SIGRH', () async {
    SharedPreferences.setMockInitialValues({});
    final sigrh = _SigrhFalso(() => _militar());
    final auth = Auth(dadosSql: sigrh);
    await auth.tryAutoLogin();
    await auth.atualizarPerfilEmSegundoPlano();
    expect(sigrh.chamadas, 0);
  });
}
