import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'update_version.dart';

Future<int> fetchCurrentBuildNumber() async {
  final cacheBust = DateTime.now().millisecondsSinceEpoch;
  final uri = Uri.base.resolve('version.json?ts=$cacheBust');
  final response = await http.get(uri);
  if (response.statusCode != 200) return 0;

  final payload = jsonDecode(response.body);
  if (payload is! Map<String, dynamic>) return 0;
  return parseAppBuildNumber(payload);
}

void reloadApp() {
  web.window.location.reload();
}
