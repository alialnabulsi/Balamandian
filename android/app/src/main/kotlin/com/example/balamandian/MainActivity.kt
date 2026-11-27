package com.example.balamandian

import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.view.View
import android.window.SplashScreenView
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var voiceChannel: MethodChannel? = null
    private var voiceBluetooth: MethodChannel.Result? = null
    private var academicPdf: AcademicPdfChannel? = null
    private var splashView: SplashScreenView? = null
    private var pendingLayout: MethodChannel.Result? = null
    private var pendingReveal: MethodChannel.Result? = null
    private var flutterDisplayed = false
    private var nativeDismissed = false
    private var nativeBounds: List<Double>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view ->
                if (nativeDismissed) {
                    view.remove()
                    return@setOnExitAnimationListener
                }
                // Keep the native frame until Flutter has painted this same logo.
                splashView = view
                replyWithLayout()
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "balamandian/voice_audio")
        voiceChannel?.setMethodCallHandler { call, reply ->
            val service = Intent(this, VoiceAudioService::class.java)
            try {
                when (call.method) {
                    "start" -> { ContextCompat.startForegroundService(this, service); reply.success(null) }
                    "stop" -> { stopService(service); reply.success(null) }
                    "bluetooth" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                            reply.success(true)
                        } else if (voiceBluetooth == null) {
                            voiceBluetooth = reply
                            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 4702)
                        } else {
                            reply.success(false)
                        }
                    }
                    else -> reply.notImplemented()
                }
            } catch (_: Exception) {
                reply.error("audio_unavailable", "Open the app and allow microphone access to start a call.", null)
            }
        }
        academicPdf = AcademicPdfChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "balamandian/splash")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> {
                    pendingLayout?.error("replaced", "Splash request replaced", null)
                    pendingLayout = result
                    replyWithLayout()
                }
                "reveal" -> {
                    pendingReveal?.error("replaced", "Splash request replaced", null)
                    pendingReveal = result
                    // Use display frames, not a startup timer. The matched Flutter
                    // frame is submitted before removal; acknowledge on the next vsync.
                    window.decorView.postOnAnimation {
                        if (isDestroyed) return@postOnAnimation
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            splashView?.remove()
                            splashView = null
                        }
                        nativeDismissed = true
                        // A destination can change while Flutter is preparing
                        // the matched logo. Complete that pending layout even
                        // when another screen releases the overlay first.
                        replyWithLayout()
                        window.decorView.postOnAnimation {
                            pendingReveal?.success(null)
                            pendingReveal = null
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterDisplayed = true
        replyWithLayout()
    }

    private fun replyWithLayout() {
        val result = pendingLayout ?: return
        if (!flutterDisplayed) return
        if (nativeDismissed) {
            pendingLayout = null
            result.success(nativeBounds)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val icon = splashView?.iconView
            if (icon != null) {
                val iconOrigin = IntArray(2)
                val flutterOrigin = IntArray(2)
                icon.getLocationOnScreen(iconOrigin)
                findViewById<View>(FLUTTER_VIEW_ID).getLocationOnScreen(flutterOrigin)
                val density = resources.displayMetrics.density.toDouble()
                // Android exposes the 192dp masked icon view. The configured
                // no-background image uses a 288dp canvas (Android splash specs).
                // Restore that transparent padding before painting the same PNG.
                val canvasWidth = icon.width * 1.5
                val canvasHeight = icon.height * 1.5
                pendingLayout = null
                nativeBounds = listOf(
                    (iconOrigin[0] - flutterOrigin[0] - (canvasWidth - icon.width) / 2) / density,
                    (iconOrigin[1] - flutterOrigin[1] - (canvasHeight - icon.height) / 2) / density,
                    canvasWidth / density,
                    canvasHeight / density,
                )
                result.success(nativeBounds)
                return
            }
            // An Activity enter/focus event can precede the splash transfer.
            // Only the system's exit callback proves its overlay is ready.
            if (splashView == null) return
        }
        pendingLayout = null
        result.success(null)
    }

    override fun onDestroy() {
        voiceBluetooth?.success(false)
        voiceBluetooth = null
        voiceChannel?.setMethodCallHandler(null)
        stopService(Intent(this, VoiceAudioService::class.java))
        academicPdf?.close()
        channel?.setMethodCallHandler(null)
        pendingLayout?.error("cancelled", "Activity destroyed", null)
        pendingLayout = null
        pendingReveal?.error("cancelled", "Activity destroyed", null)
        pendingReveal = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashView?.remove()
            splashView = null
        }
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4702) {
            voiceBluetooth?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            voiceBluetooth = null
        }
    }
}
