import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/api_services.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/vidro.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConfirmEmailScreen
//
// Cadastro e verificação do e-mail do militar. O usuário informa o e-mail,
// recebe um link de confirmação e clica nele para validar a conta.
//
// Não bloqueia mais o acesso ao app: a tela é aberta a partir de
// Configurações → Conta, e pode ser fechada a qualquer momento.
// ─────────────────────────────────────────────────────────────────────────────

class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailConfirmCtrl = TextEditingController();

  bool _isLoading = false;

  /// Mensagem de erro exibida no topo do formulário. Fica na tela até o
  /// usuário tentar de novo — diferente do SnackBar, que some sozinho.
  String? _erro;

  /// Preenchido quando o envio dá certo: a tela troca para o estado
  /// "verifique sua caixa de entrada".
  String? _emailEnviado;

  /// Segundos restantes até poder reenviar.
  int _segundosParaReenviar = 0;
  Timer? _timerReenvio;

  /// Enquanto a tela espera a confirmação, consulta `status_email.php`
  /// a cada 4s: assim que o militar clica no link (no celular ou em
  /// outro aparelho), a tela muda sozinha para "e-mail confirmado".
  Timer? _timerStatus;
  bool _confirmado = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);
    final atual = auth.emailUser ?? '';
    if (atual.isNotEmpty && atual.contains('@')) {
      _emailCtrl.text = atual;
    }
  }

  @override
  void dispose() {
    _timerStatus?.cancel();
    _timerReenvio?.cancel();
    _emailCtrl.dispose();
    _emailConfirmCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Esconde o miolo do endereço: "fulano@gmail.com" → "f****o@gmail.com".
  String _mascarar(String email) {
    final partes = email.split('@');
    if (partes.length != 2) return email;
    final nome = partes[0];
    if (nome.length <= 2) return '${nome[0]}***@${partes[1]}';
    return '${nome[0]}${'*' * (nome.length - 2)}${nome[nome.length - 1]}'
        '@${partes[1]}';
  }

  /// Converte a resposta da API numa mensagem que o militar entenda.
  String _mensagemDeErro(Map<String, dynamic> resultado) {
    final original = (resultado['message'] ?? '').toString();
    final lower = original.toLowerCase();

    if (lower.contains('não encontrada') || lower.contains('nao encontrada')) {
      return 'Sua matrícula não foi localizada no sistema. '
          'Procure o DTI/PMRR para regularizar o cadastro.';
    }
    if (lower.contains('inválido') || lower.contains('invalido')) {
      return 'O e-mail informado não é válido. Confira se não há espaços '
          'ou letras trocadas.';
    }
    if (lower.contains('não foi possível enviar') ||
        lower.contains('nao foi possivel enviar')) {
      return 'Não conseguimos enviar o e-mail agora. Tente novamente em '
          'alguns minutos.';
    }
    if (lower.contains('conexão') || lower.contains('conexao')) {
      return 'Sem conexão com o servidor. Verifique sua internet e tente '
          'novamente.';
    }
    if (lower.contains('erro http')) {
      return 'O servidor não respondeu corretamente. Tente novamente em '
          'alguns minutos.';
    }
    return original.isEmpty ? 'Não foi possível concluir o envio.' : original;
  }

  /// Observa a confirmação do link enquanto a tela estiver aberta.
  void _acompanharConfirmacao(String matricula) {
    _timerStatus?.cancel();
    _timerStatus = Timer.periodic(const Duration(seconds: 4), (t) async {
      if (!mounted) return t.cancel();

      final status = await ApiServices.checkEmailStatus(matricula);
      if (!mounted) return t.cancel();

      // Só considera confirmado quando o link pendente deixa de existir
      // (`aguardando` falso): quem já era verificado antes continuaria
      // com `verificado` true e a tela mudaria sem o militar clicar.
      if (status['code'] == 1 &&
          status['verificado'] == true &&
          status['aguardando'] == false) {
        t.cancel();
        await Provider.of<Auth>(context, listen: false)
            .atualizarStatusEmail(verificado: true, email: _emailEnviado);
        if (mounted) setState(() => _confirmado = true);
      }
    });
  }

  void _iniciarContagemReenvio() {
    _timerReenvio?.cancel();
    setState(() => _segundosParaReenviar = 60);
    _timerReenvio = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _segundosParaReenviar--);
      if (_segundosParaReenviar <= 0) t.cancel();
    });
  }

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailCtrl.text.trim();
    final auth = Provider.of<Auth>(context, listen: false);
    final matricula = auth.matricula ?? '';

    if (matricula.isEmpty) {
      setState(() => _erro =
          'Não identificamos sua matrícula. Saia do app e entre novamente.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiServices.sendEmailConfirmation(
        matricula: matricula,
        email: email,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (result['code'] == 1) {
        setState(() => _emailEnviado = email);
        _iniciarContagemReenvio();
        _acompanharConfirmacao(matricula);
      } else {
        setState(() => _erro = _mensagemDeErro(result));
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _erro =
            'O servidor demorou para responder. Verifique sua internet e '
            'tente novamente.');
      }
    } on SocketException {
      if (mounted) {
        setState(() => _erro =
            'Sem conexão com a internet. Conecte-se e tente novamente.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'Ocorreu um erro inesperado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Verificar e-mail'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: _confirmado
            ? _confirmadoView()
            : (_emailEnviado == null ? _formulario() : _enviado()),
      ),
    );
  }

  // ── Estado 1: formulário ──────────────────────────────────────────────────

  Widget _formulario() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CabecalhoIcone(
            icone: Icons.mark_email_unread_rounded,
            titulo: 'Confirme seu e-mail',
            descricao: 'Usamos seu e-mail para recuperar a senha e enviar '
                'avisos importantes da corporação.',
          ),
          const SizedBox(height: 24),

          if (_erro != null) ...[
            _Aviso(
              cor: theme.colorScheme.error,
              icone: Icons.error_outline_rounded,
              texto: _erro!,
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: _deco(
              label: 'Seu e-mail',
              icon: Icons.alternate_email_rounded,
              isDark: isDark,
            ),
            validator: (v) {
              final valor = (v ?? '').trim();
              if (valor.isEmpty) return 'Informe seu e-mail';
              final valido = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
              if (!valido.hasMatch(valor)) return 'E-mail inválido';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _emailConfirmCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: _deco(
              label: 'Repita o e-mail',
              icon: Icons.check_circle_outline_rounded,
              isDark: isDark,
            ),
            validator: (v) {
              final valor = (v ?? '').trim();
              if (valor.isEmpty) return 'Repita seu e-mail';
              if (valor.toLowerCase() != _emailCtrl.text.trim().toLowerCase()) {
                return 'Os e-mails não conferem';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isLoading ? 'Enviando...' : 'Enviar confirmação'),
              style: ElevatedButton.styleFrom(
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

          _Aviso(
            cor: AppColors.lightBlue,
            icone: Icons.info_outline_rounded,
            texto: 'Você pode continuar usando o app normalmente. '
                'A verificação fica pendente em Configurações até ser '
                'concluída.',
          ),
        ],
      ),
    );
  }

  // ── Estado 3: confirmado ──────────────────────────────────────────────────
  // Entra sozinho assim que o militar clica no link, sem fechar e abrir o app.

  Widget _confirmadoView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _CabecalhoIcone(
          icone: Icons.verified_rounded,
          titulo: 'E-mail confirmado!',
          descricao: 'Seu endereço foi verificado com sucesso. Agora ele pode '
              'ser usado para recuperar sua senha.',
          cor: isDark ? AppColors.sucessoEscuro : AppColors.sucesso,
        ),
        const SizedBox(height: 12),
        Text(
          _mascarar(_emailEnviado ?? ''),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.sucessoEscuro : AppColors.sucesso,
              ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.sucessoEscuro : AppColors.sucesso,
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

  // ── Estado 2: e-mail enviado ──────────────────────────────────────────────

  Widget _enviado() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final podeReenviar = _segundosParaReenviar <= 0 && !_isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CabecalhoIcone(
          icone: Icons.mark_email_read_rounded,
          titulo: 'E-mail enviado',
          descricao: 'Enviamos um link de confirmação para:',
          cor: isDark ? AppColors.sucessoEscuro : AppColors.sucesso,
        ),
        const SizedBox(height: 12),

        Text(
          _mascarar(_emailEnviado!),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Indicador de que a tela está observando a confirmação.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Aguardando sua confirmação...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _Passos(),
        const SizedBox(height: 16),

        _Aviso(
          cor: AppColors.gold,
          icone: Icons.search_rounded,
          texto: 'Não chegou em alguns minutos? Procure na pasta de spam '
              'ou lixo eletrônico. No Gmail, veja também a aba "Promoções".',
        ),
        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: podeReenviar
              ? () {
                  setState(() => _emailEnviado = null);
                }
              : null,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            podeReenviar
                ? 'Reenviar ou corrigir o e-mail'
                : 'Aguarde $_segundosParaReenviar s para reenviar',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar ao app'),
        ),
      ],
    );
  }

  // ── Decoração dos campos ──────────────────────────────────────────────────

  InputDecoration _deco({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary),
      // borda, preenchimento, foco e erro vêm do inputDecorationTheme
    );
  }
}

// ── Cabeçalho com ícone circular ────────────────────────────────────────────

class _CabecalhoIcone extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final Color? cor;

  const _CabecalhoIcone({
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destaque = cor ?? theme.colorScheme.primary;

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: destaque.withOpacity(0.12),
          ),
          child: Icon(icone, size: 38, color: destaque),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          descricao,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Caixa de aviso colorida ─────────────────────────────────────────────────

class _Aviso extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String texto;

  const _Aviso({required this.cor, required this.icone, required this.texto});

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

// ── Passos após o envio ─────────────────────────────────────────────────────

class _Passos extends StatelessWidget {
  static const _itens = [
    ('1', 'Abra o e-mail que enviamos'),
    ('2', 'Toque em "Confirmar meu e-mail"'),
    ('3', 'Pronto: o link vale por 15 minutos'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CartaoVidro(
      raio: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          for (final item in _itens) ...[
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.12),
                  ),
                  child: Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.$2, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            if (item != _itens.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
