import 'package:flutter/material.dart';
import 'package:projetonovo/pages/primeiro_acesso_page.dart';
import 'package:projetonovo/pages/recuperar_senha_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_model.dart';
import '../utils/auth_exception.dart';
import '../utils/app_theme.dart';
import 'convite_biometria.dart';

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
    // Largura do botão em repouso; ao carregar ele encolhe até 56.
    final larguraTotal = MediaQuery.of(context).size.width - 88;

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
          // Caixa de seleção discreta: é uma preferência secundária, não
          // precisa competir com o botão de entrar.
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => setState(() => _lembrarAcesso = !_lembrarAcesso),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _lembrarAcesso
                            ? AppColors.lightBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _lembrarAcesso
                              ? AppColors.lightBlue
                              : Colors.white38,
                          width: 1.4,
                        ),
                      ),
                      child: _lembrarAcesso
                          ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lembrar meus dados',
                      style: TextStyle(fontSize: 11.5, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Botão Entrar ───────────────────────────────────────────────
          // Ao enviar, o botão encolhe até virar um círculo com o indicador,
          // em vez de só trocar o rótulo por um spinner. É o padrão dos apps
          // atuais: o próprio controle vira o estado de carregamento.
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              width: _isLoading ? 56 : larguraTotal,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(_isLoading ? 28 : 14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _submit,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _isLoading
                          ? const SizedBox(
                              key: ValueKey('carregando'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : const Row(
                              key: ValueKey('rotulo'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Entrar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded,
                                    size: AppIconSize.sm, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ── Rodapé do cartão: acessos alternativos ───────────────────────
          Divider(color: Colors.white.withOpacity(0.12), height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _AcessoLink(
                  icone: Icons.lock_reset_rounded,
                  texto: 'Esqueci a senha',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RecuperarSenhaPage(),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: Colors.white.withOpacity(0.12),
              ),
              Expanded(
                child: _AcessoLink(
                  icone: Icons.person_add_alt_1_rounded,
                  texto: 'Primeiro acesso',
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
      // Raio 14, foco de 1,6 e erro de 12px: os mesmos números do
      // inputDecorationTheme. O que não dá para herdar aqui é a cor, porque
      // o campo fica sobre a capa escura e não sobre a superfície do app.
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBlue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.falhaEscuro, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.falhaEscuro, width: 1.6),
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.lightBlue,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      errorStyle: const TextStyle(
        color: AppColors.falhaEscuro,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 15, color: Colors.white.withOpacity(0.55)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 11.5,
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
