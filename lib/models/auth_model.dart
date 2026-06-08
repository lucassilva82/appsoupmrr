import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supercharged/supercharged.dart';

import '../data/store.dart';
import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../utils/auth_exception.dart';

class Auth with ChangeNotifier {
  /* ===============================================================
   *  Atributos de estado
   * ============================================================= */
  bool autorizado = false;
  bool useBiometrics = false;
  bool isSuperUser = false;
  bool hasCheckedBiometry = false;
  bool biometricModalShown = false;

  DateTime? _expireDate;
  Timer? _logoutTimer;

  // Credenciais
  String? password;
  String? matricula;

  // Dados do militar
  String? cpf;
  String? nomeCompleto;
  String? dataIncorporacao;
  String? nomeMilitar;
  String? grupo;

  /// ► NOVOS CAMPOS
  int? nivel;
  int? idPosto;

  // E-mail do usuário
  String? emailUser;

  // Código de ativação
  String? activationCode;

  // Foto
  String? image; // URL no servidor
  String? localImagePath; // Caminho local salvo no aparelho

  final DadosSql dadosSql = DadosSql();

  /* ===============================================================
   *  Getters
   * ============================================================= */
  bool get isAuth =>
      autorizado && (_expireDate?.isAfter(DateTime.now()) ?? false);

  /* ===============================================================
   *  Funções utilitárias
   * ============================================================= */
  String generateMd5(String input) =>
      md5.convert(utf8.encode(input)).toString();

  /* ===============================================================
   *  Fluxo de autenticação
   * ============================================================= */
  Future<void> login(String matricula, String password) =>
      _authenticate(matricula, password);

  Future<void> loginSemNotificar(String matricula, String password) =>
      _authenticateLocalNoNotify(matricula, password);

  void finalizarLogin() => notifyListeners();

  Future<void> _authenticate(String matricula, String password) async {
    await _authenticateLocalNoNotify(matricula, password);
    notifyListeners();
  }

  Future<void> _authenticateLocalNoNotify(
      String matricula, String password) async {
    debugPrint('[LOG] _authenticateLocalNoNotify iniciado');

    /* ------------------------------------------------------------
     * 1) Dados de login
     * ---------------------------------------------------------- */
    final loginData = await dadosSql.getLoginData(matricula);
    if (loginData['error'] == true) throw AuthException('sql');

    final pswServer = loginData['pswd'] ?? '';
    final passwordMd5 = generateMd5(password);

    if (pswServer.isEmpty) throw AuthException('sql');
    if (pswServer != passwordMd5) throw AuthException('INVALID_PASSWORD');

    /* ------------------------------------------------------------
     * Credenciais OK
     * ---------------------------------------------------------- */
    this.matricula = matricula;
    this.password = password;
    autorizado = true;
    _expireDate = DateTime.now().add(const Duration(seconds: 86000));

    emailUser = loginData['email'];
    activationCode = loginData['activation_code'];

    /* ------------------------------------------------------------
     * 2) Dados completos do militar
     * ---------------------------------------------------------- */
    final Militar? militarTemp =
        await dadosSql.buscarMilitarBancoByMatricula(matricula);
    if (militarTemp == null) throw AuthException('sql');

    // Campos básicos
    cpf = militarTemp.cpf;
    nomeCompleto = militarTemp.nomeCompleto;
    image = militarTemp.imageUrl;
    nomeMilitar = '${militarTemp.postoGraduacao} ${militarTemp.qra}';
    dataIncorporacao = militarTemp.dataIncorporacao;
    grupo = militarTemp.grupo;

    // ► Novos campos
    nivel = militarTemp.nivel.toInt();
    idPosto = militarTemp.idPosto.toInt();

    /* ------------------------------------------------------------
     * 3) Super-usuário — nova lógica simplificada
     * ---------------------------------------------------------- */
    if (nivel == 1) {
      //Adm
      isSuperUser = true; // sempre
    } else if (nivel == 10) {
      //Usuario comum
      isSuperUser = false; // nunca
    } else {
      // Qualquer outro nível: depende do idPosto
      isSuperUser = (idPosto != null && idPosto! < 8);
    }
    debugPrint('isSuperUser: $isSuperUser');

    /* ------------------------------------------------------------
     * 4) Imagem local & gravação dos dados
     * ---------------------------------------------------------- */
    await saveImgToFileIfNeeded();
    await saveUserData();

    /* ------------------------------------------------------------
     * 5) Salvar FCM token no Firestore vinculado à matrícula
     * ---------------------------------------------------------- */
    await _saveFcmToken();

    _autoLogout();
    debugPrint('[LOG] _authenticateLocalNoNotify finalizado');
  }

