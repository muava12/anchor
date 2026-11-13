/// How much the app animates. The person picks one in Settings → Appearance.
enum MotionSpeed {
  /// Today's motion, unchanged.
  slow(1),

  /// The same motion, three tenths as long.
  fast(0.3),

  /// No motion: every animation lands at once.
  off(0);

  const MotionSpeed(this.scale);

  /// Multiplies a design duration. Zero means "no time at all".
  final double scale;

  /// The speed in force. Set at startup and when the person changes it, and
  /// read from code that has no `Ref` and no `BuildContext`.
  static MotionSpeed current = MotionSpeed.slow;
}
