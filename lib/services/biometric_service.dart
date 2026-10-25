import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as erros_bio;
import 'package:local_auth/local_auth.dart';

import '../core/erros/falha_app.dart';

/// Resultado de pedir a biometria: deu certo, a pessoa cancelou, ou falhou
/// com o motivo explicado (código `LG-BIO-...`, regra do CLAUDE.md).
class ResultadoBiometria {
  const ResultadoBiometria._(this.ok, this.falha);
  static const confirmada = ResultadoBiometria._(true, null);
  static const cancelada = ResultadoBiometria._(false, null);
  const ResultadoBiometria.falhou(FalhaApp f) : this._(false, f);

  final bool ok;
  final FalhaApp? falha;
}

class BiometricService {
  BiometricService([LocalAuthentication? localAuth]) : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  static String get nome => Platform.isIOS ? 'Face ID' : 'biometria';

  /// O nome com o artigo certo: "o Face ID", "a biometria".
  static String get comArtigo => Platform.isIOS ? 'o Face ID' : 'a biometria';

  /// Verifica se o dispositivo suporta e tem algum tipo de biometria configurada.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Retorna a lista de tipos de biometria disponíveis (face, digital etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics;
    } catch (e) {
      return <BiometricType>[];
    }
  }

  /// Pede a biometria e diz o que aconteceu. Antes, qualquer falha virava
  /// "false" em silêncio: sem Face ID cadastrado no aparelho, o interruptor
  /// do Perfil ligava assim mesmo e a próxima entrada caía no login sem
  /// explicar nada.
  Future<ResultadoBiometria> confirmar({String motivo = 'Confirme que é você para entrar no SouPMRR'}) async {
    try {
      if (!await _localAuth.isDeviceSupported()) return ResultadoBiometria.falhou(_semSuporte());
      final ok = await _localAuth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      return ok ? ResultadoBiometria.confirmada : ResultadoBiometria.cancelada;
    } on PlatformException catch (e) {
      return ResultadoBiometria.falhou(falhaDe(e));
    } catch (e) {
      return ResultadoBiometria.falhou(FalhaApp(
        codigo: 'LG-BIO-X-${e.runtimeType}'.toUpperCase(),
        origem: OrigemFalha.aparelho,
        titulo: 'Não foi possível usar o $nome',
        texto: 'Entre com a matrícula e a senha. Se continuar, abra um chamado técnico com o código.',
        detalhe: '$e',
      ));
    }
  }

  /// Mantido para quem só quer saber se confirmou.
  Future<bool> authenticateUser() async => (await confirmar()).ok;

  static FalhaApp _semSuporte() => FalhaApp(
        codigo: 'LG-BIO-INDISP',
        origem: OrigemFalha.aparelho,
        titulo: 'Este aparelho não tem $nome',
        texto: 'O aparelho não oferece reconhecimento por ${Platform.isIOS ? 'rosto' : 'digital ou rosto'}. '
            'Continue entrando com a matrícula e a senha.',
        acao: AcaoFalha.nenhuma,
      );

  static FalhaApp falhaDe(PlatformException e) => switch (e.code) {
        erros_bio.notEnrolled => FalhaApp(
            codigo: 'LG-BIO-SEMCADASTRO',
            origem: OrigemFalha.aparelho,
            titulo: '$nome não cadastrado no aparelho',
            texto: Platform.isIOS
                ? 'Cadastre seu rosto em Ajustes › Face ID e Código e tente de novo.'
                : 'Cadastre uma digital ou o rosto nas configurações de segurança do aparelho e tente de novo.',
            acao: AcaoFalha.nenhuma,
            detalhe: e.message,
          ),
        erros_bio.passcodeNotSet => FalhaApp(
            codigo: 'LG-BIO-SEMCODIGO',
            origem: OrigemFalha.aparelho,
            titulo: 'O aparelho está sem código de bloqueio',
            texto: 'O $nome só funciona com um código (ou senha) de bloqueio de tela. Crie um nas configurações do '
                'aparelho e tente de novo.',
            acao: AcaoFalha.nenhuma,
            detalhe: e.message,
          ),
        erros_bio.lockedOut || erros_bio.permanentlyLockedOut => FalhaApp(
            codigo: 'LG-BIO-BLOQ',
            origem: OrigemFalha.aparelho,
            titulo: '$nome bloqueado por tentativas',
            texto: 'O aparelho bloqueou o $nome depois de várias tentativas. Desbloqueie a tela com o código do '
                'aparelho e tente de novo, ou entre com a matrícula e a senha.',
            acao: AcaoFalha.nenhuma,
            detalhe: e.message,
          ),
        erros_bio.notAvailable || erros_bio.otherOperatingSystem || erros_bio.biometricOnlyNotSupported =>
          _semSuporte(),
        _ => FalhaApp(
            codigo: 'LG-BIO-${e.code}'.toUpperCase(),
            origem: OrigemFalha.aparelho,
            titulo: 'Não foi possível usar o $nome',
            texto: 'Entre com a matrícula e a senha. Se continuar, abra um chamado técnico com o código.',
            detalhe: e.message,
          ),
      };
}
