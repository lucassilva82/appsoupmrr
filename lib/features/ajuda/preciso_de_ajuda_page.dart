import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/design/arte_cartao.dart';
import '../../core/log/registro_log.dart';
import '../../core/navegacao/abrir_funcao.dart';
import '../../models/auth_model.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import '../servicos/servicos_page.dart';
import 'ajuda_modelo.dart';

/// "Preciso de ajuda" (docs/SOUPM_2_2.md §8.0): assunto → perguntas →
/// resposta → "Isso resolveu?". Se não resolveu, termina num chamado
/// técnico. Eventos: ajuda.ver, ajuda.resolveu, ajuda.abriu_chamado.
class PrecisoDeAjudaPage extends StatelessWidget {
  const PrecisoDeAjudaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final assuntos = RepositorioConfig.atual.ajuda ?? ajudaPadrao;
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Preciso de ajuda'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
              child: Text('Como podemos ajudar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
              child: Text(
                  'Escolha o assunto. Mostramos as respostas mais comuns e, se não resolver, você abre um chamado e a equipe do DTI resolve por ele.',
                  style: TextStyle(fontSize: 13.5, color: mudo)),
            ),
            // 2 colunas (3 no iPad); a linha cresce até o ladrilho mais alto.
            LayoutBuilder(builder: (context, c) {
              final colunas = c.maxWidth >= 600 ? 3 : 2;
              final linhas = [
                for (var i = 0; i < assuntos.length; i += colunas)
                  assuntos.sublist(i, (i + colunas).clamp(0, assuntos.length)),
              ];
              return Column(children: [
                for (final (n, linha) in linhas.indexed) ...[
                  if (n > 0) const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (var j = 0; j < colunas; j++) ...[
                        if (j > 0) const SizedBox(width: 10),
                        Expanded(
                          child: j < linha.length
                              ? _CartaoAssunto(
                                  assunto: linha[j],
                                  aoTocar: () => Navigator.of(context)
                                      .push(MaterialPageRoute(builder: (_) => _PerguntasPage(assunto: linha[j]))),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ]),
                  ),
                ],
              ]);
            }),
            const SizedBox(height: 12),
            const _CartaoFim(
              titulo: 'Não achou o assunto?',
              texto: 'Abra um chamado técnico. Você acompanha tudo em Meus chamados.',
              filho: _BotaoChamado(),
            ),
            const _LinkSugestoes(),
          ],
        ),
      ),
    );
  }
}

/// Assunto em ladrilho (protótipo `.ch-cat`): ícone num quadrado tingido,
/// nome e quantas respostas há.
class _CartaoAssunto extends StatelessWidget {
  const _CartaoAssunto({required this.assunto, required this.aoTocar});
  final AjudaAssunto assunto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    final n = assunto.perguntas.length;
    return CartaoVidro(
      raio: 16,
      padding: const EdgeInsets.all(12),
      onTap: aoTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 87),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: pri.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(iconePorChave(assunto.icone), size: AppIconSize.sm, color: pri),
          ),
          Text(assunto.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('$n ${n == 1 ? 'resposta' : 'respostas'}',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
        ]),
      ),
    );
  }
}

/// Cartão do fim da tela (protótipo `.aj-fim`): título, texto e a ação.
class _CartaoFim extends StatelessWidget {
  const _CartaoFim({required this.titulo, this.texto, required this.filho, this.centro = false});
  final String titulo;
  final String? texto;
  final Widget filho;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CartaoVidro(
      raio: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: centro ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (texto != null) ...[
            const SizedBox(height: 4),
            Text(texto!,
                textAlign: centro ? TextAlign.center : TextAlign.start,
                style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
          ],
          const SizedBox(height: 10),
          filho,
        ],
      ),
    );
  }
}

class _PerguntasPage extends StatelessWidget {
  const _PerguntasPage({required this.assunto});

