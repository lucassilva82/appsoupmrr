class AuthException implements Exception {
  final String key;

  static const Map<String, String> errors = {
    'EMAIL_EXISTS': 'E-mail já cadastrado',
    'OPERATION_NOT_ALLOWED': 'Operação não permitida',
    'TOO_MANY_ATTEMPTS_TRY_LATER':
        'Acesso bloqueado, tente novamente mais tarde.',
    'EMAIL_NOT_FOUND': 'E-mail não encontrado',
    'INVALID_PASSWORD':
        'Senha não confere com a do SIGRH-PMRR, tente novamente',
    'USER_DISABLED': 'A conta do usuário foi desabilitada',
    'SQL': 'Matrícula inválida, erro ao contatar servidor SIGRH-PMRR'
  };

  AuthException(this.key);

  @override
  String toString() {
    return errors[key] ??
        'Ocorreu um erro no processo de autenticação, contate o suporte DTIPMRR';
  }
}
