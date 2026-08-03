package com.fishergo.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val notificationChannelName = "fishergo/notifications"
        const val notificationRequestCode = 9201
    }

    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(notificationStatus())
                "request" -> requestNotifications(result)
                "openSettings" -> openNotificationSettings(result)
                // Provider SDK integration supplies this value in a later
                // release; permission state remains useful without a token.
                "deviceToken" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "granted"
        return if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            notificationStatus() == "granted"
        ) {
            result.success("granted")
            return
        }
        if (pendingNotificationResult != null) {
            result.error("REQUEST_IN_PROGRESS", "Notification request already running", null)
            return
        }
        pendingNotificationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationRequestCode,
        )
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        try {
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationRequestCode) return
        pendingNotificationResult?.success(notificationStatus())
        pendingNotificationResult = null
    }
}
