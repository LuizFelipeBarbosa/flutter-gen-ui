import 'package:genui_template/location/location_point.dart';

enum TransitStopMode { bart, muniMetro, caltrain, ferry, bus, rail }

class BayAreaTransitStop {
  const BayAreaTransitStop({
    required this.id,
    required this.name,
    required this.operatorName,
    required this.mode,
    required this.coordinate,
    this.lineIds = const [],
    this.bartAbbr,
    this.stopCode,
  });

  final String id;
  final String name;
  final String operatorName;
  final TransitStopMode mode;
  final LocationCoordinate coordinate;
  final List<String> lineIds;
  final String? bartAbbr;
  final String? stopCode;

  String get modeLabel {
    switch (mode) {
      case TransitStopMode.bart:
        return 'BART';
      case TransitStopMode.muniMetro:
        return 'Muni Metro';
      case TransitStopMode.caltrain:
        return 'Caltrain';
      case TransitStopMode.ferry:
        return 'Ferry';
      case TransitStopMode.bus:
        return 'Bus';
      case TransitStopMode.rail:
        return 'Rail';
    }
  }

  String get systemLabel {
    if (mode == TransitStopMode.bart) return 'BART';
    if (mode == TransitStopMode.muniMetro) return 'Muni Metro';
    if (operatorName == modeLabel) return operatorName;
    return '$operatorName $modeLabel';
  }

  String get promptLabel {
    return '$name ($systemLabel)';
  }
}

class NearestTransitStop {
  const NearestTransitStop({
    required this.stop,
    required this.distanceMeters,
  });

  final BayAreaTransitStop stop;
  final double distanceMeters;

  String get distanceLabel => formatDistanceMeters(distanceMeters);
}

NearestTransitStop? nearestBayAreaTransitStop(
  LocationCoordinate coordinate, {
  Iterable<BayAreaTransitStop> stops = bayAreaTransitStops,
}) {
  NearestTransitStop? nearest;

  for (final stop in stops) {
    final distanceMeters = coordinate.distanceTo(stop.coordinate);
    if (nearest == null || distanceMeters < nearest.distanceMeters) {
      nearest = NearestTransitStop(
        stop: stop,
        distanceMeters: distanceMeters,
      );
    }
  }

  return nearest;
}

