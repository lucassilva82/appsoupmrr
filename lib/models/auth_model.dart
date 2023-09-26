import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/dados_sql.dart';
import '../utils/NotificationService.dart';
import '../utils/auth_exception.dart';
import '../models/militar.dart';

import 'package:crypto/crypto.dart';

class Auth with ChangeNotifier {
  bool autorizado = false;
  DateTime? _expireDate;
  Timer? _logoutTimer;
  String? password;
  String? matricula;
  String? image;
  String? nomeMilitar;
  String? cpf;
  String? dataIncorporacao;
  String? nomeCompleto;

  NotificationService notificationService = NotificationService();

  DadosSql dadosSql = DadosSql();

  bool get isAuth {
    final isValid = _expireDate?.isAfter(DateTime.now()) ?? false;
    if (autorizado == true) {
      return isValid;
    } else {
      return false;
    }
  }

  //Autentica o usuário
  Future<void> _authenticate(String matricula, String password) async {
    DadosSql dadosSql = DadosSql();

    String passwordMd5 = generateMd5(password);

    String resp = await dadosSql.getPasswordWithMd5(matricula, password);

    if (resp == 'error') {
      throw AuthException('sql');
    } else {
      if (resp != passwordMd5) {
        throw AuthException('INVALID_PASSWORD');
      } else {
        this.matricula = matricula;
        this.password = password;
        this.autorizado = true;
        _expireDate = DateTime.now().add(
          Duration(seconds: int.parse('86000')),
        );

        Militar? militarTemp =
            await dadosSql.buscarMilitarBancoByMatricula(matricula);
        if (militarTemp == null) {
          throw AuthException('sql');
        }
        cpf = militarTemp.cpf;
        nomeCompleto = militarTemp.nomeCompleto;
        image = militarTemp.imageUrl;
        nomeMilitar = militarTemp.postoGraduacao + ' ' + militarTemp.qra;
        dataIncorporacao = militarTemp.dataIncorporacao;

        // Salva os dados na memoria do dispositivo
        Store.saveMap('userData', {
          'cpf': cpf,
          'nomeCompleto': nomeCompleto,
          'matricula': matricula,
          'autorizado': autorizado.toString(),
          'expireDate': _expireDate?.toIso8601String(),
          'nome': nomeMilitar,
          'dataIncorporacao': dataIncorporacao,
          'image': image,
        });

        _autoLogout();
        notifyListeners();
      }
    }
  }

  saveImgToFile() {}

  String generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<void> login(String matricula, String password) async {
    return _authenticate(matricula, password);
  }

  // Faz o auto login e caso nao tenha, no primeiro login salva os dados do usuario
  Future<void> tryAutoLogin() async {
    if (isAuth) return;

    final userData = await Store.getMap('userData');
    if (userData.isEmpty) return;

    final expireDate = DateTime.parse(userData['expireDate']);
    if (expireDate.isBefore(DateTime.now())) return;

    matricula = userData['matricula'];
    userData['autorizado'] == 'true' ? autorizado = true : autorizado = false;
    _expireDate = expireDate;
    image = userData['image'];
    nomeCompleto = userData['nomeCompleto'];
    cpf = userData['cpf'];
    dataIncorporacao = userData['dataIncorporacao'];
    nomeMilitar = userData['nome'];

    _autoLogout();
    notifyListeners();
  }

  void logout() {
    _expireDate = null;

    _clearLogoutTimer();
    Store.remove('userData').then((_) {
      notifyListeners();
    });
  }

  void _clearLogoutTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = null;
  }

  void _autoLogout() {
    _clearLogoutTimer();
    final timeToLogout = _expireDate?.difference(DateTime.now()).inSeconds;
    _logoutTimer = Timer(Duration(seconds: timeToLogout ?? 0), logout);
  }
}
