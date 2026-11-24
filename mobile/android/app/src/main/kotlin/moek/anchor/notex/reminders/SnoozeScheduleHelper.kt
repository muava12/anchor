package moek.anchor.notex.reminders

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationManagerCompat
import moek.anchor.notex.R
import java.util.Date
import java.util.Locale

/**
 * Re-schedules a fired reminder NATIVELY — without launching the app:
 *
 * 1. cancels the occurrence's alarm (already fired and removed from the
 *    store) and re-arms the same id at [targetMillis];
 * 2. drops the sticky notification card;
 * 3. stashes `{noteId, targetMillis, recurrence}` in [PendingSnoozeStore]
 *    so the app can settle the occurrence for real on its next start.
 *
 * Re-arming reuses the notification id as the new alarm id: the fired
 * occurrence's alarm was removed when it fired, so there is no collision.
 * This only delays THIS occurrence; the recurring series otherwise stays
 * unchanged.
 */
object SnoozeScheduleHelper {

    fun snooze(
        context: Context,
        noteId: String,
        notificationId: Int,
        title: String,
        body: String,
        recurrence: String,
        targetMillis: Long,
        tag: String = "",
    ) {
        ReminderAlarmScheduler.cancel(context, notificationId)
        // Snoozing is an acknowledgement: drop this occurrence's escalation.
        FsiEscalationScheduler.cancel(context, notificationId)
        ReminderAlarmScheduler.arm(
            context,
            notificationId,
            noteId,
            title,
            body,
            targetMillis,
            snoozeNoteId = "",
            recurrence = recurrence,
            tag = tag,
        )
        ReminderAlarmStore.upsert(
            context,
            mapOf(
                "id" to notificationId,
                "noteId" to noteId,
                "title" to title,
                "body" to body,
                "atMillis" to targetMillis,
                "snoozeNoteId" to "",
                "recurrence" to recurrence,
                "tag" to tag,
            )
        )
        // Drop the sticky card so it does not linger for the new time.
        NotificationManagerCompat.from(context).cancel(notificationId)
        PendingSnoozeStore.put(context, noteId, targetMillis, recurrence)
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(
                context,
                context.getString(R.string.snooze_toast_snoozed, wallClock(context, targetMillis)),
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /** Wall-clock "date time" of [atMillis] for the toast, e.g. "Jun 5, 2026 9:00 AM". */
    private fun wallClock(context: Context, atMillis: Long): String {
        val locale = context.resources.configuration.locale ?: Locale.getDefault()
        val at = Date(atMillis)
        return java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM, locale).format(at) +
            " " +
            java.text.DateFormat.getTimeInstance(java.text.DateFormat.SHORT, locale).format(at)
    }
}
