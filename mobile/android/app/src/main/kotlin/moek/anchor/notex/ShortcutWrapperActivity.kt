package moek.anchor.notex

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Transparent trampoline for a launcher shortcut. It stashes the shortcut type
 * so the Flutter engine can drain it on resume, then brings MainActivity to the
 * front and finishes. The value lives in SharedPreferences, so it survives a
 * cold start (the trampoline runs before the Flutter engine is up).
 */
class ShortcutWrapperActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val shortcutType = intent?.getStringExtra("shortcut_type")
        if (!shortcutType.isNullOrEmpty()) {
            ShortcutLaunchChannel.stash(this, shortcutType)
        }
        val appIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(appIntent)
        finish()
    }
}