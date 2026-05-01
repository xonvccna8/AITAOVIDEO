package com.example.ChemiVision

import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "screen_brightness"
    private val GYRO_CHANNEL = "gyro_stream"
    private val TTS_CHANNEL = "ChemiVision/tts"
    private var sensorManager: SensorManager? = null
    private var gyroListener: SensorEventListener? = null
    private var textToSpeech: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBrightness" -> {
                        try {
                            val lp = window.attributes
                            var current = lp.screenBrightness
                            if (current < 0f) {
                                // Fallback to system brightness (0-255)
                                val sys = Settings.System.getInt(
                                    contentResolver,
                                    Settings.System.SCREEN_BRIGHTNESS,
                                    128
                                )
                                current = sys / 255f
                            }
                            result.success(current.toDouble())
                        } catch (e: Exception) {
                            result.error("ERR_GET_BRIGHTNESS", e.message, null)
                        }
                    }
                    "setBrightness" -> {
                        try {
                            val value = (call.arguments as? Double) ?: 1.0
                            runOnUiThread {
                                val lp = window.attributes
                                lp.screenBrightness = value.toFloat().coerceIn(0f, 1f)
                                window.attributes = lp
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                                result.success(null)
                            }
                        } catch (e: Exception) {
                            result.error("ERR_SET_BRIGHTNESS", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Gyroscope event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GYRO_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
                    if (sensor == null) {
                        events?.error("NO_SENSOR", "Gyroscope not available", null)
                        return
                    }
                    gyroListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent) {
                            val data = mapOf(
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble()
                            )
                            events?.success(data)
                        }
                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                    }
                    sensorManager?.registerListener(
                        gyroListener,
                        sensor,
                        SensorManager.SENSOR_DELAY_GAME
                    )
                }

                override fun onCancel(arguments: Any?) {
                    if (gyroListener != null) {
                        sensorManager?.unregisterListener(gyroListener)
                        gyroListener = null
                    }
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speakVietnamese" -> {
                        val text = call.argument<String>("text") ?: ""
                        if (text.isBlank()) {
                            result.error("EMPTY_TEXT", "Text is empty", null)
                            return@setMethodCallHandler
                        }
                        speakVietnamese(text, result)
                    }
                    "stop" -> {
                        textToSpeech?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun speakVietnamese(text: String, result: MethodChannel.Result) {
        val current = textToSpeech
        if (current == null) {
            textToSpeech = TextToSpeech(this) { status ->
                if (status != TextToSpeech.SUCCESS) {
                    result.error("TTS_INIT_FAILED", "Failed to initialize Android TTS", null)
                    return@TextToSpeech
                }
                val tts = textToSpeech ?: return@TextToSpeech
                val setLang = tts.setLanguage(Locale("vi", "VN"))
                if (setLang == TextToSpeech.LANG_MISSING_DATA || setLang == TextToSpeech.LANG_NOT_SUPPORTED) {
                    result.error("TTS_LANG_UNSUPPORTED", "Vietnamese voice is not available on this device", null)
                    return@TextToSpeech
                }
                tts.setSpeechRate(0.95f)
                tts.setPitch(1.0f)
                val speakStatus = tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ChemiVision_tts")
                if (speakStatus == TextToSpeech.ERROR) {
                    result.error("TTS_SPEAK_FAILED", "Failed to speak Vietnamese text", null)
                } else {
                    result.success(true)
                }
            }
            return
        }

        val setLang = current.setLanguage(Locale("vi", "VN"))
        if (setLang == TextToSpeech.LANG_MISSING_DATA || setLang == TextToSpeech.LANG_NOT_SUPPORTED) {
            result.error("TTS_LANG_UNSUPPORTED", "Vietnamese voice is not available on this device", null)
            return
        }
        current.setSpeechRate(0.95f)
        current.setPitch(1.0f)
        val speakStatus = current.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ChemiVision_tts")
        if (speakStatus == TextToSpeech.ERROR) {
            result.error("TTS_SPEAK_FAILED", "Failed to speak Vietnamese text", null)
        } else {
            result.success(true)
        }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}

