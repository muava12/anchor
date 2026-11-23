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
 *   Flick speed is estimated over a rolling window of the most recent move
 *   samples spanning at least [MIN_WINDOW_MS] (any refresh rate); the
 *   platform [VelocityTracker] is not used because
 *   `android.os.VelocityTracker` does not resolve on this project's CI
 *   Kotlin classpath, although sibling `android.os` classes do.
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
    // Rolling move-sample window (rawY, eventTime) for the flick estimate.
    private val samples = ArrayDeque<Pair<Float, Long>>()

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
                    samples.clear()
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
                    recordSample(event) // count the final segment too
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

    private fun recordSample(event: MotionEvent) {
        samples.addLast(event.rawY to event.eventTime)
        while (samples.size > MAX_SAMPLES) samples.removeFirst()
    }

    /**
     * Downward release speed in dp/s (+Y is down). Measured between the
     * newest sample and the newest sample at least [MIN_WINDOW_MS] older, so
     * the window is ~30-50 ms at any refresh rate and never collapses to a
     * single frame gap; if the whole span is shorter, it is used as-is.
     */
    private fun downVelocityDpPerS(): Float {
        if (samples.size < 2) return 0f
        val (lastY, lastTime) = samples.last()
        var refY = samples.first().first
        var refTime = samples.first().second
        for (i in samples.size - 1 downTo 0) {
            val (y, t) = samples[i]
            if (lastTime - t >= MIN_WINDOW_MS) {
                refY = y
                refTime = t
                break
            }
        }
        val dtMs = lastTime - refTime
        if (dtMs <= 0L) return 0f
        val pxPerMs = (lastY - refY) / dtMs
        return pxPerMs * 1000f / density
    }

    /** Slide the sheet off-screen, fade the scrim, then run [onDismissed]. */
    private fun dismiss() {
        animating = true
        sheet.animate()
            .translationY(sheet.height.toFloat())
            .setDuration(DISMISS_MS)
            .setInterpolator(PathInterpolator(0.5f, 0f, 0.8f, 0.4f))
            .setListener(
                object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        onDismissed()
                        animating = false
                    }
                }
            )
            .start()
        // The scrim animation has no listener: [animating] is cleared by the
        // sheet animation's end listener so a drag cannot start until the
        // slide-out fully finishes.
        scrim.animate()
            .alpha(0f)
            .setDuration(DISMISS_MS)
            .setInterpolator(PathInterpolator(0.5f, 0f, 0.8f, 0.4f))
            .start()
    }

    /** Animate the sheet back up; restore the scrim alpha on completion. */
    private fun springBack() {
        if (animating) return
        // Already at rest (e.g. two-finger tap with no drag): nothing to do.
        if (sheet.translationY < AT_REST_EPSILON && scrim.alpha >= baseScrimAlpha - AT_REST_EPSILON) {
            return
        }
        animating = true
        sheet.animate()
            .translationY(0f)
            .setDuration(SPRING_MS)
            .setInterpolator(PathInterpolator(0.2f, 0.7f, 0.2f, 1f))
            .setListener(
                object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        scrim.alpha = baseScrimAlpha
                        animating = false
                    }
                }
            )
            .start()
        scrim.animate()
            .alpha(baseScrimAlpha)
            .setDuration(SPRING_MS)
            .setInterpolator(PathInterpolator(0.2f, 0.7f, 0.2f, 1f))
            .start()
    }

    private companion object {
        const val DISMISS_PROGRESS = 0.25f
        const val DISMISS_VELOCITY_DP_PER_S = 1000f
        const val DISMISS_MS = 280L
        const val SPRING_MS = 200L
        private const val MIN_WINDOW_MS = 30L
        private const val MAX_SAMPLES = 32
        private const val AT_REST_EPSILON = 0.001f
    }
}
