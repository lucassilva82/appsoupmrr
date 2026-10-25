import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'arte_cartao.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Folha com arte (padrão 2.2, DESIGN §11)
//
// Toda folha que sobe de baixo (escolher a certidão, filtros, detalhes,
// "Mais") usa este desenho: uma faixa com a arte da área no topo (degradê,
// trilhas, ícones apagados), a alça, o ícone num quadrado de vidro e o
// título; o conteúdo vem embaixo, no fundo da superfície do tema. Antes cada
// tela montava a própria folha, branca ou cinza, sem a cara do app.
// ─────────────────────────────────────────────────────────────────────────────

/// Abre uma folha com arte. [corpo] recebe o contexto da folha (para fechar
/// com `Navigator.pop(ctx, valor)`). Com [rolavel], o corpo rola quando passa
/// da altura; a folha nunca passa de 90% da tela.
Future<T?> mostrarFolhaArte<T>(
  BuildContext context, {
  required Arte arte,
  required IconData icone,
  required String titulo,
  String? subtitulo,
  required Widget Function(BuildContext ctx) corpo,
  bool rolavel = true,
  EdgeInsetsGeometry paddingCorpo = const EdgeInsets.fromLTRB(16, 14, 16, 16),
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => FolhaArte(
      arte: arte,
      icone: icone,
      titulo: titulo,
      subtitulo: subtitulo,
      rolavel: rolavel,
      paddingCorpo: paddingCorpo,
      child: Builder(builder: corpo),
    ),
  );
}

/// O desenho da folha, para quem já tem o próprio `showModalBottomSheet`
/// (passe `backgroundColor: Colors.transparent`).
class FolhaArte extends StatelessWidget {
  const FolhaArte({
    super.key,
    required this.arte,
    required this.icone,
    required this.titulo,
    required this.child,
    this.subtitulo,
    this.rolavel = true,
    this.paddingCorpo = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final Arte arte;
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final Widget child;
  final bool rolavel;
  final EdgeInsetsGeometry paddingCorpo;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    const raio = Radius.circular(28);
    final corpo = Padding(
      padding: paddingCorpo.add(EdgeInsets.only(bottom: mq.viewInsets.bottom + mq.padding.bottom)),
      child: child,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * .9),
      child: Material(
        color: escuro ? const Color(0xFF10161F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: raio),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoFolhaArte(arte: arte, icone: icone, titulo: titulo, subtitulo: subtitulo),
          if (rolavel) Flexible(child: SingleChildScrollView(child: corpo)) else corpo,
        ]),
      ),
    );
  }
}

/// A faixa de cima da folha: arte cheia, alça, ícone e título em branco.
class CabecalhoFolhaArte extends StatelessWidget {
  const CabecalhoFolhaArte({
    super.key,
    required this.arte,
    required this.icone,
    required this.titulo,
    this.subtitulo,
  });

  final Arte arte;
  final IconData icone;
  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return FundoArte(
      arte: arte,
      raio: 0,
      tamanhoIcone: 84,
      child: Semantics(
        header: true,
        label: [titulo, if (subtitulo != null) subtitulo].join('. '),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Column(children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: .22)),
                ),
                child: Icon(icone, color: Colors.white, size: AppIconSize.md),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo!,
                        style: TextStyle(fontSize: 13, height: 1.3, color: Colors.white.withValues(alpha: .84))),
                  ],
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
