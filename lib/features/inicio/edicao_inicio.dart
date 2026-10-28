import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import 'preferencias_inicio.dart';

/// O estado de edição da Início, igual para a edição na própria tela e para a
/// tela "Personalizar início".
///
/// As duas precisam da mesma regra: a ordem atual **com os escondidos no
/// lugar deles**, para o militar ver o que escondeu e poder trazer de volta.
/// Por isso [ordenarBlocos] é chamada com todos marcados como visíveis — ela
/// resolve a junção com o painel — e os escondidos saem à parte.
({List<BlocoInicio> blocos, Set<String> escondidos}) montarEdicao(
  List<BlocoInicio> doPainel,
  PreferenciasInicio? pref,
) {
  final porChave = {for (final b in doPainel) b.chave: b};
  final todos = ordenarBlocos(
    doPainel,
    pref == null
        ? null
        : PreferenciasInicio(
            blocos: [for (final b in pref.blocos) (chave: b.chave, visivel: true)],
          ),
  );
  return (
    blocos: [for (final c in todos) porChave[c]!],
    escondidos: {
      for (final b in pref?.blocos ?? const <({String chave, bool visivel})>[])
        if (!b.visivel && (porChave[b.chave]?.escondivel ?? false)) b.chave,
    },
  );
}

/// O tremor do modo de edição, no espírito do iOS.
///
/// Oscila a peça por volta de um terço de grau em torno do centro, com um fio
/// de deslocamento. A fase nasce da [semente] (a posição do bloco) para que os
/// cartões não tremam em uníssono, que é o que denuncia a animação como falsa.
///
/// Usa `Transform`, que pinta fora do layout: a regra do DESIGN.md §7 —
/// *estado não muda layout* — continua valendo, e a Início não se remexe ao
/// entrar em edição.
///
/// Com **Reduzir movimento** ligado não treme. O modo de edição continua
/// evidente pela borda tracejada, pelo botão de esconder e pela barra do topo,
/// que não dependem de animação.
class BlocoTremendo extends StatefulWidget {
  const BlocoTremendo({
    super.key,
    required this.tremendo,
    required this.semente,
    required this.child,
  });

  final bool tremendo;
  final int semente;
  final Widget child;

  @override
  State<BlocoTremendo> createState() => _BlocoTremendoState();
}

class _BlocoTremendoState extends State<BlocoTremendo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // Entre 150 e 190 ms por meio ciclo: cada bloco com o seu, de novo para
    // que o conjunto não pareça uma coisa só.
    duration: Duration(milliseconds: 150 + (widget.semente % 5) * 10),
  );

  @override
  void initState() {
    super.initState();
    if (widget.tremendo) _comecar();
  }

  @override
  void didUpdateWidget(covariant BlocoTremendo anterior) {
    super.didUpdateWidget(anterior);
    if (widget.tremendo == anterior.tremendo) return;
    if (widget.tremendo) {
      _comecar();
    } else {
      _c.stop();
      _c.value = 0.5; // volta ao repouso (ângulo zero)
    }
  }

  void _comecar() {
    _c.value = 0.5 + (widget.semente.isEven ? 0.18 : -0.18);
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.tremendo || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _c,
      // O filho é construído uma vez e só reposicionado a cada quadro.
      child: widget.child,
      builder: (context, filho) {
        final t = (_c.value - 0.5) * 2; // -1 .. 1
        return Transform.translate(
          offset: Offset(t * 0.8, 0),
          child: Transform.rotate(angle: t * 0.006, child: filho),
        );
      },
    );
  }
}
