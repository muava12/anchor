package moek.anchor.notex.reminders

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** One natively re-armed snooze that still has to reach the app. */
data class PendingSnooze(
    val noteId: String,
    val newAtMillis: Long,
    val recurrence: String,
)

/**
 * Stashes the snoozed reminders that [SnoozeScheduleHelper] re-armed
 * natively while the app was closed. The Dart reminder engine drains this
 * set on the next start and settles each occurrence for real (recurring
 * math, UI state).
 *
 * At most one entry per noteId: a later snooze of the same note replaces the
 * earlier one.
 */
object PendingSnoozeStore {
    private const val PREFS = "pending_snoozes"
    private const val KEY = "snoozes"

    /** Upserts the pending snooze for [noteId] (replacing any older one). */
    fun put(context: Context, noteId: String, newAtMillis: Long, recurrence: String) {
        val kept = load(context).filter { it.noteId != noteId }
        persist(context, kept + PendingSnooze(noteId, newAtMillis, recurrence))
    }

    /** Returns every pending snooze, then clears the stash. */
    fun drain(context: Context): List<PendingSnooze> {
        val out = load(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY).apply()
        return out
    }

    private fun load(context: Context): List<PendingSnooze> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        val out = mutableListOf<PendingSnooze>()
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                PendingSnooze(
                    noteId = o.getString("noteId"),
                    newAtMillis = o.getLong("newAtMillis"),
                    recurrence = o.optString("recurrence", "none"),
                )
            )
        }
        return out
    }

    private fun persist(context: Context, snoozes: List<PendingSnooze>) {
        val arr = JSONArray()
        for (p in snoozes) {
            arr.put(
                JSONObject()
                    .put("noteId", p.noteId)
                    .put("newAtMillis", p.newAtMillis)
                    .put("recurrence", p.recurrence)
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }
}
