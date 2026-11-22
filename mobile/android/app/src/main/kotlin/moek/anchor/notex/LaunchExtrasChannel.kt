package moek.anchor.notex

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Carries a native notification launch extra (snooze / open-note) to Flutter.
 *
 * [ReminderNotificationBuilder]'s Snooze and content intents open MainActivity
 * with a note id extra; MainActivity stashes it here so the Flutter engine can
 * drain it on cold start and on each resume and open the matching screen. The
 * value is cleared on read so a stale tap never reopens.
 */
class LaunchExtrasChannel(
    private val context: Context,
    channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val PREFS_NAME = "launch_extras"
        const val KEY_SNOOZE = "snooze_note_id"
        const val KEY_OPEN = "open_note_id"

        /** Records the launch extras MainActivity saw; no-op when both empty. */
        fun stash(context: Context, snoozeNoteId: String?, openNoteId: String?) {
            if (snoozeNoteId.isNullOrEmpty() && openNoteId.isNullOrEmpty()) return
            val edit = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            if (!snoozeNoteId.isNullOrEmpty()) edit.putString(KEY_SNOOZE, snoozeNoteId) else edit.remove(KEY_SNOOZE)
            if (!openNoteId.isNullOrEmpty()) edit.putString(KEY_OPEN, openNoteId) else edit.remove(KEY_OPEN)
            edit.apply()
        }

        /** Reads and clears the stashed extras; null when nothing is pending. */
        fun drainPending(context: Context): Map<String, String>? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val snooze = prefs.getString(KEY_SNOOZE, null)
            val open = prefs.getString(KEY_OPEN, null)
            if (snooze == null && open == null) return null
            prefs.edit().remove(KEY_SNOOZE).remove(KEY_OPEN).apply()
            return mutableMapOf<String, String>().apply {
                if (snooze != null) put("snoozeNoteId", snooze)
                if (open != null) put("openNoteId", open)
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "drainLaunchExtras" -> result.success(drainPending(context))
            else -> result.notImplemented()
        }
    }
}