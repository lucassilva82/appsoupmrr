import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/theme_provider.dart';
import '../widgets/custom_appbar.dart';

// ── SettingsBody ──────────────────────────────────────────────────────────────
// Conteúdo da aba "Config." dentro do MainShell.
class SettingsBody extends StatelessWidget {
  const SettingsBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header do usuário ─────────────────────────────────────────────
          _UserHeader(auth: auth, theme: theme),
          const SizedBox(height: 24),

          // ── Seção: Aparência ──────────────────────────────────────────────
          _SectionTitle(label: 'Aparência'),
          _SettingsCard(
            children: [
              SwitchListTile(
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggle(),
                secondary: Icon(
                  themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Modo Noturno'),
                subtitle: Text(themeProvider.isDark ? 'Ativado' : 'Desativado'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Seção: Segurança ──────────────────────────────────────────────
          _SectionTitle(label: 'Segurança'),
          _SettingsCard(
            children: [
              SwitchListTile(
                value: auth.useBiometrics,
                onChanged: (val) async {
                  auth.useBiometrics = val;
                  await auth.saveUserData();
                },
                secondary: Icon(
                  Icons.fingerprint_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Biometria'),
                subtitle: const Text('Login com impressão digital / Face ID'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Seção: Notificações ───────────────────────────────────────────
          _SectionTitle(label: 'Notificações'),
          _SettingsCard(
            children: [
              ListTile(
                leading: Icon(Icons.notifications_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Avisos'),
                subtitle: const Text(
                    'Receba alertas de escala, comunicados e avisos'),
                trailing: Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Seção: Sobre ──────────────────────────────────────────────────
          _SectionTitle(label: 'Sobre'),
          _SettingsCard(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('SouPMRR'),
                subtitle: const Text('Versão 2.0 • Polícia Militar de Roraima'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.support_agent_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Suporte Técnico'),
                subtitle: const Text('DTI/PMRR'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.AJUDA_PAGE),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Botão Sair ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, auth),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: const Text(
                'Sair da conta',
                style: TextStyle(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, Auth auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja encerrar a sessão?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      auth.logout();
      Navigator.pushReplacementNamed(context, AppRoutes.AUTH_OR_HOME);
    }
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  final Auth auth;
  final ThemeData theme;
  const _UserHeader({Key? key, required this.auth, required this.theme})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSuperUser = auth.isSuperUser;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Icon(
              isSuperUser ? Icons.star_rounded : Icons.person_rounded,
              size: 32,
              color: isSuperUser ? AppColors.gold : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.nomeMilitar ?? 'Militar',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Mat. ${auth.matricula ?? '-'}',
                  style: theme.textTheme.bodySmall,
                ),
                if (isSuperUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.5), width: 1),
                      ),
                      child: const Text(
                        'Administrador',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }
}

// ── Configuracoes ─────────────────────────────────────────────────────────────
// Mantida para compatibilidade com rota existente.
class Configuracoes extends StatelessWidget {
  const Configuracoes({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Configurações'),
      body: const SettingsBody(),
    );
  }
}
