import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EventsModel {
  Map<DateTime, List<dynamic>> events = {};

  Map<String, dynamic> encodeMap(Map<DateTime, dynamic> map) {
    Map<String, dynamic> newMap = {};
    map.forEach((key, value) {
      newMap[key.toString()] = map[key];
    });

    return newMap;
  }

  Map<DateTime, dynamic> decodeMap(Map<String, dynamic> map) {
    Map<DateTime, dynamic> newMap = {};
    map.forEach((key, value) {
      newMap[DateTime.parse(key)] = map[key];
    });

    return newMap;
  }

  initPrefs() async {
    SharedPreferences prefs;
    prefs = await SharedPreferences.getInstance();
    events = Map<DateTime, List<dynamic>>.from(
        decodeMap(jsonDecode(prefs.getString("events") ?? "{}")));
  }

  savePrefs() async {
    SharedPreferences prefs;
    prefs = await SharedPreferences.getInstance();
    prefs.setString("events", jsonEncode(encodeMap(events)));
  }

  deletePrefs() async {
    SharedPreferences prefs;
    prefs = await SharedPreferences.getInstance();
    events = {};
    prefs.remove("events");
  }
}
