import 'package:flutter/material.dart';

import '../widgets/auth_form.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        image: DecorationImage(
            fit: BoxFit.fill,
            image: AssetImage('assets/imagens/entradacapa.png')),
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 197, 228, 242),
            Color.fromARGB(255, 0, 33, 84)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Text(
                    //   'MinhaPM',
                    //   style: TextStyle(
                    //     color: Color.fromARGB(255, 59, 101, 255),
                    //   ),
                    // ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    AuthForm(),
                  ],
                )),
          ),
        ],
      ),
    );
  }
}
