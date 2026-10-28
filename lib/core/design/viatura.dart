/// A viatura nova da PMRR, em vetor (SOUPM_2_2 §10.3 e §15.6).
///
/// É a porta fiel do desenho do protótipo (`viaturaNova`): caminhonete cabine
/// dupla voltada para a direita, com caçamba atrás, para-brisa inclinado,
/// pintura azul em cima e branca embaixo, faixa verde com filete azul e
/// dourado, barra de giroflex em LED de sete segmentos, escudo, "190" e
/// "POLÍCIA / MILITAR DE RORAIMA" na porta.
///
/// **Por que não é só um retângulo.** A versão anterior eram seis retângulos
/// arredondados, e o usuário leu o resultado como um carrinho de brinquedo, não
/// como a viatura da corporação. O que dá a leitura é a silhueta: o recorte dos
/// para-lamas, o capô baixo à frente, o teto recuado e a caçamba.
///
/// O protótipo desenha num `viewBox` de 200×112. Aqui o desenho é feito nessas
/// mesmas unidades e a transformação leva o eixo das rodas para a origem, para
/// quem chama continuar girando e inclinando em volta dos mesmos pontos.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Metade da distância entre os eixos, no sistema de quem chama.
///
/// A abertura inclina a viatura em volta destes pontos: a roda traseira quando
/// a frente levanta na arrancada, a dianteira quando ela freia.
const double viaturaEixoTraseiro = -46;
const double viaturaEixoDianteiro = 46;

/// Do protótipo: rodas em x = 50 e 160, raio 15, num desenho de 200 × 112.
const double _rodaProtoTras = 50;
const double _rodaProtoFrente = 160;
const double _rodaProtoY = 88;
const double _rodaProtoRaio = 15;

/// A escala que faz os dois eixos caírem exatamente em ±46.
const double _escala =
    (viaturaEixoDianteiro - viaturaEixoTraseiro) / (_rodaProtoFrente - _rodaProtoTras);

/// Raio da roda já na escala de quem chama — serve para converter o
/// deslocamento em ângulo (`giro = x / viaturaRaioRoda`), para a roda girar na
/// medida certa do caminho andado, sem patinar.
const double viaturaRaioRoda = _rodaProtoRaio * _escala;

/// Largura e altura do desenho, na escala de quem chama.
const double viaturaLargura = 190 * _escala;
const double viaturaAltura = 82 * _escala;

const Color _azulEscuro = Color(0xFF14389A);
const Color _ouro = Color(0xFFF2C230);

/// Desenha a viatura com o meio dos eixos na origem.
///
/// [giroflexAceso] alterna as metades da barra: ligado, o vermelho acende e o
/// azul apaga; desligado, o contrário. [giroflexLigado] falso deixa a barra
/// inteira apagada (é o estado da viatura parada, antes da marca acender).
/// [giroRodas] é o ângulo das rodas, em radianos. [versao] escreve "VTR x.y.z"
/// na lateral, como na tela de atualização; nulo não escreve nada.
void desenharViatura(
  Canvas canvas, {
  bool giroflexAceso = false,
  bool giroflexLigado = true,
  double giroRodas = 0,
  String? versao,
}) {
  canvas.save();
  canvas.translate(0, 2);
  canvas.scale(_escala);
  canvas.translate(-105, -_rodaProtoY);

  _sombra(canvas);
  _carroceria(canvas);
  _faixas(canvas);
  _vidros(canvas);
  _detalhesLaterais(canvas);
  _frenteETraseira(canvas);
  _giroflex(canvas, aceso: giroflexAceso, ligado: giroflexLigado);
  _letreiro(canvas, versao);
  _roda(canvas, _rodaProtoTras, giroRodas);
  _roda(canvas, _rodaProtoFrente, giroRodas);

  canvas.restore();
}

void _sombra(Canvas canvas) {
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(102, 103), width: 192, height: 10),
    Paint()..color = const Color(0xFF2F7BFF).withValues(alpha: 0.18),
  );
}

