import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';

import '../models/auth_model.dart';
import '../utils/app_routes.dart';

class DrawerPersonalizado extends StatefulWidget {
  const DrawerPersonalizado({Key? key}) : super(key: key);

  @override
  State<DrawerPersonalizado> createState() => _DrawerPersonalizadoState();
}

class _DrawerPersonalizadoState extends State<DrawerPersonalizado> {
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadLocalImage();
  }

  Future<void> _loadLocalImage() async {
    setState(() => _isLoadingImage = true);
    final auth = Provider.of<Auth>(context, listen: false);
    await auth.saveImgToFileIfNeeded();
    if (mounted) setState(() => _isLoadingImage = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);

    final isUser = auth.isSuperUser;

    final size = MediaQuery.of(context).size;
    return Drawer(
      width: size.width * 0.70,
      child: Column(
        children: [
          // Header com fundo e informações
          Container(
            height: size.height * 0.25,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/imagens/entradacapa.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Avatar com foco na parte superior da imagem
                    _isLoadingImage
                        ? const CircularProgressIndicator()
                        : Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: _imageProvider(auth),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),
                              border:
                                  Border.all(color: Colors.white70, width: 2),
                            ),
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.nomeMilitar ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Matrícula: ${auth.matricula ?? ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          if (auth.grupo != null && auth.grupo!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                auth.grupo!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Lista de itens
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildTile(
                  icon: Icons.fingerprint,
                  label: 'Biometria',
                  trailing: Switch(
                    value: auth.useBiometrics,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (val) async {
                      auth.useBiometrics = val;
                      await auth.saveUserData();
                      setState(() {});
                    },
                  ),
                ),
                const Divider(),
                _buildTile(
                  icon: Icons.home,
                  label: 'Home',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.HOME_PAGE),
                ),
                _buildTile(
                  icon: Icons.person,
                  label: 'Ficha Individual',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.PAGE_MILITAR),
                ),
                _buildTile(
                  icon: Icons.car_crash,
                  label: 'Meu Plantão',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.PLANTAO),
                ),
                _buildTile(
                  icon: Icons.beach_access,
                  label: 'Plano de Férias',
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.PLANO_DE_FERIAS_PAGE,
                  ),
                ),
                _buildTile(
                  icon: Icons.attach_money,
                  label: 'Declarações',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.DECLARACOES_PAGE),
                ),
                _buildTile(
                  icon: Icons.request_quote,
                  label: 'Contracheques',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.CONTRACHEQUE_PAGE),
                ),
                _buildTile(
                  icon: Icons.library_books,
                  label: 'Legislações',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.LEGISLACOES_PAGE),
                ),
                _buildTile(
                  icon: Icons.gavel,
                  label: 'POPS',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.POP_PAGE),
                ),
                _buildTile(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Certidões',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.CERTIDOES_PAGE),
                ),
                _buildTile(
                  icon: Icons.help_center_rounded,
                  label: 'Ajuda',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.AJUDA_PAGE),
                ),
                // Mapa da Força para superusuários
                if (isUser == true)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Stack(
                      children: [
                        Container(
                          // decoration: BoxDecoration(
                          //   borderRadius: BorderRadius.circular(8),
                          //   gradient: const LinearGradient(
                          //     colors: [
                          //       Colors.white,
                          //       Colors.lightBlue,
                          //       Colors.black87
                          //     ],
                          //     begin: Alignment.topLeft,
                          //     end: Alignment.bottomRight,
                          //   ),
                          // ),
                          child: ListTile(
                            leading:
                                const Icon(Icons.groups, color: Colors.black),
                            title: const Text(
                              'Mapa da Força',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500),
                            ),
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.MAPA_DA_FORCA),
                          ),
                        ),
                        const Positioned(
                          top: 4,
                          right: 12,
                          child: Icon(
                            Icons.supervisor_account,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                _buildTile(
                  icon: Icons.logout_rounded,
                  label: 'Sair',
                  onTap: () => QuickAlert.show(
                    context: context,
                    type: QuickAlertType.confirm,
                    title: 'Deseja sair?',
                    text: 'Sua sessão será encerrada',
                    confirmBtnText: 'Sim',
                    cancelBtnText: 'Cancelar',
                    confirmBtnColor: Colors.redAccent,
                    onConfirmBtnTap: () {
                      Provider.of<Auth>(context, listen: false).logout();
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.AUTH_OR_HOME,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[800]),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  ImageProvider _imageProvider(Auth auth) {
    if (auth.localImagePath != null && auth.localImagePath!.isNotEmpty) {
      final file = File(auth.localImagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    return NetworkImage(auth.image ?? '');
  }
}
