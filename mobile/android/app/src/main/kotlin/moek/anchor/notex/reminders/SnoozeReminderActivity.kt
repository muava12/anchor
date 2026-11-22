package moek.anchor.notex.reminders

import android.app.Activity
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.StringRes
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils
import moek.anchor.notex.R

/**
 * Standalone snooze sheet (Doop "Reminder — Snooze picker (sheet flat)",
 * frame Wn02ojCMhA).
 *
 * Translucent, show-when-locked sibling of [FullScreenReminderActivity]:
 * re-schedules a fired reminder WITHOUT launching the app. Launched with
 * the FSI/banner extras (see [EXTRA_NOTE_ID] and friends).
 *
 * In this revision every option is a placeholder (toast + finish); the
 * native re-schedule logic — chips → [SnoozeScheduleHelper], presets →
 * date/time picker — lands in the follow-up task.
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

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val recurrence = intent?.getStringExtra(EXTRA_RECURRANCE)
            ?.takeIf { it.isNotBlank() } ?: RECURRANCE_NONE
        // EXTRA_NOTE_ID, EXTRA_BODY and EXTRA_NOTIFICATION_ID travel with
        // the intent for the re-schedule logic; the placeholder handlers
        // below only need title + recurrence.

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

        wireOptions()
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

    private fun wireOptions() {
        // Chips: skip the hidden "1 day" chip when the reminder is one-shot.
        val chips = listOf(
            R.id.chip_10min to R.string.snooze_chip_10min,
            R.id.chip_30min to R.string.snooze_chip_30min,
            R.id.chip_1hour to R.string.snooze_chip_1hour,
            R.id.chip_4hours to R.string.snooze_chip_4hours,
            R.id.chip_1day to R.string.snooze_chip_1day,
        )
        chips.forEach { (viewId, labelRes) ->
            val chip = findViewById<TextView>(viewId)
            if (chip.visibility == View.VISIBLE) {
                chip.setOnClickListener { onSelect(labelRes) }
            }
        }
        val presets = listOf(
            R.id.preset_later_today to R.string.snooze_preset_later_today,
            R.id.preset_tomorrow to R.string.snooze_preset_tomorrow,
            R.id.preset_pick to R.string.snooze_preset_pick,
        )
        presets.forEach { (viewId, labelRes) ->
            findViewById<View>(viewId).setOnClickListener { onSelect(labelRes) }
        }
    }

    /** Placeholder: the option's label toasts, then the sheet closes.
     * The real re-schedule (toast + snooze) replaces this body. */
    private fun onSelect(@StringRes labelRes: Int) {
        Toast.makeText(this, getString(labelRes), Toast.LENGTH_SHORT).show()
        finish()
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
