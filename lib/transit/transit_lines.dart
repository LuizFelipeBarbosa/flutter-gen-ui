import 'package:flutter/material.dart';

enum TransitBulletShape { square, circle }

class TransitLine {
  const TransitLine({
    required this.id,
    required this.operatorName,
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.textColor,
    required this.shape,
  });

  final String id;
  final String operatorName;
  final String label;
  final String shortLabel;
  final Color color;
  final Color textColor;
  final TransitBulletShape shape;
}

class BartStation {
  const BartStation({required this.name, required this.abbr});

  final String name;
  final String abbr;
}

const String defaultBartApiKey = 'MW9S-E7SL-26DU-VV8V';

const Map<String, TransitLine> transitLines = {
  'bart-yellow': TransitLine(
    id: 'bart-yellow',
    operatorName: 'BART',
    label: 'Yellow Line',
    shortLabel: '',
    color: Color(0xFFFFC72C),
    textColor: Color(0xFF1A1300),
    shape: TransitBulletShape.square,
  ),
  'bart-orange': TransitLine(
    id: 'bart-orange',
    operatorName: 'BART',
    label: 'Orange Line',
    shortLabel: '',
    color: Color(0xFFF4922A),
    textColor: Color(0xFF1A0E00),
    shape: TransitBulletShape.square,
  ),
  'bart-green': TransitLine(
    id: 'bart-green',
    operatorName: 'BART',
    label: 'Green Line',
    shortLabel: '',
    color: Color(0xFF4DB848),
    textColor: Color(0xFF06210A),
    shape: TransitBulletShape.square,
  ),
  'bart-blue': TransitLine(
    id: 'bart-blue',
    operatorName: 'BART',
    label: 'Blue Line',
    shortLabel: '',
    color: Color(0xFF0091D2),
    textColor: Colors.white,
    shape: TransitBulletShape.square,
  ),
  'bart-red': TransitLine(
    id: 'bart-red',
    operatorName: 'BART',
    label: 'Red Line',
    shortLabel: '',
    color: Color(0xFFED1C24),
    textColor: Colors.white,
    shape: TransitBulletShape.square,
  ),
  'bart-beige': TransitLine(
    id: 'bart-beige',
    operatorName: 'BART',
    label: 'OAK Airport',
    shortLabel: '',
    color: Color(0xFFC7B299),
    textColor: Color(0xFF1A1206),
    shape: TransitBulletShape.square,
  ),
  'muni-j': TransitLine(
    id: 'muni-j',
    operatorName: 'Muni',
    label: 'J Church',
    shortLabel: 'J',
    color: Color(0xFFE68A00),
    textColor: Color(0xFF1A0E00),
    shape: TransitBulletShape.circle,
  ),
  'muni-k': TransitLine(
    id: 'muni-k',
    operatorName: 'Muni',
    label: 'K Ingleside',
    shortLabel: 'K',
    color: Color(0xFF549BBE),
    textColor: Color(0xFF06202B),
    shape: TransitBulletShape.circle,
  ),
  'muni-l': TransitLine(
    id: 'muni-l',
    operatorName: 'Muni',
    label: 'L Taraval',
    shortLabel: 'L',
    color: Color(0xFF7C5CBF),
    textColor: Colors.white,
    shape: TransitBulletShape.circle,
  ),
  'muni-m': TransitLine(
    id: 'muni-m',
    operatorName: 'Muni',
    label: 'M Ocean View',
    shortLabel: 'M',
    color: Color(0xFF008752),
    textColor: Colors.white,
    shape: TransitBulletShape.circle,
  ),
  'muni-n': TransitLine(
    id: 'muni-n',
    operatorName: 'Muni',
    label: 'N Judah',
    shortLabel: 'N',
    color: Color(0xFF14438F),
    textColor: Colors.white,
    shape: TransitBulletShape.circle,
  ),
  'muni-t': TransitLine(
    id: 'muni-t',
    operatorName: 'Muni',
    label: 'T Third',
    shortLabel: 'T',
    color: Color(0xFFD11947),
    textColor: Colors.white,
    shape: TransitBulletShape.circle,
  ),
  'caltrain': TransitLine(
    id: 'caltrain',
    operatorName: 'Caltrain',
    label: 'Caltrain',
    shortLabel: '',
    color: Color(0xFFC9D2DC),
    textColor: Color(0xFFD6001C),
    shape: TransitBulletShape.square,
  ),
};

