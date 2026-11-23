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

    /**
     * Arms a one-shot escalation alarm for this occurrence, but only
     * while the screen is on and unlocked — otherwise the full-screen
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
    ) {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (km.isKeyguardLocked()) return
        arm(context, id, noteId, title, body, recurrence, postedWhen)
    }

    private fun arm(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        recurrence: String,
        postedWhen: Long,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = escalateIntent(context, id, noteId, title, body, recurrence, postedWhen)
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

    /** Cancels the pending escalation for this occurrence. */
    fun cancel(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(escalateIntent(context, id, "", "", "", "", 0L))
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
    ): PendingIntent {
        val intent = Intent(context, FsiEscalationReceiver::class.java).apply {
            action = ACTION_ESCALATE
            putExtra("reminder_id", id)
            putExtra("note_id", noteId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("recurrence", recurrence)
            putExtra("posted_when", postedWhen)
        }
        return PendingIntent.getBroadcast(context, id, intent, pendingFlags())
    }

    private fun pendingFlags() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
}
