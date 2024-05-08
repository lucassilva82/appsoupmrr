import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/ficha_funcional.dart';

import '../models/contracheque_model.dart';
import '../models/endereco.dart';
import '../models/meses_contracheque_model.dart';
import '../models/militar.dart';
import '../models/telefone.dart';

class DadosSql {
  //URL DO BANCO SQL TROCAR URL AQUI E NA API PARA CONECTAR NO BANCO DE PRODUCAO
  final _Url = 'https://pmrr.net/flutter/sigrh';
  // final _Url = 'http://192.168.190.250/flutter/sigrh';

  Future<String> getPasswordWithMd5(String matricula, String password) async {
    print('entrou no md5');
    final String url = '${_Url}/loginrh.php?matricula=$matricula';

    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    String errorResult = 'error';

    try {
      final map = await jsonDecode(response.body);
      final dadosMilitar = map['result'];
      String psw = dadosMilitar[0]['pswd'];
      //Retorna a senha criptografada.
      print(psw);
      return psw;
    } catch (error) {
      print('deu erro total');
      return errorResult;
    }
  }

  // BUSCA UM MILITAR POR MATRICULA
  Future<Militar?> buscarMilitarBancoByMatricula(String matricula) async {
    final String url = '${_Url}/buscapormatricula.php?matricula=${matricula}';
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    FichaFuncional fichaTemp =
        await buscarSituacaoFuncional(matricula) ?? FichaFuncional();

    try {
      final map = await jsonDecode(response.body);
      final dadosMilitar = map['result'];
      bool existeFoto = dadosMilitar[0]['imagemurl'].toString() ==
              'https://rh.pmrr.net/_lib/file/img//wc2/pix_db/'
          ? false
          : true;
      Militar militarTemp = Militar(
        fichaFuncional: fichaTemp,
        dataIncorporacao: dadosMilitar[0]['incorporacao'].toString(),
        quadro: dadosMilitar[0]['quadro'].toString(),
        matricula: dadosMilitar[0]['matricula'].toString(),
        postoGraduacao:
            dadosMilitar[0]['postograduacao'].toString().toUpperCase(),
        qra: dadosMilitar[0]['qra'].toString().toUpperCase(),
        nomeCompleto: dadosMilitar[0]['nomecompleto'].toString(),
        imageUrl: existeFoto ? dadosMilitar[0]['imagemurl'].toString() : 'null',
        cpf: dadosMilitar[0]['cpf'].toString(),
        subUnidade: dadosMilitar[0]['subu_descricao'].toString(),
        // endereco: Endereco(
        //   bairro: dadosMilitar[0]['bair_nome'].toString(),
        //   rua: dadosMilitar[0]['concat'].toString(),
        //   numero: dadosMilitar[0]['numero'].toString(),
        //   cep: dadosMilitar[0]['cep'].toString(),
        //   municipio: dadosMilitar[0]['muni_nome'].toString(),
        // ),
        endereco: Endereco(
            Municipio(
              nome: dadosMilitar[0]['muni_nome'].toString(),
              id: dadosMilitar[0]['muni_cod'].toString(),
            ),
            Bairro(
                id: dadosMilitar[0]['bair_cod'].toString(),
                nome: dadosMilitar[0]['bair_nome'].toString()),
            Rua(
              id: dadosMilitar[0]['rua_cod'].toString(),
              nome: dadosMilitar[0]['concat'].toString(),
            ),
            dadosMilitar[0]['numero'].toString(),
            dadosMilitar[0]['cep'].toString()),
      );

      dadosMilitar.forEach((dados) {
        var tipo = Tipos.comum;
        bool value = false;

        if (dados['telefone'] != null) {
          if (dados['poli_cont_whats'] == 1) {
            print('tipo telefone $value');
            tipo = Tipos.whats;
            value = true;
          }

          Telefone tel =
              Telefone(numeroTel: dados['telefone'], tipo: tipo, value: value);
          militarTemp.telefones.add(tel);
        }
      });

      return militarTemp;
    } catch (error) {
      return null;
    }
  }

  // BUSCA SITUACAO FUNCIONAL DO MILITAR
  Future<FichaFuncional?> buscarSituacaoFuncional(String matricula) async {
    final String url =
        '${_Url}/buscasituacaofuncional.php?matricula=${matricula}';
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    FichaFuncional fichaFuncional = FichaFuncional();
    try {
      final map = await jsonDecode(response.body);

      map.forEach((element) {
        AlteracaoFuncional alt = AlteracaoFuncional(
          tipoSituacao: element['tipo_situ_func_sigla'] ?? '',
          situacaoFuncional: element['tipo_situ_func_descricao'] ?? '',
          dataInicio: element['index_poli_situ_func_data_inicio'] ?? '',
          dataFim: element['index_poli_situ_func_data_fim'] ?? '',
          ativo: element['index_poli_situ_func_activo'] ?? '',
        );
        fichaFuncional.alteracoesFuncional.add(alt);
      });

      return fichaFuncional;
    } catch (error) {
      print('o erro é $error');
      return null;
    }
  }

