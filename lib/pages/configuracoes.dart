import 'dart:io';

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
      child: LayoutBuilder(builder: (ctx, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
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
                  _ThemeModeSelector(
                      themeProvider: themeProvider, theme: theme),
                ],
              ),
              const SizedBox(height: 16),

              // ── Seção: Segurança ──────────────────────────────────────────────
              _SectionTitle(label: 'Segurança'),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    value: auth.useBiometrics,
                    onChanged: (val) => auth.setBiometrics(val),
                    secondary: Icon(
                      Icons.fingerprint_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Biometria'),
                    subtitle:
                        const Text('Login com impressão digital / Face ID'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Seção: Notificações ───────────────────────────────────────────
              _SectionTitle(label: 'Notificações'),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: auth.notificationsEnabled
                      ? BorderSide.none
                      : const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
                color: auth.notificationsEnabled
                    ? null
                    : Colors.redAccent.withOpacity(0.07),
                child: SwitchListTile(
                  value: auth.notificationsEnabled,
                  onChanged: (val) async {
                    if (!val) {
                      // Exige confirmação para desativar
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          icon: const Icon(Icons.notifications_off_rounded,
                              color: Colors.redAccent, size: 36),
                          title: const Text('Desativar notificações?'),
                          content: const Text(
                            'Sem notificações você não receberá avisos sobre:\n\n'
                            '• Escalas de serviço\n'
                            '• Contracheques disponíveis\n'
                            '• Comunicados oficiais\n'
                            '• Alertas importantes da PMRR\n\n'
                            'Tem certeza que deseja continuar?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              child: const Text('Desativar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                    }
                    auth.setNotificationsEnabled(val);
                  },
                  activeColor: theme.colorScheme.primary,
                  inactiveThumbColor: Colors.redAccent,
                  inactiveTrackColor: Colors.redAccent.withOpacity(0.3),
                  secondary: Icon(
                    auth.notificationsEnabled
                        ? Icons.notifications_rounded
                        : Icons.notifications_off_rounded,
                    color: auth.notificationsEnabled
                        ? theme.colorScheme.primary
                        : Colors.redAccent,
                  ),
                  title: Text(
                    'Avisos',
                    style: TextStyle(
                      color:
                          auth.notificationsEnabled ? null : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    auth.notificationsEnabled
                        ? 'Receba alertas de escala, comunicados e avisos'
                        : '⚠ Notificações desativadas — você pode perder avisos importantes',
                    style: TextStyle(
                      color: auth.notificationsEnabled
                          ? null
                          : Colors.redAccent.withOpacity(0.85),
                    ),
                  ),
                ),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Versão 2.0 • Polícia Militar de Roraima'),
                        const SizedBox(height: 2),
                        Text(
                          'Desenvolvido pelo DTI — Departamento de Tecnologia da Informação',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
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
                  icon:
                      const Icon(Icons.logout_rounded, color: Colors.redAccent),
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
      }),
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
      // Limpa a pilha de rotas até a raiz para que o modal biométrico
      // apareça sobre o fundo da tela de login, não sobre esta página.
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      auth.logout();
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

    // Resolve imagem do usuário (verifica existência do arquivo antes de usar)
    ImageProvider? avatarImage;
    final localPath = auth.localImagePath;
    final remoteUrl = auth.image;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      avatarImage = FileImage(File(localPath));
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      avatarImage = NetworkImage(remoteUrl);
    }

    // Iniciais como fallback
    final name = auth.nomeMilitar ?? auth.nomeCompleto ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.12),
            theme.colorScheme.primaryContainer.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // ── Avatar com badge de admin ─────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarImage != null
                      ? Image(
                          image: avatarImage,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (ctx, error, stack) => Container(
                            width: 72,
                            height: 72,
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 72,
                          height: 72,
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                ),
              ),
              if (isSuperUser)
                Positioned(
                  bottom: 0,
                  right: -2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // ── Informações do usuário ────────────────────────────────────
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
                const SizedBox(height: 2),
                Text(
                  'Mat. ${auth.matricula ?? '-'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                if (isSuperUser) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.shield_rounded,
                          size: 10,
                          color: AppColors.gold,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Administrador',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

// ── Seletor de tema (Auto / Escuro / Claro) ───────────────────────────────────
class _ThemeModeSelector extends StatelessWidget {
  final ThemeProvider themeProvider;
  final ThemeData theme;

  const _ThemeModeSelector({
    Key? key,
    required this.themeProvider,
    required this.theme,
  }) : super(key: key);

  String _subtitle(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.auto:
        return 'Segue automaticamente o sistema';
      case AppThemeMode.dark:
        return 'Sempre ativado';
      case AppThemeMode.light:
        return 'Sempre desativado';
    }
  }

  IconData _icon(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.auto:
        return Icons.brightness_auto_rounded;
      case AppThemeMode.dark:
        return Icons.dark_mode_rounded;
      case AppThemeMode.light:
        return Icons.light_mode_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = themeProvider.mode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(current), color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo Noturno',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(current),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppThemeMode>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
                iconSize: 14,
              ),
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('Desativado'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: AppThemeMode.auto,
                  label: Text('Automático'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('Ativado'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {current},
              onSelectionChanged: (s) => themeProvider.setMode(s.first),
            ),
          ),
          if (current == AppThemeMode.auto) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.45)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'O app acompanha a configuração de aparência do seu dispositivo.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
