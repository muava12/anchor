package moek.anchor.notex.reminders

import android.app.Activity
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.view.View
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils
import moek.anchor.notex.R
import java.util.Calendar

/**
 * Standalone snooze sheet (Doop "Reminder — Snooze picker (sheet flat)",
 * frame Wn02ojCMhA).
 *
 * Translucent, show-when-locked sibling of [FullScreenReminderActivity]:
 * re-schedules a fired reminder WITHOUT launching the app, via
 * [SnoozeScheduleHelper] (native re-arm + [PendingSnoozeStore] stash).
 * Launched with the FSI/banner extras (see [EXTRA_NOTE_ID] and friends).
 */
class SnoozeReminderActivity : Activity() {

    companion object {
        const val EXTRA_NOTE_ID = "note_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_RECURRANCE = "recurrence"
        const val EXTRA_NOTIFICATION_ID = "notification_id"

        private const val RECURRANCE_NONE = "none"
        private const val ALPHA_SCRIM_NIGHT = 153 // ~60% black
        private const val ALPHA_SCRIM_DAY = 92 // ~36% black
        private const val ALPHA_HANDLE = 97 // fsi_muted @ ~38%
        private const val ALPHA_SUBTLE = 15 // ~6% text on surface
        private const val ALPHA_BORDER = 31 // ~12% text on surface
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_snooze_reminder)
        // The sheet can be opened from the lock screen (banner/FSI snooze
        // action); keep it visible there too.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        val noteId = intent?.getStringExtra(EXTRA_NOTE_ID) ?: ""
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""
        val recurrence = intent?.getStringExtra(EXTRA_RECURRANCE)
            ?.takeIf { it.isNotBlank() } ?: RECURRANCE_NONE
        val notificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, 0) ?: 0

        paintScrimAndOptionBackgrounds()

        // Subtitle: "<title>" + " · repeats <recurrence>" when it recurs.
        val subtitle = findViewById<TextView>(R.id.snooze_subtitle)
        subtitle.text = buildString {
            if (title.isNotEmpty()) append(title)
            if (recurrence != RECURRANCE_NONE) {
                if (isNotEmpty()) append(" · ")
                append("repeats ").append(recurrence)
            }
        }
        subtitle.visibility = if (subtitle.text.isEmpty()) View.GONE else View.VISIBLE

        // The "1 day" chip only exists when the reminder recurs.
        findViewById<View>(R.id.chip_1day).visibility =
            if (recurrence != RECURRANCE_NONE) View.VISIBLE else View.GONE

        wireOptions(noteId, title, body, recurrence, notificationId)
    }

    private fun paintScrimAndOptionBackgrounds() {
        val night = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        findViewById<View>(R.id.snooze_scrim).setBackgroundColor(
            Color.argb(if (night) ALPHA_SCRIM_NIGHT else ALPHA_SCRIM_DAY, 0, 0, 0)
        )

        // Handle: 32×4dp rounded bar in fsi_muted @ ~38%.
        val handle = findViewById<View>(R.id.snooze_handle)
        handle.background = pill().apply {
            setColor(
                ColorUtils.setAlphaComponent(
                    ContextCompat.getColor(this@SnoozeReminderActivity, R.color.fsi_muted),
                    ALPHA_HANDLE
                )
            )
        }

        // Selected chip gets the 1.5dp accent border; default selection is
        // "1 hour". Unselected chips and the presets share the subtle fill
        // (presets add the 1dp border).
        val subtle = subtleColor()
        val accent = ContextCompat.getColor(this, R.color.fsi_accent)
        findViewById<View>(R.id.chip_1hour).background = pill().apply {
            setColor(subtle)
            setStroke(rounded(1.5f).toInt(), accent)
        }
        val unselectedChip = pill().apply { setColor(subtle) }
        for (id in listOf(R.id.chip_10min, R.id.chip_30min, R.id.chip_4hours, R.id.chip_1day)) {
            findViewById<View>(id).background = unselectedChip
        }
        for (id in listOf(R.id.preset_later_today, R.id.preset_tomorrow, R.id.preset_pick)) {
            findViewById<View>(id).background = roundedBox(subtle)
        }
    }

    private fun wireOptions(
        noteId: String,
        title: String,
        body: String,
        recurrence: String,
        notificationId: Int,
    ) {
        val context = this
        val snooze: (Long) -> Unit = { targetMillis ->
            SnoozeScheduleHelper.snooze(context, noteId, notificationId, title, body, recurrence, targetMillis)
            finish()
        }

        // Chips: now + minutes; the hidden "1 day" chip never binds.
        val chips = listOf(
            R.id.chip_10min to 10,
            R.id.chip_30min to 30,
            R.id.chip_1hour to 60,
            R.id.chip_4hours to 240,
            R.id.chip_1day to 1440,
        )
        chips.forEach { (viewId, minutes) ->
            val chip = findViewById<TextView>(viewId)
            if (chip.visibility == View.VISIBLE) {
                chip.setOnClickListener {
                    snooze(System.currentTimeMillis() + minutes * 60_000L)
                }
            }
        }

        val now = Calendar.getInstance()
        val laterToday = Calendar.getInstance().apply {
            time = now
            add(Calendar.HOUR_OF_DAY, 3)
            set(Calendar.MINUTE, (get(Calendar.MINUTE) + 4) / 5 * 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        findViewById<View>(R.id.preset_later_today).apply {
            // Hidden when the result lands on a different day.
            val sameDay =
                laterToday.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
                    laterToday.get(Calendar.MONTH) == now.get(Calendar.MONTH) &&
                    laterToday.get(Calendar.DAY_OF_MONTH) == now.get(Calendar.DAY_OF_MONTH)
            visibility = if (sameDay) View.VISIBLE else View.GONE
            setOnClickListener { snooze(laterToday.timeInMillis) }
        }

        val tomorrow = Calendar.getInstance().apply {
            time = now
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        findViewById<View>(R.id.preset_tomorrow).setOnClickListener {
            snooze(tomorrow.timeInMillis)
        }

        findViewById<View>(R.id.preset_pick).setOnClickListener {
            pickDateTime(noteId, notificationId, title, body, recurrence)
        }
    }

    /** Native date → time pickers, prefilled to now + 1h. */
    private fun pickDateTime(
        noteId: String,
        notificationId: Int,
        title: String,
        body: String,
        recurrence: String,
    ) {
        val prefill = Calendar.getInstance().apply { add(Calendar.HOUR_OF_DAY, 1) }
        DatePickerDialog(
            this,
            {
                _, year, month, day ->
                TimePickerDialog(
                    this,
                    { _, hour, minute ->
                        val target = Calendar.getInstance().apply {
                            set(year, month, day)
                            set(Calendar.HOUR_OF_DAY, hour)
                            set(Calendar.MINUTE, minute)
                            set(Calendar.SECOND, 0)
                            set(Calendar.MILLISECOND, 0)
                        }
                        SnoozeScheduleHelper.snooze(
                            this@SnoozeReminderActivity, noteId, notificationId, title, body, recurrence,
                            target.timeInMillis
                        )
                        finish()
                    },
                    prefill.get(Calendar.HOUR_OF_DAY),
                    prefill.get(Calendar.MINUTE),
                    DateFormat.is24HourFormat(this)
                ).show()
            },
            prefill.get(Calendar.YEAR),
            prefill.get(Calendar.MONTH),
            prefill.get(Calendar.DAY_OF_MONTH)
        ).show()
    }

    /** Subtle fill: ~6% of fsi_text over the surface. */
    private fun subtleColor(): Int =
        ColorUtils.setAlphaComponent(ContextCompat.getColor(this, R.color.fsi_text), ALPHA_SUBTLE)

    private fun roundedBox(fill: Int): GradientDrawable =
        GradientDrawable().apply {
            cornerRadius = rounded(10f)
            setColor(fill)
            setStroke(
                rounded(1f).toInt(),
                ColorUtils.setAlphaComponent(ContextCompat.getColor(this@SnoozeReminderActivity, R.color.fsi_text),
                    ALPHA_BORDER)
            )
        }

    private fun pill(): GradientDrawable =
        GradientDrawable().apply { cornerRadius = rounded(999f) }

    private fun rounded(dp: Float): Float = dp * resources.displayMetrics.density
}
