package moek.anchor.notex.reminders

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/**
 * Fires [FsiEscalationScheduler.DELAY_MS] after a reminder's banner was
 * posted, when the user left the phone unlocked and ignored the banner:
 * the reminder sheet is re-shown over the app in use.
 *
 * The guards run in order; the first that fails decides:
 * 1. the banner of this occurrence is gone (settled or swiped away) → skip
 * 2. a reminder sheet is already visible → skip
 * 3. do not disturb is on (interruption filter ≠ ALL) → skip
 * 4. the overlay permission is not granted → re-post the banner once
 * 5. otherwise launch the sheet over the current app
 */
class FsiEscalationReceiver : BroadcastReceiver() {

    private enum class Outcome { LAUNCH, REPOST, SKIP }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != FsiEscalationScheduler.ACTION_ESCALATE) return
        val id = intent.getIntExtra("reminder_id", 0)
        val noteId = intent.getStringExtra("note_id") ?: ""
        val title = intent.getStringExtra("title") ?: ""
        val body = intent.getStringExtra("body") ?: ""
        val recurrence = intent.getStringExtra("recurrence") ?: "none"
        val postedWhen = intent.getLongExtra("posted_when", 0L)
        // The escalation fired: its extras record is spent.
        FsiEscalationScheduler.forget(context, id)

        when (decide(context, id, postedWhen)) {
            Outcome.LAUNCH -> {
                try {
                    context.startActivity(
                        FullScreenReminderActivity.buildIntent(context, noteId, title, body, id, recurrence)
                    )
                } catch (e: Exception) {
                    // Launch failed (overlay revoked, card swiped on Android 14):
                    // fall back to the banner, once.
                    repostBanner(context, id, noteId, title, body, recurrence)
                }
            }
            Outcome.REPOST -> repostBanner(context, id, noteId, title, body, recurrence)
            Outcome.SKIP -> Unit
        }
    }

    /** Evaluates the escalation guards, in order; returns what to do. */
    private fun decide(context: Context, id: Int, postedWhen: Long): Outcome {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. This occurrence's banner must still be active: the `when` the
        //    builder set on post identifies the occurrence, so a settled,
        //    re-fired, or swiped banner has a different `when` and skips.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val occurrenceActive = nm.activeNotifications.any {
                it.id == id && it.notification.`when` == postedWhen
            }
            if (!occurrenceActive) return Outcome.SKIP
        }

        // 2. A sheet already visible: a later reminder rebinds it instead.
        if (ReminderSheetState.anyVisible) return Outcome.SKIP

        // 3. DND: heads-ups are suppressed, so the sheet would be too.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
        ) {
            return Outcome.SKIP
        }

        // 4. Overlay not granted: one re-post, never a reschedule.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(context)
        ) {
            return Outcome.REPOST
        }

        return Outcome.LAUNCH
    }

    /** Re-shows the banner of this occurrence; does not re-arm the alarm. */
    private fun repostBanner(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        recurrence: String,
    ) {
        ReminderNotificationBuilder.show(context, id, noteId, title, body, "", recurrence)
    }
}
