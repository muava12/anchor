package moek.anchor.notex.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by [ReminderAlarmScheduler] when a reminder's exact alarm goes off.
 * Posts the native notification and arms the 60 s escalation that re-shows
 * the sheet if the banner is ignored; the card's buttons then settle the
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
        val atMillis = intent.getLongExtra("at_millis", 0L)
        val tag = intent.getStringExtra("tag") ?: ""
        ReminderAlarmStore.remove(context, id)
        // The alarm fired: its extras record is spent.
        ReminderAlarmScheduler.forget(context, id)
        val postedWhen = ReminderNotificationBuilder.show(
            context, id, noteId, title, body, snoozeNoteId, recurrence, atMillis, tag,
        )
        FsiEscalationScheduler.scheduleIfUnlocked(
            context, id, noteId, title, body, recurrence, postedWhen, atMillis, tag,
        )
    }
}
