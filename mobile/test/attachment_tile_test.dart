import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/widgets/attachment_tile.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => AttachmentTile(
                width: AttachmentTile.height,
                appearance: NoteAppearance.of(context, null),
                deleteLabel: 'Remove',
                onDelete: () {},
                child: const ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the remove button pokes past the tile corner', (tester) async {
    await pump(tester);

    final tileTopLeft = tester.getTopLeft(find.byType(AttachmentTile));
    final buttonTopLeft = tester.getTopLeft(find.bySemanticsLabel('Remove'));
    // The button hangs half outside the top-right corner (Doop frame 7zq4fCi8lr:
    // top -5, right -4), so it overlaps the tile's rounded corner instead of
    // crowding the thumbnail.
    expect(buttonTopLeft.dy - tileTopLeft.dy, -5.0);
    final button = tester.getTopLeft(find.bySemanticsLabel('Remove'));
    final buttonRight = button.dx + tester.getSize(find.bySemanticsLabel('Remove')).width;
    expect(
      buttonRight -
          (tester.getTopLeft(find.byType(AttachmentTile)).dx +
              tester.getSize(find.byType(AttachmentTile)).width),
      4.0,
    );
  });
}
