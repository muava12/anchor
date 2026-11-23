package moek.anchor.notex.reminders

import moek.anchor.notex.MainActivity
import moek.anchor.notex.R
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.animation.PathInterpolator
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
        const val EXTRA_NOTIFICATION_ID = "notification_id"

        /**
         * Shared sheet intent: the extras every reminder sheet needs, in
         * one place, so the notification builder, a future re-fire path
         * (escalation), and the activity itself agree on the format.
         */
        fun buildIntent(
            context: Context,
            noteId: String,
            title: String,
            body: String,
            notificationId: Int,
            recurrence: String,
        ): Intent = Intent(context, FullScreenReminderActivity::class.java).apply {
            putExtra(EXTRA_NOTE_ID, noteId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(SnoozeReminderActivity.EXTRA_RECURRANCE, recurrence)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    private var sheetView: View? = null
    private var enterAnimator: ValueAnimator? = null

    // Bound from the launching (or re-launching) intent; read by the click
    // listeners so `onNewIntent` can rebind a second, later reminder.
    private var noteId = ""
    private var notificationId = -1
    private var title = ""
    private var body = ""
    private var recurrence = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_full_screen_reminder)

        // Let the home screen show through.
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)

        bind(intent)

        sheetView = findViewById(R.id.fsi_sheet)

        // Slide up on entry, per the design motion guide (standard easing).
        findViewById<View>(R.id.fsi_sheet).post { if (isFinishing) finish() else slideSheetUp() }

        // Wire up the five action rows (icon + label LinearLayouts).
        findViewById<View>(R.id.btn_open_note).setOnClickListener {
            // Open note: bring the app to the front; Flutter opens the note.
            val appIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("open_note_id", noteId)
                // The notification id lets MainActivity cancel the
                // escalation armed for this occurrence.
                putExtra(ReminderActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
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
            slideDownAndFinish()
        }
        findViewById<View>(R.id.btn_dismiss).setOnClickListener {
            // Dismiss: quiet this occurrence, drop the card, no toast.
            sendActionBroadcast(noteId, notificationId, ReminderActionReceiver.ACTION_DISMISS)
            slideDownAndFinish()
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
            slideDownAndFinish()
        }
    }

    override fun onStart() {
        super.onStart()
        ReminderSheetState.shown()
    }

    override fun onStop() {
        ReminderSheetState.hidden()
        super.onStop()
    }

    /**
     * `singleInstance`: a second reminder that fires while the sheet is
     * open is delivered here instead of stacking. Rebind the text and
     * the fields the action rows read; the enter animation does not
     * re-run (it was posted once from `onCreate`).
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    /**
     * Fill the header + body and store the extras the click rows use.
     * Recurrence comes through the fire path: the receiver reads it from
     * the alarm extras and the builder puts it on the sheet intent. Blank
     * means "none" to the snooze sheet, which hides the repeating-only
     * chip and suffix.
     */
    private fun bind(intent: Intent) {
        noteId = intent.getStringExtra(EXTRA_NOTE_ID) ?: ""
        notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        title = intent.getStringExtra(EXTRA_TITLE) ?: ""
        body = intent.getStringExtra(EXTRA_BODY) ?: ""
        recurrence = intent.getStringExtra(SnoozeReminderActivity.EXTRA_RECURRANCE) ?: ""

        findViewById<TextView>(R.id.fsi_header_meta).text = "Anchor"
        findViewById<TextView>(R.id.fsi_title).text = title
        val fsiBody = findViewById<TextView>(R.id.fsi_body)
        fsiBody.text = body
        fsiBody.visibility = if (body.isEmpty()) View.GONE else View.VISIBLE
    }

    private fun slideSheetUp() {
        val sheet = sheetView ?: return
        sheet.translationY = sheet.height.toFloat()
        enterAnimator = ValueAnimator.ofFloat(1f, 0f).apply {
            duration = 300
            interpolator = PathInterpolator(0.2f, 0.7f, 0.2f, 1f)
            addUpdateListener { sheet.translationY = (it.animatedValue as Float) * sheet.height }
            start()
        }
    }

    /** Slide the sheet down, then finish (Done / Dismiss / Close). */
    private fun slideDownAndFinish() {
        val sheet = sheetView
        enterAnimator?.cancel()
        if (sheet == null) {
            finish()
            return
        }
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 280
            interpolator = PathInterpolator(0.5f, 0f, 0.8f, 0.4f)
            addUpdateListener { sheet.translationY = (it.animatedValue as Float) * sheet.height }
            addListener(
                object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        finish()
                    }
                }
            )
            start()
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
