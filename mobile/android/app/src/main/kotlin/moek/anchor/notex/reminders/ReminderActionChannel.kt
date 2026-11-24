package moek.anchor.notex.reminders

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel between the Flutter reminder engine and the native reminder
 * stack.
 *
 * - [drainPending] reads a Done/Dismiss press that reached
 *   [ReminderActionReceiver] while the app was closed.
 * - [drainPendingSnoozes] empties the [PendingSnoozeStore] so the app can
 *   apply the natively snoozed times to its database on the next start.
 * - [armReminder] / [cancelReminder] / [cancelAllReminders] drive the native
 *   exact-alarm scheduler so a reminder rings even with the app not running.
 * - [pendingReminders] reports the native pending set, so a reconcile can find
 *   and cancel orphans the way it did for the plugin.
 * - [canDrawOverlays] / [openOverlaySettings] probe the overlay-permission
 *   state so the Dart side can explain the escalation permission.
 * - [canUseFullScreenIntent] reports whether full-screen intents can fire on
 *   this device; below SDK 34 the OS decides nothing up front, so it reads
 *   as usable.
 * - [sdkInt] returns the running Android SDK number.
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

            "drainPendingSnoozes" -> {
                val pending = PendingSnoozeStore.drain(context).map {
                    mapOf(
                        "noteId" to it.noteId,
                        "newAtMillis" to it.newAtMillis,
                        "recurrence" to it.recurrence,
                    )
                }
                result.success(pending)
            }

            "armReminder" -> {
                val id = call.argument<Int>("id") ?: 0
                val noteId = call.argument<String>("noteId") ?: ""
                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                val atMillis = call.argument<Long>("atMillis") ?: 0L
                val snoozeNoteId = call.argument<String>("snoozeNoteId") ?: ""
                val recurrence = call.argument<String>("recurrence") ?: "none"
                val tag = call.argument<String>("tag") ?: ""
                ReminderAlarmStore.upsert(
                    context,
                    mapOf(
                        "id" to id,
                        "noteId" to noteId,
                        "title" to title,
                        "body" to body,
                        "atMillis" to atMillis,
                        "snoozeNoteId" to snoozeNoteId,
                        "recurrence" to recurrence,
                        "tag" to tag,
                    )
                )
                ReminderAlarmScheduler.arm(context, id, noteId, title, body, atMillis, snoozeNoteId, recurrence, tag)
                result.success(true)
            }

            "cancelReminder" -> {
                val id = call.argument<Int>("id") ?: 0
                ReminderAlarmScheduler.cancel(context, id)
                FsiEscalationScheduler.cancel(context, id)
                ReminderAlarmStore.remove(context, id)
                result.success(true)
            }

            "cancelAllReminders" -> {
                ReminderAlarmScheduler.cancelAll(context)
                FsiEscalationScheduler.cancelAllActive(context)
                result.success(true)
            }

            "pendingReminders" -> {
                val map = LinkedHashMap<Int, Long>()
                for (r in ReminderAlarmStore.load(context)) {
                    map[r["id"] as Int] = r["atMillis"] as Long
                }
                result.success(map)
            }

            "canDrawOverlays" -> {
                result.success(Settings.canDrawOverlays(context))
            }

            "openOverlaySettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + context.packageName),
                )
                context.startActivity(intent)
                result.success(true)
            }

            "canUseFullScreenIntent" -> {
                val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    val notifications =
                        context.getSystemService(NotificationManager::class.java)
                    notifications.canUseFullScreenIntent()
                } else {
                    true
                }
                result.success(can)
            }

            "sdkInt" -> {
                result.success(Build.VERSION.SDK_INT)
            }

            else -> result.notImplemented()
        }
    }
}