/// O corpo: o contorno vai da traseira (esquerda) ao capô (direita), com os
/// dois para-lamas recortados como meia-lua. É esse recorte que faz a peça
/// parecer uma caminhonete, e não uma caixa sobre rodas.
Path _contornoCarroceria() {
  return Path()
    ..moveTo(6, 58)
    ..quadraticBezierTo(6, 54, 10, 54)
    ..lineTo(80, 54)
    ..lineTo(86, 30)
    ..quadraticBezierTo(88, 27, 92, 27)
    ..lineTo(134, 27)
    ..quadraticBezierTo(139, 27, 142, 31)
    ..lineTo(153, 48)
    ..lineTo(182, 51)
    ..quadraticBezierTo(195, 53, 196, 62)
    ..lineTo(196, 80)
    ..quadraticBezierTo(196, 86, 190, 86)
    ..lineTo(181, 86)
    ..arcToPoint(const Offset(139, 86), radius: const Radius.circular(21), clockwise: false)
    ..lineTo(71, 86)
    ..arcToPoint(const Offset(29, 86), radius: const Radius.circular(21), clockwise: false)
    ..lineTo(10, 86)
    ..quadraticBezierTo(6, 86, 6, 82)
    ..close();
}

void _carroceria(Canvas canvas) {
  final corpo = _contornoCarroceria();
  final cx = corpo.getBounds();
  canvas.drawPath(
    corpo,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFEEF3F8), Color(0xFFCBD5E1)],
        stops: [0, 0.7, 1],
      ).createShader(cx),
  );

  // A metade de cima, azul: o mesmo contorno cortado na linha da cintura.
  final alto = Path()
    ..moveTo(6, 58)
    ..quadraticBezierTo(6, 54, 10, 54)
    ..lineTo(80, 54)
    ..lineTo(86, 30)
    ..quadraticBezierTo(88, 27, 92, 27)
    ..lineTo(134, 27)
    ..quadraticBezierTo(139, 27, 142, 31)
    ..lineTo(153, 48)
    ..lineTo(182, 51)
    ..quadraticBezierTo(195, 53, 196, 62)
    ..lineTo(196, 63)
    ..lineTo(6, 63)
    ..close();
  canvas.drawPath(
    alto,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4C7DF7), Color(0xFF1F4FCF), _azulEscuro],
        stops: [0, 0.55, 1],
      ).createShader(alto.getBounds()),
  );
}

/// A faixa verde desce de leve da traseira para a frente e volta, como nas
/// viaturas de hoje; o filete azul e o dourado acompanham a mesma curva.
void _faixas(Canvas canvas) {
  final verde = Path()
    ..moveTo(6, 66.5)
    ..cubicTo(62, 60, 120, 75, 196, 64.5)
    ..lineTo(196, 69.5)
    ..cubicTo(120, 80, 62, 65, 6, 71.5)
    ..close();
  canvas.drawPath(
    verde,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF169A40), Color(0xFF27C25A), Color(0xFF169A40)],
        stops: [0, 0.5, 1],
      ).createShader(verde.getBounds()),
  );

  canvas.drawPath(
    Path()
      ..moveTo(6, 72.6)
      ..cubicTo(62, 66, 120, 81, 196, 70.6)
      ..lineTo(196, 72.4)
      ..cubicTo(120, 83, 62, 68, 6, 74.4)
      ..close(),
    Paint()..color = _azulEscuro,
  );

  canvas.drawPath(
    Path()
      ..moveTo(6, 75.2)
      ..cubicTo(62, 68.6, 120, 83.6, 196, 73.2)
      ..lineTo(196, 74)
      ..cubicTo(120, 84.4, 62, 69.4, 6, 76)
      ..close(),
    Paint()..color = _ouro,
  );
}

void _vidros(Canvas canvas) {
  final vidro = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3E5574), Color(0xFF0D1522), Color(0xFF26374F)],
      stops: [0, 0.5, 1],
    ).createShader(const Rect.fromLTRB(84.5, 31.5, 148.5, 49));

  // Vidro de trás (reto) e para-brisa (inclinado, acompanhando a coluna).
  canvas.drawPath(
    Path()
      ..moveTo(88, 31.5)
      ..lineTo(110, 31.5)
      ..lineTo(110, 49)
      ..lineTo(84.5, 49)
      ..close(),
    vidro,
  );
  canvas.drawPath(
    Path()
      ..moveTo(114, 31.5)
      ..lineTo(134, 31.5)
      ..quadraticBezierTo(137, 31.5, 139, 34)
      ..lineTo(148.5, 49)
      ..lineTo(114, 49)
      ..close(),
    vidro,
  );

  // Dois reflexos diagonais, para o vidro não ficar chapado.
  final reflexo = Paint()..color = Colors.white.withValues(alpha: 0.12);
  canvas.drawPath(
    Path()
      ..moveTo(120, 33)
      ..lineTo(127, 33)
      ..lineTo(135, 46)
      ..lineTo(128, 46)
      ..close(),
    reflexo,
  );
  canvas.drawPath(
    Path()
      ..moveTo(92, 33)
      ..lineTo(97, 33)
      ..lineTo(93, 46)
      ..lineTo(89, 46)
      ..close(),
    reflexo,
  );
}

