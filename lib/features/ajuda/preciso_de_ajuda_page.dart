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
    final assuntos = RepositorioConfig.atual.ajuda ?? ajudaPadrao;
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Preciso de ajuda'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Sobre o que é a sua dúvida?',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final colunas = c.maxWidth >= 600 ? 3 : 2;
              final largura = (c.maxWidth - 10 * (colunas - 1)) / colunas;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final a in assuntos)
                  SizedBox(
                    width: largura,
                    child: CartaoVidro(
                      raio: 16,
                      padding: const EdgeInsets.all(14),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _PerguntasPage(assunto: a))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(iconePorChave(a.icone),
                            color: theme.colorScheme.primary, size: AppIconSize.lg),
                        const SizedBox(height: 10),
                        Text(a.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 20),
            const _BotaoChamado(),
            const _LinkSugestoes(),
          ],
        ),
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
    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: assunto.nome),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (assunto.perguntas.isEmpty)
              Text('Ainda não há perguntas sobre este assunto. Se precisar, abra um chamado técnico.',
                  style: theme.textTheme.bodyMedium),
            for (final p in assunto.perguntas) ...[
              CartaoVidro(
                raio: 12,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                onTap: () {
                  registrar('ajuda.ver', chave: 'atend.ajuda',
                      dados: {'assunto': assunto.chave, 'pergunta': p.id});
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _RespostaPage(assunto: assunto, pergunta: p)));
                },
                child: Row(children: [
                  Expanded(
                      child: Text(p.pergunta,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_right_rounded,
                      size: AppIconSize.sm, color: theme.colorScheme.onSurfaceVariant),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const _BotaoChamado(),
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
  bool? _resolveu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gestor = context.select<Auth, bool>((a) => a.isSuperUser);
    final p = widget.pergunta;
    final destino = p.destino == null
        ? null
        : itemPorChave(p.destino!, menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Resposta'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(p.pergunta,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            CartaoVidro(
              raio: 16,
              padding: const EdgeInsets.all(16),
              child: Text(p.resposta, style: theme.textTheme.bodyLarge),
            ),
            if (destino != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: Icon(iconePorChave(destino.icone), size: AppIconSize.sm),
                label: Text('Ir para ${destino.rotulo}'),
                onPressed: () => abrirFuncao(context, destino, origem: 'ajuda'),
              ),
            ],
            const SizedBox(height: 24),
            if (_resolveu == null) ...[
              Text('Isso resolveu?',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      registrar('ajuda.resolveu', chave: 'atend.ajuda',
                          dados: {'assunto': widget.assunto.chave, 'pergunta': p.id});
                      setState(() => _resolveu = true);
                    },
                    child: const Text('Sim, resolveu'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _resolveu = false),
                    child: const Text('Não resolveu'),
                  ),
                ),
              ]),
            ] else if (_resolveu!) ...[
              Row(children: [
                Icon(Icons.check_circle_outline_rounded, color: AppColors.sucesso, size: AppIconSize.md),
                const SizedBox(width: 8),
                Expanded(child: Text('Que bom. Se precisar, é só voltar aqui.', style: theme.textTheme.bodyLarge)),
              ]),
            ] else ...[
              Text('Abra um chamado técnico: a equipe do DTI recebe a sua dúvida e responde por ele.',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 10),
              _BotaoChamado(assunto: widget.assunto.chave, pergunta: p.id),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Abrir chamado técnico". Os chamados no app chegam na fase 3c; até lá a
/// função vem bloqueada e o toque mostra a folha com o motivo e o código.
class _BotaoChamado extends StatelessWidget {
  const _BotaoChamado({this.assunto, this.pergunta});

  final String? assunto;
  final int? pergunta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.support_agent_outlined, size: AppIconSize.sm),
        label: const Text('Abrir chamado técnico'),
        onPressed: () {
          registrar('ajuda.abriu_chamado', chave: 'atend.ajuda',
              dados: {'assunto': assunto, 'pergunta': pergunta});
          final gestor = context.read<Auth>().isSuperUser;
          final chamados =
              itemPorChave('atend.chamados', menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
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
        child: TextButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.FEEDBACK),
          child: const Text('Tem uma ideia para o app? Sugestões e elogios'),
        ),
      ),
    );
  }
}
