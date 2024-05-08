import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

    Duration tempoServico = Duration();
    int years = 0;
    int months = 0;
    int days = 0;
    double porcentagem = 0.0;

    String formatDate(String inputDate) {
      // Parse a string date in the format yyyy/mm/dd
      DateTime dateTime = DateTime.parse(inputDate.replaceAll('/', '-'));

      // Format the date as dd/mm/yyyy
      String formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);

      return formattedDate;
    }

    if (auth.dataIncorporacao != null) {
      if (auth.dataIncorporacao!.isNotEmpty) {
        // String data = auth.dataIncorporacao! + ' 00:00:00';
        // dataCalculada = true;
        // dataIncor = DateTime.parse(data);
        // tempoServico = DateTime.now().difference(dataIncor);
        // difDias = tempoServico.inDays;
        // difAnos = (difDias / 363).toInt();
        // difMeses = ((difDias - (difAnos * 363)) / 30).toInt();
        // difDias = ((difDias - (difAnos * 363)) % 30).toInt();
        String dataInc = formatDate(auth.dataIncorporacao!);

        DateTime selectedDate = DateFormat('dd/MM/yyyy').parse(dataInc);
        DateTime currentDate = DateTime.now();

        years = currentDate.year - selectedDate.year;
        months = currentDate.month - selectedDate.month;
        days = currentDate.day - selectedDate.day;

        if (months < 0 || (months == 0 && days < 0)) {
          years--;
          months += 12;
        }
        if (days < 0) {
          final previousMonthDate = DateTime(
            selectedDate.year,
            selectedDate.month + 1,
            0,
          );
          days = previousMonthDate.day + days;
          months--;
        }
        // print("$years anos $months meses e $days dias");
        //Levando em conta 30 anos
        tempoServico = Duration(days: years * 365);
        porcentagem = (tempoServico.inDays * 100) / 10950;
        porcentagem = porcentagem / 100;

        if (porcentagem > 1) {
          porcentagem = 1;
        }
        dataCalculada = true;
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
                          ? '$years anos, $months meses e $days dias de serviço'
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
