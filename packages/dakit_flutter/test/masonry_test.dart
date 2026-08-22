import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MasonryGridView lays out and scrolls without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: 24,
            itemBuilder: (context, index) => Container(
              height: 50.0 + (index % 3) * 40.0,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Container), findsWidgets);

    // Scroll down and back to exercise leading/trailing child collection.
    await tester.drag(find.byType(MasonryGridView), const Offset(0, -800));
    await tester.pump();
    await tester.drag(find.byType(MasonryGridView), const Offset(0, 800));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MasonryGridView.extent derives the column count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasonryGridView.count(
            crossAxisCount: 3,
            itemCount: 9,
            itemBuilder: (context, index) =>
                Container(height: 80, color: Colors.green),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
