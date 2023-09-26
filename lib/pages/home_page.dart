import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'dart:async';
import '../models/auth_model.dart';
import '../widgets/card_tempo_servico.dart';
import '../widgets/carouselSlider.dart';
import '../widgets/drawer_personalizado.dart';
import '../widgets/grid_menu.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController controller = PageController();

  @override
  void initState() {
    // requestPermission();
    getPermissions();
    super.initState();
  }

  void requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    var status1 = await Permission.manageExternalStorage.status;
    if (!status1.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<bool> getPermissions() async {
    bool gotPermissions = false;

    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var release =
        androidInfo.version.release; // Version number, example: Android 12
    var sdkInt = androidInfo.version.sdkInt; // SDK, example: 31
    var manufacturer = androidInfo.manufacturer;
    var model = androidInfo.model;

    print('Android $release (SDK $sdkInt), $manufacturer $model');

    if (Platform.isAndroid) {
      var storage = await Permission.storage.status;

      if (storage != PermissionStatus.granted) {
        await Permission.storage.request();
      }

      if (sdkInt! >= 30) {
        var storage_external = await Permission.manageExternalStorage.status;

        if (storage_external != PermissionStatus.granted) {
          await Permission.manageExternalStorage.request();
        }

        storage_external = await Permission.manageExternalStorage.status;

        if (storage_external == PermissionStatus.granted &&
            storage == PermissionStatus.granted) {
          gotPermissions = true;
        }
      } else {
        // (SDK < 30)
        storage = await Permission.storage.status;

        if (storage == PermissionStatus.granted) {
          gotPermissions = true;
        }
      }
    }
    return gotPermissions;
  }

  @override
  Widget build(BuildContext context) {
    Auth auth = Provider.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Olá, ${auth.nomeMilitar}',
            style: TextStyle(fontSize: 16),
          ),
          actions: const [
            // IconButton(
            //     // onPressed: () {
            //     //   Navigator.of(context).pushNamed(AppRoutes.NOTIFICATIONS_PAGE);
            //     // },
            //     onPressed: null,
            //     icon: Icon(Icons.notifications)),
          ],
        ),
        drawer: Drawerpersonalizado(),
        body: Center(
          child: Column(
            children: [
              WidgetCarouselSlider(),
              Row(
                children: const [CardTempoServico()],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridMenu(),
              ),
              Container(
                decoration:
                    const BoxDecoration(shape: BoxShape.rectangle, boxShadow: [
                  BoxShadow(
                      color: Colors.grey,
                      spreadRadius: 2,
                      blurRadius: 3,
                      offset: Offset(0, 0))
                ]),
                child: Image.asset('assets/imagens/dti.jpeg'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
