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

    return Center(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.99,
          // padding: EdgeInsets.symmetric(
          //   horizontal: cardPadding,
          // ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título + Ícone (olho)
              Container(
                width: MediaQuery.of(context).size.width * 0.99,
                height: MediaQuery.of(context).size.height * 0.035,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.lightBlue,
                      Colors.blue.shade900,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 77, 138, 229),
                      blurRadius: 4,
                      offset: Offset(2, 2), // Shadow position
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contracheque | ${mesNome ?? ''} ${ano ?? ''}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        // Se _showValues = false, exibir olho cortado
                        // Se _showValues = true, exibir olho normal
                        icon: Icon(
                          _showValues ? Icons.visibility : Icons.visibility_off,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          // Toggle do estado
                          setState(() {
                            _showValues = !_showValues;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: cardPadding * 0.03),

              // Subtítulo
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Resumo do último contracheque',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
              SizedBox(height: cardPadding * 0.2),

              // 3 blocos (Bruto / Descontos / Líquido)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBlocoValor(
                      titulo: 'Bruto',
                      // Se _showValues = false => "****"
                      valor: _showValues
                          ? 'R\$ ${formatter.format(bruto)}'
                          : '****',
                      colorBorder: Colors.teal,
                      icon: Icons.add_circle,
                      blockHeight: blockHeight,
                      fontSize: subtitleFontSize,
                    ),
                    SizedBox(width: cardPadding * 0.3),
                    _buildBlocoValor(
                      titulo: 'Descontos',
                      valor: _showValues
                          ? 'R\$ ${formatter.format(descontos)}'
                          : '****',
                      colorBorder: Colors.orange,
                      icon: Icons.remove_circle,
                      blockHeight: blockHeight,
                      fontSize: subtitleFontSize,
                    ),
                    SizedBox(width: cardPadding * 0.3),
                    _buildBlocoValor(
                      titulo: 'Líquido',
                      valor: _showValues
                          ? 'R\$ ${formatter.format(bruto - descontos)}'
                          : '****',
                      colorBorder: Colors.blue,
                      icon: Icons.check_circle,
                      blockHeight: blockHeight,
                      fontSize: subtitleFontSize,
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

  // Cada bloco (Bruto, Descontos, Líquido)
  Widget _buildBlocoValor({
    required String titulo,
    required String valor,
    required Color colorBorder,
    required IconData icon,
    required double blockHeight,
    required double fontSize,
  }) {
    return Expanded(
      child: Container(
        height: blockHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: colorBorder, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Texto
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Ícone
            Icon(
              icon,
              color: colorBorder,
              size: fontSize * 1.2, // um pouco maior que o texto
            ),
          ],
        ),
      ),
    );
  }
}
