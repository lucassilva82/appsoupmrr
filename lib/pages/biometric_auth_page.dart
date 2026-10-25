import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/design/fundo_circuito.dart';
import '../core/erros/falha_app.dart';
import '../core/log/registro_log.dart';
import '../models/auth_model.dart';
import '../services/biometric_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/auth_exception.dart';
import '../widgets/abertura_soupmrr.dart';
import '../widgets/aviso_rapido.dart';
import '../widgets/erro_login.dart';

/// Entrada por Face ID ou digital (padrão 2.2, pedido do usuário de
/// 25/10/2026): a tela que o militar vê toda vez que abre o app depois do
/// primeiro login. Antes era uma folha simples por cima do fundo; agora é a
/// tela inteira na linguagem do login do iPhone: fundo de circuito, marca no
/// alto, cartão de vidro com a foto (anel de luz girando), nome, matrícula e
/// CPF mascarado, o símbolo do Face ID ou da digital com ondas de luz, o botão
/// principal do tema e a saída para a matrícula e a senha. O símbolo e o botão
/// fazem a mesma coisa; nada pede o rosto sem um toque.
class BiometricAuthPage extends StatefulWidget {
  const BiometricAuthPage({super.key});

  @override
  State<BiometricAuthPage> createState() => _BiometricAuthPageState();
}

