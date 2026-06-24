import '../../fish/domain/fish_collection_service.dart';
import '../../fish/domain/fish_collection_status.dart';
import '../domain/catch_log_entry.dart';
import 'catch_log_local_data_source.dart';

class RealCatchClaimResult {
  const RealCatchClaimResult({
    required this.entry,
    required this.collectionEntry,
  });

  final CatchLogEntry entry;
  final PlayerFishCollectionEntry collectionEntry;
}

class RealCatchClaimService {
  const RealCatchClaimService({
    required CatchLogLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final CatchLogLocalDataSource _localDataSource;

  Future<RealCatchClaimResult> claim({
    required String speciesId,
    required String speciesName,
    required DateTime caughtAt,
    required String photoPath,
    double? lengthCm,
    double? weightKg,
    String? notes,
    double? latitude,
    double? longitude,
    double? recognitionConfidence,
    String? recognizedSpeciesId,
    List<CatchCheckpoint> checkpoints = const [],
  }) async {
    final trimmedPhotoPath = photoPath.trim();
    if (trimmedPhotoPath.isEmpty) {
      throw ArgumentError.value(photoPath, 'photoPath', 'Photo is required');
    }

    final verifiedAt = DateTime.now();
    final entry = CatchLogEntry(
      speciesId: speciesId,
      speciesName: speciesName,
      caughtAt: caughtAt,
      lengthCm: lengthCm,
      weightKg: weightKg,
      notes: notes,
      photoPath: trimmedPhotoPath,
      latitude: latitude,
      longitude: longitude,
      checkpoints: checkpoints,
      isRealCatchProof: true,
      recognitionConfidence: recognitionConfidence,
      recognizedSpeciesId: recognizedSpeciesId,
      verifiedAt: verifiedAt,
    );

    await _localDataSource.addPending(entry);
    final collectionEntry = await FishCollectionService.markVerifiedRealCatch(
      speciesId,
      photoPath: trimmedPhotoPath,
      bestLengthCm: lengthCm,
      latitude: latitude,
      longitude: longitude,
    );

    return RealCatchClaimResult(
      entry: entry,
      collectionEntry: collectionEntry,
    );
  }
}
