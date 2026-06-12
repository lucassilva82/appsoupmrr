import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';

import '../models/auth_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import '../view/second_screen.dart';

class Contracheque extends StatefulWidget {
  Contracheque({Key? key}) : super(key: key);

  @override
  _ContrachequeState createState() => _ContrachequeState();

  String _anoSelecionado = DateTime.now().year.toString();
  late List<MesesContracheque> mesesContracheque;
}

class _ContrachequeState extends State<Contracheque> {
  final DadosSql dadosSql = DadosSql();

  List<int> get listaAnos {
    final anoAtual = DateTime.now().year;
    return List.generate(anoAtual - 2019, (i) => anoAtual - i);
  }

  Future<List<MesesContracheque>> _buscaDadosSql(String ano) async {
    final auth = Provider.of<Auth>(context, listen: false);
    widget.mesesContracheque =
        await dadosSql.listaMesesContracheque(auth.cpf!, ano);
    return widget.mesesContracheque;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(title: 'Contracheques'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYearSelector(isDark),
          Divider(
              height: 1,
              color:
                  isDark ? const Color(0xFF30363D) : const Color(0xFFE8EDF5)),
          Expanded(
            child: FutureBuilder<List<MesesContracheque>>(
              future: _buscaDadosSql(widget._anoSelecionado),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.blue),
                  );
                }
                if (snapshot.hasError) return SecondScreen();
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isDark);
                }
                return _buildList(snapshot.data!, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(bool isDark) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              'Ano:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: listaAnos.map((ano) {
                  final anoStr = ano.toString();
                  final isSelected = anoStr == widget._anoSelecionado;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => widget._anoSelecionado = anoStr),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.blue
                            : (isDark
                                ? const Color(0xFF21262D)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.blue
                              : (isDark
                                  ? const Color(0xFF30363D)
                                  : Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        anoStr,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<MesesContracheque> lista, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final item = lista[index];
        return _buildMonthCard(item, isDark, ctx);
      },
    );
  }

  Widget _buildMonthCard(
      MesesContracheque item, bool isDark, BuildContext ctx) {
    final isAtivo = item.tipo == 'A';
    final badgeLabel = isAtivo ? 'Ativo' : item.tipo;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          item.cpf = Provider.of<Auth>(ctx, listen: false).cpf!;
          Navigator.of(ctx)
              .pushNamed(AppRoutes.PAGE_VIEW_CONTRACHEQUE, arguments: item);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2128) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8EDF5),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Ícone com número do mês
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.blue, AppColors.navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    item.mes.padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Nome do mês + lotação
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.mesExtenso,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isAtivo
                          ? item.relacaoTrabalho
                          : '${item.relacaoTrabalho} · Folha ${item.folha}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Badge de tipo
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAtivo
                      ? AppColors.blue.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isAtivo ? AppColors.blue : Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Nenhum contracheque em ${widget._anoSelecionado}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

