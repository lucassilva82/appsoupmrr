import 'dart:io';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_model.dart';
import '../utils/auth_exception.dart';

class AuthForm extends StatefulWidget {
  bool exibeSenha = true;
  AuthForm({Key? key}) : super(key: key);

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Map<String, String> _authData = {
    'matricula': '',
    'password': '',
  };

  // Fazendo animações na mudança de tamanho do formulário
  AnimationController? _controller;
  // ignore: unused_field
  Animation<double>? _opacityAnimation;
  // ignore: unused_field
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 300,
      ),
    );

    _opacityAnimation = Tween(
      begin: -1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.slowMiddle,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInExpo,
      ),
    );

    // _heightAnimation?.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: ((context) => AlertDialog(
            title: Text('Ocorreu um erro'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          )),
    );
  }

  Future<void> _submit() async {
    //Inicia o loading.
    setState(() => _isLoading = true);

    Auth auth = Provider.of(context, listen: false);
    _formKey.currentState?.save();

    try {
      // Efetuar login salvando os dados dentro da classe auth.

      await auth.login(
        _authData['matricula']!,
        _authData['password']!,
      );
    } on AuthException catch (error) {
      _showErrorDialog(error.toString());
    } catch (error) {
      print(error);
      _showErrorDialog('Ocorreu um erro inesperado');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    return Column(
      children: [
        Card(
          color: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 8,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeIn,
            //height: _isLogin() ? 310 : 400,
            padding: const EdgeInsets.all(6),

            // height: _heightAnimation?.value.height ?? (_isLogin() ? 310 : 400),
            width: deviceSize.width * 0.70,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    style: TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12)),
                        labelText: 'Matrícula',
                        prefixIcon: Icon(Icons.person)),
                    keyboardType: TextInputType.number,
                    onSaved: (matricula) =>
                        _authData['matricula'] = matricula ?? '',
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                  TextFormField(
                    style: TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12)),
                        prefixIcon: Icon(Icons.lock),
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                            onPressed: () {
                              widget.exibeSenha = !widget.exibeSenha;
                              setState(() {});
                            },
                            icon: Icon(widget.exibeSenha == true
                                ? Icons.visibility
                                : Icons.visibility_off))),
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: widget.exibeSenha,
                    controller: _passwordController,
                    onSaved: (password) =>
                        _authData['password'] = password ?? '',
                    validator: (_password) {
                      final password = _password ?? '';
                      if (password.isEmpty || password.length < 5) {
                        return 'Informe uma senha válida';
                      } else {
                        return null;
                      }
                    },
                  ),

                  SizedBox(height: 20),
                  if (_isLoading == true)
                    CircularProgressIndicator(
                      color: Colors.indigo.shade900,
                      strokeWidth: 2,
                    )
                  else
                    Container(
                      width: MediaQuery.of(context).size.width * 0.50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(
                          'Entrar',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          fixedSize: Size(800, 16),
                          primary: Colors.indigo.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          // padding: const EdgeInsets.symmetric(
                          //   horizontal: 30,
                          //   vertical: 20,
                          // ),
                        ),
                      ),
                    ),

                  // Spacer(),

                  SizedBox(height: 20),
                  Container(
                    child: TextButton(
                      child: Text(
                        'Recuperar Senha / Primeiro acesso',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: ((context) => AlertDialog(
                                title: Text('Recuperar Senha'),
                                content: Text(
                                    'Você será redirecionado para o site do SIGRH, lá poderá recuperar sua senha.'),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      final Uri url = Uri.parse(
                                          "https://rh.pmrr.net/seguranca_retrieve_pswd/");

                                      if (!await launchUrl(
                                        url,
                                      )) {
                                        await launchUrl(
                                          url,
                                        );
                                      }
                                    },
                                    child: Text('OK'),
                                  ),
                                ],
                              )),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