class _BiometricAuthPageState extends State<BiometricAuthPage> with TickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool isLoading = false;
  bool downloadError = false;
  File? localFile;

  /// Rosto ou digital, pelo que o aparelho tem: no iPhone quase sempre Face
  /// ID; no Android, digital, a menos que o sistema diga que é rosto.
  bool _temRosto = Platform.isIOS;

  /// Montagem da tela: marca, cartão e rodapé, em sequência.
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  /// Giro do anel da foto e ondas do símbolo (param com "Reduzir movimento").
  late final AnimationController _giro = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();
  late final AnimationController _ondas = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();

  bool _semMovimento = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocalOrDownload());
    BiometricService(_localAuth).getAvailableBiometrics().then((tipos) {
      final rosto =
          tipos.contains(BiometricType.face) || (Platform.isIOS && !tipos.contains(BiometricType.fingerprint));
      if (mounted && rosto != _temRosto) setState(() => _temRosto = rosto);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _semMovimento = MediaQuery.disableAnimationsOf(context);
    if (_semMovimento) {
      _entrada.value = 1;
      _giro.stop();
      _ondas.stop();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _giro.dispose();
    _ondas.dispose();
    super.dispose();
  }

  String get _nomeMetodo =>
      _temRosto ? (Platform.isIOS ? 'Face ID' : 'reconhecimento facial') : (Platform.isIOS ? 'Touch ID' : 'digital');

  String get _rotuloBotao => _temRosto
      ? (Platform.isIOS ? 'Entrar com Face ID' : 'Entrar com o rosto')
      : (Platform.isIOS ? 'Entrar com Touch ID' : 'Entrar com a digital');

  IconData get _icone => _temRosto ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded;

  Future<void> _outraConta() async {
    final auth = Provider.of<Auth>(context, listen: false);
    HapticFeedback.selectionClick();
    await auth.clearAllCacheData();
    // Chegando pela rota (depois de sair da conta), o AuthOrHome não está
    // embaixo para trocar a tela sozinho.
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.AUTH_PAGE, (_) => false);
  }

  // ── Carrega a foto do militar ─────────────────────────────────────────────
  Future<void> _checkLocalOrDownload() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.localImagePath != null && auth.localImagePath!.isNotEmpty) {
      final f = File(auth.localImagePath!);
      if (await f.exists()) {
        setState(() => localFile = f);
        return;
      }
    }
    final success = await auth.downloadUserProfileImage();
    if (success && auth.localImagePath != null) {
      final f = File(auth.localImagePath!);
      if (await f.exists()) {
        setState(() => localFile = f);
        return;
      }
    }
    setState(() => downloadError = true);
  }

  // ── Autentica e faz login ─────────────────────────────────────────────────
  Future<void> _authenticateAndLogin() async {
    final auth = Provider.of<Auth>(context, listen: false);
    setState(() => isLoading = true);
    try {
      // Sem a senha guardada no cofre não há como entrar pelo rosto: pede a
      // senha uma vez (o cofre pode ter sido apagado, APRENDIZADOS §48).
      if (auth.matricula == null || auth.password == null) {
        const f = FalhaApp(
          codigo: 'LG-BIO-SENHA',
          origem: OrigemFalha.aparelho,
          titulo: 'Entre com a senha uma vez',
          texto: 'O aparelho não tem mais a sua senha guardada. Entre com a matrícula e a senha; '
              'depois disso o Face ID volta a funcionar.',
          acao: AcaoFalha.entrarDeNovo,
        );
        registrar('sessao.biometria', resultado: 'falhou', codigo: f.codigo);
        registrarErro(f, tela: 'login.biometria');
        if (mounted) {
          avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
          Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_PAGE);
        }
        return;
      }

      final r = await BiometricService(_localAuth).confirmar();
      final f = r.falha;
      registrar('sessao.biometria',
          resultado: r.ok ? 'ok' : (f == null ? 'cancelado' : 'falhou'),
          codigo: f?.codigo,
          dados: {'metodo': Platform.isIOS ? 'face_id' : 'biometria'});
      if (f != null) {
        // Fica nesta tela: o militar lê o motivo e escolhe tentar de novo ou
        // "Entrar com outros dados". Antes voltava ao login sem explicar.
        registrarErro(f, tela: 'login.biometria');
        if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
        return;
      }
      if (!r.ok) return; // cancelou: continua aqui, com o botão para tentar de novo

      await auth.loginSemNotificar(auth.matricula!, auth.password!);
      auth.finalizarLogin();
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE);
    } on AuthException catch (e) {
      // O rosto confere, mas o servidor recusou ou não respondeu: o mesmo
      // cartão de erro do login, com o código LG-.
      registrar('sessao.biometria', resultado: 'falhou', codigo: e.codigo);
      if (mounted) await mostrarErroLogin(context, e);
    } catch (e) {
      final f = FalhaApp(
        codigo: 'LG-BIO-X-${e.runtimeType}'.toUpperCase(),
        origem: OrigemFalha.aparelho,
        titulo: 'Não foi possível entrar com ${BiometricService.comArtigo}',
        texto: 'Toque em "Entrar com outros dados" e use a matrícula e a senha. Se continuar, abra um chamado '
            'técnico com o código.',
        detalhe: '$e',
      );
      registrar('sessao.biometria', resultado: 'falhou', codigo: f.codigo);
      registrarErro(f, tela: 'login.biometria');
      if (mounted) avisoErro(context, f.titulo, texto: '${f.texto} Código ${f.codigo}.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double _trecho(double inicio, double fim) =>
      Curves.easeOutCubic.transform(((_entrada.value - inicio) / (fim - inicio)).clamp(0.0, 1.0));

  Widget _surge(double inicio, double fim, Widget filho, {double deslocamento = 20}) => AnimatedBuilder(
        animation: _entrada,
        builder: (_, f) {
          final t = _trecho(inicio, fim);
          return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, deslocamento * (1 - t)), child: f));
        },
        child: filho,
      );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final tela = MediaQuery.sizeOf(context);
    final larguraMarca = (tela.width * 0.40).clamp(150.0, 210.0);
    final branco72 = Colors.white.withValues(alpha: 0.72);

    return TelaEntrada(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(children: [
                          _surge(0, .45, MarcaSouPMRR(largura: larguraMarca), deslocamento: 10),
                          const SizedBox(height: 6),
                          _surge(
                            .15,
                            .55,
                            Text('POLÍCIA MILITAR DE RORAIMA',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.82))),
                            deslocamento: 8,
                          ),
                          const SizedBox(height: 18),
                          _surge(
                            .2,
                            .75,
                            CartaoVidroEntrada(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                              child: Column(children: [
                                _Avatar(
                                    arquivo: localFile,
                                    carregando:
                                        !downloadError && localFile == null && (auth.image?.isNotEmpty ?? false),
                                    giro: _giro),
                                const SizedBox(height: 16),
                                Text('BEM-VINDO DE VOLTA',
                                    style: TextStyle(
                                        fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600, color: branco72)),
                                const SizedBox(height: 4),
                                Text(auth.nomeMilitar ?? 'Militar',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        color: Colors.white)),
                                const SizedBox(height: 12),
                                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                                  _Pilula(icone: Icons.badge_outlined, texto: 'Mat. ${auth.matricula ?? '—'}'),
                                  _Pilula(icone: Icons.lock_outline_rounded, texto: 'CPF ${_cpfMascarado(auth.cpf)}'),
                                ]),
                                const SizedBox(height: 18),
                                _Simbolo(
                                  icone: _icone,
                                  rotulo: _rotuloBotao,
                                  ondas: _ondas,
                                  carregando: isLoading,
                                  onTap: isLoading ? null : _authenticateAndLogin,
                                ),
                                const SizedBox(height: 14),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(
                                    isLoading
                                        ? 'Conferindo ${_temRosto || Platform.isIOS ? 'o' : 'a'} $_nomeMetodo…'
                                        : (_temRosto
                                            ? 'Toque no símbolo e olhe para a tela do aparelho.'
                                            : 'Toque no símbolo e encoste o dedo no leitor.'),
                                    key: ValueKey(isLoading),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13.5, height: 1.4, color: branco72),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading ? null : _authenticateAndLogin,
                                    icon: Icon(_icone, size: AppIconSize.md),
                                    label: Text(_rotuloBotao,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: .86)),
                                    onPressed: isLoading ? null : _outraConta,
                                    icon: const Icon(Icons.key_rounded, size: AppIconSize.sm),
                                    label: const Text('Entrar com matrícula e senha',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ]),
                            ),
                            deslocamento: 36,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _surge(.55, 1, const RodapeEntrada(), deslocamento: 10),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A foto do militar com um anel de luz girando devagar (ciano, azul da ação
/// e navy) e um halo suave atrás.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.arquivo, required this.carregando, required this.giro});
  final File? arquivo;
  final bool carregando;
  final Animation<double> giro;

  @override
  Widget build(BuildContext context) {
    const lado = 96.0;
    final Widget dentro = arquivo != null
        ? Image.file(arquivo!, fit: BoxFit.cover, alignment: Alignment.topCenter)
        : carregando
            ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2)))
            : Icon(Icons.person_rounded, size: 54, color: Colors.white.withValues(alpha: .7));
    return Semantics(
      image: true,
      label: 'Foto do militar',
      child: SizedBox(
        width: lado,
        height: lado,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: const Color(0xFF4FD8F0).withValues(alpha: .28), blurRadius: 30, spreadRadius: 2),
            ]),
          ),
          RotationTransition(
            turns: giro,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [
                  Color(0xFF4FD8F0),
                  AppColors.acaoClara,
                  Color(0xFF0A2350),
                  Color(0xFF4FD8F0),
                ]),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(3.5),
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF071A36)),
            child: ClipOval(child: SizedBox.expand(child: ColoredBox(color: const Color(0xFF0E2A52), child: dentro))),
          ),
        ]),
      ),
    );
  }
}