void _detalhesLaterais(Canvas canvas) {
  final cromo = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF2F5F8), Color(0xFF8E99A6)],
    ).createShader(const Rect.fromLTRB(90, 24, 132, 28))
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(90, 26), const Offset(132, 26), cromo); // rack do teto

  // Recortes das portas.
  final risco = Paint()
    ..color = Colors.black.withValues(alpha: 0.13)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;
  canvas.drawLine(const Offset(84, 50), const Offset(83, 84), risco);
  canvas.drawLine(const Offset(112, 50), const Offset(112, 84), risco);
  canvas.drawLine(const Offset(148, 50), const Offset(147, 84), risco);

  // Maçanetas.
  final cromoCheio = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF2F5F8), Color(0xFF8E99A6)],
    ).createShader(const Rect.fromLTRB(101, 63.5, 143, 65.5));
  for (final x in [101.0, 136.0]) {
    canvas.drawRRect(
      RRect.fromLTRBR(x, 63.5, x + 7, 65.5, const Radius.circular(1)),
      cromoCheio,
    );
  }

  // Retrovisor, na altura do para-brisa.
  canvas.drawPath(
    Path()
      ..moveTo(150, 45)
      ..lineTo(159, 42.5)
      ..quadraticBezierTo(161, 42, 161, 44)
      ..lineTo(160.5, 48)
      ..lineTo(151, 48.5)
      ..close(),
    Paint()..color = _azulEscuro,
  );
  canvas.drawLine(
    const Offset(152, 46),
    const Offset(158, 44.5),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.8,
  );

  // Brilho ao longo da lataria.
  canvas.drawPath(
    Path()
      ..moveTo(10, 56)
      ..quadraticBezierTo(40, 54.5, 80, 55),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  canvas.drawPath(
    Path()
      ..moveTo(155, 51)
      ..quadraticBezierTo(175, 52, 190, 54),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  // Arcos dos para-lamas e o estribo entre eles.
  final borracha = Paint()
    ..color = const Color(0xFF1B2129)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2;
  for (final x in [_rodaProtoTras, _rodaProtoFrente]) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x, 86), radius: 21),
      math.pi,
      math.pi,
      false,
      borracha,
    );
  }
  canvas.drawLine(
    const Offset(71, 84),
    const Offset(139, 84),
    Paint()
      ..color = const Color(0xFF2A313A)
      ..strokeWidth = 3.4,
  );
  canvas.drawLine(
    const Offset(74, 83.2),
    const Offset(136, 83.2),
    Paint()
      ..color = const Color(0xFF9AA6B3)
      ..strokeWidth = 0.8,
  );
}

void _frenteETraseira(Canvas canvas) {
  // Para-choque dianteiro.
  canvas.drawPath(
    Path()
      ..moveTo(181, 84)
      ..lineTo(190, 84)
      ..quadraticBezierTo(196, 84, 196, 80)
      ..lineTo(196, 76)
      ..lineTo(186, 76)
      ..close(),
    Paint()..color = const Color(0xFF1B2129),
  );

  // Farol de LED, uma lâmina fina colada na quina do capô.
  canvas.drawPath(
    Path()
      ..moveTo(178.5, 53.6)
      ..lineTo(195, 56.6)
      ..quadraticBezierTo(196, 57, 195.6, 58.4)
      ..lineTo(180, 57.4)
      ..close(),
    Paint()..color = const Color(0xFFEAF4FF),
  );
  canvas.drawLine(
    const Offset(181, 59.5),
    const Offset(194, 60.8),
    Paint()
      ..color = const Color(0xFFBFE0FF)
      ..strokeWidth = 0.9,
  );

  // Grade e farol de neblina.
  canvas.drawRRect(
    RRect.fromLTRBR(190.5, 62, 196, 71, const Radius.circular(1.2)),
    Paint()..color = const Color(0xFF12161C),
  );
  final friso = Paint()
    ..color = const Color(0xFFBCC5D0)
    ..strokeWidth = 0.8;
  canvas.drawLine(const Offset(191, 64.5), const Offset(196, 64.5), friso);
  canvas.drawLine(const Offset(191, 67), const Offset(196, 67), friso);
  canvas.drawCircle(const Offset(191.5, 79.5), 1.6, Paint()..color = const Color(0xFFFFE9A8));

  // Lanterna traseira.
  canvas.drawRRect(
    RRect.fromLTRBR(5.5, 56, 8.7, 67, const Radius.circular(1.2)),
    Paint()..color = const Color(0xFFFF3B3B),
  );
}

