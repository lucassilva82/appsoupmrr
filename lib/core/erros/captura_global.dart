import 'package:flutter/widgets.dart';

import '../log/registro_log.dart';
import 'falha_app.dart';

/// Captura todo erro que escapou de um `try` e grava no log com o código
/// `AP-FATAL-<tipo>` (docs/SOUPM_2_2.md §9.1): é o nosso "Crashlytics",
/// sem sair do Postgres.
///
/// Instalar antes do `runApp`. Não muda o que o militar vê: o erro continua
/// indo para o console em debug, e a tela segue o tratamento que já tinha.
void instalarCapturaGlobal() {
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalhes) {
    _gravar(detalhes.exception, detalhes.stack, tela: detalhes.library);
    if (anterior != null) {
      anterior(detalhes);
    } else {
      FlutterError.presentError(detalhes);
    }
  };

  // Erros assíncronos fora da árvore de widgets (Futures sem tratamento).
  WidgetsBinding.instance.platformDispatcher.onError = (erro, pilha) {
    _gravar(erro, pilha);
    debugPrint('[FATAL] $erro');
    return true;
  };
}

void _gravar(Object erro, StackTrace? pilha, {String? tela}) {
  final f = FalhaApp(
    codigo: 'AP-FATAL-${erro.runtimeType}',
    origem: OrigemFalha.app,
    titulo: 'Esta tela parou de funcionar',
    texto: 'Um erro inesperado aconteceu. O registro foi gravado para a '
        'equipe do DTI.',
    acao: AcaoFalha.abrirChamado,
    detalhe: '$erro',
  );
  registrarErro(f, tela: tela, mostrado: false, pilha: _resumo(pilha));
}

/// As 12 primeiras linhas bastam para achar o lugar; a pilha inteira pesa.
String? _resumo(StackTrace? pilha) {
  if (pilha == null) return null;
  return pilha.toString().split('\n').take(12).join('\n');
}