/// Pílula de vidro com um dado da conta (matrícula, CPF mascarado).
class _Pilula extends StatelessWidget {
  const _Pilula({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icone, size: AppIconSize.xxs + 2, color: const Color(0xFF8FE6F7))),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .86),
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

/// O símbolo do Face ID ou da digital: um botão redondo com ondas de luz
/// saindo dele. Tocar faz o mesmo que o botão principal.
class _Simbolo extends StatelessWidget {
  const _Simbolo(
      {required this.icone, required this.rotulo, required this.ondas, required this.carregando, this.onTap});
  final IconData icone;
  final String rotulo;
  final Animation<double> ondas;
  final bool carregando;
  final VoidCallback? onTap;

  static const _ciano = Color(0xFF4FD8F0);

  @override
  Widget build(BuildContext context) {
    const lado = 76.0;
    return Semantics(
      button: true,
      label: rotulo,
      excludeSemantics: true,
      child: SizedBox(
        width: 132,
        height: 100,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: ondas,
            builder: (_, __) => CustomPaint(size: const Size(132, 100), painter: _Ondas(ondas.value)),
          ),
          Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: lado,
              height: lado,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E6BC0), Color(0xFF0A2E63)],
                ),
                border: Border.all(color: _ciano.withValues(alpha: .55), width: 1.4),
              ),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: carregando
                        ? const SizedBox(
                            key: ValueKey('c'),
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                        : Icon(icone, key: const ValueKey('i'), size: 40, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Duas ondas de luz que saem do símbolo e se apagam.
class _Ondas extends CustomPainter {
  _Ondas(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    for (final atraso in [0.0, 0.5]) {
      final f = (t + atraso) % 1.0;
      final raio = 38 + 18 * Curves.easeOut.transform(f);
      final alfa = (1 - f) * .45;
      canvas.drawCircle(
          centro,
          raio,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _Simbolo._ciano.withValues(alpha: alfa));
    }
    // Brilho fixo atrás do símbolo.
    canvas.drawCircle(
        centro,
        44,
        Paint()
          ..color = _Simbolo._ciano.withValues(alpha: .10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  }

  @override
  bool shouldRepaint(_Ondas old) => old.t != t;
}

/// CPF com só os 6 dígitos do meio à mostra (***.456.789-**): o bastante para
/// o militar reconhecer a conta, sem expor o número inteiro na tela.
String _cpfMascarado(String? cpf) {
  final d = (cpf ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return '—';
  return '***.${d.substring(3, 6)}.${d.substring(6, 9)}-**';
}
