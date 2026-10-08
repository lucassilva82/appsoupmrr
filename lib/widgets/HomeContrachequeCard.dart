import 'package:flutter/material.dart';
import 'vidro.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';

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

class _HomeContrachequeCardState extends State<HomeContrachequeCard>
    with TickerProviderStateMixin {
  late Future<List<_Vinculo>?> _futureContracheque =
      Future.value(null); // valor seguro até initState carregar

  double bruto = 0.0;
  double descontos = 0.0;
  double liquido = 0.0;
  String? mesNome;
  String? ano;
  int? _mesNumero;
  bool _showValues = false;
  bool _expandido = false;
  List<_Vinculo> _vinculos = const [];
  MesesContracheque? _ultimoMes;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool get _isCurrentMonth {
    if (_mesNumero == null || ano == null) return false;
    final now = DateTime.now();
    return _mesNumero == now.month && ano == now.year.toString();
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    final auth = Provider.of<Auth>(context, listen: false);
    final cpf = auth.cpf;
    if (cpf != null && cpf.isNotEmpty) {
      _futureContracheque = _buscarUltimoContracheque(cpf);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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
  Widget _buildSkeleton(bool isDark) {
    final base =
        isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade200;
    blob({double w = double.infinity, double h = 12.0, double r = 6.0}) =>
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(r)),
        );
    return CartaoVidro(
      raio: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha 1
            Row(children: [
              blob(w: 30, h: 30, r: 9),
              const SizedBox(width: 9),
              blob(w: 90, h: 12, r: 6),
              const SizedBox(width: 8),
              blob(w: 60, h: 20, r: 6),
              const Spacer(),
              blob(w: 20, h: 20, r: 6),
            ]),
            const SizedBox(height: 10),
            // Linha 2: 3 colunas
            IntrinsicHeight(
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      blob(w: 50, h: 9, r: 4),
                      const SizedBox(height: 4),
                      blob(w: 70, h: 12, r: 4)
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      blob(w: 40, h: 9, r: 4),
                      const SizedBox(height: 4),
                      blob(w: 100, h: 14, r: 4)
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      blob(w: 50, h: 9, r: 4),
                      const SizedBox(height: 4),
                      blob(w: 70, h: 12, r: 4)
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────
  Widget _buildError(bool isDark, String msg) {
    return CartaoVidro(
      raio: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(children: [
          Icon(Icons.receipt_long_rounded, color: Colors.grey[400], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context);

    return FutureBuilder<List<_Vinculo>?>(
      future: _futureContracheque,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(isDark);
        }
        if (snapshot.hasError) {
          return _buildError(isDark, 'Erro ao carregar contracheque.');
        }
        final dados = snapshot.data;
        if (dados == null || dados.isEmpty) {
          return _buildError(isDark, 'Nenhum contracheque encontrado.');
        }
        return _buildCard(isDark, t);
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

  Widget _buildCard(bool isDark, ThemeData t) {
    final fmt =
        NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
    const primaryBlue = Color(0xFF1565C0);
    const greenColor = Color(0xFF2E7D32);
    const redColor = Color(0xFFB71C1C);
    const bgAccent = Color(0xFFE3F2FD);
    final divColor =
        isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    // Com um vínculo só não há o que expandir: o card inteiro abre o
    // contracheque, como era antes.
    final temVarios = _vinculos.length > 1;

    String maskedOrFmt(double v) =>
        _showValues ? 'R\$ ${fmt.format(v)}' : '••••••';

    void aoTocarCartao() {
      if (temVarios) {
        setState(() => _expandido = !_expandido);
        return;
      }
      final folha = _vinculos.isNotEmpty ? _vinculos.first.folha : _ultimoMes;
      if (folha != null) {
        _abrirContracheque(folha);
      } else {
        Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE);
      }
    }

    return CartaoVidro(
      raio: 16,
      child: InkWell(
        onTap: aoTocarCartao,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Linha 1: ícone · título · badge · mês · olho ────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? primaryBlue.withValues(alpha: 0.18)
                          : bgAccent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: primaryBlue, size: 16),
                  ),
                  const SizedBox(width: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Contracheque',
                          style: t.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      if (_isCurrentMonth) ...[
                        const SizedBox(width: 5),
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Opacity(
                            opacity: _pulseAnim.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('NOVO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  )),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${mesNome ?? ''} ${ano ?? ''}',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showValues = !_showValues),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Icon(
                        _showValues
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 17,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Com vários vínculos a seta vira o controle de expandir.
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 220),
                    turns: temVarios && _expandido ? 0.5 : 0,
                    child: Icon(
                      temVarios
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: temVarios ? 20 : 16,
                      color: isDark
                          ? Colors.white38
                          : Colors.black.withValues(alpha: 0.28),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Linha 2: Proventos | Líquido | Descontos ───────────────
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    Expanded(
                      child: _compactValue(
                        label: 'Proventos',
                        value: maskedOrFmt(bruto),
                        icon: Icons.arrow_upward_rounded,
                        color: greenColor,
                        isDark: isDark,
                        align: CrossAxisAlignment.start,
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: divColor),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            temVarios ? 'LÍQUIDO TOTAL' : 'LÍQUIDO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _showValues
                                  ? 'R\$ ${fmt.format(liquido)}'
                                  : '••••••',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                letterSpacing: _showValues ? -0.5 : 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: divColor),
                    Expanded(
                      child: _compactValue(
                        label: 'Descontos',
                        value: maskedOrFmt(descontos),
                        icon: Icons.arrow_downward_rounded,
                        color: redColor,
                        isDark: isDark,
                        align: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Resumo dos vínculos (fechado) ou a lista (aberto) ───────
              if (temVarios)
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expandido
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 10),
                            Divider(height: 1, color: divColor),
                            const SizedBox(height: 4),
                            for (final v in _vinculos)
                              _linhaVinculo(v, isDark, fmt),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.layers_rounded,
                                  size: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38),
                              const SizedBox(width: 4),
                              Text(
                                '${_vinculos.length} vínculos · toque para ver cada um',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Linha de um vínculo dentro do card expandido ──────────────────────
  Widget _linhaVinculo(_Vinculo v, bool isDark, NumberFormat fmt) {
    final theme = Theme.of(context);
    final cor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _abrirContracheque(v.folha),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: isDark ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cor.withValues(alpha: isDark ? 0.22 : 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 15, color: cor),
                const SizedBox(width: 8),
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Mat. ${v.folha.matricula}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showValues
                          ? 'R\$ ${fmt.format(v.liquido)}'
                          : '••••••',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: _showValues ? -0.3 : 2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _showValues
                          ? '+${fmt.format(v.proventos)} · -${fmt.format(v.descontos)}'
                          : 'proventos · descontos',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _compactValue({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required CrossAxisAlignment align,
  }) {
    return Column(
      crossAxisAlignment: align,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: align == CrossAxisAlignment.end
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            value,
            textAlign: align == CrossAxisAlignment.end
                ? TextAlign.end
                : TextAlign.start,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
              letterSpacing: value.contains('•') ? 2 : 0,
            ),
          ),
        ),
      ],
    );
  }
}
