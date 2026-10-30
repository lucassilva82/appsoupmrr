import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/erros/falha_app.dart';
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

  Future<({MeuServicoOperacao? servico, SessaoOperar? sessao})>? _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  /// Desligado no painel: nem chama o Operar, e o card some. É o único jeito de
  /// ele sumir — ver [build].
  ///
  /// Chave que o painel ainda não conhece NÃO esconde o card: é a mesma regra
  /// do `_Card` da Início (home_page.dart), item nulo vale como permitido.
  bool get _desligadoNoPainel {
    final item = RepositorioConfig.atual.item(_chaveFuncao);
    return item != null && (!item.visivel || item.bloqueado);
  }

  Future<({MeuServicoOperacao? servico, SessaoOperar? sessao})> _carregar() async {
    final sessao = await SessaoOperar.doLoginAtual();
    if (sessao == null) return (servico: null, sessao: null);
    try {
      final s = await MeuServicoApi(api: ApiClient(), sessao: sessao).ler();
      return (servico: s, sessao: sessao);
    } on FalhaApp {
      // Operar fora do ar, aparelho desligado do outro lado, sem rede: o card
      // continua na tela e diz o que sabe. Quem toca cai no Operar, que mostra
      // o erro dele — melhor que um buraco na Início.
      return (servico: null, sessao: sessao);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_desligadoNoPainel) return const SizedBox.shrink();
    return FutureBuilder<({MeuServicoOperacao? servico, SessaoOperar? sessao})>(
      future: _futuro,
      builder: (context, snap) {
        // O card é FIXO (decisão do usuário, 30/10/2026): sem escala, sem rede
        // ou ainda carregando, ele continua na tela e explica. Some só quando o
        // painel desliga a função. Card que some é função que o militar deixa
        // de descobrir.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Corpo(
            servico: snap.data?.servico,
            sessao: snap.data?.sessao,
            carregando: snap.connectionState != ConnectionState.done,
          ),
        );
      },
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({required this.servico, required this.sessao, this.carregando = false});

  final MeuServicoOperacao? servico;
  final SessaoOperar? sessao;
  final bool carregando;

  /// "2026-11-03" -> "03/11"
  static String _dia(String iso) =>
      iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : iso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servico = this.servico;
    final s = servico?.proximo;
    void abrir() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OperacoesPage(sessao: sessao)),
        );

    // Sem serviço ainda: o card continua, dizendo o que há para dizer. É
    // assim que o militar fica sabendo que o módulo existe antes de ser
    // escalado pela primeira vez.
    if (s == null) {
      return CartaoVidro(
        raio: 16,
        padding: const EdgeInsets.all(14),
        onTap: carregando ? null : abrir,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoCartao(
              icone: Icons.shield_outlined,
              titulo: 'Operações',
              meta: servico?.evento,
              mostrarSeta: !carregando,
            ),
            const SizedBox(height: 10),
            Text(
              carregando
                  ? 'Procurando o seu serviço…'
                  : servico == null
                      ? 'Não deu para consultar agora. Toque para abrir.'
                      : 'Sem escala para você ainda.',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (!carregando) ...[
              const SizedBox(height: 2),
              Text(
                servico == null
                    ? 'O Operar não respondeu. Lá dentro ele explica o porquê.'
                    : 'Quando você for escalado numa operação, o seu posto, o '
                        'horário e a equipe aparecem aqui.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    final horario = [s.horaInicio, s.horaFim].whereType<String>().join(' às ');
    final onde = s.local ?? s.posto;
    return CartaoVidro(
      raio: 16,
      padding: const EdgeInsets.all(14),
      onTap: abrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabecalhoCartao(
            icone: Icons.shield_outlined,
            titulo: 'Operações',
            meta: servico!.evento,
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
