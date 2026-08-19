import 'package:flutter_test/flutter_test.dart';
import 'package:library_management/main.dart';

void main() {
  testWidgets('App loads LoginScreen properly', (WidgetTester tester) async {
    await tester.pumpWidget(const LibraryApp());
    expect(find.text('Library Hub'), findsOneWidget);
  });
}
