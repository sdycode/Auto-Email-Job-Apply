import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_apply/models.dart';
import 'package:quick_apply/screens/cover_letters_screen.dart';

void main() {
  testWidgets('CoverLetterCard expands to full text on Read more and shows Copy button',
      (tester) async {
    final longContent = List.generate(
      20,
      (i) => 'Line $i: This is a sentence in the cover letter describing relevant experience.',
    ).join('\n');

    final letter = CoverLetter(
      id: 'c1',
      title: 'Full Stack Flutter Developer',
      content: longContent,
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CoverLetterCard(
                letter: letter,
                onEdit: () {},
              ),
            ],
          ),
        ),
      ),
    );

    // Verify Title & Copy button exist
    expect(find.text('Full Stack Flutter Developer'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);

    // Verify initial "Read more / See all" is present
    expect(find.text('Read more / See all'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('Read more / See all'));
    await tester.pumpAndSettle();

    // Verify toggle switched to "Show less" and "Copy full text" appears
    expect(find.text('Show less'), findsOneWidget);
    expect(find.text('Copy full text'), findsOneWidget);

    // Drag to bring bottom into view
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // Tap to collapse
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('Read more / See all'), findsOneWidget);
  });
}
