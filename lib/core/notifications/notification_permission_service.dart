import 'package:flutter/services.dart';

import 'notification_device_token.dart';

enum NotificationPermissionStatus { granted, denied, unavailable }

typedef NotificationPlatformInvoker = Future<Object?> Function(String method);

class NotificationPermissionService {
  NotificationPermissionService({NotificationPlatformInvoker? invoke})
      : _invoke = invoke ?? _defaultInvoke;

  static const MethodChannel _channel = MethodChannel('fishergo/notifications');

  final NotificationPlatformInvoker _invoke;

  Future<NotificationPermissionStatus> status() async {
    try {
      return _mapStatus(await _invoke('status'));
    } on MissingPluginException {
      return NotificationPermissionStatus.unavailable;
    } on PlatformException {
      return NotificationPermissionStatus.unavailable;
    }
  }

  Future<NotificationPermissionStatus> request() async {
    try {
      return _mapStatus(await _invoke('request'));
    } on MissingPluginException {
      return NotificationPermissionStatus.unavailable;
    } on PlatformException {
      return NotificationPermissionStatus.unavailable;
    }
  }

  Future<bool> openSettings() async {
    try {
      final result = await _invoke('openSettings');
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<NotificationDeviceToken?> deviceToken() async {
    try {
      return notificationDeviceTokenFromPlatformValue(
        await _invoke('deviceToken'),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<Object?> _defaultInvoke(String method) {
    return _channel.invokeMethod<Object?>(method);
  }

  static NotificationPermissionStatus _mapStatus(Object? raw) {
    if (raw == true || raw == 'granted') {
      return NotificationPermissionStatus.granted;
    }
    if (raw == false || raw == 'denied') {
      return NotificationPermissionStatus.denied;
    }
    return NotificationPermissionStatus.unavailable;
  }
}
