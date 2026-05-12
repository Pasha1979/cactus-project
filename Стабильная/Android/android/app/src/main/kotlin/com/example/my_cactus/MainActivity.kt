package com.example.my_cactus

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)   // Обязательно!

        // Передаём deep link в Flutter
        val data = intent.dataString
        if (data != null && data.startsWith("mycactus://")) {
            println("🔗 MainActivity: onNewIntent получил deep link: $data")

            // Передаём через FlutterEngine (самый надёжный способ)
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                // Вызываем наш обработчик в Dart через platform channel
                val channel = io.flutter.plugin.common.MethodChannel(messenger, "deep_link")
                channel.invokeMethod("deepLink", data)
            }
        }
    }
}