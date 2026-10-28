import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entrada suave na Início depois do login (pedido do usuário, 26/10/2026:
// "carrega a página inicial de uma vez, fica muito brusco").
//
// Só na entrada depois do login ou do Face ID/digital: a Início chega com
// esmaecimento e uma leve subida (rotaEntradaInicio) e os blocos aparecem em
// cascata (SurgeEntrada). Trocar de aba, voltar do fundo ou abrir o app já
// logado não anima. Com "Reduzir movimento", nada se mexe.
// Durações e curvas do DESIGN §7: só opacidade e deslocamento, nada de escala.
// ─────────────────────────────────────────────────────────────────────────────

class EntradaInicio {
  EntradaInicio._();

  /// Ligado no instante do login; a Início consome e desliga.
  static bool pendente = false;

  /// Intervalo entre um bloco e o seguinte na cascata.
  static const passo = Duration(milliseconds: 55);

  /// Duração de cada bloco (DESIGN §7: abrir/expandir, 240–320 ms).
  static const duracao = Duration(milliseconds: 300);

  /// Até quantos blocos entram em cascata; os de baixo, fora da tela, já
  /// aparecem prontos (o total fica abaixo de 1 s).
  static const maxEmCascata = 8;

  /// Enquanto verdadeiro, a cascata espera (o convite do Face ID ou da
  /// digital está aberto por cima da Início; animar por trás dele seria
  /// animar para ninguém ver). Ligado em main.dart ao `entradaEmAndamento`.
  static ValueListenable<bool>? aguardar;

  static DateTime? _terminaEm;

  static void _marcarFim(Duration daqui) {
    final fim = DateTime.now().add(daqui);
    final atual = _terminaEm;
    if (atual == null || fim.isAfter(atual)) _terminaEm = fim;
  }

  /// Espera a cascata em andamento terminar (com folga de um instante). O
  /// comunicado de abertura usa isto para não cobrir a Início enquanto ela
  /// ainda está entrando. Sem cascata, volta na hora.
  static Future<void> esperarTerminar() async {
    final fim = _terminaEm;
    if (fim == null) return;
    final falta = fim.difference(DateTime.now());
    if (falta > Duration.zero) await Future<void>.delayed(falta + const Duration(milliseconds: 250));
  }
}

/// Esmaece e sobe a Início por cima da tela de entrada (420 ms, easeOutCubic).
/// Usado pela rota de entrada e pela troca do AuthOrHome.
Widget transicaoEntrada(BuildContext context, Animation<double> animacao, Widget filho) {
  if (MediaQuery.disableAnimationsOf(context)) return filho;
  final curva = CurvedAnimation(parent: animacao, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curva,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, .02), end: Offset.zero).animate(curva),
      child: filho,
    ),
  );
}

/// A rota da Início depois do login: esmaece e sobe 16 pt por cima da tela de
/// entrada, em vez do corte seco.
Route<T> rotaEntradaInicio<T>(WidgetBuilder construtor, {RouteSettings? settings}) => PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, _, __) => construtor(context),
      transitionsBuilder: (context, animacao, _, filho) => transicaoEntrada(context, animacao, filho),
    );

/// Um bloco da Início que entra em cascata na primeira exibição depois do
/// login ([indice] decide o atraso). Fora disso, desenha o filho direto.
class SurgeEntrada extends StatefulWidget {
  const SurgeEntrada({super.key, required this.indice, required this.child, this.ativa});

  final int indice;
  final Widget child;

  /// Força ligar/desligar (testes); nulo = segue [EntradaInicio.pendente].
  final bool? ativa;

  @override
  State<SurgeEntrada> createState() => _SurgeEntradaState();
}

class _SurgeEntradaState extends State<SurgeEntrada> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final ligada = (widget.ativa ?? EntradaInicio.pendente) &&
        widget.indice < EntradaInicio.maxEmCascata &&
        !MediaQuery.disableAnimationsOf(context);
    if (!ligada) return;
    _c = AnimationController(vsync: this, duration: EntradaInicio.duracao);
    final aguardar = EntradaInicio.aguardar;
    if (aguardar != null && aguardar.value) {
      _aguardar = aguardar..addListener(_quandoLiberar);
    } else {
      _comecar();
    }
  }

  ValueListenable<bool>? _aguardar;

  void _quandoLiberar() {
    if (_aguardar?.value ?? false) return;
    _aguardar?.removeListener(_quandoLiberar);
    _aguardar = null;
    _comecar();
  }

  // Começa ≈150 ms depois do primeiro quadro da Início, um bloco por vez. O
  // relógio só corre depois desse quadro: montar a Início pela primeira vez
  // demora, e contar o tempo durante a montagem fazia a cascata pular.
  void _comecar() {
    final atraso = const Duration(milliseconds: 150) + EntradaInicio.passo * widget.indice;
    EntradaInicio._marcarFim(atraso + EntradaInicio.duracao + const Duration(milliseconds: 100));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(atraso, () {
        if (mounted) _c?.forward();
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _aguardar?.removeListener(_quandoLiberar);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    final curva = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curva,
      builder: (_, filho) => Opacity(
        opacity: curva.value,
        child: Transform.translate(offset: Offset(0, 14 * (1 - curva.value)), child: filho),
      ),
      child: widget.child,
    );
  }
}
