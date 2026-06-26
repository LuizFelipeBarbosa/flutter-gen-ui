import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/transit/transit_lines.dart';

void main() {
  group('resolveBartStation', () {
    test('matches longer aliases before shorter ones', () {
      final station = resolveBartStation('Departures at 12th St Oakland');

      expect(station?.name, '12th St Oakland');
      expect(station?.abbr, '12TH');
    });

    test('resolves airport and Berkeley station names', () {
      expect(resolveBartStation('Downtown Berkeley to SFO')?.abbr, 'DBRK');
      expect(resolveBartStation('next trains from SFO')?.abbr, 'SFIA');
    });
  });

  group('looksLikeBartDepartureQuery', () {
    test('recognizes live-board style requests', () {
      expect(
        looksLikeBartDepartureQuery('Next trains from Embarcadero'),
        isTrue,
      );
      expect(looksLikeBartDepartureQuery('Downtown Berkeley to SFO'), isFalse);
    });
  });
}
