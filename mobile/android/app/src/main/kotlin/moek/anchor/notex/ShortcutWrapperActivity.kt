package moek.anchor.notex

import android.content.Intent
import android.os.Bundle

/**
 * Transparent trampoline that receives a launcher-shortcut intent
 * and forwards it to the Flutter engine as a deep-link extra.
 * Finishes immediately so the user lands on the Flutter screen.
 */
class ShortcutWrapperActivity : MainActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Forward the shortcut_type extra so the Flutter router
        // can open the right create form.
        val shortcutType = intent?.getStringExtra("shortcut_type") ?: ""
        intent.putExtra("flutter_shortcut", shortcutType)
        super.onCreate(savedInstanceState)
        finish()
    }
}
