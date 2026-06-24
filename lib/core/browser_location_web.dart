// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web/web.dart' as web;

void setBrowserLocationHref(String url) {
  web.window.location.href = url;
}
