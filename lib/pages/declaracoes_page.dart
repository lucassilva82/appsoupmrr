import 'package:flutter/material.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';
import 'package:supercharged/supercharged.dart';

import '../models/auth_model.dart';
import '../widgets/declaracao_widget.dart';
// import '../widgets/drawer_personalizado.dart'; // Descomente se quiser usar o drawer

class DeclaracoesPage extends StatefulWidget {
  const DeclaracoesPage({Key? key}) : super(key: key);

  @override
  State<DeclaracoesPage> createState() => _DeclaracoesPageState();
}

class _DeclaracoesPageState extends State<DeclaracoesPage> {
  // Defina até onde quer "voltar" os anos. Ex.: 2019
  final int anoInicial = 2024;

  // Retorna lista de anos de (ano atual - 1) até anoInicial (decrescente)
  List<int> get listaAnos {
    final anoMaximo = DateTime.now().year - 1; // Pega o ano anterior
    List<int> anos = [];
    for (int ano = anoMaximo; ano >= anoInicial; ano--) {
      anos.add(ano);
    }
    return anos;
  }

  // Define o ano selecionado inicial (ano atual - 1)
  late String _anoSelecionado;

  @override
  void initState() {
    super.initState();
    _anoSelecionado = (DateTime.now().year - 1).toString();
  }

  @override
  Widget build(BuildContext context) {
    // Acesso ao Auth, caso precise do CPF
    final auth = Provider.of<Auth>(context);

    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(title: 'Declaraçoes Anuais'),
      // drawer: const Drawerpersonalizado(), // Se quiser usar o drawer

      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(width * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: height * 0.02),

              // LISTA HORIZONTAL DE ANOS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: listaAnos.map((anoInt) {
                    final anoStr = anoInt.toString();
                    final bool isSelected = (anoStr == _anoSelecionado);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          // Ao clicar, muda o ano selecionado
                          _anoSelecionado = anoStr;
                        });
                      },
                      child: Container(
                        // Espaço entre os botões/anos
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue // Ano selecionado em azul
                              : Colors.grey[300], // Demais anos em cinza claro
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${anoStr}/${anoStr.toInt()! + 1}",
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(height: height * 0.02),

              // Quadro de aviso com Ano Base e Ano Calendário
              Container(
                width: MediaQuery.of(context).size.width * 0.50,
                padding: EdgeInsets.all(width * 0.03),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade700, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ano Base: ${_anoSelecionado}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Ano Calendário: ${_anoSelecionado.toInt()! + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: height * 0.03),

              // WIDGET de declaração + Container de Avisos
              Column(
                children: [
                  // Widget que depende do ano selecionado
                  DeclaracaoWidget(
                    key: ValueKey(_anoSelecionado), // Para forçar reconstrução
                    cpf: auth.cpf ?? 'CPF Não Encontrado',
                    ano: _anoSelecionado,
                  ),

                  // SizedBox(height: height * 0.01),

                  // "Cartão" de avisos
                  Container(
                    padding: EdgeInsets.all(width * 0.05),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'Aviso de Responsabilidade',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        SizedBox(height: height * 0.02),
                        Text(
                          'O usuário é responsável pela veracidade, precisão e atualização dos dados informados neste aplicativo. '
                          'O fornecimento de informações incorretas ou falsas poderá acarretar a suspensão ou exclusão do acesso, conforme os Termos de Uso.',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.justify,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Após enviado, seus dados serão encaminhados para análise e recebimento.',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.justify,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Conforme Lei Geral de Proteção de Dados (LGPD) - Lei nº 13.709/2018.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
