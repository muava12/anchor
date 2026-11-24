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

    final tile = tester.getRect(find.byType(AttachmentTile));
    final knob = tester.getRect(find.byKey(AttachmentTile.removeKnobKey));

    // The 24 dp circle hangs 8 dp past the top and the right edge, so the
    // corner of the picture shows through the ring of the button. The touch
    // target is 44 dp and is centred on the circle, so its offset is 18 dp.
    expect(knob.size, const Size(24, 24));
    expect(knob.top, tile.top - 8);
    expect(knob.right, tile.right + 8);
  });

  testWidgets('the knob is not clipped by the tile', (tester) async {
    await pump(tester);

    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(AttachmentTile),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.clipBehavior, Clip.none);
  });

  testWidgets('the remove button keeps a 44 dp touch target', (tester) async {
    await pump(tester);

    expect(
      tester.getSize(find.bySemanticsLabel('Remove')),
      const Size(44, 44),
    );
  });
}
