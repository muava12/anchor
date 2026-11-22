package moek.anchor.notex.reminders

import moek.anchor.notex.MainActivity
import moek.anchor.notex.R
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.TextView

/**
 * Full-screen intent activity for reminder notifications.
 *
 * Launched by the system when a reminder's full-screen intent fires
 * (locked screen, screen off, or after the heads-up auto-hides).
 * The activity is translucent so the home screen shows through;
 * it displays a bottom sheet with five flat action buttons.
 *
 * Close slides the sheet away and finishes the activity; the
 * sticky notification remains in the shade.
 */
class FullScreenReminderActivity : Activity() {

    companion object {
        const val EXTRA_NOTE_ID = "note_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_TAG = "tag"
        const val EXTRA_TIME = "time"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }

    private var sheetView: View? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_full_screen_reminder)

        // Let the home screen show through.
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)

        val noteId = intent?.getStringExtra(EXTRA_NOTE_ID) ?: ""
        val notificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, -1) ?: -1
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""
        val tag = intent?.getStringExtra(EXTRA_TAG) ?: ""
        val time = intent?.getStringExtra(EXTRA_TIME) ?: ""
        // Recurrence comes through the fire path: the receiver reads it from
        // the alarm extras and the builder puts it on the sheet intent. Blank
        // means "none" to the snooze sheet, which hides the repeating-only
        // chip and suffix.
        val recurrence = intent?.getStringExtra(SnoozeReminderActivity.EXTRA_RECURRANCE) ?: ""

        // Fill the header + body.
        val headerMeta = findViewById<TextView>(R.id.fsi_header_meta)
        headerMeta.text = "Anchor · $time · $tag".trimStart('·', ' ')

        val fsiTitle = findViewById<TextView>(R.id.fsi_title)
        fsiTitle.text = title

        val fsiBody = findViewById<TextView>(R.id.fsi_body)
        fsiBody.text = body
        fsiBody.visibility = if (body.isEmpty()) View.GONE else View.VISIBLE

        sheetView = findViewById(R.id.fsi_sheet)

        // Wire up the five action rows (icon + label LinearLayouts).
        findViewById<View>(R.id.btn_open_note).setOnClickListener {
            // Open note: bring the app to the front; Flutter opens the note.
            val appIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("open_note_id", noteId)
                // NEW_TASK | CLEAR_TOP matches the banner-tap intent: a
                // background launch reuses the task instead of stacking a
                // duplicate MainActivity; the extras reach onNewIntent.
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(appIntent)
            finish()
        }
        findViewById<View>(R.id.btn_mark_done).setOnClickListener {
            // Done: settle + drop the card + finish. Toast shown by the receiver.
            sendActionBroadcast(noteId, notificationId, ReminderActionReceiver.ACTION_DONE)
            finish()
        }
        findViewById<View>(R.id.btn_dismiss).setOnClickListener {
            // Dismiss: quiet this occurrence, drop the card, no toast.
            sendActionBroadcast(noteId, notificationId, ReminderActionReceiver.ACTION_DISMISS)
            finish()
        }
        findViewById<View>(R.id.btn_snooze).setOnClickListener {
            // Snooze: the standalone snooze sheet — no app launch.
            val snoozeIntent = Intent(this, SnoozeReminderActivity::class.java).apply {
                putExtra(SnoozeReminderActivity.EXTRA_NOTE_ID, noteId)
                putExtra(SnoozeReminderActivity.EXTRA_TITLE, title)
                putExtra(SnoozeReminderActivity.EXTRA_BODY, body)
                putExtra(SnoozeReminderActivity.EXTRA_RECURRANCE, recurrence)
                putExtra(SnoozeReminderActivity.EXTRA_NOTIFICATION_ID, notificationId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(snoozeIntent)
            finish()
        }
        findViewById<View>(R.id.btn_close).setOnClickListener {
            // Close: slide the sheet down, banner stays.
            finish()
        }
    }

    private fun sendActionBroadcast(noteId: String, notificationId: Int, action: String) {
        val intent = Intent(this, ReminderActionReceiver::class.java).apply {
            this.action = action
            putExtra(ReminderActionReceiver.EXTRA_NOTE_ID, noteId)
            putExtra(ReminderActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        sendBroadcast(intent)
    }
}
