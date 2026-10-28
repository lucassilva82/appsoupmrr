import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/ficha_funcional.dart';

import '../models/contracheque_model.dart';
import '../models/endereco.dart';
import '../models/meses_contracheque_model.dart';
import '../models/militar.dart';
import '../models/telefone.dart';
import '../utils/auth_exception.dart';

class DadosSql {
  //URL DO BANCO SQL TROCAR URL AQUI E NA API PARA CONECTAR NO BANCO DE PRODUCAO
  // Para testar com a API local: --dart-define=SIGRH_URL=http://127.0.0.1:8089/sigrh
  final _Url = const String.fromEnvironment('SIGRH_URL',
      defaultValue: 'https://pmrr.online/flutter/sigrh');
  // final _Url = 'http://192.168.190.250/flutter/sigrh';

  /// Confere matrícula e senha no servidor (sigrh/login.php). A senha vai
  /// em MD5, formato do banco, e por POST; o servidor nunca devolve o hash.
  ///
  /// Retorna { "email": String?, "email_confirmado": bool }.
  /// Lança [AuthException] com a causa: as do servidor (SENHA_INVALIDA,
  /// MATRICULA_NAO_ENCONTRADA, MUITAS_TENTATIVAS, CONTA_INATIVA,
  /// DADOS_INVALIDOS, ERRO_SERVIDOR) ou as da conexão (SEM_INTERNET,
  /// SERVIDOR_INACESSIVEL, SERVIDOR_LENTO, CONEXAO_SEGURA,
  /// RESPOSTA_INVALIDA).
  Future<Map<String, dynamic>> autenticar(
      String matricula, String senhaMd5) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_Url/login.php'),
        body: {'matricula': matricula, 'senha': senhaMd5},
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException catch (e) {
      throw _falhaLogin('SERVIDOR_LENTO', e);
    } on HandshakeException catch (e) {
      throw _falhaLogin('CONEXAO_SEGURA', e);
    } on SocketException catch (e) {
      throw _falhaLogin(
          await _temInternet() ? 'SERVIDOR_INACESSIVEL' : 'SEM_INTERNET', e);
    } on http.ClientException catch (e) {
      throw _falhaLogin(
          await _temInternet() ? 'SERVIDOR_INACESSIVEL' : 'SEM_INTERNET', e);
    }

    if (response.statusCode != 200) {
      throw _falhaLogin('ERRO_SERVIDOR', 'HTTP ${response.statusCode}');
    }

    final dynamic map;
    try {
      map = json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw _falhaLogin('RESPOSTA_INVALIDA', e);
    }
    if (map is! Map) throw _falhaLogin('RESPOSTA_INVALIDA', 'não é objeto');

    if (map['code'] != 1) {
      final erro = (map['erro'] ?? '').toString();
      final falha = AuthException.completa(
        erro.isEmpty ? 'RESPOSTA_INVALIDA' : erro,
        mensagemServidor: map['message']?.toString(),
        detalhe: 'servidor: ${map['message']}',
        liberaEmSeg: int.tryParse('${map['libera_em_seg'] ?? ''}'),
        matricula: matricula,
      );
      debugPrint('[LOGIN] ${falha.codigo} ${falha.detalhe}');
      throw falha;
    }

