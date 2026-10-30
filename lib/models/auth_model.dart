import '../core/rede/api_client.dart';
import '../core/config/app_config.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:projetonovo/features/avisos/avisos_api.dart';
import 'package:projetonovo/features/operacoes/armazem_operar.dart';
import 'package:projetonovo/features/operacoes/operar_api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supercharged/supercharged.dart';

import '../core/erros/falha_app.dart';
import '../core/log/registro_log.dart';
import '../core/sessao/sessao.dart';
import '../data/store.dart';
import '../models/militar.dart';
import '../services/certidao_service.dart';
import '../services/dados_sql.dart';
import '../utils/auth_exception.dart';
import '../vitrine/vitrine.dart';

class Auth with ChangeNotifier {
  /* ===============================================================
   *  Atributos de estado
   * ============================================================= */
  bool autorizado = false;
  bool useBiometrics = false;
  bool isSuperUser = false;
  bool hasCheckedBiometry = false;
  bool biometricModalShown = false;
  bool notificationsEnabled = true;

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

  final DadosSql dadosSql;

  /// `dadosSql` só é passado nos testes (respostas simuladas do SIGRH).
  Auth({DadosSql? dadosSql}) : dadosSql = dadosSql ?? DadosSql();

  bool _atualizandoPerfil = false;

  /// Busca de novo a ficha do militar no SIGRH, sem travar a abertura.
  ///
  /// A abertura automática (`tryAutoLogin`) usa a cópia guardada no aparelho,
  /// para o app abrir na hora. Sem esta atualização, nome de guerra, posto,
  /// lotação e foto trocados no SIGRH só apareciam depois de sair e entrar de
  /// novo (APRENDIZADOS §39). Falha aqui nunca derruba a sessão: fica a cópia
  /// guardada e o motivo vai para o log com código.
  Future<void> atualizarPerfilEmSegundoPlano() async {
    final mat = matricula;
    if (!autorizado || mat == null || mat.isEmpty || _atualizandoPerfil) return;
    _atualizandoPerfil = true;
    try {
      final militar = await dadosSql
          .buscarMilitarBancoByMatricula(mat)
          .timeout(const Duration(seconds: 20));
      if (militar == null) {
        debugPrint(
            '[PERFIL] PF-VAZIO matricula=$mat: SIGRH sem ficha; mantida a cópia guardada');
        return;
      }
      if (matricula != mat || !autorizado) return; // saiu da conta no meio
      final imagemAntes = image;
      _aplicarMilitar(militar);
      if (image != imagemAntes) {
        try {
          await saveImgToFileIfNeeded();
        } catch (e) {
          debugPrint('[PERFIL] PF-FOTO matricula=$mat: $e');
        }
      }
      await saveUserData();
      notifyListeners();
      debugPrint('[PERFIL] ficha atualizada: $nomeMilitar');
    } on TimeoutException catch (e) {
      debugPrint('[PERFIL] PF-LENTO matricula=$mat: $e');
    } on SocketException catch (e) {
      debugPrint('[PERFIL] PF-REDE matricula=$mat: $e');
    } on http.ClientException catch (e) {
      debugPrint('[PERFIL] PF-REDE matricula=$mat: $e');
    } catch (e) {
      debugPrint('[PERFIL] PF-X-${e.runtimeType} matricula=$mat: $e');
    } finally {
      _atualizandoPerfil = false;
    }
  }

  /// Copia a ficha do SIGRH para a sessão. Usado no login e na atualização
  /// em segundo plano, para os dois nunca divergirem.
  void _aplicarMilitar(Militar militarTemp) {
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
  }

