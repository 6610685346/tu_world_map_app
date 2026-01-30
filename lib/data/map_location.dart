import 'package:latlong2/latlong.dart';

final List<Map<String, dynamic>> buildings = [
  {
    'id': 'ENG',
    'name': 'Engineering Building',
    'description': 'Faculty of Engineering building',
    'type': 'building', // 👈 เพิ่ม type
    'polygons': [
      [
        LatLng(14.06820, 100.60320),
        LatLng(14.06820, 100.60360),
        LatLng(14.06850, 100.60360),
        LatLng(14.06850, 100.60320),
      ],
    ],
  },
  {
    'id': 'GYM6',
    'name': 'Gym 6',
    'description': 'Sports and fitness building',
    'type': 'gym', // 👈 เพิ่ม type
    'polygons': [
      [
        LatLng(14.06732934062687, 100.60422284413761),
        LatLng(14.06726860316219, 100.6042196330992),
        LatLng(14.067106636511511, 100.60401733771084),
        LatLng(14.067041226869136, 100.60401412667414),
        LatLng(14.06677958811592, 100.60430633112355),
        LatLng(14.066737539002276, 100.60441550641275),
        LatLng(14.066729752128452, 100.60457284727158),
        LatLng(14.066762456996102, 100.60467560048409),
        LatLng(14.066726637379361, 100.60467560048409),
        LatLng(14.066723522629374, 100.60482009719135),
        LatLng(14.066876145309465, 100.60481206959639),
        LatLng(14.067031882633543, 100.6049517497454),
        LatLng(14.067087948043692, 100.6049517497454),
        LatLng(14.067316881661228, 100.60473982124199),
        LatLng(14.067369832261079, 100.60460014109299),
        LatLng(14.067374504372012, 100.60447009405726),
        LatLng(14.067354258556236, 100.60438339603292),
        LatLng(14.067332455368643, 100.60433201942675),
        LatLng(14.06732934062687, 100.60422284413761),
      ],
    ],
  },

  {
    'id': 'CANTEEN1',
    'name': 'Main Canteen',
    'description': 'Student food court',
    'type': 'canteen', // 👈 เพิ่ม type
    'polygons': [
      [
        LatLng(14.0679, 100.6039),
        LatLng(14.0679, 100.6042),
        LatLng(14.0682, 100.6042),
        LatLng(14.0682, 100.6039),
      ],
    ],
  },
];

