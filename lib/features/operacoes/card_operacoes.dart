import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/rede/api_client.dart';
import '../../widgets/cartao_painel.dart';
import '../../widgets/vidro.dart';
import 'meu_servico.dart';
import 'operacoes_page.dart';
import 'operar_api.dart';

/// Card da Início: o serviço do militar na operação em curso.
///
/// Ele só existe quando há serviço. Sem escala, sem login, módulo desligado no
/// painel ou Operar fora do ar, o card **não desenha** — é o mesmo contrato do
/// `CardPainel.desenha`: card de dado que não tem dado não vira card vazio.
class CardOperacoes extends StatefulWidget {
  const CardOperacoes({super.key});

  @override
  State<CardOperacoes> createState() => _CardOperacoesState();
}

class _CardOperacoesState extends State<CardOperacoes> {
  static const _chaveFuncao = OperarApi.chaveLog;

  Future<({MeuServicoOperacao servico, SessaoOperar sessao})?>? _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<({MeuServicoOperacao servico, SessaoOperar sessao})?> _carregar() async {
    // Desligado no painel: nem chama o Operar. É assim que o módulo se liga e
    // desliga sem publicar versão.
    //
    // Chave que o painel ainda não conhece NÃO esconde o card — é a mesma
    // regra do `_Card` da Início (home_page.dart): item nulo vale como
    // permitido. Esconder aqui deixaria o módulo morto até alguém cadastrar a
    // chave, e o militar não saberia por quê.
    final item = RepositorioConfig.atual.item(_chaveFuncao);
    if (item != null && (!item.visivel || item.bloqueado)) return null;
    final sessao = await SessaoOperar.doLoginAtual();
    if (sessao == null) return null;
    final api = MeuServicoApi(api: ApiClient(), sessao: sessao);
    final s = await api.ler();
    return s.temServico ? (servico: s, sessao: sessao) : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({MeuServicoOperacao servico, SessaoOperar sessao})?>(
      future: _futuro,
      builder: (context, snap) {
        final d = snap.data;
        // Enquanto carrega, e em qualquer falha, o card não ocupa espaço: a
        // Início não pode ficar com um buraco por causa de outro sistema.
        if (d == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Corpo(servico: d.servico, sessao: d.sessao),
        );
      },
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({required this.servico, required this.sessao});

  final MeuServicoOperacao servico;
  final SessaoOperar sessao;

  /// "2026-11-03" -> "03/11"
  static String _dia(String iso) =>
      iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : iso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = servico.proximo!;
    final horario = [s.horaInicio, s.horaFim].whereType<String>().join(' às ');
    final onde = s.local ?? s.posto;
    return CartaoVidro(
      raio: 16,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OperacoesPage(sessao: sessao)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabecalhoCartao(
            icone: Icons.shield_outlined,
            titulo: 'Operações',
            meta: servico.evento,
          ),
          const SizedBox(height: 10),
          if (s.restrita)
            Text(s.escala, style: theme.textTheme.titleSmall)
          else ...[
            Text(
              onde ?? s.escala,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (s.municipio != null) ...[
              const SizedBox(height: 2),
              Text(s.municipio!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ParCartao(rotulo: 'Dia', valor: _dia(s.data))),
                if (horario.isNotEmpty)
                  Expanded(child: ParCartao(rotulo: 'Horário', valor: horario)),
                if (s.funcao != null)
                  Expanded(
                    child: ParCartao(rotulo: 'Função', valor: s.funcao!.replaceAll('_', ' ')),
                  ),
              ],
            ),
          ],
          if (servico.servicos.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              '+${servico.servicos.length - 1} serviço${servico.servicos.length > 2 ? 's' : ''} na operação',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
