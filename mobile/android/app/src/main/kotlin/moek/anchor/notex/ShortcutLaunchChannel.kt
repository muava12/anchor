package moek.anchor.notex

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Carries a launcher-shortcut tap from the native trampoline to Flutter.
 *
 * [ShortcutWrapperActivity] stashes the shortcut type here; the Flutter engine
 * drains it on cold start and on each resume, then opens the matching route.
 * The value is cleared on read so a stale tap never reopens.
 */
class ShortcutLaunchChannel(
    private val context: Context,
    channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val PREFS_NAME = "shortcuts"
        const val KEY_PENDING = "pending_shortcut_type"

        /** Records the shortcut type the trampoline was launched with. */
        fun stash(context: Context, shortcutType: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING, shortcutType)
                .apply()
        }

        /** Reads and clears the stashed shortcut type, or null when empty. */
        fun drainPending(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val type = prefs.getString(KEY_PENDING, null) ?: return null
            prefs.edit().remove(KEY_PENDING).apply()
            return type
        }
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "drainShortcut" -> result.success(drainPending(context))
            else -> result.notImplemented()
        }
    }
}