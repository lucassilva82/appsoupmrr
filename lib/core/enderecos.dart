/// Endereços das APIs do app, num lugar só.
///
/// Para testar com a API local: `--dart-define=SIGRH_URL=http://127.0.0.1:8089/sigrh`
/// (o mesmo define que o `DadosSql` já usa).
const urlSigrh = String.fromEnvironment('SIGRH_URL',
    defaultValue: 'https://pmrr.online/flutter/sigrh');

/// O sistema Operar (GAPE/PMRR), que o módulo Operações abre. O app fala com
/// ele DIRETO: a nossa API só emite o token de aparelho (ver
/// `features/operacoes/operar_api.dart`). Trocar o endereço do Operar custa
/// caro para a tropa — a digital e as etiquetas das viaturas são presas ao
/// domínio —, por isso ele fica aqui, e não espalhado pelas telas.
const urlOperar = String.fromEnvironment('OPERAR_URL',
    defaultValue: 'https://operar.pmrr.online');
