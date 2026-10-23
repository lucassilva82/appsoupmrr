import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A viatura nova da PMRR em vetor (SOUPM_2_2 §10.3 e §15.6): caminhonete
/// cabine dupla, faixa verde com filete dourado e barra de giroflex em LED.
/// Desenha com o meio das rodas na origem; mede 148 de largura.
///
/// [giroflexAceso] alterna o vermelho e o azul; [giroflexLigado] falso deixa
/// a barra apagada. [giroRodas] é o ângulo das rodas, em radianos.
void desenharViatura(Canvas canvas,
    {bool giroflexAceso = false, bool giroflexLigado = true, double giroRodas = 0}) {
  const azul = Color(0xFF1E3A8A);
  const verde = Color(0xFF15803D);
  canvas.drawRRect(RRect.fromLTRBR(-74, -32, 74, 0, const Radius.circular(8)), Paint()..color = Colors.white);
  canvas.drawRect(const Rect.fromLTRB(-72, -20, 72, -14), Paint()..color = verde);
  canvas.drawRect(const Rect.fromLTRB(-72, -14, 72, -12), Paint()..color = const Color(0xFFE0A100));
  canvas.drawRRect(RRect.fromLTRBR(-30, -58, 40, -30, const Radius.circular(9)), Paint()..color = azul);
  canvas.drawRRect(RRect.fromLTRBR(-24, -54, 4, -36, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));
  canvas.drawRRect(RRect.fromLTRBR(8, -54, 34, -36, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));
  final vermelho = !giroflexLigado ? const Color(0xFF475569) : (giroflexAceso ? const Color(0xFFEF4444) : const Color(0xFF7F1D1D));
  final azulLed = !giroflexLigado ? const Color(0xFF475569) : (giroflexAceso ? const Color(0xFF1E3A8A) : const Color(0xFF60A5FA));
  canvas.drawRRect(RRect.fromLTRBR(-20, -66, 0, -59, const Radius.circular(3)), Paint()..color = vermelho);
  canvas.drawRRect(RRect.fromLTRBR(0, -66, 20, -59, const Radius.circular(3)), Paint()..color = azulLed);
  canvas.drawRRect(RRect.fromLTRBR(66, -28, 74, -22, const Radius.circular(2)), Paint()..color = const Color(0xFFFFF7CC));
  for (final x in [-46.0, 46.0]) {
    canvas.save();
    canvas.translate(x, 2);
    canvas.rotate(giroRodas);
    canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF111827));
    canvas.drawCircle(Offset.zero, 7, Paint()..color = const Color(0xFFCBD5E1));
    canvas.drawRect(const Rect.fromLTRB(-1.5, -7, 1.5, 7), Paint()..color = const Color(0xFF64748B));
    canvas.restore();
    canvas.drawArc(Rect.fromCircle(center: Offset(x, 2), radius: 9), -2.4, 1.2, false,
        Paint()..color = const Color(0xFFDC2626)..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

/// Luz da piscada do giroflex sobre o fundo: um halo vermelho ou azul.
void desenharLuzGiroflex(Canvas canvas, Offset centro, bool vermelho, double forca) {
  if (forca <= 0) return;
  final cor = vermelho ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
  canvas.drawCircle(
    centro,
    220,
    Paint()
      ..shader = RadialGradient(colors: [cor.withValues(alpha: 0.28 * forca), cor.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: centro, radius: 220)),
  );
}

double grausParaRad(double g) => g * math.pi / 180;
