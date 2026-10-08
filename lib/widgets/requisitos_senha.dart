import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Regras de senha — as mesmas exigidas pelo SIGRH, já que a senha é a mesma
// nos dois sistemas. Usado na troca de senha, na recuperação e no primeiro
// acesso.
// ─────────────────────────────────────────────────────────────────────────────

const regrasSenha = <({String texto, String chave})>[
  (texto: 'Mínimo 8 caracteres', chave: 'tamanho'),
  (texto: 'Uma letra maiúscula', chave: 'maiuscula'),
  (texto: 'Uma letra minúscula', chave: 'minuscula'),
  (texto: 'Um número', chave: 'numero'),
  (texto: 'Um caractere especial', chave: 'especial'),
];

Map<String, bool> avaliarSenha(String senha) => {
      'tamanho': senha.length >= 8,
      'maiuscula': RegExp(r'[A-Z]').hasMatch(senha),
      'minuscula': RegExp(r'[a-z]').hasMatch(senha),
      'numero': RegExp(r'[0-9]').hasMatch(senha),
      'especial': RegExp(r'[^A-Za-z0-9]').hasMatch(senha),
    };

bool senhaValida(String senha) =>
    avaliarSenha(senha).values.every((cumprida) => cumprida);

/// Lista marcando em verde/vermelho cada requisito conforme o usuário digita.
class RequisitosSenha extends StatelessWidget {
  final String senha;

  const RequisitosSenha({Key? key, required this.senha}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final situacao = avaliarSenha(senha);
    final vazio = senha.isEmpty;

    const verde = Color(0xFF2E7D32);
    const vermelho = Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withOpacity(0.72) : Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A senha deve conter:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 8),
          for (final regra in regrasSenha)
            Builder(builder: (_) {
              final ok = situacao[regra.chave] ?? false;
              final cor = vazio
                  ? theme.colorScheme.onSurface.withOpacity(0.70)
                  : (ok ? verde : vermelho);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        ok
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(ok),
                        size: 16,
                        color: cor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: cor,
                          fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
                        ),
                        child: Text(regra.texto),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Caixa de aviso colorida usada nas telas de acesso.
class AvisoCaixa extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String texto;

  const AvisoCaixa({
    Key? key,
    required this.cor,
    required this.icone,
    required this.texto,
  }) : super(key: key);

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

/// Campo de senha com o visual usado nas telas de acesso.
InputDecoration decoracaoCampo({
  required BuildContext context,
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: isDark ? AppColors.darkCard.withOpacity(0.72) : Colors.white.withOpacity(0.78),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
    ),
  );
}
