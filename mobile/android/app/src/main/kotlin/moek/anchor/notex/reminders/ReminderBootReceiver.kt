package moek.anchor.notex.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms every persisted reminder after a reboot or an app update. */
class ReminderBootReceiver : BroadcastReceiver() {
    companion object {
        private const val QUICKBOOT = "com.htc.intent.action.QUICKBOOT_POWERON"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            QUICKBOOT ->
                ReminderAlarmScheduler.rearmAll(context)
        }
    }
}