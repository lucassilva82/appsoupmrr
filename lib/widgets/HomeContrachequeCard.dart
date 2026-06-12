import 'package:auto_size_text/auto_size_text.dart';
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

class _HomeContrachequeCardState extends State<HomeContrachequeCard> {
  late Future<ContrachequeModel?> _futureContracheque;

  double bruto = 0.0;
  double descontos = 0.0;
  double liquido = 0.0;
  String? mesNome;
  String? ano;
  bool _showValues = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);
    _futureContracheque = _buscarUltimoContracheque(auth.cpf!);
  }

  Future<ContrachequeModel?> _buscarUltimoContracheque(String cpf) async {
    final dadosSql = DadosSql();
    final anoAtual = DateTime.now().year;
    List<MesesContracheque> lista =
        await dadosSql.listaMesesContracheque(cpf, anoAtual.toString());
    if (lista.isEmpty) {
      lista = await dadosSql.listaMesesContracheque(cpf, (anoAtual - 1).toString());
    }
    if (lista.isEmpty) return null;
    return _buscarDadosContracheque(lista.first);
  }

  Future<ContrachequeModel> _buscarDadosContracheque(MesesContracheque mesSel) async {
    final dadosSql = DadosSql();
    final contracheque = await dadosSql.buscaContracheque(
      mesSel.cpf, mesSel.ano, mesSel.mes, mesSel.mesExtenso,
      mesSel.matricula, mesSel.tipo, mesSel.codProvento,
      mesSel.relacaoTrabalho, mesSel.folha,
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
    });
    return contracheque;
  }

  // ── Skeleton ─────────────────────────────────────────────────────────
  Widget _buildSkeleton(bool isDark) {
    final base = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade200;
    blob({double w = double.infinity, double h = 12.0, double r = 6.0}) =>
        Container(
          width: w, height: h,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(r)),
        );
    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            blob(w: 36, h: 36, r: 10),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              blob(w: 110, h: 12),
              blob(w: 70, h: 10),
            ]),
            const Spacer(),
            blob(w: 32, h: 32, r: 10),
          ]),
          const SizedBox(height: 14),
          Center(child: blob(w: 120, h: 24, r: 8)),
          const SizedBox(height: 3),
          Center(child: blob(w: 50, h: 9, r: 4)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: blob(h: 44, r: 10)),
            const SizedBox(width: 8),
            Expanded(child: blob(h: 44, r: 10)),
          ]),
        ]),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────
  Widget _buildError(bool isDark, String msg) {
    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(children: [
          Icon(Icons.receipt_long_rounded, color: Colors.grey[400], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis),
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
        if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeleton(isDark);
        if (snapshot.hasError) return _buildError(isDark, 'Erro ao carregar contracheque.');
        if (snapshot.data == null) return _buildError(isDark, 'Nenhum contracheque encontrado.');
        return _buildCard(isDark, t);
      },
    );
  }

  Widget _buildCard(bool isDark, ThemeData t) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
    const primaryBlue = Color(0xFF1565C0);
    const greenColor  = Color(0xFF2E7D32);
    const redColor    = Color(0xFFB71C1C);
    const bgAccent    = Color(0xFFE3F2FD);

    String maskedOrFmt(double v) => _showValues ? 'R\$\u2009${fmt.format(v)}' : '••••••';

    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E7F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // ── Header ───────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? primaryBlue.withValues(alpha: 0.18) : bgAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: primaryBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Contracheque', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${mesNome ?? ''} ${ano ?? ''}',
                      style: t.textTheme.labelSmall?.copyWith(color: Colors.grey[500])),
                ]),
              ),
              // Botão olho
              GestureDetector(
                onTap: () => setState(() => _showValues = !_showValues),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _showValues ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: Colors.grey[500],
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // ── Líquido em destaque ────────────────────────────────
            Center(
              child: Column(children: [
                AutoSizeText(
                  _showValues ? 'R\$\u2009${fmt.format(liquido)}' : '••••••',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    letterSpacing: _showValues ? -0.5 : 4,
                  ),
                  maxLines: 1,
                  minFontSize: 13,
                ),
                const SizedBox(height: 1),
                Text('LÍQUIDO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    )),
              ]),
            ),

            const SizedBox(height: 8),

            // ── Bruto e Descontos (menores, 2 colunas) ─────────────
            Row(children: [
              _buildPill(
                context: context,
                titulo: 'Proventos',
                valor: maskedOrFmt(bruto),
                accent: greenColor,
                icon: Icons.arrow_upward_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildPill(
                context: context,
                titulo: 'Descontos',
                valor: maskedOrFmt(descontos),
                accent: redColor,
                icon: Icons.arrow_downward_rounded,
                isDark: isDark,
              ),
            ]),

            // ── Footer ───────────────────────────────────────────────
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('Ver detalhes',
                  style: TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 16, color: primaryBlue),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required String titulo,
    required String valor,
    required Color accent,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: isDark ? accent.withValues(alpha: 0.1) : accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: isDark ? 0.25 : 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 11, color: accent),
            const SizedBox(width: 4),
            Text(titulo,
                style: TextStyle(
                    color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          AutoSizeText(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              letterSpacing: valor.contains('•') ? 2 : 0,
            ),
            maxLines: 1,
            minFontSize: 8,
          ),
        ]),
      ),
    );
  }
}
