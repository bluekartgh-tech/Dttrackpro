class Device {
  final int id;
  final String name;
  final String online; // online / offline / ack / etc
  final double lat;
  final double lng;
  final double speed;
  final double course;
  final String? address;
  final String? time;
  final int? timestamp;
  final String? protocol;
  final String? plateNumber;
  final String? imei;
  final String? driver;
  final Map<String, dynamic>? iconColors;
  final List<Sensor> sensors;
  final Map<String, dynamic> raw;

  Device({
    required this.id,
    required this.name,
    required this.online,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.course,
    this.address,
    this.time,
    this.timestamp,
    this.protocol,
    this.plateNumber,
    this.imei,
    this.driver,
    this.iconColors,
    this.sensors = const [],
    required this.raw,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final sensorsList = <Sensor>[];
    if (json['sensors'] is List) {
      for (final s in json['sensors']) {
        if (s is Map) sensorsList.add(Sensor.fromJson(Map<String, dynamic>.from(s)));
      }
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return Device(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      online: json['online']?.toString() ?? 'offline',
      lat: parseDouble(json['lat']),
      lng: parseDouble(json['lng']),
      speed: parseDouble(json['speed']),
      course: parseDouble(json['course']),
      address: json['address']?.toString(),
      time: json['time']?.toString(),
      timestamp: json['timestamp'] is int ? json['timestamp'] : int.tryParse(json['timestamp']?.toString() ?? ''),
      protocol: json['protocol']?.toString(),
      plateNumber: json['device_data']?['plate_number']?.toString() ??
          json['plate_number']?.toString(),
      imei: json['device_data']?['imei']?.toString() ?? json['imei']?.toString(),
      driver: json['driver']?.toString() == '-' ? null : json['driver']?.toString(),
      iconColors: json['icon_colors'] is Map
          ? Map<String, dynamic>.from(json['icon_colors'])
          : null,
      sensors: sensorsList,
      raw: json,
    );
  }

  bool get isOnline => online == 'online' || online == 'ack' || online == 'moving';
  bool get isMoving => speed > 0 || online == 'moving';
  bool get isOffline => online == 'offline' || online == 'stopped';

  String get statusLabel {
    if (isMoving) return 'Moving';
    if (isOnline) return 'Online';
    return 'Offline';
  }

  String? get battery {
    for (final s in sensors) {
      if (s.type.toLowerCase().contains('battery') || s.name.toLowerCase().contains('battery')) {
        return s.value;
      }
    }
    return null;
  }

  String? get ignition {
    for (final s in sensors) {
      if (s.type.toLowerCase().contains('ignition') || s.name.toLowerCase().contains('ignition')) {
        return s.value;
      }
    }
    return null;
  }

  String? get fuel {
    for (final s in sensors) {
      if (s.type.toLowerCase().contains('fuel') || s.name.toLowerCase().contains('fuel')) {
        return s.value;
      }
    }
    return null;
  }
}

class Sensor {
  final int id;
  final String type;
  final String name;
  final String value;
  final dynamic val;

  Sensor({
    required this.id,
    required this.type,
    required this.name,
    required this.value,
    this.val,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      val: json['val'],
    );
  }
}
