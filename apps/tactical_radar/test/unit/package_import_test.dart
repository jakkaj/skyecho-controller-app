import 'package:flutter_test/flutter_test.dart';
import 'package:skyecho/skyecho.dart';
import 'package:skyecho_gdl90/skyecho_gdl90.dart';

void main() {
  test('skyecho package imports successfully', () {
    final client = SkyEchoClient('http://192.168.4.1');
    expect(client, isNotNull);
  });

  test('skyecho_gdl90 package imports successfully', () {
    final stream = Gdl90Stream(port: 4000);
    expect(stream, isNotNull);
  });
}
