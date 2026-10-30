// ─────────────────────────────────────────────────────────────────────────────
// O armazém do Operar dentro da WebView, visto de fora.
//
// O app de campo do Operar guarda tudo no `localStorage` da origem dele:
// token do aparelho, PIN, escala, avisos, fotos, conversas e a fila de
// registros que ainda não subiram. Esse armazém é da WebView, não do Sou PM —
// o cofre seguro do app não o alcança.
//
// Só existe UMA WebView no Sou PM, e ela só abre o Operar. Por isso dá para
// limpar sem escolher origem: o que há ali é só do Operar.
//
// Melhor esforço, de propósito: no Android não há apagar `localStorage` por
// origem (o `deleteOrigin` do WebStorage só alcança Web SQL e AppCache), e a
// chamada pode falhar calada. Quem GARANTE a limpeza é a guarda de dono da
// `OperacoesPage`, que roda antes da página do Operar e não tem como ser
// contornada. Isto aqui só adianta o serviço: tira os dados do disco na hora
// em que o militar sai, em vez de na próxima abertura.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Esvazia o que a WebView guarda do Operar. Nunca lança: é chamada no meio do
/// logout, e logout que trava por causa de cache é pior do que cache que fica.
Future<void> limparArmazemOperar() async {
  try {
    await CookieManager.instance().deleteAllCookies();
  } catch (_) {
    // Sem cookies para apagar, ou plataforma sem suporte.
  }
  try {
    if (Platform.isAndroid) {
      await WebStorageManager.instance().deleteAllData();
    } else {
      // No iPhone a limpeza é por data: tudo o que foi gravado desde sempre.
      await WebStorageManager.instance().removeDataModifiedSince(
        dataTypes: WebsiteDataType.ALL,
        date: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
  } catch (_) {
    // A guarda de dono cobre o que não saiu daqui.
  }
}
