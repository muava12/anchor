package moek.anchor.notex.reminders

import java.util.concurrent.atomic.AtomicInteger

/**
 * Tracks how many reminder sheet activities are currently visible:
 * [FullScreenReminderActivity] and [SnoozeReminderActivity] call
 * [shown] from `onStart` and [hidden] from `onStop`.
 *
 * Thread-safe: the counter is an [AtomicInteger], so the fire receiver
 * (a background thread, Task 3 escalation) can read [anyVisible]
 * concurrently with the main thread mutating it.
 *
 * Process-lifetime state: Task 3 reads [anyVisible] to decide whether
 * a new reminder that fires while a sheet is open should escalate it
 * instead of stacking another sheet.
 */
object ReminderSheetState {
    private val visibleSheets = AtomicInteger(0)

    /** A sheet activity entered the foreground (its `onStart`). */
    fun shown() {
        visibleSheets.incrementAndGet()
    }

    /** A sheet activity left the foreground (its `onStop`). */
    fun hidden() {
        visibleSheets.decrementAndGet()
    }

    /** True when at least one reminder sheet is visible. */
    val anyVisible: Boolean
        get() = visibleSheets.get() > 0
}
