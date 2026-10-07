import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_model.dart';
import '../utils/api_services.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlterarSenhaPage
//
// Troca da senha de acesso, aberta em Configurações → Conta.
// A senha é a mesma do SIGRH e do SouPMRR, por isso o aviso em tela.
//
// Fluxo: senha atual + nova (duas vezes) → alterar_senha.php → e-mail de
// confirmação enviado pelo servidor.
// ─────────────────────────────────────────────────────────────────────────────

class AlterarSenhaPage extends StatefulWidget {
  const AlterarSenhaPage({Key? key}) : super(key: key);

  @override
  State<AlterarSenhaPage> createState() => _AlterarSenhaPageState();
}

class _AlterarSenhaPageState extends State<AlterarSenhaPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _atualCtrl = TextEditingController();
  final _novaCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();

  bool _verAtual = false;
  bool _verNova = false;
  bool _carregando = false;
  bool _concluido = false;
  String? _erro;

  /// Sacode o formulário quando o servidor recusa a troca.
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _atualCtrl.dispose();
    _novaCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  // ── Força da senha ────────────────────────────────────────────────────────

  int _forca(String senha) {
    var pontos = 0;
    if (senha.length >= 6) pontos++;
    if (senha.length >= 10) pontos++;
    if (RegExp(r'[A-Z]').hasMatch(senha) && RegExp(r'[a-z]').hasMatch(senha)) {
      pontos++;
    }
    if (RegExp(r'[0-9]').hasMatch(senha)) pontos++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(senha)) pontos++;
    return pontos.clamp(0, 4);
  }

  ({String texto, Color cor}) _rotuloForca(int forca) {
    switch (forca) {
      case 0:
      case 1:
        return (texto: 'Senha fraca', cor: const Color(0xFFC62828));
      case 2:
        return (texto: 'Senha razoável', cor: const Color(0xFFE65100));
      case 3:
        return (texto: 'Senha boa', cor: const Color(0xFF2E7D32));
      default:
        return (texto: 'Senha forte', cor: const Color(0xFF1B5E20));
    }
  }

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeCtrl.forward(from: 0);
      return;
    }

    final auth = Provider.of<Auth>(context, listen: false);
    final matricula = auth.matricula ?? '';
    if (matricula.isEmpty) {
      setState(() => _erro = 'Não identificamos sua matrícula. '
          'Saia do app e entre novamente.');
      return;
    }

    setState(() => _carregando = true);

    final senhaAtual = _atualCtrl.text.trim();
    final senhaNova = _novaCtrl.text.trim();

    final resultado = await ApiServices.alterarSenha(
      matricula: matricula,
      senhaAtualMd5: auth.generateMd5(senhaAtual),
      senhaNovaMd5: auth.generateMd5(senhaNova),
    );

    if (!mounted) return;

    if (resultado['code'] == 1) {
      // A senha guardada no app precisa acompanhar a troca, senão o
      // login automático e a biometria passam a falhar.
      auth.password = senhaNova;
      await auth.saveUserData();

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('password') != null) {
        await prefs.setString('password', senhaNova);
      }

      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _concluido = true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _erro = (resultado['message'] ?? 'Não foi possível alterar a senha.')
            .toString();
        _carregando = false;
      });
      _shakeCtrl.forward(from: 0);
      return;
    }

    if (mounted) setState(() => _carregando = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Alterar senha'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _concluido ? _sucesso() : _formulario(),
        ),
      ),
    );
  }

  // ── Formulário ────────────────────────────────────────────────────────────

  Widget _formulario() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final forca = _forca(_novaCtrl.text);
    final rotulo = _rotuloForca(forca);

    return AnimatedBuilder(
      key: const ValueKey('form'),
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shake.value, 0),
        child: child,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.12),
                ),
                child: Icon(Icons.lock_reset_rounded,
                    size: 36, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alterar senha de acesso',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'A mesma senha vale para o SIGRH e para o SouPMRR. '
              'Ao alterar aqui, ela muda nos dois.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.70),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            if (_erro != null) ...[
              _Caixa(
                cor: theme.colorScheme.error,
                icone: Icons.error_outline_rounded,
                texto: _erro!,
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _atualCtrl,
              obscureText: !_verAtual,
              decoration: _deco(
                label: 'Senha atual',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                onToggle: () => setState(() => _verAtual = !_verAtual),
                visivel: _verAtual,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe sua senha atual'
                  : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _novaCtrl,
              obscureText: !_verNova,
              onChanged: (_) => setState(() {}),
              decoration: _deco(
                label: 'Nova senha',
                icon: Icons.lock_person_rounded,
                isDark: isDark,
                onToggle: () => setState(() => _verNova = !_verNova),
                visivel: _verNova,
              ),
              validator: (v) {
                final valor = (v ?? '').trim();
                if (valor.isEmpty) return 'Informe a nova senha';
                if (valor.length < 6) {
                  return 'A nova senha precisa ter ao menos 6 caracteres';
                }
                if (valor == _atualCtrl.text.trim()) {
                  return 'A nova senha deve ser diferente da atual';
                }
                return null;
              },
            ),

            // Barra de força — anima conforme o militar digita.
            if (_novaCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        tween: Tween(begin: 0, end: forca / 4),
                        builder: (_, valor, __) => LinearProgressIndicator(
                          value: valor,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE8EEF6),
                          valueColor: AlwaysStoppedAnimation(rotulo.cor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rotulo.texto,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: rotulo.cor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            TextFormField(
              controller: _repetirCtrl,
              obscureText: !_verNova,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _deco(
                label: 'Repita a nova senha',
                icon: Icons.check_circle_outline_rounded,
                isDark: isDark,
              ),
              validator: (v) {
                final valor = (v ?? '').trim();
                if (valor.isEmpty) return 'Repita a nova senha';
                if (valor != _novaCtrl.text.trim()) {
                  return 'As senhas não conferem';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _carregando ? null : _submit,
                icon: _carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_carregando ? 'Alterando...' : 'Alterar senha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _Caixa(
              cor: AppColors.lightBlue,
              icone: Icons.mark_email_read_outlined,
              texto: 'Ao concluir, enviamos um e-mail confirmando a alteração '
                  'para o endereço cadastrado.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Sucesso ───────────────────────────────────────────────────────────────

  Widget _sucesso() {
    final theme = Theme.of(context);
    const verde = Color(0xFF2E7D32);

    return Column(
      key: const ValueKey('sucesso'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        // Selo que cresce ao aparecer.
        Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            tween: Tween(begin: 0.4, end: 1.0),
            builder: (_, escala, child) =>
                Transform.scale(scale: escala, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: verde.withOpacity(0.12),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  size: 44, color: verde),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Senha alterada!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: verde),
        ),
        const SizedBox(height: 10),
        Text(
          'Sua nova senha já está valendo no SouPMRR e no SIGRH.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        _Caixa(
          cor: AppColors.lightBlue,
          icone: Icons.mail_outline_rounded,
          texto: 'Enviamos um e-mail confirmando a alteração. Se não foi você, '
              'procure o DTI/PMRR imediatamente.',
        ),
        const SizedBox(height: 28),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Voltar ao app',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── Decoração dos campos ──────────────────────────────────────────────────

  InputDecoration _deco({
    required String label,
    required IconData icon,
    required bool isDark,
    VoidCallback? onToggle,
    bool visivel = false,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary),
      suffixIcon: onToggle == null
          ? null
          : IconButton(
              onPressed: onToggle,
              icon: Icon(
                visivel
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
      ),
    );
  }
}

// ── Caixa de aviso ──────────────────────────────────────────────────────────

class _Caixa extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String texto;

  const _Caixa({required this.cor, required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
