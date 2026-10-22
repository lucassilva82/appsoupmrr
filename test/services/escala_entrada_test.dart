// Entrada automática na intranet (EscalaService.entrarSozinho): senha guardada
// no cofre primeiro, depois a do app; senha recusada não é tentada de novo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/services/escala_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CofreFalso extends CofreSenhaIntranet {
  ({String matricula, String senha})? guardada;
  int apagou = 0;

  @override
  Future<({String matricula, String senha})?> ler() async => guardada;

  @override
  Future<void> gravar(String matricula, String senha) async =>
      guardada = (matricula: matricula, senha: senha);

  @override
  Future<void> apagar() async {
    apagou++;
    guardada = null;
  }
}

/// Simula a intranet: aceita [senhaCerta]; [erro] força uma resposta.
class _ServicoFalso extends EscalaService {
  _ServicoFalso(this.cofreFalso, {this.senhaCerta, this.erro})
      : super(cofre: cofreFalso);

  final _CofreFalso cofreFalso;
  final String? senhaCerta;
  final Object? erro;
  final tentadas = <String>[];

  @override
  Future<EscalaLoginResult> login(String matricula, String senha,
      {String? codigo2fa}) async {
    tentadas.add(senha);
    if (erro != null) throw erro!;
    if (senha != senhaCerta) {
      throw const EscalaServiceException(
          'INVALID_CREDENTIALS', 'Matricula ou senha invalidos');
    }
    await cofreFalso.gravar(matricula, senha);
    return const EscalaLoginResult(precisaMigrarSenha: false);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('usa primeiro a senha da intranet guardada no cofre', () async {
    final cofre = _CofreFalso()
      ..guardada = (matricula: '1234567', senha: 'intranet');
    final s = _ServicoFalso(cofre, senhaCerta: 'intranet');
    final r = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r.tipo, EntradaIntranet.ok);
    expect(s.tentadas, ['intranet']);
  });

  test('senha do cofre recusada é apagada e tenta a do app', () async {
    final cofre = _CofreFalso()
      ..guardada = (matricula: '1234567', senha: 'velha');
    final s = _ServicoFalso(cofre, senhaCerta: 'app');
    final r = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r.tipo, EntradaIntranet.ok);
    expect(s.tentadas, ['velha', 'app']);
    expect(cofre.apagou, 1);
    expect(cofre.guardada?.senha, 'app');
  });

  test('senha do cofre de outra matrícula não é usada', () async {
    final cofre = _CofreFalso()
      ..guardada = (matricula: '111111', senha: 'outro');
    final s = _ServicoFalso(cofre, senhaCerta: 'app');
    await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(s.tentadas, ['app']);
  });

  test('senha do app recusada pede a senha e não é tentada de novo', () async {
    final cofre = _CofreFalso();
    final s = _ServicoFalso(cofre, senhaCerta: 'intranet');
    final r1 = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r1.tipo, EntradaIntranet.precisaSenha);
    final r2 = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r2.tipo, EntradaIntranet.precisaSenha);
    expect(s.tentadas, ['app'], reason: 'não insiste na senha recusada');
  });

  test('verificação em duas etapas', () async {
    final s = _ServicoFalso(_CofreFalso(),
        erro: const EscalaServiceException('REQUIRES_2FA', '2FA'));
    final r = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r.tipo, EntradaIntranet.precisa2fa);
  });

  test('servidor fora não apaga senha nem marca recusa', () async {
    final cofre = _CofreFalso()
      ..guardada = (matricula: '1234567', senha: 'intranet');
    final s = _ServicoFalso(cofre,
        erro: const EscalaServiceException('API_HTML_RESPONSE', 'HTML'));
    final r = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r.tipo, EntradaIntranet.falhou);
    expect(cofre.apagou, 0);
  });

  test('sem rede devolve falhou', () async {
    final s = _ServicoFalso(_CofreFalso(),
        erro: const SocketException('sem rota'));
    final r = await s.entrarSozinho(matricula: '1234567', senhaApp: 'app');
    expect(r.tipo, EntradaIntranet.falhou);
  });

  test('sem nenhuma senha pede a senha sem chamar a intranet', () async {
    final s = _ServicoFalso(_CofreFalso());
    final r = await s.entrarSozinho(matricula: '1234567', senhaApp: null);
    expect(r.tipo, EntradaIntranet.precisaSenha);
    expect(s.tentadas, isEmpty);
  });
}
