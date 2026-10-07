import 'package:flutter/material.dart';
import 'package:projetonovo/pages/primeiro_acesso_page.dart';
import 'package:projetonovo/pages/recuperar_senha_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_model.dart';
import '../utils/auth_exception.dart';

class AuthForm extends StatefulWidget {
  bool exibeSenha = true;
  AuthForm({Key? key}) : super(key: key);

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
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
    final savedP = prefs.getString('password') ?? '';
    final lembrar = prefs.getBool('lembrarAcesso') ?? false;

    if (lembrar) {
      setState(() {
        _matriculaController.text = savedM;
        _passwordController.text = savedP;
        _lembrarAcesso = lembrar;
      });
    }
  }

  void _showErrorDialog(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocorreu um erro'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _askEnableBiometrics() async {
    final auth = Provider.of<Auth>(context, listen: false);

    final answer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Ativar Biometria?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deseja habilitar login por biometria para os próximos acessos?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300]),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'NÃO',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text(
                      'SIM',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    final bool biometriaAceita = answer ?? false;
    auth.useBiometrics = biometriaAceita;
    await auth.saveUserData();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<Auth>(context, listen: false);
    _formKey.currentState?.save();

    try {
      // O e-mail não verificado NÃO bloqueia mais o acesso: muitos militares
      // ficavam presos na tela de confirmação sem conseguir entrar. A pendência
      // passou a aparecer em Configurações → Conta, de onde a verificação pode
      // ser feita a qualquer momento.
      await auth.loginSemNotificar(
          _authData['matricula']!, _authData['password']!);

      // Grava (ou não) as credenciais
      final prefs = await SharedPreferences.getInstance();
      if (_lembrarAcesso) {
        await prefs.setString('matricula', _authData['matricula']!);
        await prefs.setString('password', _authData['password']!);
        await prefs.setBool('lembrarAcesso', true);
      } else {
        await prefs.remove('matricula');
        await prefs.remove('password');
        await prefs.setBool('lembrarAcesso', false);
      }

      // Pergunta biometria
      if (!auth.useBiometrics) {
        await _askEnableBiometrics();
      }

      // Finaliza -> vai Home
      auth.finalizarLogin();
    } on AuthException catch (error) {
      _showErrorDialog(error.toString());
    } catch (error) {
      _showErrorDialog('Ocorreu um erro inesperado.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Matrícula ───────────────────────────────────────────────────
          TextFormField(
            controller: _matriculaController,
            style: const TextStyle(fontSize: 15, color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: _fieldDeco(
              label: 'Matrícula',
              icon: Icons.badge_outlined,
            ),
            onSaved: (v) => _authData['matricula'] = v?.trim() ?? '',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe sua matrícula';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Senha ────────────────────────────────────────────────────────
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(fontSize: 15, color: Colors.white),
            obscureText: widget.exibeSenha,
            decoration: _fieldDeco(
              label: 'Senha',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  widget.exibeSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white60,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => widget.exibeSenha = !widget.exibeSenha),
              ),
            ),
            onSaved: (v) => _authData['password'] = v?.trim() ?? '',
            validator: (v) {
              if (v == null || v.length < 5) {
                return 'Senha inválida (mín. 5 caracteres)';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // ── Lembrar Dados ────────────────────────────────────────────────
          Row(
            children: [
              Transform.scale(
                scale: 0.85,
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _lembrarAcesso,
                  onChanged: (v) => setState(() => _lembrarAcesso = v),
                  activeColor: const Color(0xFF42A5F5),
                  inactiveTrackColor: Colors.white24,
                  inactiveThumbColor: Colors.white38,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Text(
                'Lembrar dados de acesso',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Botão ENTRAR — o botão absorve o estado de loading ───────
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF42A5F5),
                        Color(0xFF1565C0),
                        Color(0xFF002154),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: InkWell(
                    onTap: _isLoading ? null : _submit,
                    child: SizedBox(
                      height: 54,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: _isLoading
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  key: ValueKey('content'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ENTRAR',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Recuperar senha / Primeiro acesso ────────────────────────────
          // Agora resolvido dentro do app, sem mandar o militar para o SIGRH.
          Row(
            children: [
              Expanded(
                child: _AcessoBotao(
                  icone: Icons.lock_reset_rounded,
                  titulo: 'Esqueci a senha',
                  legenda: 'Recuperar por e-mail',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RecuperarSenhaPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AcessoBotao(
                  icone: Icons.person_add_alt_1_rounded,
                  titulo: 'Primeiro acesso',
                  legenda: 'Criar minha senha',
                  destaque: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrimeiroAcessoPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Decoração padronizada dos campos com estilo glassmorphism
  InputDecoration _fieldDeco({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white60, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
    );
  }
}

// ── Botão de acesso alternativo (recuperar senha / primeiro acesso) ──────────
// Cartão translúcido no mesmo estilo do formulário de login.
class _AcessoBotao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String legenda;
  final bool destaque;
  final VoidCallback onTap;

  const _AcessoBotao({
    required this.icone,
    required this.titulo,
    required this.legenda,
    required this.onTap,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final corBorda = destaque
        ? const Color(0xFF42A5F5).withOpacity(0.55)
        : Colors.white.withOpacity(0.18);

    return Material(
      color: Colors.white.withOpacity(destaque ? 0.12 : 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: corBorda),
          ),
          child: Column(
            children: [
              Icon(icone,
                  size: 22,
                  color: destaque ? const Color(0xFF90CAF9) : Colors.white70),
              const SizedBox(height: 6),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                legenda,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
