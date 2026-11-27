package com.example.balamandian

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Only app-created PDFs in one private cache directory can receive read grants. */
class NotesPdfOpener(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val pattern = Regex("private-note-[a-f0-9]{32}\\.pdf")
    private val authority get() = "${activity.packageName}.notes.pdf"
    private val directory get() = File(activity.cacheDir, "notes-pdf").canonicalFile

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "openPdf" -> {
                    val path = call.argument<String>("path")
                        ?: throw IllegalArgumentException("Missing PDF path")
                    val file = File(path).canonicalFile
                    require(file.parentFile == directory && pattern.matches(file.name))
                    require(file.isFile && file.length() in 1L..5242880L)
                    val uri = FileProvider.getUriForFile(activity, authority, file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/pdf")
                        clipData = ClipData.newRawUri("Private note PDF", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(intent)
                    result.success(null)
                }
                "clearPdf" -> {
                    directory.listFiles()?.filter { pattern.matches(it.name) }?.forEach { file ->
                        val uri = FileProvider.getUriForFile(activity, authority, file)
                        activity.revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: ActivityNotFoundException) {
            result.error("NO_PDF_VIEWER", "Install a PDF viewer to open this attachment.", null)
        } catch (_: Exception) {
            result.error("PDF_UNAVAILABLE", "This private PDF could not be opened.", null)
        }
    }
}
