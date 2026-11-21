package moek.anchor.notex.reminders

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.widget.Toast

/**
 * Receives reminder action intents (Done / Dismiss) fired from the
 * notification's action buttons while the app is in the background.
 *
 * Writes the action to SharedPreferences so the Flutter engine can drain
 * it on the next cold start. Done shows a brief toast; Dismiss is silent.
 */
class ReminderActionReceiver : android.content.BroadcastReceiver() {

    companion object {
        const val ACTION_DONE = "moek.anchor.notex.REMINDER_DONE"
        const val ACTION_DISMISS = "moek.anchor.notex.REMINDER_DISMISS"
        const val EXTRA_NOTE_ID = "note_id"
        const val PREFS_NAME = "reminder_actions"
        const val KEY_PENDING_NOTE_ID = "pending_note_id"
        const val KEY_PENDING_TYPE = "pending_type"

        /**
         * Reads and clears the pending action from SharedPreferences.
         * Returns a map with "noteId" and "type", or null when nothing is pending.
         */
        fun drainPending(context: Context): Map<String, String>? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val noteId = prefs.getString(KEY_PENDING_NOTE_ID, null) ?: return null
            val type = prefs.getString(KEY_PENDING_TYPE, "") ?: ""
            prefs.edit().remove(KEY_PENDING_NOTE_ID).remove(KEY_PENDING_TYPE).apply()
            return mapOf("noteId" to noteId, "type" to type)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        val noteId = intent.getStringExtra(EXTRA_NOTE_ID) ?: return
        val type = when (intent.action) {
            ACTION_DONE -> "done"
            ACTION_DISMISS -> "dismiss"
            else -> return
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_NOTE_ID, noteId)
            .putString(KEY_PENDING_TYPE, type)
            .apply()

        if (type == "done") {
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(context, "Selesai", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
