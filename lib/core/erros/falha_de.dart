import 'dart:async';
import 'dart:io';

import '../log/registro_log.dart';
import 'falha_app.dart';

/// Converte qualquer exceção das telas antigas (que ainda usam `http` solto)
/// numa [FalhaApp] com código, e grava no log. Substitui o "Erro inesperado:
/// $e" que mostrava o texto técnico ao militar (CLAUDE.md: erro sempre
/// explicado).
FalhaApp falhaDe(String prefixo, Object? erro, {String? tela}) {
  final f = switch (erro) {
    FalhaApp f => f,
    TimeoutException() => FalhaApp.lento(prefixo, detalhe: '$erro'),
    HandshakeException() => FalhaApp.conexaoSegura(prefixo, detalhe: '$erro'),
    SocketException() || HttpException() => FalhaApp.semInternet(prefixo, detalhe: '$erro'),
    FormatException() => FalhaApp.respostaInvalida(prefixo, detalhe: '$erro'),
    _ => FalhaApp.inesperada(prefixo, erro ?? 'nulo'),
  };
  registrarErro(f, tela: tela);
  return f;
}

/// Texto curto para um aviso: título, o que fazer e o código.
String textoFalha(String prefixo, Object? erro, {String? tela}) {
  final f = falhaDe(prefixo, erro, tela: tela);
  return '${f.titulo}. ${f.texto} Código ${f.codigo}.';
}