/// A barra de giroflex: sete segmentos, três vermelhos, um branco no meio e
/// três azuis. [aceso] troca qual metade está acesa — é o que dá a piscada.
void _giroflex(Canvas canvas, {required bool aceso, required bool ligado}) {
  canvas.drawRRect(
    RRect.fromLTRBR(93, 20.6, 131, 25.2, const Radius.circular(2.3)),
    Paint()..color = const Color(0xFF11151B),
  );
  final pe = Paint()..color = const Color(0xFF8E99A6);
  canvas.drawRect(const Rect.fromLTRB(95, 25, 97, 27.4), pe);
  canvas.drawRect(const Rect.fromLTRB(127, 25, 129, 27.4), pe);

  const apagado = Color(0xFF39414D);
  final vermelho = !ligado
      ? apagado
      : (aceso ? const Color(0xFFFF3B3B) : const Color(0xFF6B1F22));
  final azul = !ligado
      ? apagado
      : (aceso ? const Color(0xFF1B2F63) : const Color(0xFF2F7BFF));
  final branco = !ligado ? apagado : const Color(0xFFFFFFFF);

  for (var i = 0; i < 7; i++) {
    final x = 94.4 + i * 5.2;
    final cor = i < 3 ? vermelho : (i == 3 ? branco : azul);
    canvas.drawRRect(
      RRect.fromLTRBR(x, 21.3, x + 4.4, 24.5, const Radius.circular(1)),
      Paint()..color = cor,
    );
  }
}

/// O que identifica a viatura: o escudo dourado com a estrela, o "190" na
/// caçamba e "POLÍCIA / MILITAR DE RORAIMA" na porta, em itálico com contorno
/// branco (o `paint-order: stroke` do protótipo, que aqui é desenhar duas
/// vezes: o contorno antes, o preenchimento por cima).
void _letreiro(Canvas canvas, String? versao) {
  if (versao != null && versao.isNotEmpty) {
    _texto(canvas, 'VTR $versao', const Offset(90, 55.5),
        tamanho: 5, peso: FontWeight.w700, cor: Colors.white, espaco: 0.4);
  }

  // Escudo.
  canvas.drawPath(
    Path()
      ..moveTo(122, 54.5)
      ..relativeLineTo(3.2, 1.2)
      ..relativeLineTo(0, 3.4)
      ..relativeQuadraticBezierTo(0, 2.6, -3.2, 4)
      ..relativeQuadraticBezierTo(-3.2, -1.4, -3.2, -4)
      ..relativeLineTo(0, -3.4)
      ..close(),
    Paint()..color = _ouro,
  );
  canvas.drawPath(
    Path()
      ..moveTo(122, 54.5)
      ..relativeLineTo(3.2, 1.2)
      ..relativeLineTo(0, 3.4)
      ..relativeQuadraticBezierTo(0, 2.6, -3.2, 4)
      ..relativeQuadraticBezierTo(-3.2, -1.4, -3.2, -4)
      ..relativeLineTo(0, -3.4)
      ..close(),
    Paint()
      ..color = _azulEscuro
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7,
  );
  canvas.drawPath(
    Path()
      ..moveTo(122, 56.8)
      ..relativeLineTo(0.9, 1.8)
      ..relativeLineTo(2, 0.2)
      ..relativeLineTo(-1.5, 1.3)
      ..relativeLineTo(0.4, 2)
      ..relativeLineTo(-1.8, -1)
      ..relativeLineTo(-1.8, 1)
      ..relativeLineTo(0.4, -2)
      ..relativeLineTo(-1.5, -1.3)
      ..relativeLineTo(2, -0.2)
      ..close(),
    Paint()..color = _azulEscuro,
  );

  _texto(canvas, '190', const Offset(24, 74),
      tamanho: 6.5, peso: FontWeight.w900, cor: _azulEscuro, italico: true);

  _texto(canvas, 'POLÍCIA', const Offset(105, 69.8),
      tamanho: 10.6,
      peso: FontWeight.w900,
      cor: _azulEscuro,
      italico: true,
      espaco: 0.5,
      centralizado: true,
      contorno: Colors.white,
      larguraContorno: 1.6);

  _texto(canvas, 'MILITAR DE RORAIMA', const Offset(105, 79.8),
      tamanho: 3.3,
      peso: FontWeight.w700,
      cor: _azulEscuro,
      italico: true,
      espaco: 0.9,
      centralizado: true);
}

