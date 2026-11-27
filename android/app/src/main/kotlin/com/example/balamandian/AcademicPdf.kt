package com.example.balamandian

import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.min
import kotlin.math.roundToInt

class AcademicPdfService : Service() {
    private val worker = HandlerThread("academic-pdf")
    private lateinit var endpoint: Messenger

    override fun onCreate() {
        super.onCreate()
        worker.start()
        endpoint = Messenger(Handler(worker.looper) { message ->
            @Suppress("DEPRECATION")
            val file = message.data.getParcelable<ParcelFileDescriptor>("pdf")
            val result = Message.obtain()
            val preview = try {
                file?.use { render(it) }
            } catch (_: Exception) {
                null
            }
            result.data = Bundle().apply { putByteArray("preview", preview) }
            runCatching { message.replyTo.send(result) }
            true
        })
    }

    override fun onBind(intent: Intent): IBinder = endpoint.binder

    override fun onDestroy() {
        worker.quitSafely()
        super.onDestroy()
    }

    private fun render(file: ParcelFileDescriptor): ByteArray? = PdfRenderer(file).use { renderer ->
        if (renderer.pageCount == 0) return null
        renderer.openPage(0).use { page ->
            val scale = min(700f / page.width, 1000f / page.height)
            val bitmap = Bitmap.createBitmap(
                (page.width * scale).roundToInt().coerceAtLeast(1),
                (page.height * scale).roundToInt().coerceAtLeast(1),
                Bitmap.Config.ARGB_8888,
            )
            try {
                bitmap.eraseColor(Color.WHITE)
                val transform = Matrix().apply { setScale(scale, scale) }
                page.render(bitmap, null, transform, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                ByteArrayOutputStream().use { output ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 77, output)
                    output.toByteArray().takeIf { it.size < 700_000 }
                }
            } finally {
                bitmap.recycle()
            }
        }
    }
}

class AcademicPdfChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "balamandian/academic_pdf")
    private val handler = Handler(Looper.getMainLooper())
    private var connection: ServiceConnection? = null
    private var result: MethodChannel.Result? = null
    private var pdf: ParcelFileDescriptor? = null
    private val timeout = Runnable { finish(null) }

    init {
        channel.setMethodCallHandler { call, reply ->
            if (call.method != "firstPage") { reply.notImplemented(); return@setMethodCallHandler }
            val bytes = call.arguments as? ByteArray
            if (result != null || bytes == null || bytes.isEmpty() || bytes.size > 8_000_000) {
                reply.error("preview_unavailable", "Document preview is unavailable.", null)
                return@setMethodCallHandler
            }
            result = reply
            handler.postDelayed(timeout, 9000)
            Thread {
                val descriptor = runCatching {
                    val temporary = File.createTempFile("academic-", ".pdf", context.cacheDir)
                    try {
                        temporary.writeBytes(bytes)
                        ParcelFileDescriptor.open(temporary, ParcelFileDescriptor.MODE_READ_ONLY)
                    } finally {
                        temporary.delete()
                    }
                }.getOrNull()
                handler.post {
                    if (result !== reply || descriptor == null) {
                        descriptor?.close()
                        if (result === reply) finish(null)
                    } else {
                        pdf = descriptor
                        connect()
                    }
                }
            }.start()
        }
    }

    private fun connect() {
        val client = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                val connected = this
                val call = Message.obtain().apply {
                    data = Bundle().apply { putParcelable("pdf", pdf) }
                    replyTo = Messenger(Handler(Looper.getMainLooper()) { reply ->
                        if (connection === connected) finish(reply.data.getByteArray("preview"))
                        true
                    })
                }
                if (runCatching { Messenger(binder).send(call) }.isFailure) finish(null)
                pdf?.close()
                pdf = null
            }

            override fun onServiceDisconnected(name: ComponentName) { finish(null) }
            override fun onNullBinding(name: ComponentName) { finish(null) }
            override fun onBindingDied(name: ComponentName) { finish(null) }
        }
        connection = client
        if (!context.bindService(Intent(context, AcademicPdfService::class.java), client, Context.BIND_AUTO_CREATE)) finish(null)
    }

    private fun finish(bytes: ByteArray?) {
        handler.removeCallbacks(timeout)
        connection?.let { runCatching { context.unbindService(it) } }
        connection = null
        pdf?.close()
        pdf = null
        val reply = result ?: return
        result = null
        if (bytes == null) reply.error("preview_unavailable", "Could not preview this PDF.", null) else reply.success(bytes)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        finish(null)
    }
}
