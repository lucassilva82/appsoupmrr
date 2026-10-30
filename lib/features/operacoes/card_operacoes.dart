import 'package:flutter/material.dart';

import '../../core/design/arte_cartao.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';
import '../../widgets/cartao_painel.dart';
import 'meu_servico.dart';
import 'operacoes_page.dart';
import 'operar_api.dart';

/// Card da Início: o serviço do militar na operação em curso.
///
/// Card de resumo da Início, então `CartaoArte` com a arte da área
/// `operacional` e a gramática do DESIGN §2b — cabeçalho discreto, um número
/// grande, apoio, rodapé. Quem aplica o `temaSobreArte` é o `_Card` da
/// home_page, que também trata a função bloqueada no painel.
///
/// O card é FIXO (decisão do usuário, 30/10/2026): sem escala, sem rede ou
/// ainda carregando, ele continua na tela e explica. Card que some é função
/// que o militar deixa de descobrir — ele só saberia que o módulo existe
/// depois de ser escalado, que é tarde demais.
class CardOperacoes extends StatefulWidget {
  const CardOperacoes({super.key});

  @override
  State<CardOperacoes> createState() => _CardOperacoesState();
}

class _CardOperacoesState extends State<CardOperacoes> {
  Future<({MeuServicoOperacao? servico, SessaoOperar? sessao})>? _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<({MeuServicoOperacao? servico, SessaoOperar? sessao})> _carregar() async {
    final sessao = await SessaoOperar.doLoginAtual();
    if (sessao == null) return (servico: null, sessao: null);
    try {
      final s = await MeuServicoApi(api: ApiClient(), sessao: sessao).ler();
      return (servico: s, sessao: sessao);
    } on FalhaApp {
      // Operar fora do ar, aparelho desligado do outro lado, sem rede: o card
      // continua e diz o que sabe. Quem toca cai no Operar, que explica o
      // próprio erro melhor do que eu adivinharia daqui.
      return (servico: null, sessao: sessao);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({MeuServicoOperacao? servico, SessaoOperar? sessao})>(
      future: _futuro,
      builder: (context, snap) => _Corpo(
        servico: snap.data?.servico,
        sessao: snap.data?.sessao,
        carregando: snap.connectionState != ConnectionState.done,
      ),
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
    final servico = this.servico;
    final s = servico?.proximo;

    return CartaoArte(
      arte: Arte.de('operacional'),
      padding: EdgeInsets.zero,
      onTap: carregando
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OperacoesPage(sessao: sessao)),
              ),
      child: Padding(
        padding: kPaddingCartao,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CabecalhoCartao(
              icone: Icons.shield_outlined,
              titulo: 'Operações',
              meta: servico?.evento,
              mostrarSeta: !carregando,
            ),
            const SizedBox(height: 12),
            if (s == null) ..._semServico(context) else ..._comServico(context, s, servico!),
          ],
        ),
      ),
    );
  }

  /// Sem escala, sem resposta ou carregando: uma frase no lugar do número.
  /// Não há dado para pôr em destaque, e inventar um seria pior.
  List<Widget> _semServico(BuildContext context) {
    final theme = Theme.of(context);
    final (titulo, apoio) = carregando
        ? ('Procurando o seu serviço…', null)
        : servico == null
            ? (
                'Não deu para consultar agora',
                'Toque para abrir — lá dentro o Operar explica o porquê.',
              )
            : (
                'Sem escala para você ainda',
                'Quando você for escalado numa operação, o seu posto, o horário '
                    'e a equipe aparecem aqui.',
              );
    return [
      // A cor vem do colorScheme, não do textTheme: o `temaSobreArte` troca só
      // o `onSurface` para branco e não refaz o textTheme, então um
      // `titleMedium` sai com a cor do tema claro — escuro sobre arte escura.
      Text(
        titulo,
        style: TextStyle(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      if (apoio != null) ...[
        const SizedBox(height: 4),
        Text(apoio, style: TextStyle(fontSize: 12.5, height: 1.35, color: TomCartao.medio(context))),
      ],
    ];
  }

  /// Com escala: o dia em destaque, o posto como apoio, a função no rodapé.
  List<Widget> _comServico(BuildContext context, ServicoOperacao s, MeuServicoOperacao servico) {
    if (s.restrita) {
      return [
        DestaqueCartao(valor: _dia(s.data), rotulo: 'Seu serviço'),
        const SizedBox(height: 10),
        RodapeCartao(icone: Icons.lock_outline, texto: s.escala, acaoTexto: 'Abrir'),
      ];
    }
    final horario = [s.horaInicio, s.horaFim].whereType<String>().join(' às ');
    final onde = s.local ?? s.posto;
    final outros = servico.servicos.length - 1;
    return [
      DestaqueCartao(
        valor: _dia(s.data),
        complemento: horario.isEmpty ? null : horario,
        rotulo: 'Seu serviço',
      ),
      if (onde != null) ...[
        const SizedBox(height: 10),
        Text(
          onde,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppDisplaySize.valor,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (s.municipio != null)
          Text(
            s.municipio!,
            style: TextStyle(fontSize: 12.5, color: TomCartao.medio(context)),
          ),
      ],
      const SizedBox(height: 10),
      RodapeCartao(
        icone: Icons.badge_outlined,
        texto: [
          if (s.funcao != null) s.funcao!.replaceAll('_', ' '),
          if (outros > 0) '+$outros serviço${outros > 1 ? 's' : ''} na operação',
        ].join(' · '),
        acaoTexto: 'Abrir',
      ),
    ];
  }
}
