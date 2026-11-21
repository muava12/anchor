package moek.anchor.notex.reminders

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel that creates a custom PendingIntent for a notification's
 * action button so the [ReminderActionReceiver] receives it in the background.
 *
 * Flutter calls [attachActionIntent] after the notification is posted;
 * the native side rebuilds the action's PendingIntent to target the
 * receiver with the note id and action type as extras.
 */
class ReminderActionChannel(
    private val context: Context,
    channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "drainPending" -> {
                val pending = ReminderActionReceiver.drainPending(context)
                result.success(pending)
            }
            else -> result.notImplemented()
        }
    }
}