const bayAreaTransitStops = <BayAreaTransitStop>[
  BayAreaTransitStop(
    id: 'bart-embarcadero',
    name: 'Embarcadero',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.792874, longitude: -122.39702),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'EMBR',
  ),
  BayAreaTransitStop(
    id: 'bart-montgomery',
    name: 'Montgomery St',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.789405, longitude: -122.401066),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'MONT',
  ),
  BayAreaTransitStop(
    id: 'bart-powell',
    name: 'Powell St',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.784471, longitude: -122.407974),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'POWL',
  ),
  BayAreaTransitStop(
    id: 'bart-civic-center',
    name: 'Civic Center',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.779528, longitude: -122.413756),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'CIVC',
  ),
  BayAreaTransitStop(
    id: 'bart-16th-st-mission',
    name: '16th St Mission',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.764847, longitude: -122.420042),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: '16TH',
  ),
  BayAreaTransitStop(
    id: 'bart-24th-st-mission',
    name: '24th St Mission',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.752254, longitude: -122.418466),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: '24TH',
  ),
  BayAreaTransitStop(
    id: 'bart-glen-park',
    name: 'Glen Park',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.733064, longitude: -122.433817),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'GLEN',
  ),
  BayAreaTransitStop(
    id: 'bart-balboa-park',
    name: 'Balboa Park',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.721981, longitude: -122.447414),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'BALB',
  ),
  BayAreaTransitStop(
    id: 'bart-daly-city',
    name: 'Daly City',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.706121, longitude: -122.469081),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'DALY',
  ),
  BayAreaTransitStop(
    id: 'bart-colma',
    name: 'Colma',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.684638, longitude: -122.466233),
    lineIds: ['bart-yellow', 'bart-red'],
    bartAbbr: 'COLM',
  ),
  BayAreaTransitStop(
    id: 'bart-south-san-francisco',
    name: 'South San Francisco',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.664245, longitude: -122.444044),
    lineIds: ['bart-yellow', 'bart-red'],
    bartAbbr: 'SSAN',
  ),
  BayAreaTransitStop(
    id: 'bart-san-bruno',
    name: 'San Bruno',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.637761, longitude: -122.416287),
    lineIds: ['bart-yellow', 'bart-red'],
    bartAbbr: 'SBRN',
  ),
  BayAreaTransitStop(
    id: 'bart-sfo',
    name: 'SFO',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.615966, longitude: -122.392409),
    lineIds: ['bart-yellow', 'bart-red'],
    bartAbbr: 'SFIA',
  ),
  BayAreaTransitStop(
    id: 'bart-millbrae',
    name: 'Millbrae',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.600271, longitude: -122.386702),
    lineIds: ['bart-yellow', 'bart-red'],
    bartAbbr: 'MLBR',
  ),
  BayAreaTransitStop(
    id: 'bart-west-oakland',
    name: 'West Oakland',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.804872, longitude: -122.29514),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-blue'],
    bartAbbr: 'WOAK',
  ),
  BayAreaTransitStop(
    id: 'bart-12th-st-oakland',
    name: '12th St Oakland',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.803664, longitude: -122.271604),
    lineIds: ['bart-yellow', 'bart-red', 'bart-green', 'bart-orange'],
    bartAbbr: '12TH',
  ),
  BayAreaTransitStop(
    id: 'bart-19th-st-oakland',
    name: '19th St Oakland',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.80835, longitude: -122.268602),
    lineIds: ['bart-yellow', 'bart-red', 'bart-orange'],
    bartAbbr: '19TH',
  ),
  BayAreaTransitStop(
    id: 'bart-macarthur',
    name: 'MacArthur',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.829065, longitude: -122.26704),
    lineIds: ['bart-yellow', 'bart-red', 'bart-orange'],
    bartAbbr: 'MCAR',
  ),
  BayAreaTransitStop(
    id: 'bart-ashby',
    name: 'Ashby',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.852803, longitude: -122.270062),
    lineIds: ['bart-orange', 'bart-red'],
    bartAbbr: 'ASHB',
  ),
  BayAreaTransitStop(
    id: 'bart-downtown-berkeley',
    name: 'Downtown Berkeley',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.870104, longitude: -122.268133),
    lineIds: ['bart-orange', 'bart-red'],
    bartAbbr: 'DBRK',
  ),
  BayAreaTransitStop(
    id: 'bart-north-berkeley',
    name: 'North Berkeley',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.873967, longitude: -122.28344),
    lineIds: ['bart-orange', 'bart-red'],
    bartAbbr: 'NBRK',
  ),
  BayAreaTransitStop(
    id: 'bart-richmond',
    name: 'Richmond',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.936811, longitude: -122.353095),
    lineIds: ['bart-orange', 'bart-red'],
    bartAbbr: 'RICH',
  ),
  BayAreaTransitStop(
    id: 'bart-el-cerrito-del-norte',
    name: 'El Cerrito del Norte',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.925086, longitude: -122.317269),
    lineIds: ['bart-orange', 'bart-red'],
    bartAbbr: 'DELN',
  ),
  BayAreaTransitStop(
    id: 'bart-el-cerrito-plaza',
    name: 'El Cerrito Plaza',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.902632, longitude: -122.298904),
    lineIds: ['bart-orange', 'bart-red'],
    bartAbbr: 'PLZA',
  ),
  BayAreaTransitStop(
    id: 'bart-rockridge',
    name: 'Rockridge',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.844601, longitude: -122.251793),
    lineIds: ['bart-yellow'],
    bartAbbr: 'ROCK',
  ),
  BayAreaTransitStop(
    id: 'bart-orinda',
    name: 'Orinda',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.878427, longitude: -122.18374),
    lineIds: ['bart-yellow'],
    bartAbbr: 'ORIN',
  ),
  BayAreaTransitStop(
    id: 'bart-lafayette',
    name: 'Lafayette',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.893176, longitude: -122.12463),
    lineIds: ['bart-yellow'],
    bartAbbr: 'LAFY',
  ),
  BayAreaTransitStop(
    id: 'bart-walnut-creek',
    name: 'Walnut Creek',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.905522, longitude: -122.067527),
    lineIds: ['bart-yellow'],
    bartAbbr: 'WCRK',
  ),
  BayAreaTransitStop(
    id: 'bart-pleasant-hill',
    name: 'Pleasant Hill',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.928403, longitude: -122.056013),
    lineIds: ['bart-yellow'],
    bartAbbr: 'PHIL',
  ),
  BayAreaTransitStop(
    id: 'bart-concord',
    name: 'Concord',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.973745, longitude: -122.029095),
    lineIds: ['bart-yellow'],
    bartAbbr: 'CONC',
  ),
  BayAreaTransitStop(
    id: 'bart-north-concord',
    name: 'North Concord',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 38.003275, longitude: -122.024599),
    lineIds: ['bart-yellow'],
    bartAbbr: 'NCON',
  ),
  BayAreaTransitStop(
    id: 'bart-pittsburg-bay-point',
    name: 'Pittsburg/Bay Point',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 38.018914, longitude: -121.944208),
    lineIds: ['bart-yellow'],
    bartAbbr: 'PITT',
  ),
  BayAreaTransitStop(
    id: 'bart-antioch',
    name: 'Antioch',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.995388, longitude: -121.78042),
    lineIds: ['bart-yellow'],
    bartAbbr: 'ANTC',
  ),
  BayAreaTransitStop(
    id: 'bart-lake-merritt',
    name: 'Lake Merritt',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.797484, longitude: -122.265609),
    lineIds: ['bart-orange', 'bart-green', 'bart-blue'],
    bartAbbr: 'LAKE',
  ),
  BayAreaTransitStop(
    id: 'bart-fruitvale',
    name: 'Fruitvale',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.774963, longitude: -122.224274),
    lineIds: ['bart-orange', 'bart-green', 'bart-blue'],
    bartAbbr: 'FTVL',
  ),
  BayAreaTransitStop(
    id: 'bart-coliseum',
    name: 'Coliseum',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.754006, longitude: -122.197273),
    lineIds: ['bart-orange', 'bart-green', 'bart-blue', 'bart-beige'],
    bartAbbr: 'COLS',
  ),
  BayAreaTransitStop(
    id: 'bart-oakland-airport',
    name: 'Oakland Airport',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.713238, longitude: -122.212191),
    lineIds: ['bart-beige'],
    bartAbbr: 'OAKL',
  ),
  BayAreaTransitStop(
    id: 'bart-san-leandro',
    name: 'San Leandro',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.721947, longitude: -122.160844),
    lineIds: ['bart-orange', 'bart-green', 'bart-blue'],
    bartAbbr: 'SANL',
  ),
  BayAreaTransitStop(
    id: 'bart-bay-fair',
    name: 'Bay Fair',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.697185, longitude: -122.126871),
    lineIds: ['bart-orange', 'bart-green', 'bart-blue'],
    bartAbbr: 'BAYF',
  ),
  BayAreaTransitStop(
    id: 'bart-hayward',
    name: 'Hayward',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.669723, longitude: -122.087018),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'HAYW',
  ),
  BayAreaTransitStop(
    id: 'bart-south-hayward',
    name: 'South Hayward',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.634375, longitude: -122.057189),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'SHAY',
  ),
  BayAreaTransitStop(
    id: 'bart-union-city',
    name: 'Union City',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.590746, longitude: -122.017282),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'UCTY',
  ),
  BayAreaTransitStop(
    id: 'bart-fremont',
    name: 'Fremont',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.557489, longitude: -121.97662),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'FRMT',
  ),
  BayAreaTransitStop(
    id: 'bart-warm-springs',
    name: 'Warm Springs',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.502171, longitude: -121.939313),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'WARM',
  ),
  BayAreaTransitStop(
    id: 'bart-milpitas',
    name: 'Milpitas',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.410277, longitude: -121.891081),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'MLPT',
  ),
  BayAreaTransitStop(
    id: 'bart-berryessa',
    name: 'Berryessa/North San Jose',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.368473, longitude: -121.874681),
    lineIds: ['bart-orange', 'bart-green'],
    bartAbbr: 'BERY',
  ),
  BayAreaTransitStop(
    id: 'bart-castro-valley',
    name: 'Castro Valley',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.690746, longitude: -122.075602),
    lineIds: ['bart-blue'],
    bartAbbr: 'CAST',
  ),
  BayAreaTransitStop(
    id: 'bart-west-dublin-pleasanton',
    name: 'West Dublin/Pleasanton',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.699759, longitude: -121.928099),
    lineIds: ['bart-blue'],
    bartAbbr: 'WDUB',
  ),
  BayAreaTransitStop(
    id: 'bart-dublin-pleasanton',
    name: 'Dublin/Pleasanton',
    operatorName: 'BART',
    mode: TransitStopMode.bart,
    coordinate: LocationCoordinate(latitude: 37.701695, longitude: -121.899179),
    lineIds: ['bart-blue'],
    bartAbbr: 'DUBL',
  ),
  BayAreaTransitStop(
    id: 'muni-4th-king',
    name: '4th & King',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.77634, longitude: -122.39493),
    lineIds: ['muni-n', 'muni-t'],
  ),
  BayAreaTransitStop(
    id: 'muni-embarcadero',
    name: 'Embarcadero',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.792874, longitude: -122.39702),
    lineIds: ['muni-j', 'muni-k', 'muni-l', 'muni-m', 'muni-n', 'muni-t'],
  ),
  BayAreaTransitStop(
    id: 'muni-montgomery',
    name: 'Montgomery',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.789405, longitude: -122.401066),
    lineIds: ['muni-j', 'muni-k', 'muni-l', 'muni-m', 'muni-n', 'muni-t'],
  ),
  BayAreaTransitStop(
    id: 'muni-powell',
    name: 'Powell',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.784471, longitude: -122.407974),
    lineIds: ['muni-j', 'muni-k', 'muni-l', 'muni-m', 'muni-n', 'muni-t'],
  ),
  BayAreaTransitStop(
    id: 'muni-civic-center',
    name: 'Civic Center',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.779528, longitude: -122.413756),
    lineIds: ['muni-j', 'muni-k', 'muni-l', 'muni-m', 'muni-n', 'muni-t'],
  ),
  BayAreaTransitStop(
    id: 'muni-van-ness',
    name: 'Van Ness',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.7752, longitude: -122.4192),
    lineIds: ['muni-j', 'muni-k', 'muni-l', 'muni-m', 'muni-n'],
  ),
  BayAreaTransitStop(
    id: 'muni-church',
    name: 'Church',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.76703, longitude: -122.42914),
    lineIds: ['muni-j', 'muni-k', 'muni-l', 'muni-m', 'muni-n'],
  ),
  BayAreaTransitStop(
    id: 'muni-castro',
    name: 'Castro',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.76268, longitude: -122.43567),
    lineIds: ['muni-k', 'muni-l', 'muni-m'],
  ),
  BayAreaTransitStop(
    id: 'muni-forest-hill',
    name: 'Forest Hill',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.74817, longitude: -122.45914),
    lineIds: ['muni-k', 'muni-l', 'muni-m'],
  ),
  BayAreaTransitStop(
    id: 'muni-west-portal',
    name: 'West Portal',
    operatorName: 'Muni',
    mode: TransitStopMode.muniMetro,
    coordinate: LocationCoordinate(latitude: 37.74095, longitude: -122.46531),
    lineIds: ['muni-k', 'muni-l', 'muni-m'],
  ),
  BayAreaTransitStop(
    id: 'sf-caltrain',
    name: 'San Francisco Caltrain',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.77639, longitude: -122.39498),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-22nd-st',
    name: '22nd St',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.7576, longitude: -122.39246),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-bayshore',
    name: 'Bayshore',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.70954, longitude: -122.4016),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-south-san-francisco',
    name: 'South SF',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.65589, longitude: -122.40505),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-san-bruno',
    name: 'San Bruno',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.63113, longitude: -122.41109),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-millbrae',
    name: 'Millbrae Caltrain',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.59998, longitude: -122.38677),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-burlingame',
    name: 'Burlingame',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.57972, longitude: -122.3455),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-san-mateo',
    name: 'San Mateo',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.56814, longitude: -122.32399),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-hillsdale',
    name: 'Hillsdale',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.53771, longitude: -122.29729),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-belmont',
    name: 'Belmont',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.52039, longitude: -122.27582),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-san-carlos',
    name: 'San Carlos',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.50809, longitude: -122.26019),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-redwood-city',
    name: 'Redwood City',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.48578, longitude: -122.23175),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-menlo-park',
    name: 'Menlo Park',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.45482, longitude: -122.18219),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-palo-alto',
    name: 'Palo Alto',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.44333, longitude: -122.16472),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-california-ave',
    name: 'California Ave',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.42882, longitude: -122.14107),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-mountain-view',
    name: 'Mountain View',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.39455, longitude: -122.07605),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-sunnyvale',
    name: 'Sunnyvale',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.3787, longitude: -122.0307),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-lawrence',
    name: 'Lawrence',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.3706, longitude: -121.9975),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-santa-clara',
    name: 'Santa Clara',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.3532, longitude: -121.9367),
    lineIds: ['caltrain'],
  ),
  BayAreaTransitStop(
    id: 'caltrain-san-jose-diridon',
    name: 'San Jose Diridon',
    operatorName: 'Caltrain',
    mode: TransitStopMode.caltrain,
    coordinate: LocationCoordinate(latitude: 37.32984, longitude: -121.90221),
    lineIds: ['caltrain'],
  ),
];
