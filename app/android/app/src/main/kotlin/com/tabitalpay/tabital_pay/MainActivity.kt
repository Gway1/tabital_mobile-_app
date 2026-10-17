package com.tabitalpay.tabital_pay

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity: local_auth (the app lock) shows the system biometric prompt in a fragment
class MainActivity : FlutterFragmentActivity() {
    private var cameraResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        secureChannel(flutterEngine)
        deviceChannel(flutterEngine)
        // The Smile ID selfie runs in a web view, which can only use the camera once the app has it
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tabitalpay/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method != "camera") {
                    result.notImplemented()
                } else if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (cameraResult != null) {
                    result.error("busy", "A camera request is already open", null)
                } else {
                    cameraResult = result
                    requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST)
                }
            }
    }

    private fun deviceChannel(flutterEngine: FlutterEngine) {
        // Fraud checks (§9D): the API flags sign-ins and purchases from emulators (X-Device-Flags)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tabitalpay/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "flags") result.success(if (isEmulator()) "emulator" else "") else result.notImplemented()
            }
    }

    private fun isEmulator(): Boolean {
        val fp = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val product = Build.PRODUCT.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        return fp.startsWith("generic") || fp.startsWith("unknown") || fp.contains("emulator") ||
            model.contains("emulator") || model.contains("android sdk built for") || model.contains("google_sdk") ||
            product.startsWith("sdk") || product.contains("emulator") || product.contains("simulator") ||
            hardware.contains("goldfish") || hardware.contains("ranchu") ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
    }

    private fun secureChannel(flutterEngine: FlutterEngine) {
        // Payment and identity screens hide their contents from screenshots and the app switcher
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tabitalpay/secure")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val on = call.arguments as? Boolean ?: false
                runOnUiThread {
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(on)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_REQUEST) {
            cameraResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            cameraResult = null
        }
    }

    companion object {
        private const val CAMERA_REQUEST = 4101
    }
}
