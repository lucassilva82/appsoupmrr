import 'package:flutter/material.dart';

import '../models/militar.dart';
import '../utils/app_routes.dart';

class DadosEndereco extends StatelessWidget {
  final Militar militar;
  const DadosEndereco({Key? key, required this.militar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Container(
        width: width * 0.99,
        height: height * 0.20,
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
              width: width * 0.99,
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
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 4,
                    offset: Offset(2, 2), // Shadow position
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    'Endereço',
                    style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.all(2),
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.ENDERECO_PAGE,
                        arguments: militar,
                      );
                    },
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.white,
                    ),
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
                          'Município: ',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          militar.endereco.municipio!.nome,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: width * 0.99,
                    height: height * 0.04,
                    child: Row(children: [
                      Text(
                        'Rua: ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${militar.endereco.rua!.nome}',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Número: ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text('${militar.endereco.numero}'),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    child: Row(
                      children: [
                        Text(
                          'Bairro: ',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          militar.endereco.bairro!.nome,
                          style: TextStyle(
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'CEP: ',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          militar.endereco.cep!,
                          style: TextStyle(
                            fontSize: 12,
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
      ),
    );
  }
}
