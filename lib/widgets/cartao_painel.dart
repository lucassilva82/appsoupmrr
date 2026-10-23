import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Peças dos cards do painel (Início)
//
// Os três cards da home — tempo de serviço, contracheque e plano de férias —
// contavam a mesma história de jeitos diferentes: cada um com seu cabeçalho,
// seu azul fixo `Color(0xFF1565C0)` e sua régua de tamanhos. Lado a lado na
// mesma tela isso aparece como três produtos, não um.
//
// A gramática aqui é uma só, e vem do desenho aprovado:
//
//   cabeçalho discreto  →  UM número grande  →  apoio  →  rodapé
//
// O peso fica todo no número. Tudo em volta é cinza de apoio, e só a ação
// (pílula, link) usa o azul. É o oposto do que havia antes, onde selo, chip,
// badge e barra disputavam atenção e o dado em si ficava em 11pt.
// ─────────────────────────────────────────────────────────────────────────────

/// Escala de display dos cards. A escala de texto do DESIGN.md (10–18) cobre
/// corpo e rótulo; um número herói precisa sair dela, e sair de forma
/// combinada em vez de cada card escolher o seu.
class AppDisplaySize {
  AppDisplaySize._();

  static const heroi = 28.0; // o número principal do card
  static const heroiMenor = 24.0; // quando o texto é longo (datas, moeda)
  static const apoio = 17.0; // a segunda linha do herói
  static const valor = 18.0; // valor de um par rótulo/valor
}

/// Cinzas de apoio dos cards, para não haver meia dúzia de alfas soltos.
class TomCartao {
  TomCartao._();

  /// Texto de apoio legível — rótulos, legendas.
  static Color medio(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.62);

  /// Texto terciário — fonte do dado, observação de rodapé.
  static Color fraco(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.42);

  /// Linha divisória interna.
  static Color linha(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.10);

  /// Trilho de barra de progresso e fundos neutros muito leves.
  static Color trilho(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.10);
}

/// Azul das superfícies cheias dos cards (pílula, barra, marcador).
/// É o mesmo dos botões — ver DESIGN.md §5.
const Gradient gradienteAcao = LinearGradient(
  colors: [AppColors.acaoClara, AppColors.acao],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// Espaçamento interno padrão de um card do painel.
const EdgeInsets kPaddingCartao = EdgeInsets.fromLTRB(16, 14, 16, 14);

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho
// ─────────────────────────────────────────────────────────────────────────────

/// Ícone contornado + título + meta à direita + seta.
///
/// Sem o quadradinho tingido atrás do ícone: ele criava uma segunda superfície
/// dentro de um card que já é uma superfície, que é justamente o empilhamento
/// de tons que o DESIGN.md §3b manda evitar.
class CabecalhoCartao extends StatelessWidget {
  const CabecalhoCartao({
    Key? key,
    required this.icone,
    required this.titulo,
    this.meta,
    this.acao,
    this.mostrarSeta = true,
  }) : super(key: key);

  final IconData icone;
  final String titulo;

  /// Texto curto à direita: o ano, o mês de referência.
  final String? meta;

  /// Controle próprio do card (o olho do contracheque, por exemplo).
  final Widget? acao;

  final bool mostrarSeta;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icone, size: AppIconSize.sm, color: cor.withValues(alpha: 0.80)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cor.withValues(alpha: 0.92),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (meta != null) ...[
          Text(
            meta!,
            style: TextStyle(fontSize: 13, color: TomCartao.medio(context)),
          ),
          const SizedBox(width: 6),
        ],
        if (acao != null) ...[
          acao!,
          const SizedBox(width: 2),
        ],
        if (mostrarSeta)
          Icon(Icons.chevron_right_rounded,
              size: AppIconSize.sm, color: cor.withValues(alpha: 0.38)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Herói
// ─────────────────────────────────────────────────────────────────────────────

/// O número que justifica o card existir.
///
/// [valor] sai grande e pesado; [complemento] é a continuação dele, um degrau
/// abaixo — "5 anos" / "6 meses e 26 dias".
class DestaqueCartao extends StatelessWidget {
  const DestaqueCartao({
    Key? key,
    required this.valor,
    this.complemento,
    this.rotulo,
    this.corValor,
    this.tamanho = AppDisplaySize.heroi,
    this.tamanhoComplemento = AppDisplaySize.apoio,
  }) : super(key: key);

  final String valor;
  final String? complemento;

  /// Etiqueta miúda em caixa alta acima do número.
  final String? rotulo;

  final Color? corValor;
  final double tamanho;
  final double tamanhoComplemento;

  @override
  Widget build(BuildContext context) {
    final cor = corValor ?? Theme.of(context).colorScheme.onSurface;

    // Dynamic Type: o número herói cresce com o tamanho de fonte do sistema
    // até 1,3× (SOUPM_2_2 §15.2); o resto do card cresce sem limite.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rotulo != null) ...[
            Text(rotulo!.toUpperCase(), style: estiloRotulo(context)),
            const SizedBox(height: 6),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: TextStyle(
                fontSize: tamanho,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
                color: cor,
              ),
            ),
          ),
          if (complemento != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                complemento!,
                maxLines: 1,
                style: TextStyle(
                  fontSize: tamanhoComplemento,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.2,
                  color: cor.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Etiqueta miúda em caixa alta, no azul de acento — "PRÓXIMO PERÍODO".
TextStyle estiloRotulo(BuildContext context) => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: Theme.of(context).colorScheme.primary,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Barra de progresso
// ─────────────────────────────────────────────────────────────────────────────

/// Barra fina, um tom só. Sem texto dentro: rótulo em cima de barra colorida
/// nunca fecha os 4.5:1 em toda a extensão, porque o fundo muda no meio.
class BarraProgressoCartao extends StatelessWidget {
  const BarraProgressoCartao({
    Key? key,
    required this.valor,
    this.valorBase,
    this.altura = 6,
    this.semantica,
  }) : super(key: key);

  /// 0..1 — o total.
  final double valor;

  /// 0..1 — a parte do total que vem da fonte principal. Quando informado, o
  /// trecho restante sai num tom mais claro, que é como o tempo agregado do
  /// IPER aparece sem precisar de uma legenda de quadradinhos coloridos.
  final double? valorBase;

  final double altura;
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final semAnimacao = MediaQuery.of(context).disableAnimations;
    final v = valor.clamp(0.0, 1.0);
    final base = valorBase?.clamp(0.0, v);

    Widget segmento(double fracao, {required bool claro}) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fracao <= 0 ? 0.0001 : fracao,
            child: Container(
              decoration: BoxDecoration(
                gradient: claro ? null : gradienteAcao,
                color:
                    claro ? AppColors.acaoClara.withValues(alpha: 0.55) : null,
                borderRadius: BorderRadius.circular(altura),
              ),
            ),
          ),
        );

    final barra = ClipRRect(
      borderRadius: BorderRadius.circular(altura),
      child: SizedBox(
        height: altura,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: semAnimacao ? 1 : 0, end: 1),
          duration: Duration(milliseconds: semAnimacao ? 0 : 700),
          curve: Curves.easeOutCubic,
          builder: (_, t, __) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: TomCartao.trilho(context)),
              segmento(v * t, claro: base != null),
              if (base != null) segmento(base * t, claro: false),
            ],
          ),
        ),
      ),
    );

    if (semantica == null) return ExcludeSemantics(child: barra);
    return Semantics(
        label: semantica, value: '${(v * 100).round()}%', child: barra);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Peças menores
