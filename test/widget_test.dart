import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neki/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NekiApp()),
    );

    // The splash screen should be showing "NEki"
    expect(find.text('NEki'), findsOneWidget);
  });
}
