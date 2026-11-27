package com.example.balamandian

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/** Native alarms survive process death; no Dart engine is started by an alarm. */
object CalendarAlarms {
    const val CHANNEL = "campus-calendar-reminders"
    private const val PREFS = "private-calendar-reminders"
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun allowed(c: Context): Boolean = (Build.VERSION.SDK_INT < 33 || c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) && c.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    private fun alarm(c: Context, owner: String, id: String): PendingIntent = PendingIntent.getBroadcast(c, 0,
        Intent(c, CalendarAlarmReceiver::class.java).setData(Uri.parse("balamandian-internal://reminder/$owner/$id")).putExtra("owner", owner).putExtra("event", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun events(c: Context): JSONArray = try { JSONArray(prefs(c).getString("events", "[]")) } catch (_: Exception) { JSONArray() }
    fun replace(c: Context, owner: String?, list: List<Map<String, Any?>>) {
        val oldOwner = prefs(c).getString("owner", null)
        val manager = c.getSystemService(AlarmManager::class.java)
        if (oldOwner != null) {
            val old = events(c)
            for (i in 0 until old.length()) {
                val id = old.getJSONObject(i).getString("id")
                val operation = alarm(c, oldOwner, id)
                manager.cancel(operation)
                operation.cancel()
                c.getSystemService(NotificationManager::class.java).cancel(id, 0)
            }
        }
        val valid = JSONArray()
        if (owner != null && allowed(c)) for (e in list) {
            val id = e["id"] as? String ?: continue
            val at = (e["at"] as? Number)?.toLong() ?: continue
            if (!id.matches(Regex("[a-fA-F0-9-]{36}")) || at <= System.currentTimeMillis()) continue
            val title = (e["title"] as? String ?: "Calendar event").take(160)
            valid.put(JSONObject().put("id", id).put("at", at).put("title", title))
        }
        // Commit before scheduling; the receiver checks the persisted owner and occurrence.
        prefs(c).edit().putString("owner", owner).putString("events", valid.toString()).commit()
        reschedule(c)
    }
    fun reschedule(c: Context) {
        val owner = prefs(c).getString("owner", null) ?: return
        if (!allowed(c)) return
        val list = events(c)
        // Keep a rolling window below platform/vendor per-UID alarm limits. The full
        // future queue is persisted and replenished even without a Flutter process.
        val future = (0 until list.length()).map { list.getJSONObject(it) }.filter { it.getLong("at") > System.currentTimeMillis() }.sortedBy { it.getLong("at") }.take(64)
        for (event in future) c.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, event.getLong("at"), alarm(c, owner, event.getString("id")))

    }
    fun fire(c: Context, intent: Intent) {
        val owner = intent.getStringExtra("owner") ?: return
        val id = intent.getStringExtra("event") ?: return
        if (prefs(c).getString("owner", null) != owner || !allowed(c)) return
        val list = events(c)
        val event = (0 until list.length()).map { list.getJSONObject(it) }.firstOrNull { it.getString("id") == id } ?: return
        val at = event.getLong("at")
        // Never post early, or replay an obsolete reminder after reboot / permission changes.
        if (at > System.currentTimeMillis() || System.currentTimeMillis() - at > 6 * 3600000L) return
        val remaining = JSONArray(); for (i in 0 until list.length()) if (list.getJSONObject(i).getString("id") != id) remaining.put(list.getJSONObject(i))
        prefs(c).edit().putString("events", remaining.toString()).commit()
        val manager = c.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "Calendar reminders", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java).setAction("balamandian.OPEN_CALENDAR.$owner.$id").putExtra("calendarOwner", owner).putExtra("calendarEvent", id).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        manager.notify(id, 0, notification.setSmallIcon(R.drawable.ic_calendar_notification).setContentTitle(event.getString("title")).setContentText("Calendar reminder - campus time Asia/Beirut").setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(open).setAutoCancel(true).build())
        reschedule(c)
    }
}
class CalendarAlarmReceiver : BroadcastReceiver() { override fun onReceive(context: Context, intent: Intent) { CalendarAlarms.fire(context, intent) } }
class CalendarRescheduleReceiver : BroadcastReceiver() { override fun onReceive(context: Context, intent: Intent) { if (intent.action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) CalendarAlarms.reschedule(context) } }
class CalendarReminderBridge(private val activity: MainActivity, private val channel: MethodChannel) : MethodChannel.MethodCallHandler {
    private var permissionResult: MethodChannel.Result? = null
    private var pendingLink: Map<String,String>? = null
    init { accept(activity.intent, false) }
    fun accept(intent: Intent?, emit: Boolean = true) {
        val id = intent?.getStringExtra("calendarEvent") ?: return
        val owner = intent.getStringExtra("calendarOwner") ?: return
        if (!id.matches(Regex("[a-fA-F0-9-]{36}"))) return
        val link = mapOf("event" to id, "owner" to owner)
        if (emit) channel.invokeMethod("notificationOpened", link) else pendingLink = link
        intent.removeExtra("calendarEvent"); intent.removeExtra("calendarOwner")
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "permission" -> result.success(CalendarAlarms.allowed(activity))
            "requestPermission" -> {
                if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    if (permissionResult != null) { result.success(false); return }
                    permissionResult = result; activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7103)
                } else result.success(CalendarAlarms.allowed(activity))
            }
            "replace" -> { val owner = call.argument<String>("owner"); val events = call.argument<List<Map<String, Any?>>>("events") ?: emptyList(); CalendarAlarms.replace(activity, owner, events); result.success(null) }
            "initialLink" -> { result.success(pendingLink); pendingLink = null }
            else -> result.notImplemented()
        }
    }
    fun permissionReply(requestCode: Int) { if (requestCode == 7103) { permissionResult?.success(CalendarAlarms.allowed(activity)); permissionResult = null } }
    fun dispose() { permissionResult?.success(false); permissionResult = null }
}
