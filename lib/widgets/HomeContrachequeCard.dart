import 'package:flutter/material.dart';
import 'package:projetonovo/utils/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/auth_model.dart';
import '../services/dados_sql.dart';
import '../models/meses_contracheque_model.dart';
import '../models/contracheque_model.dart';

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

  // NOVO: controla se os valores estão visíveis ou não.
  // Por padrão, ficam escondidos.
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

    List<MesesContracheque> listaAnoAtual =
        await dadosSql.listaMesesContracheque(cpf, anoAtual.toString());
    // print("essse aqui ${listaAnoAtual[2].mes}");

    if (listaAnoAtual.isEmpty) {
      final listaAnoAnterior = await dadosSql.listaMesesContracheque(
        cpf,
        (anoAtual - 1).toString(),
      );
      if (listaAnoAnterior.isEmpty) {
        return null;
      } else {
        // As listas de meses são ordenadas por mês decrescente.
        // Portanto, o primeiro item é o mais recente (ex.: Dezembro).
        final ultimoItem = listaAnoAnterior.first;
        return _buscarDadosContracheque(ultimoItem);
      }
    } else {
      final ultimoItem = listaAnoAtual.first;
      return _buscarDadosContracheque(ultimoItem);
    }
  }

  Future<ContrachequeModel> _buscarDadosContracheque(
      MesesContracheque mesSel) async {
    final dadosSql = DadosSql();
    ContrachequeModel contracheque = await dadosSql.buscaContracheque(
        mesSel.cpf,
        mesSel.ano,
        mesSel.mes,
        mesSel.mesExtenso,
        mesSel.matricula,
        mesSel.tipo,
        mesSel.codProvento,
        mesSel.relacaoTrabalho,
        mesSel.folha);

    double somaProventos = 0.0;
    double somaDescontos = 0.0;

    for (var item in contracheque.proventos) {
      if (item.tipoRubrica == "P") {
        somaProventos += double.tryParse(item.provento) ?? 0.0;
      } else {
        somaDescontos += double.tryParse(item.desconto) ?? 0.0;
      }
    }

    setState(() {
      bruto = somaProventos;
      descontos = somaDescontos;
      liquido = bruto - descontos;
      mesNome = mesSel.mesExtenso;
      ano = mesSel.ano.toString();
    });

    return contracheque;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final double cardWidth = screenWidth * 0.99;
    final double cardPadding = screenWidth * 0.03;
    final double titleFontSize = screenWidth * 0.03;
    final double subtitleFontSize = screenWidth * 0.02;
    final double blockHeight = screenHeight * 0.04;

    return FutureBuilder<ContrachequeModel?>(
      future: _futureContracheque,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading(cardWidth);
        }
        if (snapshot.hasError) {
          return _buildError(
            width: cardWidth,
            msg: 'Erro ao buscar contracheque: ${snapshot.error}',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return _buildError(
            width: cardWidth,
            msg: 'Nenhum contracheque encontrado.',
          );
        }

        return _buildCardContracheque(
          context: context,
          cardWidth: cardWidth,
          cardPadding: cardPadding,
          titleFontSize: titleFontSize,
          subtitleFontSize: subtitleFontSize,
          blockHeight: blockHeight,
        );
      },
    );
  }

  Widget _buildLoading(double width) {
    return Center(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(16),
        child: SizedBox(
          width: width,
          height: 60,
          child: const Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
    );
  }

  Widget _buildError({required double width, required String msg}) {
    return Center(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(16),
        child: SizedBox(
          width: width,
          height: 80,
          child: Center(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContracheque({
    required BuildContext context,
    required double cardWidth,
    required double cardPadding,
    required double titleFontSize,
    required double subtitleFontSize,
    required double blockHeight,
  }) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryBlue = Color(0xFF1565C0);
    const bgAccent = Color(0xFFE3F2FD);

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE),
      child: Card(
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE0E7F0),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? primaryBlue.withOpacity(0.18) : bgAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contracheque',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${mesNome ?? ''} ${ano ?? ''}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  // Botão olho
                  GestureDetector(
                    onTap: () => setState(() => _showValues = !_showValues),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _showValues
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── 3 Blocos de valor ─────────────────────────────────────────
              Row(
                children: [
                  _buildBlocoValor(
                    context: context,
                    titulo: 'Bruto',
                    valor: _showValues
                        ? 'R\$ ${formatter.format(bruto)}'
                        : '••••••',
                    accent: const Color(0xFF2E7D32),
                    icon: Icons.arrow_upward_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildBlocoValor(
                    context: context,
                    titulo: 'Descontos',
                    valor: _showValues
                        ? 'R\$ ${formatter.format(descontos)}'
                        : '••••••',
                    accent: const Color(0xFFE65100),
                    icon: Icons.arrow_downward_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildBlocoValor(
                    context: context,
                    titulo: 'Líquido',
                    valor: _showValues
                        ? 'R\$ ${formatter.format(bruto - descontos)}'
                        : '••••••',
                    accent: primaryBlue,
                    icon: Icons.account_balance_wallet_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlocoValor({
    required BuildContext context,
    required String titulo,
    required String valor,
    required Color accent,
    required IconData icon,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: isDark
              ? accent.withOpacity(0.1)
              : accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withOpacity(isDark ? 0.3 : 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: accent),
                const SizedBox(width: 4),
                Text(
                  titulo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: valor.contains('•') ? 2 : 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
