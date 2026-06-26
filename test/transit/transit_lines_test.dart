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

    test('resolves station names from abbreviations', () {
      final station = bartStationForAbbr('EMBR');

      expect(station?.name, 'Embarcadero');
      expect(station?.abbr, 'EMBR');
    });
  });

  test('includes generic 511 line styles', () {
    expect(lineFor(regionalBusLineId).label, 'Bus');
    expect(lineFor(regionalRailLineId).label, 'Rail');
    expect(lineFor(regionalFerryLineId).label, 'Ferry');
    expect(lineFor(regionalTransitLineId).label, 'Line');
  });
}
