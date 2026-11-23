package moek.anchor.notex.reminders

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Mirrors the Dart scheduler's pending reminders so a reboot or an app update
 * can re-arm their exact alarms. The Dart side is the source of truth; this
 * store is rebuilt from its armReminder / cancelReminder / cancelAllReminders
 * calls.
 */
object ReminderAlarmStore {
    private const val PREFS = "reminder_alarms"
    private const val KEY = "reminders"

    /** Replaces the persisted set with [reminders]. */
    fun save(context: Context, reminders: List<Map<String, Any>>) {
        val arr = JSONArray()
        for (r in reminders) {
            arr.put(
                JSONObject()
                    .put("id", r["id"] as Int)
                    .put("noteId", r["noteId"] as String)
                    .put("title", r["title"] as String)
                    .put("body", r["body"] as String)
                    .put("atMillis", r["atMillis"] as Long)
                    .put("snoozeNoteId", r["snoozeNoteId"] as String)
                    .put("recurrence", r["recurrence"] as? String ?: "none")
                    .put("tag", r["tag"] as? String ?: "")
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }

    /** The persisted reminders, each a map with id/noteId/title/body/atMillis/snoozeNoteId/recurrence/tag. */
    fun load(context: Context): List<Map<String, Any>> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        val out = mutableListOf<Map<String, Any>>()
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                mapOf(
                    "id" to o.getInt("id"),
                    "noteId" to o.getString("noteId"),
                    "title" to o.getString("title"),
                    "body" to o.optString("body"),
                    "atMillis" to o.getLong("atMillis"),
                    "snoozeNoteId" to o.optString("snoozeNoteId"),
                    "recurrence" to o.optString("recurrence", "none"),
                    "tag" to o.optString("tag"),
                )
            )
        }
        return out
    }

    /** Replaces the entry with [id], or appends it. */
    fun upsert(context: Context, reminder: Map<String, Any>) {
        val id = reminder["id"] as Int
        val kept = load(context).filter { it["id"] != id }.toMutableList()
        kept.add(reminder)
        save(context, kept)
    }

    fun remove(context: Context, id: Int) {
        val current = load(context)
        val kept = current.filter { it["id"] != id }
        if (kept.size == current.size) return
        save(context, kept)
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY).apply()
    }
}