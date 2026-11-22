package moek.anchor.notex.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by [ReminderAlarmScheduler] when a reminder's exact alarm goes off.
 * Posts the native notification; the card's buttons then settle the
 * occurrence natively (see [ReminderActionReceiver]) without the app running.
 */
class ReminderFireReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderAlarmScheduler.ACTION_FIRE) return
        val id = intent.getIntExtra("reminder_id", 0)
        val noteId = intent.getStringExtra("note_id") ?: ""
        val title = intent.getStringExtra("title") ?: ""
        val body = intent.getStringExtra("body") ?: ""
        val snoozeNoteId = intent.getStringExtra("snooze_note_id") ?: ""
        val recurrence = intent.getStringExtra("recurrence") ?: "none"
        ReminderAlarmStore.remove(context, id)
        ReminderNotificationBuilder.show(context, id, noteId, title, body, snoozeNoteId, recurrence)
    }
}