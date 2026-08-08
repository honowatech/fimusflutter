package com.honowa.fimus

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.honowa.fimus/ussd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "callUssd" -> {
                    val rawCode = call.argument<String>("code")
                    if (rawCode != null) {
                        try {
                            var cleanCode = rawCode.trim().replace("%23", "#").replace("%2A", "*").replace("%2a", "*")
                            cleanCode = cleanCode.replace("\\s+".toRegex(), "")

                            val encodedCode = Uri.encode(cleanCode)
                            val ussdUri = Uri.parse("tel:$encodedCode")

                            val intent = Intent(Intent.ACTION_CALL).apply {
                                data = ussdUri
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("USSD_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "USSD code is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
