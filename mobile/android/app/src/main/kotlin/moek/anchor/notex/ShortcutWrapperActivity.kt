package moek.anchor.notex

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Transparent trampoline that receives a launcher-shortcut intent
 * and forwards it to the Flutter engine as a deep-link extra.
 * Finishes immediately so the user lands on the Flutter screen.
 */
class ShortcutWrapperActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val shortcutType = intent?.getStringExtra("shortcut_type") ?: ""
        val appIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("flutter_shortcut", shortcutType)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(appIntent)
        finish()
    }
}