// ─────────────────────────────────────────────────────────────────────────────

/// Linha divisória interna do card.
class DivisorCartao extends StatelessWidget {
  const DivisorCartao({Key? key, this.espaco = 13}) : super(key: key);

  final double espaco;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: espaco),
        child: Container(height: 1, color: TomCartao.linha(context)),
      );
}

/// Pílula cheia de destaque — "Começam em 69 dias".
class PilulaCartao extends StatelessWidget {
  const PilulaCartao({
    Key? key,
    required this.texto,
    this.icone,
    this.neutra = false,
  }) : super(key: key);

  final String texto;
  final IconData? icone;

  /// Quando o fato já passou, a pílula perde a cor e vira apoio.
  final bool neutra;

  @override
  Widget build(BuildContext context) {
    final corTexto = neutra ? TomCartao.medio(context) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        gradient: neutra ? null : gradienteAcao,
        color: neutra ? TomCartao.trilho(context) : null,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: AppIconSize.xxs + 2, color: corTexto),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: corTexto,
            ),
          ),
        ],
      ),
    );
  }
}

/// Par rótulo em cima, valor embaixo — "Previsão de 30 anos" / "Mar/2051".
class ParCartao extends StatelessWidget {
  const ParCartao({
    Key? key,
    required this.rotulo,
    required this.valor,
    this.corValor,
    this.alinhamento = CrossAxisAlignment.start,
  }) : super(key: key);

  final String rotulo;
  final String valor;
  final Color? corValor;
  final CrossAxisAlignment alinhamento;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: alinhamento,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rotulo,
              style: TextStyle(fontSize: 13, color: TomCartao.medio(context))),
          const SizedBox(height: 3),
          Text(
            valor,
            style: TextStyle(
              fontSize: AppDisplaySize.valor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: corValor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
}

/// Marcador redondo de item concluído / pendente.
class MarcadorCartao extends StatelessWidget {
  const MarcadorCartao({Key? key, required this.concluido}) : super(key: key);

  final bool concluido;

  @override
  Widget build(BuildContext context) {
    if (concluido) {
      return Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          gradient: gradienteAcao,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TomCartao.linha(context), width: 1.4),
      ),
    );
  }
}

/// Rodapé: observação discreta à esquerda, link da ação à direita.
class RodapeCartao extends StatelessWidget {
  const RodapeCartao({
    Key? key,
    this.icone,
    this.texto,
    this.acaoTexto,
  }) : super(key: key);

  final IconData? icone;
  final String? texto;
  final String? acaoTexto;

  @override
  Widget build(BuildContext context) {
    final primaria = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: AppIconSize.xs, color: TomCartao.fraco(context)),
          const SizedBox(width: 7),
        ],
        if (texto != null)
          Expanded(
            child: Text(
              texto!,
              style: TextStyle(fontSize: 12, color: TomCartao.fraco(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Spacer(),
        if (acaoTexto != null) ...[
          const SizedBox(width: 8),
          Text(
            acaoTexto!,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: primaria),
          ),
          Icon(Icons.chevron_right_rounded,
              size: AppIconSize.xs, color: primaria),
        ],
      ],
    );
  }
}
