import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';

import '../models/auth_model.dart';
import '../utils/api_services.dart';
import '../utils/app_routes.dart';

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

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);
    // Preenche com o e-mail já carregado (se existir no Auth)
    // _emailCtrl.text = auth.emailUser ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final emailConfirm = _emailConfirmCtrl.text.trim();

    if (email != emailConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Os e-mails não conferem!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final matricula = auth.matricula ?? '';

      if (matricula.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matrícula inválida!')),
        );
        return;
      }

      // Exemplo de Timeout para 10s (opcional)
      final result = await Future.any([
        ApiServices.sendEmailConfirmation(matricula: matricula, email: email),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Tempo excedido');
        }),
      ]);

      if (result['code'] == 1) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'E-mail de confirmação enviado',
          text: 'Clique no link em seu e-mail para ativar seu cadastro.',
          confirmBtnText: 'OK',
          onConfirmBtnTap: () {
            Navigator.of(context).pop(); // Fecha o QuickAlert
            auth.logout();
            Navigator.of(context).pushReplacementNamed(AppRoutes.AUTH_OR_HOME);
          },
        );
      } else {
        final msg = result['message'] ?? 'Erro desconhecido!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } on TimeoutException {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro de Conexão',
        text: 'Verifique sua internet e tente novamente.',
        confirmBtnText: 'OK',
      );
    } on SocketException {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro de Conexão',
        text: 'Verifique sua conexão e tente novamente.',
        confirmBtnText: 'OK',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirmar E-mail',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Container somente para a mensagem, com fundo degradê
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2196F3), // Azul
                      Color(0xFF90CAF9), // Azul mais claro
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: const [
                    Text(
                      'Por favor, nos informe seu e-mail atual para acessar o app.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Você receberá um e-mail de confirmação.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Campo E-mail
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Informe seu e-mail'
                    : null,
              ),
              const SizedBox(height: 16),

              // Campo Confirmar E-mail
              TextFormField(
                controller: _emailConfirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirme seu e-mail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Confirme seu e-mail'
                    : null,
              ),
              const SizedBox(height: 24),

              // Botão ou indicador de carregamento
              _isLoading
                  ? const CircularProgressIndicator.adaptive()
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'Enviar Confirmação',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