const TransitLine fallbackTransitLine = TransitLine(
  id: 'unknown',
  operatorName: '',
  label: 'Line',
  shortLabel: '',
  color: Color(0xFF7C8997),
  textColor: Color(0xFF0C1622),
  shape: TransitBulletShape.square,
);

TransitLine lineFor(String? id) => transitLines[id] ?? fallbackTransitLine;

const Map<String, String> bartColorLineIds = {
  'YELLOW': 'bart-yellow',
  'ORANGE': 'bart-orange',
  'GREEN': 'bart-green',
  'BLUE': 'bart-blue',
  'RED': 'bart-red',
  'BEIGE': 'bart-beige',
};

final List<MapEntry<String, BartStation>> bartStationAliases = [
  const MapEntry('embarcadero', BartStation(name: 'Embarcadero', abbr: 'EMBR')),
  const MapEntry(
    'montgomery',
    BartStation(name: 'Montgomery St', abbr: 'MONT'),
  ),
  const MapEntry('powell', BartStation(name: 'Powell St', abbr: 'POWL')),
  const MapEntry(
    'civic center',
    BartStation(name: 'Civic Center', abbr: 'CIVC'),
  ),
  const MapEntry('civic', BartStation(name: 'Civic Center', abbr: 'CIVC')),
  const MapEntry('16th', BartStation(name: '16th St Mission', abbr: '16TH')),
  const MapEntry('24th', BartStation(name: '24th St Mission', abbr: '24TH')),
  const MapEntry('12th', BartStation(name: '12th St Oakland', abbr: '12TH')),
  const MapEntry(
    'oakland city center',
    BartStation(name: '12th St Oakland', abbr: '12TH'),
  ),
  const MapEntry(
    'downtown oakland',
    BartStation(name: '12th St Oakland', abbr: '12TH'),
  ),
  const MapEntry('19th', BartStation(name: '19th St Oakland', abbr: '19TH')),
  const MapEntry('macarthur', BartStation(name: 'MacArthur', abbr: 'MCAR')),
  const MapEntry('ashby', BartStation(name: 'Ashby', abbr: 'ASHB')),
  const MapEntry(
    'downtown berkeley',
    BartStation(name: 'Downtown Berkeley', abbr: 'DBRK'),
  ),
  const MapEntry(
    'north berkeley',
    BartStation(name: 'North Berkeley', abbr: 'NBRK'),
  ),
  const MapEntry(
    'berkeley',
    BartStation(name: 'Downtown Berkeley', abbr: 'DBRK'),
  ),
  const MapEntry('richmond', BartStation(name: 'Richmond', abbr: 'RICH')),
  const MapEntry(
    'el cerrito del norte',
    BartStation(name: 'El Cerrito del Norte', abbr: 'DELN'),
  ),
  const MapEntry(
    'del norte',
    BartStation(name: 'El Cerrito del Norte', abbr: 'DELN'),
  ),
  const MapEntry(
    'el cerrito plaza',
    BartStation(name: 'El Cerrito Plaza', abbr: 'PLZA'),
  ),
  const MapEntry('rockridge', BartStation(name: 'Rockridge', abbr: 'ROCK')),
  const MapEntry('orinda', BartStation(name: 'Orinda', abbr: 'ORIN')),
  const MapEntry('lafayette', BartStation(name: 'Lafayette', abbr: 'LAFY')),
  const MapEntry(
    'walnut creek',
    BartStation(name: 'Walnut Creek', abbr: 'WCRK'),
  ),
  const MapEntry(
    'pleasant hill',
    BartStation(name: 'Pleasant Hill', abbr: 'PHIL'),
  ),
  const MapEntry(
    'north concord',
    BartStation(name: 'North Concord', abbr: 'NCON'),
  ),
  const MapEntry('concord', BartStation(name: 'Concord', abbr: 'CONC')),
  const MapEntry(
    'pittsburg',
    BartStation(name: 'Pittsburg/Bay Point', abbr: 'PITT'),
  ),
  const MapEntry(
    'bay point',
    BartStation(name: 'Pittsburg/Bay Point', abbr: 'PITT'),
  ),
  const MapEntry('antioch', BartStation(name: 'Antioch', abbr: 'ANTC')),
  const MapEntry(
    'west oakland',
    BartStation(name: 'West Oakland', abbr: 'WOAK'),
  ),
  const MapEntry(
    'lake merritt',
    BartStation(name: 'Lake Merritt', abbr: 'LAKE'),
  ),
  const MapEntry('fruitvale', BartStation(name: 'Fruitvale', abbr: 'FTVL')),
  const MapEntry('coliseum', BartStation(name: 'Coliseum', abbr: 'COLS')),
  const MapEntry(
    'san leandro',
    BartStation(name: 'San Leandro', abbr: 'SANL'),
  ),
  const MapEntry('bay fair', BartStation(name: 'Bay Fair', abbr: 'BAYF')),
  const MapEntry('bayfair', BartStation(name: 'Bay Fair', abbr: 'BAYF')),
  const MapEntry(
    'south hayward',
    BartStation(name: 'South Hayward', abbr: 'SHAY'),
  ),
  const MapEntry('hayward', BartStation(name: 'Hayward', abbr: 'HAYW')),
  const MapEntry(
    'union city',
    BartStation(name: 'Union City', abbr: 'UCTY'),
  ),
  const MapEntry('fremont', BartStation(name: 'Fremont', abbr: 'FRMT')),
  const MapEntry(
    'warm springs',
    BartStation(name: 'Warm Springs', abbr: 'WARM'),
  ),
  const MapEntry('milpitas', BartStation(name: 'Milpitas', abbr: 'MLPT')),
  const MapEntry('berryessa', BartStation(name: 'Berryessa', abbr: 'BERY')),
  const MapEntry(
    'north san jose',
    BartStation(name: 'Berryessa', abbr: 'BERY'),
  ),
  const MapEntry(
    'castro valley',
    BartStation(name: 'Castro Valley', abbr: 'CAST'),
  ),
  const MapEntry(
    'west dublin',
    BartStation(name: 'West Dublin/Pleasanton', abbr: 'WDUB'),
  ),
  const MapEntry(
    'dublin',
    BartStation(name: 'Dublin/Pleasanton', abbr: 'DUBL'),
  ),
  const MapEntry(
    'pleasanton',
    BartStation(name: 'Dublin/Pleasanton', abbr: 'DUBL'),
  ),
  const MapEntry('balboa', BartStation(name: 'Balboa Park', abbr: 'BALB')),
  const MapEntry('glen park', BartStation(name: 'Glen Park', abbr: 'GLEN')),
  const MapEntry('daly city', BartStation(name: 'Daly City', abbr: 'DALY')),
  const MapEntry('daly', BartStation(name: 'Daly City', abbr: 'DALY')),
  const MapEntry('colma', BartStation(name: 'Colma', abbr: 'COLM')),
  const MapEntry(
    'south san francisco',
    BartStation(name: 'South San Francisco', abbr: 'SSAN'),
  ),
  const MapEntry(
    'south sf',
    BartStation(name: 'South San Francisco', abbr: 'SSAN'),
  ),
  const MapEntry('san bruno', BartStation(name: 'San Bruno', abbr: 'SBRN')),
  const MapEntry('sfo', BartStation(name: 'SFO', abbr: 'SFIA')),
  const MapEntry(
    'san francisco international',
    BartStation(name: 'SFO', abbr: 'SFIA'),
  ),
  const MapEntry(
    'san francisco airport',
    BartStation(name: 'SFO', abbr: 'SFIA'),
  ),
  const MapEntry('millbrae', BartStation(name: 'Millbrae', abbr: 'MLBR')),
  const MapEntry(
    'oakland airport',
    BartStation(name: 'Oakland Airport', abbr: 'OAKL'),
  ),
  const MapEntry(
    'oak airport',
    BartStation(name: 'Oakland Airport', abbr: 'OAKL'),
  ),
  const MapEntry(
    'oakland international',
    BartStation(name: 'Oakland Airport', abbr: 'OAKL'),
  ),
]..sort((a, b) => b.key.length.compareTo(a.key.length));

BartStation? resolveBartStation(String text) {
  final query = text.toLowerCase();
  for (final alias in bartStationAliases) {
    if (query.contains(alias.key)) return alias.value;
  }
  return null;
}

bool looksLikeBartDepartureQuery(String text) {
  final query = text.toLowerCase();
  return RegExp(
    '(departures?|next trains?|next bart|leaving from|trains? from|'
    "when'?s the next|when is the next)",
  ).hasMatch(query);
}
