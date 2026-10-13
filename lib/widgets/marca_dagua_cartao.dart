import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Marca d'água dos cards do painel
//
// Um desenho grande, inclinado e quase apagado no canto do card. Não é
// enfeite solto: cada um repete, em forma, o que o card diz em texto — o
// calendário marca o período das férias, a folha destaca a linha do líquido,
// a medalha traz o arco do tempo cumprido.
//
// Por que desenhado e não `Icon(...)` em corpo 92: ícone do Material nesse
// tamanho não vira ilustração, vira um ícone grande — traço de espessura
// fixa, sem hierarquia interna e com canto duro batendo na borda do card.
//
// A máscara radial é o que o deixa solto: ele se dissolve antes de encostar
// no texto, em vez de ser cortado pela borda do card.
// ─────────────────────────────────────────────────────────────────────────────

enum DesenhoMarca {
  /// Calendário com um intervalo selecionado — plano de férias.
  calendario,

  /// Folha de pagamento com a linha do líquido destacada — contracheque.
  folha,

  /// Medalha com o arco do progresso — tempo de serviço.
  medalha,
}

class MarcaDaguaCartao extends StatelessWidget {
  const MarcaDaguaCartao({
    Key? key,
    required this.desenho,
    this.progresso,
  }) : super(key: key);

  final DesenhoMarca desenho;

  /// 0..1 — só a medalha usa, para o arco ser o progresso de verdade.
  final double? progresso;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurface;

    final CustomPainter pintura;
    switch (desenho) {
      case DesenhoMarca.calendario:
        pintura = _PinturaCalendario(cor: cor, acento: AppColors.acaoClara);
        break;
      case DesenhoMarca.folha:
        pintura = _PinturaFolha(cor: cor, acento: AppColors.acaoClara);
        break;
      case DesenhoMarca.medalha:
        pintura = _PinturaMedalha(
          cor: cor,
          acento: AppColors.acaoClara,
          progresso: (progresso ?? 0.0).clamp(0.0, 1.0),
        );
        break;
    }

    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -0.16, // ~9°, o bastante para deitar sem parecer torto
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          // Radial, não linear: um degradê de um canto ao outro deixa o canto
          // oposto opaco, e lá o desenho encosta no texto com aresta de régua.
          shaderCallback: (r) => const RadialGradient(
            center: Alignment(0.25, 0.1),
            radius: 0.78,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.35, 1.0],
          ).createShader(r),
          child: CustomPaint(
            size: const Size(132, 120),
            painter: pintura,
          ),
        ),
      ),
    );
  }
}

// ─── Tons comuns aos três desenhos ───────────────────────────────────────────
// Ficam juntos para os três terem o mesmo peso no card. Mexer num sem mexer
// nos outros é o caminho para um aparecer mais que o resto.

class _Tons {
  _Tons._();

  static const corpo = 0.035; // preenchimento da superfície
  static const borda = 0.075; // contorno
  static const detalhe = 0.11; // argolas, peças pequenas
  static const conteudo = 0.06; // linhas, dias, miolo
  static const tinta = 0.07; // cabeçalho tingido e brilho de fundo
  static const destaqueA = 0.20; // a parte que importa, começo do degradê
  static const destaqueB = 0.07; // ... e o fim dele
  static const larguraBorda = 1.4;
}

/// Brilho atrás do desenho, para ele não parecer colado no fundo chapado.
void _luz(Canvas canvas, Size size, Color acento,
    {Alignment em = Alignment.center}) {
  final centro = Offset(
    size.width * (0.5 + em.x * 0.5),
    size.height * (0.5 + em.y * 0.5),
  );
  final raio = size.width * 0.58;
  canvas.drawCircle(
    centro,
    raio,
    Paint()
      ..shader = RadialGradient(
        colors: [acento.withValues(alpha: _Tons.tinta), Colors.transparent],
      ).createShader(Rect.fromCircle(center: centro, radius: raio)),
  );
}

Paint _preenche(Color c, double alfa) =>
    Paint()..color = c.withValues(alpha: alfa);

Paint _contorna(Color c, double alfa, [double largura = _Tons.larguraBorda]) =>
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura
      ..color = c.withValues(alpha: alfa);

Paint _destaca(Rect r, Color acento) => Paint()
  ..shader = LinearGradient(
    colors: [
      acento.withValues(alpha: _Tons.destaqueA),
      acento.withValues(alpha: _Tons.destaqueB),
    ],
  ).createShader(r);

// ─── Calendário ──────────────────────────────────────────────────────────────

class _PinturaCalendario extends CustomPainter {
  const _PinturaCalendario({required this.cor, required this.acento});

  final Color cor;
  final Color acento;

