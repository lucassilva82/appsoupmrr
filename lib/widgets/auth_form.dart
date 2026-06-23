import 'package:flutter/material.dart';
import 'package:projetonovo/pages/confirm_email.dart';
import 'package:projetonovo/utils/api_services.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
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
      // 1) Se já existe um token válido, exibe QuickAlert e para
      final tokenResult =
          await ApiServices.checkIfTokenExists(_authData['matricula']!);
      if (tokenResult['code'] == 1) {
        // Token já existe e não expirou: pede pro usuário verificar e-mail
        await QuickAlert.show(
          context: context,
          type: QuickAlertType.info,
          title: 'Verifique seu e-mail',
          text: 'Acesse o link enviado ao seu e-mail para ativar sua conta!',
          confirmBtnText: 'OK',
          onConfirmBtnTap: () {
            Navigator.of(context).pop(); // Fecha o QuickAlert
          },
        );
        return; // Interrompe aqui
      }

      // 2) Se não há token válido, apenas checamos credenciais
      //    mas NÃO setamos 'autorizado = true'.
      await auth.checkCredentialsWithoutLogin(
        _authData['matricula']!,
        _authData['password']!,
      );

      // Agora temos em 'auth.activationCode' o valor do banco,
      // mas 'autorizado' continua false.

      if (auth.activationCode != 'pmrr190!@') {
        // 3) Se activationCode != 'pmrr190!@', manda pra ConfirmEmail
        auth.useBiometrics = false;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConfirmEmailScreen()),
        );
        // NÃO faz login. Assim, no hot restart, o app não te vê como logado
        return;
      } else {
        // 4) Se activationCode == 'pmrr190!@', aí sim faz login de fato
        await auth.loginSemNotificar(
            _authData['matricula']!, _authData['password']!);

        // 5) Grava (ou não) as credenciais
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
      }
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

          // ── Recuperar Senha ──────────────────────────────────────────────
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Recuperar Senha'),
                  content: const Text(
                    'Você será redirecionado ao SIGRH para recuperar sua senha ou realizar seu primeiro acesso.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              'Recuperar Senha / Primeiro acesso',
              style: TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
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