  /* ===============================================================
   *  Métodos de arquivo/imagem e armazenamento local
   * ============================================================= */
  Future<void> saveImgToFileIfNeeded() async {
    if (image == null || image!.isEmpty || matricula == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fullPath = '${dir.path}/user_profile_${matricula!}.jpg';

    final userData = await Store.getMap('userData');
    final alreadySaved =
        userData['image'] == image && userData['localImagePath'] == fullPath;

    if (alreadySaved && await File(fullPath).exists()) {
      localImagePath = fullPath;
      return;
    }

    try {
      final response = await http.get(Uri.parse(image!));
      if (response.statusCode == 200) {
        await File(fullPath).writeAsBytes(response.bodyBytes);
        localImagePath = fullPath;

        userData['image'] = image;
        userData['localImagePath'] = fullPath;
        await Store.saveMap('userData', userData);
      }
    } catch (e) {
      debugPrint('[LOG] Erro ao baixar imagem: $e');
    }
  }

  Future<void> saveUserData() async => Store.saveMap('userData', {
        'cpf': cpf,
        'nomeCompleto': nomeCompleto,
        'matricula': matricula,
        'password': password,
        'autorizado': autorizado.toString(),
        'expireDate': _expireDate?.toIso8601String() ?? '',
        'nome': nomeMilitar,
        'dataIncorporacao': dataIncorporacao,
        'image': image,
        'localImagePath': localImagePath ?? '',
        'useBiometrics': useBiometrics.toString(),
        'biometricModalShown': biometricModalShown.toString(),
        'emailUser': emailUser ?? '',
        'activationCode': activationCode ?? '',
        'grupo': grupo ?? '',
        'nivel': nivel?.toString() ?? '',
        'idPosto': idPosto?.toString() ?? '',
        'isSuperUser': isSuperUser.toString(),
      });

  /// Salva (ou atualiza) o FCM token do dispositivo no Firestore,
  /// usando a matrícula como ID do documento em /militares/{matricula}.
  Future<void> _saveFcmToken() async {
    if (matricula == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('militares')
          .doc(matricula)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint(
          '[LOG] FCM token salvo no Firestore para matrícula $matricula');
    } catch (e) {
      debugPrint('[LOG] Erro ao salvar FCM token no Firestore: $e');
    }
  }

  /* --------------- MÉTODO MENCIONADO PELO USUÁRIO ---------------- */
  Future<bool> downloadUserProfileImage() async {
    if (image == null || image!.isEmpty || matricula == null) return false;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/user_profile_${matricula!}.jpg';
      final response = await http.get(Uri.parse(image!));

      if (response.statusCode == 200) {
        await File(filePath).writeAsBytes(response.bodyBytes);
        localImagePath = filePath;

        final userData = await Store.getMap('userData');
        userData['localImagePath'] = filePath;
        await Store.saveMap('userData', userData);

        return true;
      }
    } catch (e) {
      debugPrint('[LOG] downloadUserProfileImage erro: $e');
    }
    return false;
  }

