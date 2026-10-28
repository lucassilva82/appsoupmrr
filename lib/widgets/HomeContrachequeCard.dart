import 'package:flutter/material.dart';
import 'package:projetonovo/core/design/arte_cartao.dart';
import 'cartao_painel.dart';
import 'vidro.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

class HomeContrachequeCard extends StatefulWidget {
  const HomeContrachequeCard({Key? key}) : super(key: key);

  @override
  State<HomeContrachequeCard> createState() => _HomeContrachequeCardState();
}

/// Um vínculo do militar no mês (PM, pensão, função civil…), com os valores
/// daquela folha isolados. O card soma todos e também mostra um a um.
class _Vinculo {
  final MesesContracheque folha;
  final String rotulo;
  final double proventos;
  final double descontos;

  const _Vinculo({
    required this.folha,
    required this.rotulo,
    required this.proventos,
    required this.descontos,
  });

  double get liquido => proventos - descontos;
}

class _HomeContrachequeCardState extends State<HomeContrachequeCard> {
  late Future<List<_Vinculo>?> _futureContracheque =
      Future.value(null); // valor seguro até initState carregar

  double bruto = 0.0;
  double descontos = 0.0;
  double liquido = 0.0;
  String? mesNome;
  String? ano;
  int? _mesNumero;
  bool _showValues = false;
  List<_Vinculo> _vinculos = const [];
  MesesContracheque? _ultimoMes;

