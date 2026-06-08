import 'package:flutter/material.dart';
import '../models/militar.dart';

class DadosPrincipal extends StatelessWidget {
  final Militar militar;
  const DadosPrincipal({Key? key, required this.militar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      width: width * 0.60,
      height: height * 0.28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com gradiente e fonte menor
          Container(
            width: width * 0.60,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.lightBlue,
                  Colors.blue.shade900,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.topRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Policial Militar',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Corpo rolável com os dados, com padding reduzido
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRowDetail(
                      label: 'Posto/Graduação:',
                      info: '${militar.postoGraduacao} ${militar.quadro}'),
                  const SizedBox(height: 4),
                  _buildColumnDetail(
                      label: 'Nome:', info: militar.nomeCompleto),
                  const SizedBox(height: 4),
                  _buildColumnDetail(
                      label: 'Lotação:', info: militar.subUnidade),
                  const SizedBox(height: 4),
                  _buildColumnDetail(
                      label: 'Incorporação:', info: militar.dataIncorporacao),
                  _buildColumnDetail(
                      label: 'Matrícula SEGAD:', info: militar.matRhNova),
                  const SizedBox(height: 2),
                  _buildColumnDetail(
                      label: 'Matrícula PMRR:', info: militar.matricula),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRowDetail({required String label, required String info}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            info,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildColumnDetail({required String label, required String info}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          info,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