void _texto(
  Canvas canvas,
  String texto,
  Offset onde, {
  required double tamanho,
  required FontWeight peso,
  required Color cor,
  bool italico = false,
  double espaco = 0,
  bool centralizado = false,
  Color? contorno,
  double larguraContorno = 0,
}) {
  TextPainter medir(Paint? tinta, Color? plano) => TextPainter(
        text: TextSpan(
          text: texto,
          style: TextStyle(
            fontSize: tamanho,
            fontWeight: peso,
            fontStyle: italico ? FontStyle.italic : FontStyle.normal,
            letterSpacing: espaco,
            height: 1,
            color: tinta == null ? plano : null,
            foreground: tinta,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  if (contorno != null) {
    final traco = medir(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = larguraContorno
        ..strokeJoin = StrokeJoin.round
        ..color = contorno,
      null,
    );
    traco.paint(canvas, Offset(centralizado ? onde.dx - traco.width / 2 : onde.dx, onde.dy));
  }
  final cheio = medir(null, cor);
  cheio.paint(canvas, Offset(centralizado ? onde.dx - cheio.width / 2 : onde.dx, onde.dy));
}

/// A roda: pneu parado, pinça de freio vermelha parada (ela é do carro, não da
/// roda) e, girando, o aro de liga com seis raios.
void _roda(Canvas canvas, double x, double giro) {
  const r = _rodaProtoRaio;
  final centro = Offset(x, _rodaProtoY);

  canvas.drawCircle(centro, r, Paint()..color = const Color(0xFF0E1014));
  canvas.drawCircle(
    centro,
    r - 1.2,
    Paint()
      ..color = const Color(0xFF2B3038)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  // Pinça de freio: fica no lugar enquanto a roda gira.
  canvas.drawPath(
    Path()
      ..moveTo(x - r * 0.55, _rodaProtoY - r * 0.42)
      ..arcToPoint(Offset(x + r * 0.1, _rodaProtoY - r * 0.7),
          radius: const Radius.circular(r * 0.7), clockwise: true),
    Paint()
      ..color = const Color(0xFFE5484D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2,
  );

  canvas.save();
  canvas.translate(centro.dx, centro.dy);
  canvas.rotate(giro);

  canvas.drawCircle(
    Offset.zero,
    r * 0.68,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 0.8,
        colors: [Color(0xFFF4F7FA), Color(0xFFAEB8C4), Color(0xFF6E7885)],
        stops: [0, 0.6, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.68)),
  );

  final raio = Paint()..color = const Color(0xFF2A3038);
  for (var i = 0; i < 6; i++) {
    final g = i * math.pi / 3;
    canvas.drawPath(
      Path()
        ..moveTo(math.cos(g) * r * 0.18, math.sin(g) * r * 0.18)
        ..lineTo(math.cos(g - 0.18) * r * 0.62, math.sin(g - 0.18) * r * 0.62)
        ..lineTo(math.cos(g + 0.18) * r * 0.62, math.sin(g + 0.18) * r * 0.62)
        ..close(),
      raio,
    );
  }

  canvas.drawCircle(
    Offset.zero,
    r * 0.68,
    Paint()
      ..color = const Color(0xFFE9EEF4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  canvas.drawCircle(Offset.zero, r * 0.2, Paint()..color = const Color(0xFFC9D2DD));
  canvas.drawCircle(Offset.zero, r * 0.08, Paint()..color = const Color(0xFF1F4FCF));
  canvas.restore();
}

/// Luz da piscada do giroflex sobre o fundo: um halo vermelho ou azul.
void desenharLuzGiroflex(Canvas canvas, Offset centro, bool vermelho, double forca) {
  if (forca <= 0) return;
  final cor = vermelho ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
  canvas.drawCircle(
    centro,
    220,
    Paint()
      ..shader = ui.Gradient.radial(centro, 220, [
        cor.withValues(alpha: 0.28 * forca),
        cor.withValues(alpha: 0),
      ]),
  );
}

double grausParaRad(double g) => g * math.pi / 180;
