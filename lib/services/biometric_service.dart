import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

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

  /// Realiza a autenticação biométrica.
  Future<bool> authenticateUser() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Por favor, autentique-se para continuar.',
        options: const AuthenticationOptions(
          biometricOnly: true, // Apenas biometria, sem PIN/padrão
        ),
      );
      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }
}
