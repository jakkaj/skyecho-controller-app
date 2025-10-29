import 'package:flutter_test/flutter_test.dart';
import 'package:tactical_radar/main.dart';

void main() {
  testWidgets('app launches and renders config screen', (tester) async {
    // Arrange & Act
    await tester.pumpWidget(const TacticalRadarApp());
    await tester.pumpAndSettle();

    // Assert - app bar shows SkyEcho title
    expect(find.textContaining('SkyEcho'), findsOneWidget);

    // Save button exists
    expect(find.text('Save Configuration'), findsOneWidget);
  });
}
