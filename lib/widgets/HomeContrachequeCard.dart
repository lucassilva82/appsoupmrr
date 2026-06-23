import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/contracheque_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

class HomeContrachequeCard extends StatefulWidget {
  const HomeContrachequeCard({Key? key}) : super(key: key);

  @override
  State<HomeContrachequeCard> createState() => _HomeContrachequeCardState();
}

class _HomeContrachequeCardState extends State<HomeContrachequeCard>
    with SingleTickerProviderStateMixin {
  late Future<ContrachequeModel?> _futureContracheque =
      Future.value(null); // valor seguro até initState carregar

  double bruto = 0.0;
  double descontos = 0.0;
  double liquido = 0.0;
  String? mesNome;
  String? ano;
  int? _mesNumero;
  bool _showValues = false;

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

  Future<ContrachequeModel?> _buscarUltimoContracheque(String cpf) async {
    final dadosSql = DadosSql();
    final anoAtual = DateTime.now().year;
    List<MesesContracheque> lista =
        await dadosSql.listaMesesContracheque(cpf, anoAtual.toString());
    if (lista.isEmpty) {
      lista =
          await dadosSql.listaMesesContracheque(cpf, (anoAtual - 1).toString());
    }
    if (lista.isEmpty) return null;
    return _buscarDadosContracheque(lista.first);
  }

  Future<ContrachequeModel> _buscarDadosContracheque(
      MesesContracheque mesSel) async {
    final dadosSql = DadosSql();
    final contracheque = await dadosSql.buscaContracheque(
      mesSel.cpf,
      mesSel.ano,
      mesSel.mes,
      mesSel.mesExtenso,
      mesSel.matricula,
      mesSel.tipo,
      mesSel.codProvento,
      mesSel.relacaoTrabalho,
      mesSel.folha,
    );
    double somaP = 0.0, somaD = 0.0;
    for (final item in contracheque.proventos) {
      if (item.tipoRubrica == 'P') {
        somaP += double.tryParse(item.provento) ?? 0.0;
      } else {
        somaD += double.tryParse(item.desconto) ?? 0.0;
      }
    }
    setState(() {
      bruto = somaP;
      descontos = somaD;
      liquido = somaP - somaD;
      mesNome = mesSel.mesExtenso;
      ano = mesSel.ano.toString();
      _mesNumero = int.tryParse(mesSel.mes);
    });
    return contracheque;
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
    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
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
    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
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

    return FutureBuilder<ContrachequeModel?>(
      future: _futureContracheque,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return _buildSkeleton(isDark);
        if (snapshot.hasError)
          return _buildError(isDark, 'Erro ao carregar contracheque.');
        if (snapshot.data == null)
          return _buildError(isDark, 'Nenhum contracheque encontrado.');
        return _buildCard(isDark, t);
      },
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

    String maskedOrFmt(double v) =>
        _showValues ? 'R\$\u2009${fmt.format(v)}' : '••••••';

    return Card(
      margin: EdgeInsets.zero,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE),
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
                  // Título + badge NOVO
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
                  // Mês/ano em chip pequeno
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${mesNome ?? ''} ${ano ?? ''}',
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  // Botão olho
                  GestureDetector(
                    onTap: () => setState(() => _showValues = !_showValues),
                    child: Icon(
                      _showValues
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 17,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.2)),
                ],
              ),

              const SizedBox(height: 10),

              // ── Linha 2: Proventos | Líquido | Descontos ───────────────
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    // Proventos
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
                    // Divider
                    Container(
                        width: 1,
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: divColor),
                    // Líquido (destaque central)
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('LÍQUIDO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.white38 : Colors.black38,
                              )),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _showValues
                                  ? 'R\$\u2009${fmt.format(liquido)}'
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
                    // Divider
                    Container(
                        width: 1,
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: divColor),
                    // Descontos
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
            ],
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
