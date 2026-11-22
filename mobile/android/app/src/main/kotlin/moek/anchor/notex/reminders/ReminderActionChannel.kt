package moek.anchor.notex.reminders

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel between the Flutter reminder engine and the native reminder
 * stack.
 *
 * - [drainPending] reads a Done/Dismiss press that reached
 *   [ReminderActionReceiver] while the app was closed.
 * - [armReminder] / [cancelReminder] / [cancelAllReminders] drive the native
 *   exact-alarm scheduler so a reminder rings even with the app not running.
 * - [pendingReminders] reports the native pending set, so a reconcile can find
 *   and cancel orphans the way it did for the plugin.
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

            "armReminder" -> {
                val id = call.argument<Int>("id") ?: 0
                val noteId = call.argument<String>("noteId") ?: ""
                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                val atMillis = call.argument<Long>("atMillis") ?: 0L
                val snoozeNoteId = call.argument<String>("snoozeNoteId") ?: ""
                ReminderAlarmStore.upsert(
                    context,
                    mapOf(
                        "id" to id,
                        "noteId" to noteId,
                        "title" to title,
                        "body" to body,
                        "atMillis" to atMillis,
                        "snoozeNoteId" to snoozeNoteId,
                    )
                )
                ReminderAlarmScheduler.arm(context, id, noteId, title, body, atMillis, snoozeNoteId)
                result.success(true)
            }

            "cancelReminder" -> {
                val id = call.argument<Int>("id") ?: 0
                ReminderAlarmScheduler.cancel(context, id)
                ReminderAlarmStore.remove(context, id)
                result.success(true)
            }

            "cancelAllReminders" -> {
                ReminderAlarmScheduler.cancelAll(context)
                result.success(true)
            }

            "pendingReminders" -> {
                val map = LinkedHashMap<Int, Long>()
                for (r in ReminderAlarmStore.load(context)) {
                    map[r["id"] as Int] = r["atMillis"] as Long
                }
                result.success(map)
            }

            else -> result.notImplemented()
        }
    }
}