    final email = (map['email'] ?? '').toString().trim();
    return {
      'email': email.isEmpty ? null : email,
      'email_confirmado': map['email_confirmado'] == true,
    };
  }

  /// Monta a falha e registra o motivo técnico no log (nunca na tela).
  AuthException _falhaLogin(String causa, Object detalhe) {
    final falha = AuthException.completa(causa, detalhe: '$detalhe');
    debugPrint('[LOGIN] ${falha.codigo} $detalhe');
    return falha;
  }

  // Só para testar a mensagem de "sem internet" no simulador, que usa a rede
  // do Mac: --dart-define=HOST_TESTE_INTERNET=nao-existe.invalid
  static const _hostTesteInternet = String.fromEnvironment(
      'HOST_TESTE_INTERNET',
      defaultValue: 'google.com');

  /// Distingue "aparelho sem internet" de "nosso servidor fora do ar":
  /// se outro endereço conhecido resolve, a internet está funcionando.
  Future<bool> _temInternet() async {
    try {
      final r = await InternetAddress.lookup(_hostTesteInternet)
          .timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // === BUSCA UM MILITAR POR MATRICULA ======================
  Future<Militar?> buscarMilitarBancoByMatricula(String matricula) async {
    final String url = '$_Url/buscapormatricula.php?matricula=$matricula';
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    FichaFuncional fichaTemp =
        await buscarSituacaoFuncional(matricula) ?? FichaFuncional();

    try {
      final map = _safeJsonDecode(response);
      final dadosMilitar = map['result'];
      bool existeFoto = dadosMilitar[0]['imagemurl'].toString() ==
              'https://rh.pmrr.online/_lib/file/img//wc2/pix_db/'
          ? false
          : true;
      Militar militarTemp = Militar(
        fichaFuncional: fichaTemp,
        matRhNova: dadosMilitar[0]['sigrh'].toString(),
        dataIncorporacao: dadosMilitar[0]['incorporacao'].toString(),
        quadro: dadosMilitar[0]['quadro'].toString(),
        matricula: dadosMilitar[0]['matricula'].toString(),
        postoGraduacao:
            dadosMilitar[0]['postograduacao'].toString().toUpperCase(),
        qra: dadosMilitar[0]['qra'].toString().toUpperCase(),
        grupo: dadosMilitar[0]['grupo'].toString(),
        nivel: dadosMilitar[0]['nivel'].toString(),
        idPosto: dadosMilitar[0]['id_posto'].toString(),
        nomeCompleto: dadosMilitar[0]['nomecompleto'].toString(),
        imageUrl: existeFoto
            ? dadosMilitar[0]['imagemurl']
                .toString()
                .replaceAll('pmrr.net', 'pmrr.online')
            : 'null',
        cpf: dadosMilitar[0]['cpf'].toString(),
        subUnidade: dadosMilitar[0]['subu_descricao'].toString(),
        endereco: Endereco(
          Municipio(
            nome: dadosMilitar[0]['muni_nome'].toString(),
            id: dadosMilitar[0]['muni_cod'].toString(),
          ),
          Bairro(
            id: dadosMilitar[0]['bair_cod'].toString(),
            nome: dadosMilitar[0]['bair_nome'].toString(),
          ),
          Rua(
            id: dadosMilitar[0]['rua_cod'].toString(),
            nome: dadosMilitar[0]['concat'].toString(),
          ),
          dadosMilitar[0]['numero'].toString(),
          dadosMilitar[0]['cep'].toString(),
        ),
      );

      dadosMilitar.forEach((dados) {
        var tipo = Tipos.comum;
        bool value = false;

        if (dados['telefone'] != null) {
          if (dados['poli_cont_whats'] == 1) {
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

  // === BUSCA SITUACAO FUNCIONAL DO MILITAR =================
  Future<FichaFuncional?> buscarSituacaoFuncional(String matricula) async {
    final String url = '$_Url/buscasituacaofuncional.php?matricula=$matricula';
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    FichaFuncional fichaFuncional = FichaFuncional();
    try {
      final map = _safeJsonDecode(response);

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
      return null;
    }
  }

  Future<bool> adicionaContatos(
      String matricula, String telefone, String possuiwhats) async {
    try {
      final String url =
          '$_Url/inserecontato.php?matricula=$matricula&telefone=$telefone&possuiwhats=$possuiwhats';
      await http.get(Uri.parse(Uri.encodeFull(url)));
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<bool> excluiContatos(String matricula) async {
    try {
      final String url = '$_Url/deletacontato.php?matricula=$matricula';
      await http.get(Uri.parse(Uri.encodeFull(url)));
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<List<Endereco>> listaEnderecoCompleto(String busca) async {
    if (busca.length < 3) {
      throw Exception();
    }
    final String url = '$_Url/listaenderecocompleto.php';
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    if (response.statusCode == 200) {
      try {
        final List enderecos = _safeJsonDecode(response);

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
          '$_Url/atualizaendereco.php?codmuni=$codMuni&codbairro=$codBairro&codrua=$codRua&numero=$numero&cep=$cep&matricula=$matricula';

      await http.get(Uri.parse(Uri.encodeFull(url)));
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<List<MesesContracheque>> listaMesesContracheque(
      String cpf, String ano) async {
    final String url = "$_Url/listamesescontracheque_new.php?cpf=$cpf&ano=$ano";
    final response = await http.get(Uri.parse(Uri.encodeFull(url)));
    final String urlOld = "$_Url/listamesescontracheque.php?cpf=$cpf&ano=$ano";
    final responseOld = await http.get(Uri.parse(Uri.encodeFull(urlOld)));

    List<MesesContracheque> mesesContracheque = [];

    // API nova
    if (response.statusCode == 200) {
      try {
        var dados = _safeJsonDecode(response);
        print(dados.toString());
        dados.forEach((element) {
          MesesContracheque mesContracheque = MesesContracheque(
            tipo: "B",
            codProvento: "0",
            mes: element['mes'].toString(),
            mesExtenso: element['mes_extenso'],
            relacaoTrabalho: element['relacaotrabalho'],
            folha: (element['folha'] ?? '').toString(),
            cpf: element['cpf'],
            ano: ano.toString(),
            matricula: element['matricula'].toString(),
          );
          mesesContracheque.add(mesContracheque);
        });
        print("Tamanho após API nova: ${mesesContracheque.length}");
      } catch (error) {
        // Mostra/log o erro se necessário
      }
    }

    // API antiga
    if (responseOld.statusCode == 200) {
      try {
        var dadosOld = _safeJsonDecode(responseOld);
        print(dadosOld.toString());
        dadosOld.forEach((element) {
          MesesContracheque mesContracheque = MesesContracheque(
            tipo: "A",
            codProvento: element['cod_provento'].toString(),
            mes: element['mes'].toString(),
            mesExtenso: element['mes'],
            relacaoTrabalho: element['lotacao'],
            folha: element['lotacao'].toString(),
            cpf: element['cpf'].toString(),
            ano: ano.toString(),
            matricula: element['matricula'].toString(),
          );
          mesesContracheque.add(mesContracheque);
        });
        print("Tamanho após API antiga: ${mesesContracheque.length}");
      } catch (error) {
        // Trate o erro se necessário
      }
    }

    // Ordena a lista do mês mais novo (maior número) para o mais antigo (menor)
    // Utiliza sua função converteMes para transformar o mês em número (string) e depois em int
    mesesContracheque.sort((a, b) => int.parse(converteMes(b.mesExtenso))
        .compareTo(int.parse(converteMes(a.mesExtenso))));

    return mesesContracheque;
  }

  Future<ContrachequeModel> buscaContracheque(
      String cpf,
      String ano,
      String mes,
      String mesExtenso,
      String matricula,
      String tipo,
      String codProvento,
      String relacaoTrabalho,
      String folha) async {
    mes = converteMes(mesExtenso); // Garante que 'mes' seja o número correto
    print(
        "Tipo de contracheque: $tipo e mes = $mes e mesExtenso = $mesExtenso, relacaoTrabalho = $relacaoTrabalho");
    // Se o tipo for "A", usamos a API antiga
    if (tipo == "A") {
      final String url =
          "${_Url}/exibecontracheque.php?cpf=$cpf&ano=$ano&mes=$mes&cod=$codProvento&matricula=$matricula&relacaoTrabalho=$relacaoTrabalho";

      final response = await http.get(Uri.parse(Uri.encodeFull(url)));
      print("respsta foi = ${response.body}");
      ContrachequeModel contracheque = ContrachequeModel();
      contracheque.proventos = [];

      if (response.statusCode == 200) {
        try {
          var dados = _safeJsonDecode(response);

          dados.forEach((element) {
            String tipoRub = element['dp'].toString();
            TipoProvento dp = TipoProvento(
              tipoRubrica: element['dp'].toString(),
              descricaoRubrica: _fixOrdinals(element['descricao'].toString()),
              provento: tipoRub == "P" ? element['valor'].toString() : "0.00",
              desconto: tipoRub == "D" ? element['valor'].toString() : "0.00",
              parcelas: element['parcelas'].toString(),
            );

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
    } else {
      // A nova API utiliza o parâmetro "mesExtenso",
      // utilizamos o valor passado em 'mes' diretamente (ex: "AGOSTO")
      final String url =
          "$_Url/exibecontracheque_new.php?cpf=$cpf&matricula=$matricula&ano=$ano&mesExtenso=$mesExtenso&relacaoTrabalho=$relacaoTrabalho&folha=$folha";
      final response = await http.get(Uri.parse(Uri.encodeFull(url)));

      ContrachequeModel contracheque = ContrachequeModel();
      contracheque.proventos = [];

      if (response.statusCode == 200) {
        try {
          var jsonResponse = _safeJsonDecode(response);
          if (jsonResponse["code"] == 1) {
            List<dynamic> data = jsonResponse["data"];
            if (data.isNotEmpty) {
              // Preenche os dados principais a partir do primeiro registro
              var first = data[0];
              contracheque.matricula = first["matricula"] ?? '';
              contracheque.matriculaLegado =
                  (first["matriculalegado"] ?? '').toString();
              contracheque.mesExtenso = first["mes_extenso"] ?? '';
              contracheque.UnidadeOrganizacional =
                  first["unidade_organizacional"] ?? '';
              contracheque.Folha = first["folha"] ?? '';
            }
            // Para cada registro, adiciona um TipoProvento
            for (var element in data) {
              // Obtém o valor do provento (ex: "8.791,85")
              String proventoStr = element["provento"] ?? '';
              // Remove o separador de milhar e troca a vírgula decimal por ponto
              String cleanedProvento =
                  proventoStr.replaceAll('.', '').replaceAll(',', '.');
              // Converte para double (caso necessário para cálculo)
              double valorProvento = double.tryParse(cleanedProvento) ?? 0.0;

              // Faz o mesmo tratamento para desconto
              String descontoStr = element["desconto"] ?? '';
              String cleanedDesconto =
                  descontoStr.replaceAll('.', '').replaceAll(',', '.');
              double valorDesconto = double.tryParse(cleanedDesconto) ?? 0.0;

              // Armazena os valores convertidos em strings com 2 casas decimais
              TipoProvento tp = TipoProvento(
                tipoRubrica: element["tiporubrica"] ?? '',
                descricaoRubrica:
                    _fixOrdinals(element["descricaorubrica"] ?? ''),
                provento: valorProvento.toStringAsFixed(2),
                parcelas: element["parcelas"] ?? '',
                desconto: valorDesconto.toStringAsFixed(2),
              );
              contracheque.proventos.add(tp);
            }
          }
          return contracheque;
        } catch (error) {
          print("Erro ao processar o contracheque: $error");
          return contracheque;
        }
      } else {
        return contracheque;
      }
    }
  }

  String converteMes(String mes) {
    if (mes == 'Janeiro') return '1';
    if (mes == 'Fevereiro') return '2';
    if (mes == 'Março') return '3';
    if (mes == 'Abril') return '4';
    if (mes == 'Maio') return '5';
    if (mes == 'Junho') return '6';
    if (mes == 'Julho') return '7';
    if (mes == 'Agosto') return '8';
    if (mes == 'Setembro') return '9';
    if (mes == 'Outubro') return '10';
    if (mes == 'Novembro') return '11';
    if (mes == 'Dezembro') return '12';
    return mes;
  }

  /// Corrige sequências comuns de mojibake de ordinais (ex.: "2�" -> "2ª")
  String _fixOrdinals(String s) {
    if (s.isEmpty) return s;
    // Remove 'Â' inserido por dupla decodificação
    s = s.replaceAll('Â', '');
    // Substitui o caractere de substituição por 'ª' quando vem após um dígito
    s = s.replaceAllMapped(RegExp(r'(\d)�'), (m) => '${m.group(1)}ª');
    // Também cobre casos com espaço entre o dígito e o marcador
    s = s.replaceAllMapped(RegExp(r'(\d)\s�'), (m) => '${m.group(1)}ª');
    return s;
  }

  /// Decodifica JSON de forma segura, tentando primeiro UTF-8 e depois Latin1
  dynamic _safeJsonDecode(http.Response response) {
    try {
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (_) {
      try {
        return json.decode(latin1.decode(response.bodyBytes));
      } catch (e) {
        // Último recurso: permitir UTF-8 malformado
        return json
            .decode(utf8.decode(response.bodyBytes, allowMalformed: true));
      }
    }
  }
}