  final AjudaAssunto assunto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;
    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: assunto.nome),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (assunto.perguntas.isEmpty)
              Text('Ainda não há perguntas sobre este assunto. Se precisar, abra um chamado técnico.',
                  style: theme.textTheme.bodyMedium)
            else
              CartaoVidro(
                raio: 16,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final p in assunto.perguntas)
                    InkWell(
                      onTap: () {
                        registrar('ajuda.ver',
                            chave: 'atend.ajuda', dados: {'assunto': assunto.chave, 'pergunta': p.id});
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => _RespostaPage(assunto: assunto, pergunta: p)));
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Icon(Icons.help_outline_rounded, size: AppIconSize.sm, color: pri),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(p.pergunta,
                                  style: TextStyle(
                                      fontSize: 15.5, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: AppIconSize.sm, color: theme.colorScheme.onSurface.withValues(alpha: .38)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 12),
            _CartaoFim(titulo: 'Sua dúvida não está aqui?', filho: _BotaoChamado(assunto: assunto.chave)),
          ],
        ),
      ),
    );
  }
}

class _RespostaPage extends StatefulWidget {
  const _RespostaPage({required this.assunto, required this.pergunta});

  final AjudaAssunto assunto;
  final AjudaPergunta pergunta;

  @override
  State<_RespostaPage> createState() => _RespostaPageState();
}

class _RespostaPageState extends State<_RespostaPage> {
  bool _resolveu = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    final p = widget.pergunta;
    final destino =
        p.destino == null ? null : itemPorChave(p.destino!, menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: widget.assunto.nome),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            CartaoVidro(
              raio: 16,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p.pergunta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(p.resposta, style: TextStyle(fontSize: 15, height: 1.5, color: theme.colorScheme.onSurface)),
                if (destino != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: Icon(iconePorChave(destino.icone), size: AppIconSize.sm),
                    label: Text('Ir para ${destino.rotulo}'),
                    onPressed: () => abrirFuncao(context, destino, origem: 'ajuda'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            if (_resolveu)
              CartaoVidro(
                raio: 16,
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.sucesso.withValues(alpha: .14), shape: BoxShape.circle),
                    child: const Icon(Icons.thumb_up_rounded, color: AppColors.sucesso, size: AppIconSize.md),
                  ),
                  const SizedBox(height: 6),
                  const Text('Que bom que resolveu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      // Resposta → perguntas → assuntos.
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.pop();
                    },
                    child: const Text('Voltar aos assuntos'),
                  ),
                ]),
              )
            else
              _CartaoFim(
                titulo: 'Isso resolveu?',
                centro: true,
                filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  OutlinedButton(
                    onPressed: () {
                      registrar('ajuda.resolveu',
                          chave: 'atend.ajuda', dados: {'assunto': widget.assunto.chave, 'pergunta': p.id});
                      setState(() => _resolveu = true);
                    },
                    child: const Text('Sim, resolveu'),
                  ),
                  const SizedBox(height: 8),
                  _BotaoChamado(assunto: widget.assunto.chave, pergunta: p.id, rotulo: 'Não, abrir chamado'),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Abrir chamado técnico". Os chamados no app chegam na fase 3c; até lá a
/// função vem bloqueada e o toque mostra a folha com o motivo e o código.
class _BotaoChamado extends StatelessWidget {
  const _BotaoChamado({this.assunto, this.pergunta, this.rotulo = 'Abrir chamado técnico'});

  final String? assunto;
  final int? pergunta;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.confirmation_number_outlined, size: AppIconSize.sm),
        label: Text(rotulo),
        onPressed: () {
          registrar('ajuda.abriu_chamado', chave: 'atend.ajuda', dados: {'assunto': assunto, 'pergunta': pergunta});
          final gestor = context.read<Auth>().isSuperUser;
          final chamados = itemPorChave('atend.chamados', menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
          if (chamados == null) {
            avisoInfo(context, 'Chamados no app em breve');
            return;
          }
          abrirFuncao(context, chamados, origem: 'ajuda');
        },
      ),
    );
  }
}

class _LinkSugestoes extends StatelessWidget {
  const _LinkSugestoes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.FEEDBACK),
          icon: const Icon(Icons.lightbulb_outline_rounded, size: AppIconSize.xs),
          label: const Text('Tem uma ideia para o app? Sugestões e elogios'),
        ),
      ),
    );
  }
}
