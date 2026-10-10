enum DetectionKind {
  person('Person'),
  vehicle('Vehicle'),
  motion('Motion');

  const DetectionKind(this.label);
  final String label;
}

class CameraModel {
  const CameraModel({
    required this.id,
    required this.name,
    required this.location,
    required this.image,
    required this.enabled,
    this.source = '',
  });

  final String id;
  final String name;
  final String location;
  final String image;
  final bool enabled;

  /// Where edge.py finds the camera: "192.168.1.50:8080" (IP Webcam app) or a
  /// full http(s):// / rtsp:// URL. Empty = not set yet.
  final String source;

  CameraModel copyWith({bool? enabled, String? location, String? source}) => CameraModel(
        id: id,
        name: name,
        location: location ?? this.location,
        image: image,
        enabled: enabled ?? this.enabled,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'image': image,
        'enabled': enabled,
        'source': source,
      };

  factory CameraModel.fromJson(Map<String, dynamic> j) => CameraModel(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String,
        image: j['image'] as String,
        enabled: j['enabled'] as bool,
        source: (j['source'] ?? '').toString(),
      );
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.cameraName,
    required this.image,
    required this.kind,
    required this.personName,
    required this.time,
    required this.seen,
    this.summary,
    this.tags = const [],
    this.relation,
  });

  final String id;
  final String cameraName;
  final String image;
  final DetectionKind kind;
  final String personName; // recognised person, or "Unknown"
  final DateTime time;
  final bool seen;
  final String? summary; // LLM sentence from n8n, read aloud
  final List<String> tags; // 1-6 short AI tags, e.g. "person", "shopping bags"
  final String? relation; // e.g. "wife", set when a saved person was recognised

  AlertModel copyWith({bool? seen, String? image}) => AlertModel(
        id: id,
        cameraName: cameraName,
        image: image ?? this.image,
        kind: kind,
        personName: personName,
        time: time,
        seen: seen ?? this.seen,
        summary: summary,
        tags: tags,
        relation: relation,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cameraName': cameraName,
        'image': image,
        'kind': kind.name,
        'personName': personName,
        'time': time.millisecondsSinceEpoch,
        'seen': seen,
        'summary': summary,
        'tags': tags,
        'relation': relation,
      };

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id: j['id'] as String,
        cameraName: j['cameraName'] as String,
        image: j['image'] as String,
        kind: DetectionKind.values.asNameMap()[j['kind']] ?? DetectionKind.motion,
        personName: j['personName'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
        seen: j['seen'] as bool,
        summary: j['summary'] as String?,
        tags: [
          for (final t in (j['tags'] as List? ?? const []))
            if (t.toString().trim().isNotEmpty) t.toString().trim(),
        ],
        relation: (j['relation'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['relation'] as String).trim(),
      );
}

/// Someone you saved in the People tab so the camera can recognise them.
class PersonModel {
  const PersonModel({
    required this.id,
    required this.name,
    required this.relation,
    this.enrolled = false,
    this.deleting = false,
  });

  final String id;
  final String name;
  final String relation; // wife, husband, mum, friend, ...
  /// True once edge.py has downloaded the photos and learned the face.
  final bool enrolled;

  /// True while the server is waiting for edge.py to delete their photos.
  final bool deleting;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'enrolled': enrolled,
        'deleting': deleting,
      };

  /// The n8n server sends `status` ("pending" | "enrolled" | "deleting");
  /// the local cache stores `enrolled` / `deleting` booleans. Accept both.
  factory PersonModel.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] ?? '').toString();
    return PersonModel(
      id: j['id'].toString(),
      name: (j['name'] ?? '').toString(),
      relation: (j['relation'] ?? '').toString(),
      enrolled: j['enrolled'] == true || status == 'enrolled',
      deleting: j['deleting'] == true || status == 'deleting',
    );
  }
}