  Future<bool> adicionaContatos(
      String matricula, String telefone, String possuiwhats) async {
    try {
      final String url =
          '${_Url}/inserecontato.php?matricula=$matricula&telefone=$telefone&possuiwhats=$possuiwhats';
      // ignore: unused_local_variable
      final response = await http.get(Uri.parse(Uri.encodeFull(url)));
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<bool> excluiContatos(String matricula) async {
    try {
      final String url = '${_Url}/deletacontato.php?matricula=${matricula}';
      // ignore: unused_local_variable
      final response = await http.get(Uri.parse(Uri.encodeFull(url)));
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<List<Endereco>> listaEnderecoCompleto(String busca) async {
    final String url = '${_Url}/listaenderecocompleto.php';
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    if (response.statusCode == 200) {
      try {
        final List enderecos = json.decode(response.body);

        return enderecos.map((json) => Endereco.fromJson(json)).where((end) {
          final endLower = end.logradouro!.toLowerCase();
          final buscaLower = busca.toLowerCase();

          return endLower.contains(buscaLower);
        }).toList();
      } catch (error) {
        throw Exception();
      }
    } else {
      throw Exception();
    }
  }

  Future<bool> atualizaEndereco(String codMuni, String codBairro, String codRua,
      String numero, String cep, String matricula) async {
    try {
      final String url =
          '${_Url}/atualizaendereco.php?codmuni=$codMuni&codbairro=$codBairro&codrua=$codRua&numero=$numero&cep=$cep&matricula=$matricula';

      // ignore: unused_local_variable
      final response = await http.get(Uri.parse(Uri.encodeFull(url)));
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<List<MesesContracheque>> listaMesesContracheque(
      String cpf, String ano) async {
    // String cpfConfig = retiraCaracterInicial(cpf);

    final String url = "${_Url}/listamesescontracheque.php?cpf='$cpf'&ano=$ano";
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));

    List<MesesContracheque> mesesContracheque = [];

    if (response.statusCode == 200) {
      try {
        var dados = json.decode(response.body);

        dados.forEach((element) {
          MesesContracheque mesContracheque = MesesContracheque(
              mes: element['mes'],
              lotacao: element['lotacao'],
              tipoProvento: element['tipo_provento'],
              cpf: element['cpf'],
              codProvento: element['cod_provento'].toString(),
              ano: element['ano'].toString());

          mesesContracheque.add(mesContracheque);
        });

        return mesesContracheque;
      } catch (error) {
        return mesesContracheque;
      }
    } else {
      return mesesContracheque;
    }
  }

  retiraCaracterInicial(String cpf) {
    while (cpf.startsWith('0')) {
      cpf = cpf.replaceFirst(r'0', '');
    }
    return cpf;
  }

  Future<ContrachequeModel> buscaContracheque(
      String cpf, String ano, String mes, String codProvento) async {
    // cpf = retiraCaracterInicial(cpf);
    mes = converteMes(mes);

    print(cpf);

    final String url =
        "${_Url}/exibecontracheque.php?cpf=$cpf&ano=$ano&mes=$mes&cod=$codProvento";

    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    print(response.body);
    ContrachequeModel contracheque = ContrachequeModel();
    contracheque.proventos = [];

    if (response.statusCode == 200) {
      try {
        var dados = json.decode(response.body);

        dados.forEach((element) {
          TipoProvento dp = TipoProvento(
              dp: element['dp'].toString(),
              descricao: element['descricao'].toString(),
              valor: element['valor'].toString());

          contracheque.proventos.add(dp);
        });
        print('aqui ${contracheque.proventos}');

        return contracheque;
      } catch (error) {
        print(error);
        return contracheque;
      }
    } else {
      return contracheque;
    }
  }

  converteMes(String mes) {
    if (mes == 'Janeiro') {
      return '1';
    }
    if (mes == 'Fevereiro') {
      return '2';
    }
    if (mes == 'Março') {
      return '3';
    }
    if (mes == 'Abril') {
      return '4';
    }
    if (mes == 'Maio') {
      return '5';
    }
    if (mes == 'Junho') {
      return '6';
    }
    if (mes == 'Julho') {
      return '7';
    }
    if (mes == 'Agosto') {
      return '8';
    }
    if (mes == 'Setembro') {
      return '9';
    }
    if (mes == 'Outubro') {
      return '10';
    }
    if (mes == 'Novembro') {
      return '11';
    }
    if (mes == 'Dezembro') {
      return '12';
    }
  }
}