  bool get _isCurrentMonth {
    if (_mesNumero == null || ano == null) return false;
    final now = DateTime.now();
    return _mesNumero == now.month && ano == now.year.toString();
  }

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);
    final cpf = auth.cpf;
    if (cpf != null && cpf.isNotEmpty) {
      _futureContracheque = _buscarUltimoContracheque(cpf);
    }
  }

  Future<List<_Vinculo>?> _buscarUltimoContracheque(String cpf) async {
    final dadosSql = DadosSql();
    final anoAtual = DateTime.now().year;
    List<MesesContracheque> lista =
        await dadosSql.listaMesesContracheque(cpf, anoAtual.toString());
    if (lista.isEmpty) {
      lista =
          await dadosSql.listaMesesContracheque(cpf, (anoAtual - 1).toString());
    }
    if (lista.isEmpty) return null;
    final ultimo = lista.first;
    ultimo.cpf = cpf;
    _ultimoMes = ultimo;

    // Seleciona TODAS as folhas/vínculos do último mês (mesmo mês e ano),
    // para que o card mostre o total que o usuário efetivamente recebe
    // somando todos os vínculos (usuários podem ter 3 ou mais).
    final mesTopo = dadosSql.converteMes(ultimo.mesExtenso);
    final seen = <String>{};
    final folhasDoMes = <MesesContracheque>[];
    for (final m in lista) {
      if (dadosSql.converteMes(m.mesExtenso) == mesTopo &&
          m.ano == ultimo.ano) {
        // Evita contagem dupla do mesmo vínculo/folha vindo das duas APIs.
        final key =
            '${m.tipo}|${m.matricula}|${m.folha}|${m.relacaoTrabalho}|${m.codProvento}';
        if (seen.add(key)) {
          m.cpf = cpf;
          folhasDoMes.add(m);
        }
      }
    }

    return _buscarDadosContracheque(folhasDoMes, ultimo);
  }

  /// Deixa o nome do vínculo apresentável: "POLICIAL MILITAR" → "Policial Militar".
  String _rotuloVinculo(MesesContracheque m) {
    final bruto = m.tipo == 'A'
        ? m.relacaoTrabalho
        : (m.folha.isNotEmpty ? m.folha : m.relacaoTrabalho);
    final texto = bruto.trim();
    if (texto.isEmpty) return 'Vínculo';
    return texto
        .split(RegExp(r'\s+'))
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<List<_Vinculo>> _buscarDadosContracheque(
      List<MesesContracheque> folhas, MesesContracheque mesRef) async {
    final dadosSql = DadosSql();
    final vinculos = <_Vinculo>[];

    // Cada folha é consultada separadamente para que o card consiga mostrar
    // o total e, ao expandir, o que veio de cada vínculo.
    for (final folha in folhas) {
      final contracheque = await dadosSql.buscaContracheque(
        folha.cpf,
        folha.ano,
        folha.mes,
        folha.mesExtenso,
        folha.matricula,
        folha.tipo,
        folha.codProvento,
        folha.relacaoTrabalho,
        folha.folha,
      );

      double p = 0.0, d = 0.0;
      for (final item in contracheque.proventos) {
        if (item.tipoRubrica == 'P') {
          p += double.tryParse(item.provento) ?? 0.0;
        } else {
          d += double.tryParse(item.desconto) ?? 0.0;
        }
      }

      // Folha sem nenhum valor não vira linha no card.
      if (p == 0 && d == 0) continue;

      vinculos.add(_Vinculo(
        folha: folha,
        rotulo: _rotuloVinculo(folha),
        proventos: p,
        descontos: d,
      ));
    }

    // Maior líquido primeiro: o vínculo principal encabeça a lista.
    vinculos.sort((a, b) => b.liquido.compareTo(a.liquido));

    final somaP = vinculos.fold<double>(0, (t, v) => t + v.proventos);
    final somaD = vinculos.fold<double>(0, (t, v) => t + v.descontos);

    setState(() {
      _vinculos = vinculos;
      bruto = somaP;
      descontos = somaD;
      liquido = somaP - somaD;
      mesNome = mesRef.mesExtenso;
      ano = mesRef.ano.toString();
      _mesNumero = int.tryParse(dadosSql.converteMes(mesRef.mesExtenso));
    });
    return vinculos;
  }

  // ── Skeleton compacto (espelha o novo layout) ───────────────────────
  Widget _blob(bool isDark,
          {double w = double.infinity, double h = 12, double r = 6}) =>
      Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  Widget _buildSkeleton(bool isDark) => CartaoVidro(
        raio: 16,
        child: Padding(
          padding: kPaddingCartao,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _blob(isDark, w: 150, h: 18),
                const SizedBox(height: 10),
                _blob(isDark, w: 70, h: 11),
                _blob(isDark, w: 220, h: 32, r: 10),
                const SizedBox(height: 14),
                _blob(isDark, h: 36, r: 8),
              ]),
        ),
      );

  Widget _buildError(BuildContext context, String msg) => CartaoVidro(
        raio: 16,
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE),
        child: Padding(
          padding: kPaddingCartao,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CabecalhoCartao(
                icone: Icons.receipt_long_outlined,
                titulo: 'Contracheque',
              ),
              const SizedBox(height: 14),
              Text(msg,
                  style:
                      TextStyle(fontSize: 15, color: TomCartao.medio(context))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<_Vinculo>?>(
      future: _futureContracheque,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(isDark);
        }
        if (snapshot.hasError) {
          return _buildError(
              context, 'Não foi possível carregar o contracheque.');
        }
        final dados = snapshot.data;
        if (dados == null || dados.isEmpty) {
          return _buildError(context, 'Nenhum contracheque encontrado.');
        }
        return _buildCard(context, isDark);
      },
    );
  }

  void _abrirContracheque(MesesContracheque folha) {
    folha.cpf = Provider.of<Auth>(context, listen: false).cpf ?? folha.cpf;
    Navigator.of(context).pushNamed(
      AppRoutes.PAGE_VIEW_CONTRACHEQUE,
      arguments: folha,
    );
  }

  Widget _buildCard(BuildContext context, bool isDark) {
    final fmt =
        NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);

    // Verde e vermelho por modo — o par do Material reprova em contraste
    // sobre a base escura nova (ver DESIGN.md §3 Cores).
    // Sobre a arte o fundo é sempre escuro: valem os tons claros.
    const verde = AppColors.sucessoEscuro;
    const vermelho = AppColors.falhaEscuro;

    final temVarios = _vinculos.length > 1;

    String valor(double v) => _showValues ? 'R\$ ${fmt.format(v)}' : '••••••';

    // Com um vínculo só, o card inteiro abre a folha. Com vários, não: não
    // haveria como saber qual deles o toque abriria.
    void aoTocarCartao() {
      if (temVarios) return;
      final folha = _vinculos.isNotEmpty ? _vinculos.first.folha : _ultimoMes;
      if (folha != null) {
        _abrirContracheque(folha);
      } else {
        Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE);
      }
    }

    final referencia = '${mesNome ?? ''} ${ano ?? ''}'.trim();

    return CartaoArte(
      arte: Arte.de('cc'),
      padding: EdgeInsets.zero,
      onTap: temVarios ? null : aoTocarCartao,
      child: Stack(
        children: [
          Padding(
            padding: kPaddingCartao,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CabecalhoCartao(
                  icone: Icons.receipt_long_outlined,
                  titulo: 'Contracheque',
                  meta: referencia.isEmpty ? null : referencia,
                  mostrarSeta: false,
                  acao: Semantics(
                    button: true,
                    label: _showValues ? 'Ocultar valores' : 'Mostrar valores',
                    child: InkResponse(
                      onTap: () => setState(() => _showValues = !_showValues),
                      radius: 24,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          _showValues
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: AppIconSize.sm,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── O líquido é o número do card ─────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DestaqueCartao(
                        rotulo: temVarios ? 'Líquido total' : 'Líquido',
                        valor: valor(liquido),
                        tamanho: AppDisplaySize.heroiMenor,
                      ),
                    ),
                    if (_isCurrentMonth)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: PilulaCartao(texto: 'Novo'),
                      ),
                  ],
                ),

                const DivisorCartao(espaco: 12),

                // ── Proventos e descontos, lado a lado ───────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _parValor(
                        rotulo: 'Proventos',
                        valorTexto: valor(bruto),
                        icone: Icons.arrow_upward_rounded,
                        cor: verde,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _parValor(
                        rotulo: 'Descontos',
                        valorTexto: valor(descontos),
                        icone: Icons.arrow_downward_rounded,
                        cor: vermelho,
                        aDireita: true,
                      ),
                    ),
                  ],
                ),

                // ── Vínculos ─────────────────────────────────────────────────
                // Sempre visíveis: o total sozinho esconderia que há mais de um.
                if (temVarios) ...[
                  const DivisorCartao(espaco: 12),
                  for (var n = 0; n < _vinculos.length; n++) ...[
                    if (n > 0) const SizedBox(height: 10),
                    _linhaVinculo(_vinculos[n], fmt),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Rótulo com seta semântica em cima, valor embaixo. A seta e o sinal
  /// existem porque cor sozinha não pode carregar o significado.
  Widget _parValor({
    required String rotulo,
    required String valorTexto,
    required IconData icone,
    required Color cor,
    bool aDireita = false,
  }) {
    final alinhamento =
        aDireita ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alinhamento,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment:
              aDireita ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Icon(icone, size: AppIconSize.xxs, color: cor),
            const SizedBox(width: 4),
            Text(rotulo,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: cor)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: aDireita ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            valorTexto,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: _showValues ? -0.2 : 2,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }

  /// Uma folha, quando o militar tem mais de um vínculo no mês.
  Widget _linhaVinculo(_Vinculo v, NumberFormat fmt) {
    final cor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _abrirContracheque(v.folha),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                size: AppIconSize.xs, color: cor.withValues(alpha: 0.55)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    v.rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cor.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text('Mat. ${v.folha.matricula}',
                      style: TextStyle(
                          fontSize: 11.5, color: TomCartao.medio(context))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _showValues ? 'R\$ ${fmt.format(v.liquido)}' : '••••••',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: _showValues ? -0.2 : 2,
                color: cor.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: AppIconSize.xs, color: cor.withValues(alpha: 0.38)),
          ],
        ),
      ),
    );
  }
}
