import 'package:flutter/material.dart';

import '../animation/fade_animation.dart';
import '../utils/app_routes.dart';
import '../utils/my_strings.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(55);

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        MyStrings.logoText,
        style: textTheme.bodyMedium,
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(AppRoutes.HOME_PAGE);
          },
          icon: const Icon(
            Icons.close,
            color: Colors.black,
          ),
        )
      ],
    );
  }
}
