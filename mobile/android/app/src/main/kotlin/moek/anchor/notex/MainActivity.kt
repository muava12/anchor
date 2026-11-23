package moek.anchor.notex

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import moek.anchor.notex.backup.BackupFolderPlugin
import moek.anchor.notex.photos.PhotoConverterPlugin
import moek.anchor.notex.share.ShareFolderPlugin
import moek.anchor.notex.reminders.ReminderActionChannel
import moek.anchor.notex.widget.NotesWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity, not FlutterActivity: local_auth shows the biometric
// prompt through a fragment, and it fails on a plain activity.
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        attachWidgetNoteUri(intent)
        stashLaunchExtras(intent)
        super.onCreate(savedInstanceState)
        preferFastestRefreshRate()
        // Talks to the launcher, which takes a moment: not while starting up.
        Thread(::publishShortcuts).start()
    }

    override fun onNewIntent(intent: Intent) {
        attachWidgetNoteUri(intent)
        stashLaunchExtras(intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BackupFolderPlugin())
        flutterEngine.plugins.add(PhotoConverterPlugin())
        flutterEngine.plugins.add(ShareFolderPlugin(listens = true))
        ReminderActionChannel(
            this,
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moek.anchor.notex/reminder_actions"),
        )
        LaunchExtrasChannel(
            this,
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moek.anchor.notex/launch_extras"),
        )
        // FlutterFragmentActivity has no popSystemNavigator hook, so the back
        // arrow at the root of a folder asks for this instead of finishing.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "moek.anchor.notex/system",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> result.success(moveTaskToBack(true))
                else -> result.notImplemented()
            }
        }
    }

    private fun preferFastestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay)
            ?: return
        val current = display.mode
        val fastest = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        window.attributes = window.attributes.apply { preferredDisplayModeId = fastest.modeId }
    }

    // home_widget reads the launch target only from the intent's data URI.
    private fun attachWidgetNoteUri(intent: Intent?) {
        if (intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) return
        if (intent.data != null) return
        val noteId = intent.getStringExtra(NotesWidgetProvider.EXTRA_NOTE_ID) ?: return
        intent.data = Uri.parse("${NotesWidgetProvider.URI_SCHEME}://note/$noteId")
    }

    // A native reminder's Snooze / content intent opens MainActivity with a note
    // id; stash it so the Flutter engine can open the snooze picker or the note.
    private fun stashLaunchExtras(intent: Intent?) {
        val snooze = intent?.getStringExtra("snooze_note_id")
        val open = intent?.getStringExtra("open_note_id")
        if (!snooze.isNullOrEmpty() || !open.isNullOrEmpty()) {
            LaunchExtrasChannel.stash(this, snooze, open)
        }
    }

    /**
     * The launcher's long-press menu: quick actions. They are dynamic so they
     * target this app's package, and they launch like the widget's buttons,
     * which home_widget hands to the Flutter side on cold and warm starts.
     */
    private fun publishShortcuts() {
        if (Build.VERSION.SDK_INT < 25) return
        try {
            val manager = getSystemService(ShortcutManager::class.java) ?: return
            fun shortcut(id: String, label: String, uri: String, icon: Int) =
                ShortcutInfo.Builder(this, id)
                    .setShortLabel(label)
                    .setLongLabel(label)
                    .setIcon(Icon.createWithResource(this, icon))
                    .setIntent(
                        Intent(this, MainActivity::class.java)
                            .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                            .setData(Uri.parse(uri))
                            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    )
                    .build()
            val scheme = NotesWidgetProvider.URI_SCHEME
            manager.setDynamicShortcuts(listOf(
                shortcut("new_note", getString(R.string.shortcut_new_note), "$scheme://note/new", R.drawable.ic_shortcut_note),
                shortcut("new_journal", getString(R.string.shortcut_new_journal), "$scheme://journal/new", R.drawable.ic_shortcut_journal),
                shortcut("new_checklist", getString(R.string.shortcut_new_checklist), "$scheme://note/new?checklist=1", R.drawable.ic_shortcut_checklist),
            ))
        } catch (e: Exception) {
            android.util.Log.w("AnchorShortcuts", "Couldn't publish app shortcuts", e)
        }
    }
}
