import 'package:flutter_test/flutter_test.dart';
import 'package:tactical_radar/main.dart';

void main() {
  testWidgets('app launches and renders MaterialApp with title',
      (tester) async {
    // Arrange & Act
    await tester.pumpWidget(const TacticalRadarApp());

    // Assert
    expect(find.text('Tactical Radar'), findsOneWidget);
  });
}
