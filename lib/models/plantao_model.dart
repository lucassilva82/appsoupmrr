// Escalas tipos
/* 
Rua Padrao: 12/24 - 12/72
Guarda: 24/96
Guarda Menor: 24/72
Giro: 8h, 8h, 8h, 72h folga
*/
import '../data/store.dart';

enum TipoEscala { ruaPadrao, guarda, guardaMenor, giro }

enum Turno { diurno, noturno, diario, giro }

class PlantaoModel {
  bool plantaoConfigurado = false;
  late DateTime primeiroServico;
  Map<DateTime, Turno> escalaServico = {};
  Map<DateTime, Turno> sviCadastrado = {};

  late TipoEscala escala;
  late Turno turnoIn;

  Future<bool> tryGetPlantao() async {
    final plantaoData = await Store.getMap('plantaoData');
    if (plantaoData.isEmpty) return false;

    primeiroServico = DateTime.parse(plantaoData['primeiroServico']);
    primeiroServico = DateTime.utc(
        primeiroServico.year, primeiroServico.month, primeiroServico.day);
    plantaoConfigurado = true;
    String tipoEscala = plantaoData['tipoEscala'];
    escala = _verificaTipoEscala(tipoEscala);
    String turnoInicial = plantaoData['turnoInicial'];
    turnoIn = _verificaTurnoIn(turnoInicial);

    if (escala == TipoEscala.ruaPadrao) {
      calculaEscalaRuaPadrao(primeiroServico, turnoIn);
    }
    if (escala == TipoEscala.guarda) {
      calculaEscalaGuarda(primeiroServico, turnoIn);
    }
    if (escala == TipoEscala.guardaMenor) {
      calculaEscalaGuardaMenor(primeiroServico, turnoIn);
    }
    if (escala == TipoEscala.giro) {
      calculaEscalaGiro(primeiroServico, turnoIn);
    }

    return plantaoConfigurado;
  }

  TipoEscala _verificaTipoEscala(String s) {
    if (s == 'TipoEscala.ruaPadrao') {
      return TipoEscala.ruaPadrao;
    }
    if (s == 'TipoEscala.guarda') {
      return TipoEscala.guarda;
    }
    if (s == 'TipoEscala.guardaMenor') {
      return TipoEscala.guardaMenor;
    }
    if (s == 'TipoEscala.giro') {
      return TipoEscala.giro;
    }
    return TipoEscala.ruaPadrao;
  }

  Turno _verificaTurnoIn(String s) {
    if (s == 'semTurno') {
      return Turno.diario;
    } else if (s == 'Turno.diurno') {
      return Turno.diurno;
    } else if (s == 'Turno.noturno') {
      return Turno.noturno;
    } else if (s == 'Turno.diario') {
      return Turno.diario;
    } else if (s == 'Turno.giro') {
      return Turno.giro;
    }
    return Turno.noturno;
  }

  calculaEscalaRuaPadrao(DateTime servicoInicial, Turno turnoInicial) async {
    primeiroServico = servicoInicial;
    escala = TipoEscala.ruaPadrao;
    turnoIn = turnoInicial;
    plantaoConfigurado = true;
    escalaServico = {};

    Turno turno1 = turnoInicial;
    Turno turno2 = turnoInicial == Turno.diurno ? Turno.noturno : Turno.diurno;
    DateTime dataCalculada = servicoInicial;
    DateTime dataCalculada2 = turnoInicial == Turno.diurno
        ? servicoInicial.add(const Duration(days: 1))
        : servicoInicial.add(const Duration(days: 4));

    for (int i = 0; i < 720; i += 3) {
      Map<DateTime, Turno> servico = {
        dataCalculada: turno1,
        dataCalculada2: turno2
      };

      dataCalculada = dataCalculada.add(const Duration(days: 5));
      dataCalculada2 = dataCalculada2.add(const Duration(days: 5));
      escalaServico.addEntries(servico.entries);
      servico.clear();
    }
  }

  calculaEscalaGuarda(DateTime servicoInicial, Turno turnoInicial) {
    primeiroServico = servicoInicial;
    plantaoConfigurado = true;
    escalaServico = {};

    DateTime dataCalculada = servicoInicial;

    for (int i = 0; i < 365; i += 3) {
      Map<DateTime, Turno> servico = {
        dataCalculada: turnoInicial,
      };
      escalaServico.addEntries(servico.entries);
      dataCalculada = dataCalculada.add(const Duration(days: 5));

      servico.clear();
    }
  }

  calculaEscalaGuardaMenor(DateTime servicoInicial, Turno turnoInicial) {
    primeiroServico = servicoInicial;
    plantaoConfigurado = true;
    escalaServico = {};

    DateTime dataCalculada = servicoInicial;

    for (int i = 0; i < 365; i += 3) {
      Map<DateTime, Turno> servico = {
        dataCalculada: turnoInicial,
      };
      escalaServico.addEntries(servico.entries);
      dataCalculada = dataCalculada.add(const Duration(days: 4));

      servico.clear();
    }
  }

  calculaEscalaGiro(DateTime servicoInicial, Turno turnoInicial) {
    primeiroServico = servicoInicial;
    plantaoConfigurado = true;
    escalaServico = {};

    DateTime dataCalculada = servicoInicial;
    DateTime dataCalculada2 = servicoInicial.add(Duration(days: 1));
    DateTime dataCalculada3 = servicoInicial.add(Duration(days: 2));

    for (int i = 0; i < 365; i += 3) {
      Map<DateTime, Turno> servico = {
        dataCalculada: turnoInicial,
        dataCalculada2: turnoInicial,
        dataCalculada3: turnoInicial,
      };
      escalaServico.addEntries(servico.entries);
      dataCalculada = dataCalculada.add(const Duration(days: 6));
      dataCalculada2 = dataCalculada2.add(const Duration(days: 6));
      dataCalculada3 = dataCalculada3.add(const Duration(days: 6));

      servico.clear();
    }
  }

  salvaEscalaMemoria(
      DateTime primeiroServ, TipoEscala tipoEs, Turno tur) async {
    primeiroServico = primeiroServ;
    escala = tipoEs;
    turnoIn = tur;
    Store.saveMap('plantaoData', {
      'primeiroServico': primeiroServico.toIso8601String(),
      'tipoEscala': escala.toString(),
      // ignore: unnecessary_null_comparison
      'turnoInicial': turnoIn == null ? 'semTurno' : turnoIn.toString(),
    });
  }

  excluiEscalaMemoria() async {
    escalaServico = {};
    await Store.remove('plantaoData');
  }

  String getTipoEscala() {
    if (escala == TipoEscala.ruaPadrao) {
      return '12h/24h - 12h/72h';
    }
    if (escala == TipoEscala.guarda) {
      return '24h/96h ';
    }
    if (escala == TipoEscala.guardaMenor) {
      return '24h/72h';
    }
    if (escala == TipoEscala.giro) {
      return '8h, 8h, 8h, 72h';
    }
    return '';
  }
}
