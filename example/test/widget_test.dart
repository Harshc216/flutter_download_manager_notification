import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('Media Downloader App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const DownloadManagerApp());
    expect(find.text('Media Downloader'), findsOneWidget);
  });
}
