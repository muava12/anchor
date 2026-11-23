package moek.anchor.notex.reminders

/**
 * Tracks how many reminder sheet activities are currently visible:
 * [FullScreenReminderActivity] and [SnoozeReminderActivity] call
 * [shown] from `onStart` and [hidden] from `onStop`.
 *
 * Process-lifetime state: Task 3 (escalation) reads [anyVisible] to
 * decide whether a new reminder that fires while a sheet is open should
 * escalate it instead of stacking another sheet.
 */
object ReminderSheetState {
    @Volatile
    private var visibleSheets = 0

    /** A sheet activity entered the foreground (its `onStart`). */
    fun shown() {
        visibleSheets++
    }

    /** A sheet activity left the foreground (its `onStop`). */
    fun hidden() {
        visibleSheets--
    }

    /** True when at least one reminder sheet is visible. */
    val anyVisible: Boolean
        get() = visibleSheets > 0
}
