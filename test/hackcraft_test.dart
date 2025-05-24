import 'package:test/test.dart';
import 'package:hackcraft/hackcraft.dart';

void main() {
  group('HackCraft Tests', () {
    test('Player can be instantiated', () {
      final player = Player('test_player');
      expect(player, isNotNull);
      expect(player.name, equals('test_player'));
    });
  });
}
