package com.smartroutes.app

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.smartroutes.app.navigation.NavigationActivity

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smartroutes.navigation"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startNavigationWithStops") {
                val stops = call.argument<List<Map<String, Double>>>("stops")
                val intent = Intent(this, NavigationActivity::class.java)
                intent.putExtra("stops", ArrayList(stops))
                startActivity(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
