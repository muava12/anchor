package moek.anchor.notex.reminders

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import moek.anchor.notex.MainActivity
import moek.anchor.notex.R

/**
 * Builds and posts the reminder notification natively: ongoing, big text, and
 * native action buttons that reach [ReminderActionReceiver] even when the app
 * is closed (Done / Dismiss), with Snooze bringing the app to the front. The
 * full-screen and content intents point at [FullScreenReminderActivity] so
 * the reminder sheet shows on the lock screen and home screen.
 */
object ReminderNotificationBuilder {
    private const val CHANNEL_ID = "reminders"

    fun show(
        context: Context,
        id: Int,
        noteId: String,
        title: String,
        body: String,
        snoozeNoteId: String,
    ) {
        ensureChannel(context)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val flags = pendingFlags()

        // A plain tap opens the note in the app.
        val tap = Intent(context, MainActivity::class.java).apply {
            putExtra("open_note_id", noteId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val content = PendingIntent.getActivity(context, id, tap, flags)

        // Full-screen intent: the reminder sheet, so a heads-up lands on the
        // lock screen and home screen instead of just the shade.
        val sheet = Intent(context, FullScreenReminderActivity::class.java).apply {
            putExtra(FullScreenReminderActivity.EXTRA_NOTE_ID, noteId)
            putExtra(FullScreenReminderActivity.EXTRA_TITLE, title)
            putExtra(FullScreenReminderActivity.EXTRA_BODY, body)
            putExtra(ReminderActionReceiver.EXTRA_NOTIFICATION_ID, id)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val fullScreen = PendingIntent.getActivity(context, id * 2 + 1, sheet, flags)

        val snoozeNote = snoozeNoteId.ifEmpty { noteId }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setContentIntent(content)
            .setFullScreenIntent(fullScreen, true)
            .addAction(
                doneAction(context, id * 3 + 1, noteId, id)
            )
            .addAction(
                dismissAction(context, id * 3 + 2, noteId, id)
            )
            .addAction(
                snoozeAction(context, id * 3 + 3, snoozeNote)
            )
            .build()

        nm.notify(id, notification)
    }

    private fun doneAction(context: Context, code: Int, noteId: String, notificationId: Int): NotificationCompat.Action {
        val intent = Intent(context, ReminderActionReceiver::class.java).apply {
            action = ReminderActionReceiver.ACTION_DONE
            putExtra(ReminderActionReceiver.EXTRA_NOTE_ID, noteId)
            putExtra(ReminderActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val pi = PendingIntent.getBroadcast(context, code, intent, pendingFlags())
        return NotificationCompat.Action.Builder(0, context.getString(R.string.reminder_action_done), pi).build()
    }

    private fun dismissAction(context: Context, code: Int, noteId: String, notificationId: Int): NotificationCompat.Action {
        val intent = Intent(context, ReminderActionReceiver::class.java).apply {
            action = ReminderActionReceiver.ACTION_DISMISS
            putExtra(ReminderActionReceiver.EXTRA_NOTE_ID, noteId)
            putExtra(ReminderActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val pi = PendingIntent.getBroadcast(context, code, intent, pendingFlags())
        return NotificationCompat.Action.Builder(0, context.getString(R.string.reminder_action_dismiss), pi).build()
    }

    private fun snoozeAction(context: Context, code: Int, snoozeNoteId: String): NotificationCompat.Action {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("snooze_note_id", snoozeNoteId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pi = PendingIntent.getActivity(context, code, intent, pendingFlags())
        return NotificationCompat.Action.Builder(0, context.getString(R.string.reminder_action_snooze), pi).build()
    }

    private fun pendingFlags() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.reminder_channel_name),
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = context.getString(R.string.reminder_channel_description)
        channel.enableVibration(true)
        nm.createNotificationChannel(channel)
    }
}