package moek.anchor.notex.reminders

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.annotation.SuppressLint
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.PathInterpolator
import kotlin.math.max

/**
 * Makes a bottom-anchored sheet [sheet] draggable down-to-dismiss via a
 * [dragZone] touch area.
 *
 * - Dragging the zone translates [sheet] down and fades [scrim] in step.
 * - Release dismisses (slide-out, then [onDismissed]) when the sheet is
 *   more than [DISMISS_PROGRESS] of its height down, or when the release
 *   flick exceeds [DISMISS_VELOCITY_DP_PER_S]; otherwise it springs back.
 *   Flick speed is estimated from the two most recent move samples; the
 *   platform VelocityTracker is not available on this build's classpath.
 * - [MotionEvent.ACTION_CANCEL] and a second pointer always spring back.
 * - While a spring/dismiss animation runs, touches are ignored.
 *
 * Drag-close is a plain close (same as the sheet's Cancel button): the
 * caller's [onDismissed] decides what happens; no re-scheduling.
 */
class SheetDragHelper(
    private val sheet: View,
    private val scrim: View,
    private val dragZone: View,
    private val onDismissed: () -> Unit,
) {
    private val slopPx = ViewConfiguration.get(dragZone.context).scaledTouchSlop
    private val density = dragZone.resources.displayMetrics.density

    private var baseTranslationY = 0f
    private var baseScrimAlpha = 1f
    private var downRawY = 0f
    private var dragging = false
    private var animating = false
    // Two most recent move samples for the release-flick estimate.
    private var prevRawY = 0f
    private var prevTime = 0L
    private var lastRawY = 0f
    private var lastTime = 0L
    private var hasSamples = false

    @SuppressLint("ClickableViewAccessibility")
    fun attach() {
        baseScrimAlpha = scrim.alpha
        dragZone.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    if (animating) return@setOnTouchListener false
                    baseTranslationY = sheet.translationY
                    downRawY = event.rawY
                    dragging = false
                    hasSamples = false
                    true
                }

                MotionEvent.ACTION_POINTER_DOWN -> {
                    // Two pointers: abandon the drag, spring back.
                    springBack()
                    false
                }

                MotionEvent.ACTION_MOVE -> {
                    if (!dragging && event.rawY - downRawY > slopPx) {
                        dragging = true
                        downRawY -= slopPx
                        sheet.parent?.requestDisallowInterceptTouchEvent(true)
                    }
                    if (dragging) {
                        val offset = max(0f, baseTranslationY + (event.rawY - downRawY))
                        sheet.translationY = offset
                        scrim.alpha = baseScrimAlpha * (1f - offset / sheet.height)
                    }
                    recordSample(event)
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (!dragging) return@setOnTouchListener true
                    dragging = false
                    val pastThreshold = sheet.translationY > sheet.height * DISMISS_PROGRESS
                    val fastFlick = downVelocityDpPerS() > DISMISS_VELOCITY_DP_PER_S
                    if (pastThreshold || fastFlick) {
                        dismiss()
                    } else {
                        springBack()
                    }
                    true
                }

                else -> {
                    // ACTION_CANCEL and friends: spring back.
                    if (dragging) {
                        dragging = false
                        springBack()
                    }
                    false
                }
            }
        }
    }

    /** Slide the sheet off-screen, fade the scrim, then run [onDismissed]. */
    private fun dismiss() {
        animating = true
        sheet.animate()
            .translationY(sheet.height.toFloat())
            .setDuration(DISMISS_MS)
            .setInterpolator(PathInterpolator(0.5f, 0f, 0.8f, 0.4f))
            .setListener(endListener {
                scrim.alpha = 0f
                onDismissed()
            })
            .start()
        scrim.animate()
            .alpha(0f)
            .setDuration(DISMISS_MS)
            .setInterpolator(PathInterpolator(0.5f, 0f, 0.8f, 0.4f))
            .setListener(endListener { animating = false })
            .start()
    }

    /** Animate the sheet back up; clear the scrim fade on completion. */
    private fun springBack() {
        if (animating) return
        animating = true
        sheet.animate()
            .translationY(0f)
            .setDuration(SPRING_MS)
            .setInterpolator(PathInterpolator(0.2f, 0.7f, 0.2f, 1f))
            .setListener(endListener { scrim.alpha = baseScrimAlpha })
            .start()
        scrim.animate()
            .alpha(baseScrimAlpha)
            .setDuration(SPRING_MS)
            .setInterpolator(PathInterpolator(0.2f, 0.7f, 0.2f, 1f))
            .setListener(endListener { animating = false })
            .start()
    }

    private fun recordSample(event: MotionEvent) {
        prevRawY = lastRawY
        prevTime = lastTime
        lastRawY = event.rawY
        lastTime = event.eventTime
        hasSamples = true
    }

    /**
     * Downward release speed in dp/s, estimated over the two most recent
     * move samples (+Y is down). ~1000 dp/s matches the dismiss flick.
     */
    private fun downVelocityDpPerS(): Float {
        if (!hasSamples) return 0f
        val dtMs = lastTime - prevTime
        if (dtMs < MIN_SAMPLE_DT_MS) return 0f
        val pxPerMs = (lastRawY - prevRawY) / dtMs
        return pxPerMs * 1000f / density
    }

    private fun endListener(onEnd: () -> Unit) =
        object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) = onEnd()
        }

    private companion object {
        const val DISMISS_PROGRESS = 0.25f
        const val DISMISS_VELOCITY_DP_PER_S = 1000f
        const val DISMISS_MS = 280L
        const val SPRING_MS = 200L
        const val MIN_SAMPLE_DT_MS = 8L
    }
}
