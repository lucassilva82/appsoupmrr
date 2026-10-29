import 'package:flutter/material.dart';

import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';
import '../../utils/app_theme.dart';

/// Efetivo previsto × existente do Mapa da Força (API: sigrh/mapa_efetivo.php).
///
/// A regra que governa esta tela: **"não há previsão" e "ocupação zero" são
/// coisas diferentes** (APRENDIZADOS §37). Sem vaga prevista o percentual vem
/// nulo da API e a tela escreve "sem previsão", nunca 0%.

/// Previsto × existente de um escopo qualquer.
class Ocupacao {
  const Ocupacao({
    required this.previsto,
    required this.existente,
    required this.faltam,
    required this.excedente,
    this.pct,
  });

  final int previsto;
  final int existente;
  final int faltam;
  final int excedente;

  /// Nulo quando não há vaga prevista: a tela não inventa 0%.
  final double? pct;

  bool get semPrevisao => previsto <= 0;
  bool get temExcedente => excedente > 0;

  static Ocupacao deJson(Map j) => Ocupacao(
        previsto: (j['previsto'] as num?)?.toInt() ?? 0,
        existente: (j['existente'] as num?)?.toInt() ?? 0,
        faltam: (j['faltam'] as num?)?.toInt() ?? 0,
        excedente: (j['excedente'] as num?)?.toInt() ?? 0,
        pct: (j['pct'] as num?)?.toDouble(),
      );
}

/// Uma linha da lista: um comando, uma unidade, uma subunidade ou um posto.
class ItemEfetivo {
  const ItemEfetivo({required this.chave, required this.nome, required this.ocupacao, this.descricao});

  /// Id numérico (comando/unidade/subunidade) ou a sigla do posto.
  final String chave;
  final String nome;
  final String? descricao;
  final Ocupacao ocupacao;

  static ItemEfetivo deJson(Map j, {required bool posto}) => ItemEfetivo(
        chave: '${posto ? j['sigla'] : j['id']}',
        nome: '${posto ? j['sigla'] : j['nome']}',
        descricao: posto ? (j['descricao'] as String?) : null,
        ocupacao: Ocupacao.deJson(j),
      );
}

/// O que a API devolve para um escopo.
class EfetivoEscopo {
  const EfetivoEscopo({
    required this.nivel,
    required this.nome,
    required this.total,
    required this.filhoNivel,
    required this.filhos,
    required this.postos,
    required this.fonteSuspeita,
    required this.falhas,
  });

  final String nivel;
  final String? nome;
  final Ocupacao total;
  final String? filhoNivel;
  final List<ItemEfetivo> filhos;
  final List<ItemEfetivo> postos;

  /// A API comparou a soma da previsão com a contagem de gente e as duas
  /// ficaram muito perto — então a "previsão" pode ser a própria contagem.
  /// Enquanto isso não for conferido, a tela **não mostra percentual**
  /// (§27 e §52: melhor não dizer do que dizer errado).
  final bool fonteSuspeita;
  final List<String> falhas;

  String get titulo => nome ?? 'Toda a PMRR';
}

class MapaEfetivoRepositorio {
  MapaEfetivoRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/mapa_efetivo.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'MF';

  /// A última leitura do escopo inteiro. O banner do topo do Mapa da Força lê
  /// daqui, para o banner e a tela nunca mostrarem números diferentes da mesma
  /// coisa — era um número fixo no código antes (APRENDIZADOS §52).
  static final pmrr = ValueNotifier<EfetivoEscopo?>(null);

  Future<EfetivoEscopo> carregar({String? comando, String? unidade, String? subunidade}) async {
    final j = await api.postJson(url, prefixo: prefixo, campos: {
      'matricula': matricula,
      'senha': senhaMd5,
      if (comando != null) 'comando': comando,
      if (unidade != null) 'unidade': unidade,
      if (subunidade != null) 'subunidade': subunidade,
    });
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'mapa_efetivo.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    final escopo = (j['escopo'] as Map?) ?? const {};
    final conf = (j['conferencia'] as Map?) ?? const {};
    return EfetivoEscopo(
      nivel: '${escopo['nivel'] ?? 'pmrr'}',
      nome: escopo['nome'] as String?,
      total: Ocupacao.deJson((j['total'] as Map?) ?? const {}),
      filhoNivel: j['filho_nivel'] as String?,
      filhos: [for (final f in (j['filhos'] as List? ?? const [])) ItemEfetivo.deJson(f as Map, posto: false)],
      postos: [for (final p in (j['postos'] as List? ?? const [])) ItemEfetivo.deJson(p as Map, posto: true)],
      fonteSuspeita: conf['previsto_parece_contagem'] == true,
      falhas: [for (final f in (j['falhas'] as List? ?? const [])) '$f'],
    );
  }
}

