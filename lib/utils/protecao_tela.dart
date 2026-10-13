import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bloqueio de captura de tela
//
// Ligado **só** onde há dado pessoal de terceiro na tela — a ficha de um
// militar aberta pelo Mapa da Força. No resto do app o militar pode printar
// e gravar à vontade: o contracheque, as férias e o tempo de serviço são
// dados dele, e impedir que ele guarde os próprios dados só atrapalha.
//
// O bloqueio era global antes, aplicado no `main()`. Isso protegia a ficha
// alheia, sim, mas cobrava o preço em todas as outras telas.
//
// Como cada plataforma avisa é diferente, e não dá para uniformizar:
//
//  • Android — FLAG_SECURE impede a captura no nível do sistema. O próprio
//    Android mostra o aviso dele e o app não fica sabendo da tentativa.
//  • iOS — não existe bloqueio real de print. O sistema deixa capturar e
//    avisa depois; o que dá para fazer é detectar e borrar a imagem, que é
//    o que [ocultar] faz.
//
// Por isso a ficha também traz o aviso escrito na própria tela: é a única
// forma de o militar saber da regra nos dois sistemas, antes de tentar.
// ─────────────────────────────────────────────────────────────────────────────

class ProtecaoTela {
  ProtecaoTela._();

  static const String aviso =
      'Print bloqueado para assegurar a privacidade dos militares';

  /// Verdadeiro enquanto uma tela protegida está aberta.
  static final ValueNotifier<bool> ativa = ValueNotifier<bool>(false);

  /// Verdadeiro no instante em que uma captura é detectada (iOS), para o
  /// app borrar o conteúdo antes que a imagem seja gravada.
  static final ValueNotifier<bool> ocultar = ValueNotifier<bool>(false);

  static Future<void> ligar() async {
    if (ativa.value) return;
    ativa.value = true;
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (_) {
      // Sem bloqueio nativo o aviso na tela continua valendo; melhor seguir
      // do que derrubar a ficha por causa do plugin.
    }
  }

  static Future<void> desligar() async {
    if (!ativa.value) return;
    ativa.value = false;
    ocultar.value = false;
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (_) {}
  }
}
