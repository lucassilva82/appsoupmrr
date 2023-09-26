import 'package:flutter/material.dart';

import '../models/auth_model.dart';
import 'package:provider/provider.dart';

import 'auth_page.dart';
import 'home_page.dart';

class AuthOrHome extends StatelessWidget {
  const AuthOrHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Auth auth = Provider.of(context);

    return FutureBuilder(
        future: auth.tryAutoLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Text('Ocorreu um erro');
          } else {
            return auth.isAuth ? HomePage() : AuthPage();
          }
        });
  }
}
