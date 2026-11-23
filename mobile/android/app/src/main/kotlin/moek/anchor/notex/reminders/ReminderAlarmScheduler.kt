package moek.anchor.notex.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Arms exact alarms for scheduled reminders. One broadcast pending intent per
 * reminder id; [ReminderFireReceiver] posts the notification when it fires.
 *
 * The extras each armed intent carries are persisted ([remember]):
 * `AlarmManager.cancel` matches on the EXACT intent (including extras), so
 * [cancel] rebuilds the identical pending intent from the stored record.
 * Without this, canceling with different extras silently no-ops and the
 * alarm fires anyway.
 */
object ReminderAlarmScheduler {
    const val ACTION_FIRE = "moek.anchor.notex.REMINDER_FIRE"

    private const val ARMED_PREFS = "reminder_alarms_armed"
    private const val ARMED_KEY = "alarms"

    private data class ArmedRecord(
        val id: Int,
        val noteId: String,
        val title: String,
        val body: String,
        val snoozeNoteId: String,
        val recurrence: String,
    )

    private fun fireIntent(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        snoozeNoteId: String,
        recurrence: String,
    ): PendingIntent {
        val intent = Intent(context, ReminderFireReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra("reminder_id", id)
            putExtra("note_id", noteId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("snooze_note_id", snoozeNoteId)
            putExtra("recurrence", recurrence)
        }
        return PendingIntent.getBroadcast(context, id, intent, pendingFlags())
    }

    private fun pendingFlags() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    /** Schedules a one-shot exact alarm; falls back to inexact without the grant. */
    fun arm(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        atMillis: Long,
        snoozeNoteId: String,
        recurrence: String,
    ) {
        // Persist the extras before arming: [cancel] rebuilds the identical
        // pending intent from this record.
        remember(context, ArmedRecord(id, noteId, title, body, snoozeNoteId, recurrence))
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = fireIntent(context, id, noteId, title, body, snoozeNoteId, recurrence)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, atMillis, pi)
            }
        } catch (e: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, atMillis, pi)
        }
    }

    /**
     * Cancels the pending alarm for this id. Rebuilds the armed intent from
     * the persisted extras so am.cancel actually matches; no-op when no
     * record is known, so double-cancel is safe.
     */
    fun cancel(context: Context, id: Int) {
        val rec = recordFor(context, id) ?: return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(fireIntent(context, rec.id, rec.noteId, rec.title, rec.body, rec.snoozeNoteId, rec.recurrence))
        forget(context, id)
    }

    /** Drops the armed record after the alarm has fired. */
    fun forget(context: Context, id: Int) {
        val current = armedRecords(context)
        val kept = current.filter { it.id != id }
        if (kept.size == current.size) return
        saveArmed(context, kept)
    }

    fun cancelAll(context: Context) {
        // Every id the app may still have armed: the persisted armed set plus
        // the pending store (alarms armed before this code existed).
        val ids = (armedRecords(context).map { it.id } +
            ReminderAlarmStore.load(context).map { it["id"] as Int }).toSet()
        for (id in ids) {
            cancel(context, id)
        }
        saveArmed(context, emptyList())
        ReminderAlarmStore.clear(context)
    }

    /**
     * The record [cancel] rebuilds the intent from: the persisted armed set
     * first, then [ReminderAlarmStore] (which holds every field the fire
     * intent carries).
     */
    private fun recordFor(context: Context, id: Int): ArmedRecord? {
        armedRecords(context).firstOrNull { it.id == id }?.let { return it }
        val store = ReminderAlarmStore.load(context).firstOrNull { it["id"] == id } ?: return null
        return ArmedRecord(
            store["id"] as Int,
            store["noteId"] as String,
            store["title"] as String,
            store["body"] as String,
            store["snoozeNoteId"] as String,
            store["recurrence"] as String,
        )
    }

    private fun remember(context: Context, rec: ArmedRecord) {
        val kept = armedRecords(context).filter { it.id != rec.id }.toMutableList()
        kept.add(rec)
        saveArmed(context, kept)
    }

    private fun saveArmed(context: Context, records: List<ArmedRecord>) {
        val arr = JSONArray()
        for (r in records) {
            arr.put(
                JSONObject()
                    .put("id", r.id)
                    .put("noteId", r.noteId)
                    .put("title", r.title)
                    .put("body", r.body)
                    .put("snoozeNoteId", r.snoozeNoteId)
                    .put("recurrence", r.recurrence)
            )
        }
        context.getSharedPreferences(ARMED_PREFS, Context.MODE_PRIVATE)
            .edit().putString(ARMED_KEY, arr.toString()).apply()
    }

    private fun armedRecords(context: Context): List<ArmedRecord> {
        val raw = context.getSharedPreferences(ARMED_PREFS, Context.MODE_PRIVATE)
            .getString(ARMED_KEY, null) ?: return emptyList()
        val out = mutableListOf<ArmedRecord>()
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                ArmedRecord(
                    o.getInt("id"),
                    o.getString("noteId"),
                    o.getString("title"),
                    o.optString("body"),
                    o.optString("snoozeNoteId"),
                    o.optString("recurrence", "none"),
                )
            )
        }
        return out
    }

    /** Re-arms every persisted alarm; called on boot and package replace. */
    fun rearmAll(context: Context) {
        for (r in ReminderAlarmStore.load(context)) {
            arm(
                context,
                r["id"] as Int,
                r["noteId"] as String,
                r["title"] as String,
                r["body"] as String,
                r["atMillis"] as Long,
                r["snoozeNoteId"] as String,
                r["recurrence"] as String,
            )
        }
    }
}
