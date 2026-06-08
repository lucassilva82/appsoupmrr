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
    final deviceSize = MediaQuery.of(context).size;

    return Card(
      color: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: deviceSize.width * 0.70,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _matriculaController,
                style: const TextStyle(fontSize: 16, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Matrícula',
                  prefixIcon: Icon(Icons.person, color: Colors.grey[700]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.7),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.indigo.shade900, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                onSaved: (matricula) =>
                    _authData['matricula'] = matricula?.trim() ?? '',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe sua matrícula';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(fontSize: 16, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock, color: Colors.grey[700]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      widget.exibeSenha
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[700],
                    ),
                    onPressed: () {
                      setState(() {
                        widget.exibeSenha = !widget.exibeSenha;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.7),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.indigo.shade900, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: widget.exibeSenha,
                onSaved: (password) =>
                    _authData['password'] = password?.trim() ?? '',
                validator: (password) {
                  if (password == null || password.length < 5) {
                    return 'Informe uma senha válida (mín. 5 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lembrar Dados',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _lembrarAcesso,
                      onChanged: (bool valor) {
                        setState(() {
                          _lembrarAcesso = valor;
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _isLoading
                  ? const CircularProgressIndicator.adaptive(
                      backgroundColor: Colors.white,
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _submit,
                        child: const Text('Entrar',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
              const SizedBox(height: 16),

              // Link "Recuperar Senha"
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Recuperar Senha'),
                      content: const Text(
                        'Você será redirecionado para o site do SIGRH, lá poderá recuperar sua senha.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Recuperar Senha / Primeiro acesso',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
