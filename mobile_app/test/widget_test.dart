import 'package:flutter_test/flutter_test.dart';
import 'package:library_management/main.dart';

void main() {
  testWidgets('App loads MyLibbook LoginScreen properly', (WidgetTester tester) async {
    await tester.pumpWidget(const LibraryApp());
    await tester.pumpAndSettle();
    expect(find.text('MyLibbook'), findsWidgets);
    expect(find.text('Smart. Organized. Knowledge.'), findsOneWidget);
    expect(find.text('Secure Login'), findsOneWidget);
  });
}