  /* ===============================================================
   *  Auto-login
   * ============================================================= */
  Future<void> tryAutoLogin() async {
    debugPrint('[LOG] tryAutoLogin iniciado');
    final userData = await Store.getMap('userData');
    if (userData.isEmpty) {
      notifyListeners();
      return;
    }

    // Campos básicos
    matricula = userData['matricula'];
    password = userData['password'];
    cpf = userData['cpf'];
    nomeCompleto = userData['nomeCompleto'];
    dataIncorporacao = userData['dataIncorporacao'];
    nomeMilitar = userData['nome'];
    image = userData['image'];
    localImagePath = userData['localImagePath'];
    useBiometrics = userData['useBiometrics'] == 'true';
    biometricModalShown = userData['biometricModalShown'] == 'true';
    emailUser = userData['emailUser'];
    activationCode = userData['activationCode'];
    grupo = userData['grupo'];

    // ► Novos campos
    nivel = int.tryParse(userData['nivel'] ?? '');
    idPosto = int.tryParse(userData['idPosto'] ?? '');

    // Recalcula super-usuário pela mesma regra
    if (nivel == 1) {
      isSuperUser = true;
    } else if (nivel == 10) {
      isSuperUser = false;
    } else {
      isSuperUser = (idPosto != null && idPosto! < 8);
    }

    final expireDate = DateTime.tryParse(userData['expireDate'] ?? '');
    if (expireDate == null || expireDate.isBefore(DateTime.now())) {
      autorizado = false;
      _expireDate = null;
      biometricModalShown = false;
      notifyListeners();
      return;
    }

    autorizado = userData['autorizado'] == 'true';
    _expireDate = expireDate;
    if (autorizado) _autoLogout();
    notifyListeners();
  }

  /* ===============================================================
   *  Outros utilitários públicos já existentes
   * ============================================================= */
  Future<void> checkCredentialsWithoutLogin(
      String matricula, String password) async {
    final loginData = await dadosSql.getLoginData(matricula);

    if (loginData['error'] == true) throw AuthException('sql');

    final pswServer = loginData['pswd'] ?? '';
    if (pswServer.isEmpty || pswServer != generateMd5(password))
      throw AuthException('INVALID_PASSWORD');

    this.matricula = matricula;
    this.password = password;
    activationCode = loginData['activation_code'] ?? '';
    emailUser = loginData['email'] ?? '';
  }

  void logout() async {
    _expireDate = null;
    autorizado = false;
    hasCheckedBiometry = false;
    _clearLogoutTimer();

    final userData = await Store.getMap('userData');
    if (userData.isNotEmpty) {
      userData['autorizado'] = 'false';
      userData['expireDate'] = '';
      await Store.saveMap('userData', userData);
    }
    notifyListeners();
  }

  Future<void> clearAllCacheData() async {
    try {
      if (localImagePath != null && localImagePath!.isNotEmpty) {
        final f = File(localImagePath!);
        if (await f.exists()) await f.delete();
      }
      await Store.remove('userData');

      autorizado = false;
      useBiometrics = false;
      hasCheckedBiometry = false;
      biometricModalShown = false;
      isSuperUser = false;
      _expireDate = null;
      _clearLogoutTimer();

      password = null;
      matricula = null;
      cpf = null;
      nomeCompleto = null;
      dataIncorporacao = null;
      nomeMilitar = null;
      image = null;
      localImagePath = null;
      emailUser = null;
      activationCode = null;
      grupo = null;
      nivel = null;
      idPosto = null;
    } catch (e) {
      debugPrint('[LOG] Erro ao limpar dados: $e');
    }
  }

  /* ===============================================================
   *  Lógica de expiração automática
   * ============================================================= */
  void _autoLogout() {
    _clearLogoutTimer();
    final int? seconds = _expireDate?.difference(DateTime.now()).inSeconds;
    if (seconds != null && seconds > 0) {
      _logoutTimer = Timer(Duration(seconds: seconds), logout);
    }
  }

  void _clearLogoutTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = null;
  }
}
