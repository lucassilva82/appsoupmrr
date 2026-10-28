/// Endereços das APIs do app, num lugar só.
///
/// Para testar com a API local: `--dart-define=SIGRH_URL=http://127.0.0.1:8089/sigrh`
/// (o mesmo define que o `DadosSql` já usa).
const urlSigrh = String.fromEnvironment('SIGRH_URL',
    defaultValue: 'https://pmrr.online/flutter/sigrh');
