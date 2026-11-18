import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

import '../../domain/journal_meta.dart';

/// A journal mood, drawn as its full-colour Wangcai face.
///
/// The faces ship in full colour and are not tinted: the surrounding
/// container supplies any accent, the face keeps its own palette.
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.mood, this.size = 20});

  final JournalMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      mood.asset,
      width: size,
      height: size,
      semanticsLabel: mood.name,
    );
  }
}