package com.example.gold_gym_fe_android

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Play Integrity (anti APK modifikasi): lihat lib/services/play_integrity.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "okejual/integrity")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestToken") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val nonce = call.argument<String>("nonce")
                if (nonce.isNullOrEmpty()) {
                    result.error("ARG", "nonce kosong", null)
                    return@setMethodCallHandler
                }
                val cloudProject = call.argument<String>("cloudProjectNumber")?.toLongOrNull()
                try {
                    val request = IntegrityTokenRequest.builder().setNonce(nonce)
                    if (cloudProject != null) request.setCloudProjectNumber(cloudProject)
                    IntegrityManagerFactory.create(applicationContext)
                        .requestIntegrityToken(request.build())
                        .addOnSuccessListener { result.success(it.token()) }
                        .addOnFailureListener { result.error("INTEGRITY", it.message, null) }
                } catch (e: Exception) {
                    result.error("INTEGRITY", e.message, null)
                }
            }
    }
}