// ── O desenho ────────────────────────────────────────────────────────────────

/// A barra de ocupação: o trilho é o previsto, o preenchido é o existente.
///
/// A forma foi escolhida antes da cor: o trabalho do dado aqui é **magnitude
/// contra uma meta**, não identidade — por isso uma barra com marca de alvo, e
/// não uma paleta de categorias. E o significado está no texto ao lado
/// ("182 de 240 · faltam 58"): a cor nunca carrega sozinha a informação.
class BarraOcupacao extends StatelessWidget {
  const BarraOcupacao({super.key, required this.ocupacao, this.altura = 8});

  final Ocupacao ocupacao;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escuro = theme.brightness == Brightness.dark;
    final trilho = theme.colorScheme.onSurface.withValues(alpha: escuro ? 0.12 : 0.10);
    final cheio = theme.colorScheme.primary;
    // Excedente não é "bom" nem "ruim": é outra coisa. Fica no dourado da
    // área de Gestão, que já é a identidade desta tela.
    final sobra = AppColors.douradoTexto(theme.brightness);

    if (ocupacao.semPrevisao) {
      return SizedBox(
        height: altura,
        child: DecoratedBox(
          decoration: BoxDecoration(color: trilho, borderRadius: BorderRadius.circular(altura)),
        ),
      );
    }

    final fracao = (ocupacao.existente / ocupacao.previsto).clamp(0.0, 1.0);
    final fracaoSobra = ocupacao.previsto > 0
        ? (ocupacao.excedente / ocupacao.previsto).clamp(0.0, 0.35)
        : 0.0;

    return LayoutBuilder(builder: (context, c) {
      final largura = c.maxWidth;
      return SizedBox(
        height: altura,
        child: Stack(children: [
          // Trilho: o previsto inteiro.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: trilho, borderRadius: BorderRadius.circular(altura)),
            ),
          ),
          // Preenchido: o existente, ancorado na base, com a ponta arredondada.
          Positioned(
            left: 0,
            width: (largura * fracao).clamp(altura, largura),
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(color: cheio, borderRadius: BorderRadius.circular(altura)),
            ),
          ),
          // Excedente: um trecho próprio depois do alvo, separado por um fio da
          // superfície, para as duas quantidades não se lerem como uma só.
          if (fracaoSobra > 0)
            Positioned(
              left: largura * fracao - altura,
              width: (largura * fracaoSobra).clamp(altura, largura * 0.35),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: sobra,
                  borderRadius: BorderRadius.circular(altura),
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

/// A frase que acompanha a barra. O texto é quem informa; a cor acompanha.
class LinhaOcupacao extends StatelessWidget {
  const LinhaOcupacao({super.key, required this.ocupacao, required this.mostrarPct});

  final Ocupacao ocupacao;
  final bool mostrarPct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: theme.brightness == Brightness.dark ? 0.70 : 0.68);
    if (ocupacao.semPrevisao) {
      return Text('${ocupacao.existente} militares · sem previsão cadastrada',
          style: TextStyle(fontSize: 12.5, color: mudo));
    }
    final partes = <String>[
      '${ocupacao.existente} de ${ocupacao.previsto}',
      if (mostrarPct && ocupacao.pct != null) '${ocupacao.pct!.toStringAsFixed(0)}%',
      if (ocupacao.faltam > 0) 'faltam ${ocupacao.faltam}',
      if (ocupacao.temExcedente) 'excedente de ${ocupacao.excedente}',
    ];
    return Text(partes.join(' · '), style: TextStyle(fontSize: 12.5, color: mudo));
  }
}
