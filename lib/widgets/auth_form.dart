import 'dart:math' as math;

import '../core/sessao/sessao.dart';
import 'package:flutter/material.dart';
import 'package:projetonovo/pages/primeiro_acesso_page.dart';
import 'package:projetonovo/pages/recuperar_senha_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_model.dart';
import '../utils/auth_exception.dart';
import '../utils/app_theme.dart';
import 'convite_biometria.dart';
import 'erro_login.dart';

class AuthForm extends StatefulWidget {

  /// Android: campos contornados e botão do Material 3. iOS: campos
  /// agrupados num bloco só, como os formulários do sistema.
  final bool material;
  const AuthForm({Key? key, this.material = false}) : super(key: key);

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _focoSenha = FocusNode();
  bool _ocultarSenha = true;

  /// Balanço curto dos campos quando falta algo (como o "não" do iOS).
  late final AnimationController _balanco =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _apertado = false;
  bool _isLoading = false;
  bool _lembrarAcesso = true;

  final _matriculaController = TextEditingController();
  final _passwordController = TextEditingController();

  final Map<String, String> _authData = {
    'matricula': '',
    'password': '',
  };

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
  }

  Future<void> _loadUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedM = prefs.getString('matricula') ?? '';
    final savedP = await Sessao.instancia.senhaLembrada() ?? '';
    final lembrar = prefs.getBool('lembrarAcesso') ?? false;

    if (lembrar) {
      setState(() {
        _matriculaController.text = savedM;
        _passwordController.text = savedP;
        _lembrarAcesso = lembrar;
      });
    }
  }

  /// Pergunta, uma vez, se a pessoa quer entrar por biometria nas próximas
  /// vezes. O convite só aparece se o aparelho tiver sensor configurado, e só
  /// liga depois de a biometria ser confirmada — ligar sem testar deixaria a
  /// pessoa trancada fora no próximo acesso.
  Future<void> _askEnableBiometrics() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final ativou = await convidarParaBiometria(context);
    auth.useBiometrics = ativou;
    await auth.saveUserData();
  }

  @override
  void dispose() {
    _balanco.dispose();
    _focoSenha.dispose();
    _matriculaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (!MediaQuery.disableAnimationsOf(context)) _balanco.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final auth = Provider.of<Auth>(context, listen: false);
    _formKey.currentState?.save();

    AuthException? falha;
    try {
      // O e-mail não verificado NÃO bloqueia mais o acesso: muitos militares
      // ficavam presos na tela de confirmação sem conseguir entrar. A pendência
      // passou a aparecer em Perfil → Conta, de onde a verificação pode
      // ser feita a qualquer momento.
      await auth.loginSemNotificar(
          _authData['matricula']!, _authData['password']!);

      // Grava (ou não) as credenciais
      final prefs = await SharedPreferences.getInstance();
      if (_lembrarAcesso) {
        await prefs.setString('matricula', _authData['matricula']!);
        await Sessao.instancia.gravarSenhaLembrada(_authData['password']);
        await prefs.setBool('lembrarAcesso', true);
      } else {
        await prefs.remove('matricula');
        await Sessao.instancia.gravarSenhaLembrada(null);
        await prefs.setBool('lembrarAcesso', false);
      }

      // Pergunta biometria
      if (!auth.useBiometrics) {
        await _askEnableBiometrics();
      }

      // Finaliza -> vai Home
      auth.finalizarLogin();
    } on AuthException catch (error) {
      falha = error;
    } catch (error, stack) {
      // Nada pode cair numa mensagem genérica sem rastro: o código leva o
      // tipo do erro, e o detalhe vai para o log.
      falha = AuthException.completa(
        error.runtimeType.toString().toUpperCase(),
        detalhe: '$error',
      );
      debugPrint('[LOGIN] ${falha.codigo} $error\n$stack');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (falha != null && mounted) await _mostrarFalha(falha);
  }

  Future<void> _mostrarFalha(AuthException falha) async {
    final acao = await mostrarErroLogin(context, falha);
    if (!mounted || acao == null) return;
    switch (acao) {
      case AcaoErroLogin.tentarDeNovo:
        await _submit();
      case AcaoErroLogin.recuperarSenha:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecuperarSenhaPage()),
        );
      case AcaoErroLogin.primeiroAcesso:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrimeiroAcessoPage()),
        );
      case AcaoErroLogin.fechar:
        break;
    }
  }

  // ── Campos ──────────────────────────────────────────────────────────────

  Widget _campoMatricula(InputDecoration deco) => TextFormField(
        controller: _matriculaController,
        style: const TextStyle(fontSize: 16, color: Colors.white),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username],
        onFieldSubmitted: (_) => _focoSenha.requestFocus(),
        decoration: deco,
        onSaved: (v) => _authData['matricula'] = v?.trim() ?? '',
        validator: (v) => (v == null || v.isEmpty) ? 'Informe sua matrícula' : null,
      );

  Widget _campoSenha(InputDecoration deco) => TextFormField(
        controller: _passwordController,
        focusNode: _focoSenha,
        style: const TextStyle(fontSize: 16, color: Colors.white),
        obscureText: _ocultarSenha,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onFieldSubmitted: (_) => _submit(),
        decoration: deco.copyWith(
          suffixIcon: IconButton(
            tooltip: _ocultarSenha ? 'Mostrar senha' : 'Esconder senha',
            icon: Icon(
              _ocultarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white60,
              size: 20,
            ),
            onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
          ),
        ),
        onSaved: (v) => _authData['password'] = v?.trim() ?? '',
        validator: (v) => (v == null || v.length < 5) ? 'Senha inválida (mín. 5 caracteres)' : null,
      );

  /// iOS: os dois campos num bloco só, com um fio entre eles (como o login
  /// do Apple ID e os formulários dos Ajustes).
  Widget _camposIos() {
    InputDecoration deco(String rotulo, IconData icone) => InputDecoration(
          labelText: rotulo,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
          floatingLabelStyle:
              const TextStyle(color: AppColors.lightBlue, fontSize: 13, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icone, color: Colors.white60, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
          errorStyle: const TextStyle(color: AppColors.falhaEscuro, fontSize: 12, height: 1.3),
          errorMaxLines: 2,
        );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(children: [
        _campoMatricula(deco('Matrícula', Icons.badge_outlined)),
        Divider(height: 1, thickness: 0.5, indent: 48, color: Colors.white.withValues(alpha: 0.18)),
        _campoSenha(deco('Senha', Icons.lock_outline_rounded)),
      ]),
    );
  }

  /// Android: campos contornados do Material 3.
  Widget _camposMaterial() => Column(children: [
        _campoMatricula(_fieldDeco(label: 'Matrícula', icon: Icons.badge_outlined)),
        const SizedBox(height: 14),
        _campoSenha(_fieldDeco(label: 'Senha', icon: Icons.lock_outline_rounded)),
      ]);

  Widget _lembrar() => Align(
        alignment: Alignment.centerLeft,
        child: widget.material
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(
                  value: _lembrarAcesso,
                  onChanged: (v) => setState(() => _lembrarAcesso = v ?? false),
                  side: const BorderSide(color: Colors.white54, width: 1.5),
                  activeColor: AppColors.lightBlue,
                ),
                GestureDetector(
                  onTap: () => setState(() => _lembrarAcesso = !_lembrarAcesso),
                  child: const Text('Lembrar meus dados', style: TextStyle(fontSize: 14, color: Colors.white70)),
                ),
              ])
            : Semantics(
                toggled: _lembrarAcesso,
                label: 'Lembrar meus dados',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => setState(() => _lembrarAcesso = !_lembrarAcesso),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _lembrarAcesso ? AppColors.lightBlue : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _lembrarAcesso ? AppColors.lightBlue : Colors.white38, width: 1.5),
                        ),
                        child: _lembrarAcesso ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 10),
                      const Text('Lembrar meus dados', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    ]),
                  ),
                ),
              ),
      );

  Widget _botao() {
    final rotulo = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _isLoading
          ? const SizedBox(
              key: ValueKey('carregando'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            )
          : const Text('Entrar',
              key: ValueKey('rotulo'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
    );
    if (widget.material) {
      return SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.acao,
            disabledBackgroundColor: AppColors.acao.withValues(alpha: 0.55),
            shape: const StadiumBorder(),
          ),
          child: rotulo,
        ),
      );
    }
    // iOS: o botão afunda um pouco ao apertar e volta (sem ripple).
    return Listener(
      onPointerDown: (_) => setState(() => _apertado = true),
      onPointerUp: (_) => setState(() => _apertado = false),
      onPointerCancel: (_) => setState(() => _apertado = false),
      child: AnimatedScale(
        scale: _apertado && !_isLoading ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Semantics(
          button: true,
          label: 'Entrar',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _isLoading ? null : _submit,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.acaoClara.withValues(alpha: _isLoading ? 0.55 : 1),
                    AppColors.acao.withValues(alpha: _isLoading ? 0.55 : 1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.acao.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: rotulo,
            ),
          ),
        ),
      ),
    );
  }

  Widget _links() {
    void abrir(Widget pagina) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
    if (widget.material) {
      return Row(children: [
        Expanded(
          child: TextButton.icon(
            onPressed: () => abrir(const RecuperarSenhaPage()),
            style: TextButton.styleFrom(foregroundColor: AppColors.lightBlue),
            icon: const Icon(Icons.lock_reset_rounded, size: 18),
            label: const Text('Esqueci a senha'),
          ),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: () => abrir(const PrimeiroAcessoPage()),
            style: TextButton.styleFrom(foregroundColor: AppColors.lightBlue),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Primeiro acesso'),
          ),
        ),
      ]);
    }
    return Row(children: [
      Expanded(
        child: _AcessoLink(
          icone: Icons.lock_reset_rounded,
          texto: 'Esqueci a senha',
          onTap: () => abrir(const RecuperarSenhaPage()),
        ),
      ),
      Container(width: 1, height: 18, color: Colors.white.withValues(alpha: 0.14)),
      Expanded(
        child: _AcessoLink(
          icone: Icons.person_add_alt_1_rounded,
          texto: 'Primeiro acesso',
          onTap: () => abrir(const PrimeiroAcessoPage()),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final campos = widget.material ? _camposMaterial() : _camposIos();
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _balanco,
              builder: (_, filho) {
                final t = _balanco.value;
                // Três idas e voltas que diminuem.
                final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 6) * 10 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: filho);
              },
              child: campos,
            ),
            const SizedBox(height: 6),
            _lembrar(),
            const SizedBox(height: 14),
            _botao(),
            const SizedBox(height: 10),
            _links(),
          ],
        ),
      ),
    );
  }

  /// Campo contornado do Android (Material 3), sobre o fundo escuro.
  InputDecoration _fieldDeco({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.white60, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.falhaEscuro, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.falhaEscuro, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w600, fontSize: 13),
      errorStyle: const TextStyle(color: AppColors.falhaEscuro, fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
      errorMaxLines: 2,
    );
  }
}

// ── Acesso alternativo: ícone + texto, discreto, no rodapé do cartão ────────
class _AcessoLink extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback onTap;

  const _AcessoLink({
    required this.icone,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 16, color: Colors.white.withOpacity(0.62)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
