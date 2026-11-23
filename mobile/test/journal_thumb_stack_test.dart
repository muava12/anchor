import 'dart:math' as math;

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_thumb_stack.dart';
import 'package:anchor/features/notes/data/repository/attachment_file_provider.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

List<NoteImagePreview> _pics(int count) => [
  for (var i = 0; i < count; i++)
    NoteImagePreview(attachmentId: 'a$i', noteId: 'n1', filename: '$i.jpg'),
];

Widget _wrapStack(List<NoteImagePreview> previews, Map<String, String> files) {
  return ProviderScope(
    overrides: [
      attachmentFileProvider.overrideWith(
        (ref, key) => files[key.attachmentId],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: JournalThumbStack(previews: previews)),
      ),
    ),
  );
}

void main() {
  testWidgets('a picture is 56, the size the token sets', (tester) async {
    expect(AnchorTokens.sizeJournalThumb, 56);

    await tester.pumpWidget(_wrapStack(_pics(1), const {'a0': '/tmp/pic.jpg'}));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(_filePathOf(image.image), '/tmp/pic.jpg');
    expect(tester.getSize(find.byType(Image)), const Size(56, 56));
  });

  testWidgets('a stack of three fans the back cards, no count badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapStack(_pics(3), const {
        'a0': '/tmp/a.jpg',
        'a1': '/tmp/b.jpg',
        'a2': '/tmp/c.jpg',
      }),
    );
    await tester.pump();

    // Every card in the stack is a real image, not a blank swatch.
    final paths = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => _filePathOf(image.image))
        .toList();
    expect(paths.length, 3);
    expect(paths.toSet(), {'/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg'});
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(tester.getSize(find.byWidget(image)), const Size(56, 56));
    }

    // The design fans the stack: the back cards rotate and fade. The tree
    // order is the furthest card first, then the middle one, then the front.
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.length, 3);
    expect(_angleAbove(tester, images[0]), closeTo(0.13, 1e-9));
    expect(_opacityAbove(tester, images[0]), closeTo(0.7, 1e-9));
    expect(_angleAbove(tester, images[1]), closeTo(-0.07, 1e-9));
    expect(_opacityAbove(tester, images[1]), closeTo(0.8, 1e-9));
    // The front card is square-on and solid.
    expect(_angleAbove(tester, images[2]), 0);
    expect(_opacityAbove(tester, images[2]), 1);

    // The stack carries no count badge.
    expect(find.text('3'), findsNothing);
    expect(find.byIcon(LucideIcons.image), findsNothing);
  });

  testWidgets('four pictures still stack three, with no count badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapStack(_pics(4), const {
        'a0': '/tmp/a.jpg',
        'a1': '/tmp/b.jpg',
        'a2': '/tmp/c.jpg',
        'a3': '/tmp/d.jpg',
      }),
    );
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(3));
    expect(find.text('4'), findsNothing);
    expect(find.byIcon(LucideIcons.image), findsNothing);
  });
}

/// The file path an [ImageProvider] draws, through any `cacheWidth` wrapper.
String _filePathOf(ImageProvider provider) {
  var current = provider;
  while (current is ResizeImage) {
    current = current.imageProvider;
  }
  return (current as FileImage).file.path;
}

/// The z-rotation above [image], in radians; 0 when nothing rotates it.
double _angleAbove(WidgetTester tester, Image image) {
  final finder = find.ancestor(
    of: find.byWidget(image),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) return 0;
  final matrix = tester.widget<Transform>(finder.first).transform;
  return math.atan2(matrix[1], matrix[0]);
}

/// The opacity above [image]; 1 when nothing fades it.
double _opacityAbove(WidgetTester tester, Image image) {
  final finder = find.ancestor(
    of: find.byWidget(image),
    matching: find.byType(Opacity),
  );
  if (finder.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(finder.first).opacity;
}
