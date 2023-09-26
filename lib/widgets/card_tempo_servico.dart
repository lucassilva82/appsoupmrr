import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';

class CardTempoServico extends StatelessWidget {
  const CardTempoServico({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    Auth auth = Provider.of(context);
    bool dataCalculada = false;

    DateTime dataIncor = DateTime.now();
    Duration tempoServico = Duration();
    int difAnos = 0;
    int difMeses = 0;
    int difDias = 0;
    double porcentagem = 0.0;

    if (auth.dataIncorporacao != null) {
      if (auth.dataIncorporacao!.isNotEmpty) {
        String data = auth.dataIncorporacao! + ' 00:00:00';
        dataCalculada = true;
        dataIncor = DateTime.parse(data);
        tempoServico = DateTime.now().difference(dataIncor);
        difDias = tempoServico.inDays;
        difAnos = (difDias / 363).toInt();
        difMeses = ((difDias - (difAnos * 363)) / 30).toInt();
        difDias = ((difDias - (difAnos * 363)) % 30).toInt();

        //Levando em conta 30 anos
        porcentagem = (tempoServico.inDays * 100) / 10950;
        porcentagem = porcentagem / 100;

        if (porcentagem > 1) {
          porcentagem = 1;
        }
      }
    }

    return Center(
      child: Container(
        width: width,
        height: height * 0.06,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: LinearPercentIndicator(
                linearGradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 217, 230, 236),
                    Colors.green,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.topRight,
                ),
                barRadius: const Radius.circular(20),
                animation: true,
                lineHeight: 24,
                animationDuration: 1000,
                percent: porcentagem,
                center: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(
                      width: 30,
                    ),
                    Text(
                      dataCalculada == true
                          ? '$difAnos anos, $difMeses meses e $difDias dias de serviço'
                          : 'erro',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.surfing_sharp,
                        size: 22,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
