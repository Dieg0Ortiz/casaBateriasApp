package com.casabaterias.erp

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "erp_baterias/security",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkDevice" -> result.success(if (deviceIsCompromised()) "comprometido" else "ok")
                else -> result.notImplemented()
            }
        }
    }

    private fun deviceIsCompromised(): Boolean {
        return isUsbDebuggingEnabled() || isRooted()
    }

    private fun isUsbDebuggingEnabled(): Boolean {
        return runCatching {
            Settings.Secure.getInt(contentResolver, Settings.Secure.ADB_ENABLED, 0) == 1
        }.getOrDefault(false)
    }

    private fun isRooted(): Boolean {
        // Binarios su en rutas habituales.
        val suPaths = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/vendor/bin/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/su/bin/su",
            "/system/xbin/busybox",
            "/system/bin/busybox",
        )
        for (path in suPaths) {
            if (java.io.File(path).exists()) return true
        }

        // Aplicaciones de root conocidas instaladas.
        val rootPackages = listOf(
            "com.topjohnwu.magisk",
            "com.kingroot.kinguser",
            "com.kingo.root",
            "com.superuser",
            "eu.chainfire.supersu",
            "de.robv.android.xposed.installer",
            "com.thirdparty.superuser",
            "com.stericson.rootchecker",
        )
        val pm = packageManager
        for (pkg in rootPackages) {
            runCatching { pm.getPackageInfo(pkg, 0) }.onSuccess { return true }
        }

        // Build con claves de fábrica (test-keys) sugiere imagen modificada.
        if (Build.TAGS != null && Build.TAGS.contains("test-keys")) return true
        
        // `su` accesible desde el runtime.
        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val output = process.inputStream.bufferedReader().readText().trim()
            if (output.isNotEmpty()) return true
        } catch (_: Exception) {
            // Sin shell: no podemos confirmar, no se marca.
        }

        return false
    }
}
