package moek.anchor.notex.reminders

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject

/**
 * Arms the 60 s escalation for a fired reminder: if the banner is
 * unacknowledged, [FsiEscalationReceiver] re-shows the reminder sheet
 * over the app in use.
 *
 * [scheduleIfUnlocked] is called from [ReminderFireReceiver] right after
 * the notification is posted. Task 4's cancel hooks call [cancel] /
 * [cancelAllActive] whenever the user settles the banner.
 */
object FsiEscalationScheduler {
    const val ACTION_ESCALATE = "moek.anchor.notex.FSI_ESCALATE"
    const val DELAY_MS = 60_000L

    private const val PREFS = "fsi_escalations"
    private const val KEY = "escalations"

    private data class Record(
        val id: Int,
        val noteId: String,
        val title: String,
        val body: String,
        val recurrence: String,
        val postedWhen: Long,
        val atMillis: Long,
        val tag: String,
    )

    /**
     * Arms a one-shot escalation alarm for this occurrence, but only
     * while the screen is on and unlocked. Otherwise the full-screen
     * intent already shows the sheet and escalation would double it.
     */
    fun scheduleIfUnlocked(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        recurrence: String,
        postedWhen: Long,
        atMillis: Long = 0L,
        tag: String = "",
    ) {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (km.isKeyguardLocked()) return
        arm(context, id, noteId, title, body, recurrence, postedWhen, atMillis, tag)
    }

    private fun arm(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        recurrence: String,
        postedWhen: Long,
        atMillis: Long,
        tag: String,
    ) {
        // Persist the extras first: [cancel] rebuilds the IDENTICAL pending
        // intent, and am.cancel only matches on exact extras. A memory map
        // would lose the record when the canceling process never called arm.
        remember(context, Record(id, noteId, title, body, recurrence, postedWhen, atMillis, tag))
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = escalateIntent(context, id, noteId, title, body, recurrence, postedWhen, atMillis, tag)
        // ELAPSED_REALTIME: the 60 s clock keeps running through doze,
        // so a screen-off before the alarm still launches the sheet.
        val triggerAt = SystemClock.elapsedRealtime() + DELAY_MS
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            } else {
                am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            }
        } catch (e: SecurityException) {
            am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
        }
    }

    /**
     * Cancels the pending escalation for this occurrence. Rebuilds the armed
     * intent from the persisted extras so am.cancel actually matches; no-op
     * when nothing is armed (record absent), so double-cancel is safe.
     */
    fun cancel(context: Context, id: Int) {
        val rec = record(context, id) ?: return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(escalateIntent(context, rec.id, rec.noteId, rec.title, rec.body, rec.recurrence, rec.postedWhen, rec.atMillis, rec.tag))
        forget(context, id)
    }

    /** Drops the armed record after the escalation alarm has fired. */
    fun forget(context: Context, id: Int) {
        val current = load(context)
        val kept = current.filter { it.id != id }
        if (kept.size == current.size) return
        save(context, kept)
    }

    /** Cancels the escalation of every active notification. */
    fun cancelAllActive(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (active in nm.activeNotifications) {
            cancel(context, active.id)
        }
    }

    private fun escalateIntent(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        recurrence: String,
        postedWhen: Long,
        atMillis: Long,
        tag: String,
    ): PendingIntent {
        val intent = Intent(context, FsiEscalationReceiver::class.java).apply {
            action = ACTION_ESCALATE
            putExtra("reminder_id", id)
            putExtra("note_id", noteId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("recurrence", recurrence)
            putExtra("posted_when", postedWhen)
            putExtra("at_millis", atMillis)
            putExtra("tag", tag)
        }
        return PendingIntent.getBroadcast(context, id, intent, pendingFlags())
    }

    private fun record(context: Context, id: Int) = load(context).firstOrNull { it.id == id }

    private fun remember(context: Context, rec: Record) {
        val kept = load(context).filter { it.id != rec.id }.toMutableList()
        kept.add(rec)
        save(context, kept)
    }

    private fun save(context: Context, records: List<Record>) {
        val arr = JSONArray()
        for (r in records) {
            arr.put(
                JSONObject()
                    .put("id", r.id)
                    .put("noteId", r.noteId)
                    .put("title", r.title)
                    .put("body", r.body)
                    .put("recurrence", r.recurrence)
                    .put("postedWhen", r.postedWhen)
                    .put("atMillis", r.atMillis)
                    .put("tag", r.tag)
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }

    private fun load(context: Context): List<Record> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        val out = mutableListOf<Record>()
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                Record(
                    o.getInt("id"),
                    o.getString("noteId"),
                    o.getString("title"),
                    o.optString("body"),
                    o.optString("recurrence", "none"),
                    o.getLong("postedWhen"),
                    o.optLong("atMillis"),
                    o.optString("tag"),
                )
            )
        }
        return out
    }

    private fun pendingFlags() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
}
