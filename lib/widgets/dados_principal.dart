import 'package:flutter/material.dart';

import '../models/militar.dart';

class DadosPrincipal extends StatelessWidget {
  final Militar militar;
  const DadosPrincipal({Key? key, required this.militar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Container(
      width: width * 0.60,
      height: height * 0.28,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 4,
            offset: Offset(2, 2), // Shadow position
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: width * 0.60,
            height: height * 0.04,
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
                  topLeft: Radius.circular(5), topRight: Radius.circular(5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  blurRadius: 4,
                  offset: Offset(2, 2), // Shadow position
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 10,
                ),
                Text(
                  'Policial Militar',
                  style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Posto/Graduação Atual: ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${militar.postoGraduacao} ${militar.quadro}',
                        style: const TextStyle(fontSize: 09),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nome:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        width: width * 0.60,
                        height: height * 0.03,
                        child: TextFormField(
                          enabled: false,
                          readOnly: true,
                          style: TextStyle(fontSize: 10),
                          initialValue: militar.nomeCompleto,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lotação:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        width: width * 0.60,
                        height: height * 0.03,
                        child: TextFormField(
                          enabled: false,
                          readOnly: true,
                          style: TextStyle(fontSize: 10),
                          initialValue: militar.subUnidade,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data de incorporação:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        width: width * 0.60,
                        height: height * 0.03,
                        child: TextFormField(
                          enabled: false,
                          readOnly: true,
                          style: TextStyle(fontSize: 10),
                          initialValue: militar.dataIncorporacao,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
