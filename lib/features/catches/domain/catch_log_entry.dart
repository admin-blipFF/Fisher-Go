import 'package:uuid/uuid.dart';

enum CatchSyncStatus { pending, syncing, synced, failed }

class CatchCheckpoint {
  const CatchCheckpoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.spotId,
    this.spotName,
    this.triggerType = 'manual',
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String? spotId;
  final String? spotName;
  final String triggerType;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'recordedAt': recordedAt.toIso8601String(),
        'spotId': spotId,
        'spotName': spotName,
        'triggerType': triggerType,
      };

  factory CatchCheckpoint.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return CatchCheckpoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(map['recordedAt'] as String),
      spotId: map['spotId'] as String?,
      spotName: map['spotName'] as String?,
      triggerType: (map['triggerType'] as String?) ?? 'manual',
    );
  }
}

class CatchLogEntry {
  CatchLogEntry({
    String? id,
    required this.speciesId,
    required this.speciesName,
    required this.caughtAt,
    this.lengthCm,
    this.weightKg,
    this.notes,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.checkpoints = const [],
    this.syncStatus = CatchSyncStatus.pending,
    this.isRealCatchProof = false,
    this.recognitionConfidence,
    this.recognizedSpeciesId,
    this.verifiedAt,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String speciesId;
  final String speciesName;
  final DateTime caughtAt;
  final double? lengthCm;
  final double? weightKg;
  final String? notes;
  final String? photoPath;
  final double? latitude;
  final double? longitude;
  final List<CatchCheckpoint> checkpoints;
  final CatchSyncStatus syncStatus;
  final bool isRealCatchProof;
  final double? recognitionConfidence;
  final String? recognizedSpeciesId;
  final DateTime? verifiedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'speciesId': speciesId,
        'speciesName': speciesName,
        'caughtAt': caughtAt.toIso8601String(),
        'lengthCm': lengthCm,
        'weightKg': weightKg,
        'notes': notes,
        'photoPath': photoPath,
        'latitude': latitude,
        'longitude': longitude,
        'checkpoints': checkpoints.map((item) => item.toMap()).toList(),
        'syncStatus': syncStatus.name,
        'isRealCatchProof': isRealCatchProof,
        'recognitionConfidence': recognitionConfidence,
        'recognizedSpeciesId': recognizedSpeciesId,
        'verifiedAt': verifiedAt?.toIso8601String(),
      };

  factory CatchLogEntry.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return CatchLogEntry(
      id: map['id'] as String,
      speciesId: map['speciesId'] as String,
      speciesName: map['speciesName'] as String,
      caughtAt: DateTime.parse(map['caughtAt'] as String),
      lengthCm: (map['lengthCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      photoPath: map['photoPath'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      checkpoints: (map['checkpoints'] as List<dynamic>? ?? const [])
          .map((item) => CatchCheckpoint.fromMap(item as Map<dynamic, dynamic>))
          .toList(growable: false),
      syncStatus: CatchSyncStatus.values.firstWhere(
        (value) => value.name == map['syncStatus'],
        orElse: () => CatchSyncStatus.pending,
      ),
      isRealCatchProof: (map['isRealCatchProof'] as bool?) ?? false,
      recognitionConfidence: (map['recognitionConfidence'] as num?)?.toDouble(),
      recognizedSpeciesId: map['recognizedSpeciesId'] as String?,
      verifiedAt: map['verifiedAt'] == null
          ? null
          : DateTime.tryParse(map['verifiedAt'] as String),
    );
  }
}