  // Valor de activation_code de quem confirmou o e-mail; as telas de
  // Configurações e Confirmar e-mail comparam com ele.
  static const _codigoVerificado = 'pmrr190!@';

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
     * 1) Senha conferida no servidor (sigrh/login.php)
     * ---------------------------------------------------------- */
    final loginData =
        await dadosSql.autenticar(matricula, generateMd5(password));

    /* ------------------------------------------------------------
     * Credenciais OK
     * ---------------------------------------------------------- */
    this.matricula = matricula;
    this.password = password;
    autorizado = true;
    _expireDate = DateTime.now().add(const Duration(seconds: 86000));

    emailUser = loginData['email'];
    activationCode =
        loginData['email_confirmado'] == true ? _codigoVerificado : '';

    /* ------------------------------------------------------------
     * 2) Dados completos do militar
     * ---------------------------------------------------------- */
    // A senha já passou no servidor, então a internet funciona: falha de
    // rede aqui é o servidor que não atendeu.
    final Militar? militarTemp;
    try {
      militarTemp = await dadosSql
          .buscarMilitarBancoByMatricula(matricula)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (e) {
      throw _falhaFicha('SERVIDOR_LENTO', e);
    } on SocketException catch (e) {
      throw _falhaFicha('SERVIDOR_INACESSIVEL', e);
    } on http.ClientException catch (e) {
      throw _falhaFicha('SERVIDOR_INACESSIVEL', e);
    }
    if (militarTemp == null) {
      throw _falhaFicha('SQL', 'buscapormatricula sem dados');
    }

    _aplicarMilitar(militarTemp);

    /* ------------------------------------------------------------
     * 4) Imagem local & gravação dos dados
     * ---------------------------------------------------------- */
    await saveImgToFileIfNeeded();
    await saveUserData();

    /* ------------------------------------------------------------
     * 5) Salvar FCM token no Firestore vinculado à matrícula
     *    Fire-and-forget: não bloqueia o login.
     *    Se falhar (ex: APNs indisponível no simulador), o listener
     *    onTokenRefresh em main.dart salva quando o token aparecer.
     * ---------------------------------------------------------- */
    unawaited(_saveFcmToken());

    _autoLogout();
    debugPrint('[LOG] _authenticateLocalNoNotify finalizado');
  }

  /// Falha ao carregar a ficha depois da senha certa. Desfaz a autorização,
  /// para o app não ficar meio logado.
  AuthException _falhaFicha(String causa, Object detalhe) {
    autorizado = false;
    _expireDate = null;
    final falha = AuthException.completa(causa, detalhe: 'ficha: $detalhe');
    debugPrint('[LOGIN] ${falha.codigo} ${falha.detalhe}');
    return falha;
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

  /// Atualiza localmente a situação do e-mail (consultada em
  /// `status_email.php`) e avisa a interface. Usado para a tela de
  /// verificação reagir assim que o militar clica no link.
  Future<void> atualizarStatusEmail({
    required bool verificado,
    String? email,
  }) async {
    activationCode = verificado ? _codigoVerificado : '';
    if (email != null && email.isNotEmpty) emailUser = email;
    notifyListeners();
    await saveUserData();
  }

  /// A senha não entra mais no `userData`: vai para o cofre do aparelho
  /// (Keychain/Keystore), pela [Sessao]. Ver docs/SOUPM_2_2.md §6.6.
  Future<void> saveUserData() async {
    Sessao.matriculaAtual = matricula;
    // Entrou: a configuração do app passa a vir com o menu deste militar.
    unawaited(carregarAppConfig(
        api: ApiClient(), matricula: matricula, senha: password));
    // O cofre falhar não pode impedir de guardar o resto: no pior caso a
    // pessoa digita a senha de novo na próxima abertura.
    try {
      await Sessao.instancia.gravarSenha(password);
    } catch (e) {
      registrarErro(
          FalhaApp(
              codigo: 'LG-COFRE',
              origem: OrigemFalha.aparelho,
              titulo: 'Não foi possível guardar a senha no aparelho',
              texto: 'Na próxima abertura o app vai pedir a senha de novo.',
              detalhe: '$e'),
          mostrado: false);
    }
    await Store.saveMap('userData', _dadosGuardados());
  }

  Map<String, dynamic> _dadosGuardados() => {
        'cpf': cpf,
        'nomeCompleto': nomeCompleto,
        'matricula': matricula,
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
        'notificationsEnabled': notificationsEnabled.toString(),
      };

  /// Salva (ou atualiza) o FCM token do dispositivo no Firestore,
  /// usando a matrícula como ID do documento em /militares/{matricula}.
  Future<void> _saveFcmToken() async {
    // Matrícula fictícia: nada vai para o Firestore.
    if (modoVitrine) return;
    debugPrint('[FCM] ── _saveFcmToken() iniciado ──');
    if (matricula == null) {
      debugPrint('[FCM] ❌ Matrícula nula — token NÃO salvo.');
      return;
    }
    debugPrint('[FCM] Matrícula: $matricula');
    String? token;

    // 1) Tenta obter via plugin Flutter (funciona em device físico).
    try {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('[FCM] Token via plugin: ${token.substring(0, 40)}...');
      }
    } catch (e) {
      debugPrint('[FCM] getToken() falhou ($e)');
    }

    // 2) Fallback: token capturado nativamente no AppDelegate
    //    (necessário no simulador iOS, onde o plugin lança apns-token-not-set).
    if (token == null) {
      token = await Store.getString('native_fcm_token');
      if (token.isNotEmpty) {
        debugPrint(
            '[FCM] Token via nativo (UserDefaults): ${token.substring(0, 40)}...');
      } else {
        token = null;
      }
    }

    if (token == null) {
      debugPrint(
          '[FCM] ❌ Nenhum token disponível — será salvo via onTokenRefresh.');
      return;
    }

    // 3) Salva no Firestore
    try {
      debugPrint('[FCM] Salvando em Firestore → militares/$matricula ...');
      await FirebaseFirestore.instance
          .collection('militares')
          .doc(matricula)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('[FCM] ✅ Token salvo com sucesso! '
          'Firestore: militares/$matricula → fcmToken OK');
    } catch (e, stack) {
      debugPrint('[FCM] ❌ ERRO ao salvar token no Firestore: $e');
      debugPrint('[FCM] Stack: $stack');
    }

    // 4) 2.2: o aparelho também vai para o Postgres (soupm_dispositivo), de
    //    onde a API manda o push depois do corte do Firestore (§13).
    await DispositivoApi().registrar(
        token: token, matricula: matricula!, senhaMd5: generateMd5(password ?? ''));
  }

  /// O token deste aparelho, pelo plugin ou pelo valor nativo do iOS.
  static Future<String?> tokenDoAparelho() async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    final nativo = await Store.getString('native_fcm_token');
    return nativo.isEmpty ? null : nativo;
  }

  /// Sair da conta para de mandar push a este aparelho: o token deixa de ser
  /// desta matrícula no Postgres e, se o Firestore ainda aponta para ele, sai
  /// de lá também. Antes o logout não mexia no token e o aparelho continuava
  /// recebendo os avisos da conta anterior.
  Future<void> _desligarPushDaConta(String? matriculaQueSaiu) async {
    if (modoVitrine) return;
    final token = await tokenDoAparelho();
    if (token == null) return;
    await DispositivoApi().remover(token);
    if (matriculaQueSaiu == null || matriculaQueSaiu.isEmpty) return;
    try {
      final doc = FirebaseFirestore.instance.collection('militares').doc(matriculaQueSaiu);
      if ((await doc.get()).data()?['fcmToken'] == token) {
        await doc.update({'fcmToken': FieldValue.delete()});
      }
    } catch (e) {
      debugPrint('[FCM] não foi possível tirar o token do Firestore no logout: $e');
    }
  }

  /* ===============================================================
   *  Preferências do usuário
   * ============================================================= */
  Future<void> setBiometrics(bool val) async {
    useBiometrics = val;
    notifyListeners();
    await saveUserData();
  }

  Future<void> setNotificationsEnabled(bool val) async {
    notificationsEnabled = val;
    notifyListeners();
    await saveUserData();
    try {
      if (val) {
        // Reinscreve nos tópicos globais
        await FirebaseMessaging.instance.subscribeToTopic('todos_militares');
        await FirebaseMessaging.instance.subscribeToTopic('pmrr_usuarios');
        // Salva token individual no Firestore
        if (matricula != null) {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FirebaseFirestore.instance
                .collection('militares')
                .doc(matricula)
                .set({'fcmToken': token}, SetOptions(merge: true));
          }
        }
      } else {
        // Desinscreve dos tópicos globais
        await FirebaseMessaging.instance
            .unsubscribeFromTopic('todos_militares');
        await FirebaseMessaging.instance.unsubscribeFromTopic('pmrr_usuarios');
        // Remove token individual do Firestore
        if (matricula != null) {
          await FirebaseFirestore.instance
              .collection('militares')
              .doc(matricula)
              .update({'fcmToken': FieldValue.delete()});
        }
      }
    } catch (e) {
      debugPrint('[LOG] Erro ao atualizar notificações: $e');
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
    // Quem vem da 2.1.x tem a senha no armazenamento comum: passa para o
    // cofre antes de ler, sem deslogar ninguém.
    try {
      await Sessao.instancia.migrar();
    } catch (e) {
      debugPrint('[SESSAO] migração adiada: $e');
    }
    final userData = await Store.getMap('userData');
    if (userData.isEmpty) {
      notifyListeners();
      return;
    }

    // Campos básicos
    matricula = userData['matricula'];
    Sessao.matriculaAtual = matricula;
    try {
      password = await Sessao.instancia.senha();
    } catch (e) {
      password = null;
      debugPrint('[SESSAO] cofre indisponível: $e');
    }
    cpf = userData['cpf'];
    nomeCompleto = userData['nomeCompleto'];
    dataIncorporacao = userData['dataIncorporacao'];
    nomeMilitar = userData['nome'];
    image = userData['image']?.replaceAll('pmrr.net', 'pmrr.online');
    localImagePath = userData['localImagePath'];
    useBiometrics = userData['useBiometrics'] == 'true';
    biometricModalShown = userData['biometricModalShown'] == 'true';
    notificationsEnabled = userData['notificationsEnabled'] != 'false';
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
    final loginData =
        await dadosSql.autenticar(matricula, generateMd5(password));

    this.matricula = matricula;
    this.password = password;
    activationCode =
        loginData['email_confirmado'] == true ? _codigoVerificado : '';
    emailUser = loginData['email'] ?? '';
  }

  /// [deliberado] é o "Sair" que o militar toca. A expiração automática chama
  /// isto sem o sinal, e é diferente de propósito: ela não desfaz o acesso ao
  /// Operar, porque é o mesmo militar voltando e pedir `/acesso` de novo
  /// derrubaria o aparelho dele no navegador.
  void logout({bool deliberado = false}) async {
    _expireDate = null;
    autorizado = false;
    hasCheckedBiometry = false;
    biometricModalShown = false;
    _clearLogoutTimer();

    // Notifica imediatamente: o estado em memória já está correto.
    // Não espera o storage para atualizar a UI.
    notifyListeners();

    unawaited(_desligarPushDaConta(matricula));

    // Salva o logout no storage em background
    final userData = await Store.getMap('userData');
    if (userData.isNotEmpty) {
      userData['autorizado'] = 'false';
      userData['expireDate'] = '';
      await Store.saveMap('userData', userData);
    }

    // O módulo Operações não tem "sair" próprio: quem entra no Sou PM só usa
    // a conta da matrícula que entrou, e o único logout é este (decisão do
    // Lucas, 30/10/2026). Então sair daqui desfaz o acesso ao Operar — o
    // token sai do cofre e o armazém da WebView fica marcado para esvaziar.
    if (deliberado) {
      await SessaoOperar.limparDoAparelho();
      unawaited(limparArmazemOperar());
    }
  }

  Future<void> clearAllCacheData() async {
    try {
      final imagePath = localImagePath; // salva antes de nullar

      // Reset imediato de todo o estado em memória
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

      // Notifica imediatamente — AuthOrHome exibe AuthPage
      notifyListeners();

      // Limpeza de arquivos e storage em background
      if (imagePath != null && imagePath.isNotEmpty) {
        final f = File(imagePath);
        if (await f.exists()) await f.delete();
      }
      await Store.remove('userData');
      await Sessao.instancia.apagarTudo();
      Sessao.matriculaAtual = null;
      // Certidões têm dados pessoais (a Ficha traz conta e endereço).
      await CertidaoService.apagarTudo();
      // O token do Operar é um acesso a outro sistema: sai com quem o pediu.
      await SessaoOperar.limparDoAparelho();
      unawaited(limparArmazemOperar());
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
