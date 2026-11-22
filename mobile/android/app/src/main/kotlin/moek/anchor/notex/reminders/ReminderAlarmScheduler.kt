package moek.anchor.notex.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Arms exact alarms for scheduled reminders. One broadcast pending intent per
 * reminder id; [ReminderFireReceiver] posts the notification when it fires.
 */
object ReminderAlarmScheduler {
    const val ACTION_FIRE = "moek.anchor.notex.REMINDER_FIRE"

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

    fun cancel(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(fireIntent(context, id, "", "", "", "", "none"))
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (r in ReminderAlarmStore.load(context)) {
            am.cancel(fireIntent(context, r["id"] as Int, "", "", "", "", "none"))
        }
        ReminderAlarmStore.clear(context)
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