  @override
  void paint(Canvas canvas, Size size) {
    const topoCorpo = 16.0;
    final corpo = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, topoCorpo, size.width, size.height),
      const Radius.circular(16),
    );

    _luz(canvas, size, acento, em: const Alignment(0.24, -0.16));
    canvas.drawRRect(corpo, _preenche(cor, _Tons.corpo));

    // Cabeçalho do calendário, levemente tingido.
    canvas.save();
    canvas.clipRRect(corpo);
    canvas.drawRect(
      Rect.fromLTRB(0, topoCorpo, size.width, topoCorpo + 26),
      _preenche(acento, _Tons.tinta),
    );
    canvas.restore();

    canvas.drawRRect(corpo, _contorna(cor, _Tons.borda));

    // Argolas da espiral.
    for (final x in [size.width * 0.26, size.width * 0.68]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 2, 7, 26),
          const Radius.circular(3.5),
        ),
        _preenche(cor, _Tons.detalhe),
      );
    }

    // Grade dos dias.
    const colunas = 4, linhas = 3, celula = 16.0, vao = 9.0;
    final largura = colunas * celula + (colunas - 1) * vao;
    final esquerda = (size.width - largura) / 2;
    const topoGrade = 54.0;

    for (var l = 0; l < linhas; l++) {
      for (var c = 0; c < colunas; c++) {
        // A faixa do meio é o período: sai como um bloco só, não como três
        // quadradinhos soltos.
        if (l == 1 && c >= 1) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              esquerda + c * (celula + vao),
              topoGrade + l * (celula + vao),
              celula,
              celula,
            ),
            const Radius.circular(4),
          ),
          _preenche(cor, _Tons.conteudo),
        );
      }
    }

    // O período, como a seleção de um intervalo num seletor de datas.
    final faixa = Rect.fromLTWH(
      esquerda + (celula + vao) - 3,
      topoGrade + (celula + vao) - 3,
      3 * celula + 2 * vao + 6,
      celula + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(faixa, const Radius.circular(11)),
      _destaca(faixa, acento),
    );
  }

  @override
  bool shouldRepaint(_PinturaCalendario antiga) =>
      antiga.cor != cor || antiga.acento != acento;
}

// ─── Folha de pagamento ──────────────────────────────────────────────────────

class _PinturaFolha extends CustomPainter {
  const _PinturaFolha({required this.cor, required this.acento});

  final Color cor;
  final Color acento;

  @override
  void paint(Canvas canvas, Size size) {
    final corpo = RRect.fromRectAndRadius(
      Rect.fromLTRB(8, 0, size.width - 8, size.height),
      const Radius.circular(14),
    );

    _luz(canvas, size, acento, em: const Alignment(0.18, -0.1));
    canvas.drawRRect(corpo, _preenche(cor, _Tons.corpo));

    // Cabeçalho da folha.
    canvas.save();
    canvas.clipRRect(corpo);
    canvas.drawRect(
      Rect.fromLTRB(8, 0, size.width - 8, 22),
      _preenche(acento, _Tons.tinta),
    );
    canvas.restore();

    canvas.drawRRect(corpo, _contorna(cor, _Tons.borda));

    // Linhas de rubrica: rótulo à esquerda, valor à direita, como na folha
    // de verdade. A terceira é o líquido — é ela que o card mostra grande.
    const esquerda = 20.0;
    final direita = size.width - 20.0;
    const alturaLinha = 8.0;
    const vao = 13.0;
    const topo = 36.0;
    const larguraValor = 24.0;

    const larguraRotulo = [44.0, 52.0, 38.0, 48.0];

    for (var n = 0; n < larguraRotulo.length; n++) {
      final y = topo + n * (alturaLinha + vao);
      final destaque = n == 2;

      final rotulo = Rect.fromLTWH(
        esquerda,
        y,
        larguraRotulo[n],
        alturaLinha,
      );
      final valor = Rect.fromLTWH(
        direita - larguraValor,
        y,
        larguraValor,
        alturaLinha,
      );

      if (destaque) {
        // A linha inteira acesa, não só o valor: é o total da folha.
        final faixa = Rect.fromLTRB(
          esquerda - 5,
          y - 5,
          direita + 5,
          y + alturaLinha + 5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(faixa, const Radius.circular(9)),
          _destaca(faixa, acento),
        );
      } else {
        for (final r in [rotulo, valor]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(4)),
            _preenche(cor, _Tons.conteudo),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PinturaFolha antiga) =>
      antiga.cor != cor || antiga.acento != acento;
}

// ─── Medalha ─────────────────────────────────────────────────────────────────

class _PinturaMedalha extends CustomPainter {
  const _PinturaMedalha({
    required this.cor,
    required this.acento,
    required this.progresso,
  });

  final Color cor;
  final Color acento;
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    _luz(canvas, size, acento, em: const Alignment(0.0, 0.1));

    final centro = Offset(size.width / 2, size.height * 0.66);
    const raio = 33.0;
    const espessura = 9.0;

    // Fitas, saindo de trás da medalha.
    for (final lado in [-1.0, 1.0]) {
      final caminho = Path()
        ..moveTo(centro.dx + lado * 9, centro.dy - raio + 4)
        ..lineTo(centro.dx + lado * 25, 14)
        ..lineTo(centro.dx + lado * 8, 14)
        ..lineTo(centro.dx - lado * 5, centro.dy - raio + 4)
        ..close();
      canvas.drawPath(caminho, _preenche(cor, 0.085));
    }

    // Aro da medalha.
    canvas.drawCircle(
      centro,
      raio,
      _contorna(cor, _Tons.borda + 0.015, espessura),
    );

    // O arco é o tempo já cumprido — o mesmo número que a barra do card
    // mostra, e o motivo de a medalha estar aqui e não um relógio.
    if (progresso > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raio),
        -math.pi / 2,
        progresso * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = espessura
          ..strokeCap = StrokeCap.round
          ..color = acento.withValues(alpha: _Tons.destaqueA + 0.06),
      );
    }

    // Estrela do miolo.
    final estrela = Path();
    const pontas = 5;
    const externo = 15.0, interno = 6.5;
    for (var n = 0; n < pontas * 2; n++) {
      final r = n.isEven ? externo : interno;
      final a = -math.pi / 2 + n * math.pi / pontas;
      final p =
          Offset(centro.dx + r * math.cos(a), centro.dy + r * math.sin(a));
      n == 0 ? estrela.moveTo(p.dx, p.dy) : estrela.lineTo(p.dx, p.dy);
    }
    estrela.close();
    canvas.drawPath(estrela, _preenche(cor, _Tons.conteudo + 0.02));
  }

  @override
  bool shouldRepaint(_PinturaMedalha antiga) =>
      antiga.cor != cor ||
      antiga.acento != acento ||
      antiga.progresso != progresso;
}
