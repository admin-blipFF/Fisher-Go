# Native Real Catch Photo Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn FisherGO's real catch photo upload into a complete native mobile loop: photo + species + location saves to the offline queue, promotes the fish collection entry to verified real catch, and shows the hook badge in the encyclopedia.

**Architecture:** Reuse the existing catch log, Hive offline queue, `FishCollectionService`, and collection badge state. Add a focused real-catch claim service so UI code does not directly coordinate queue writes, collection promotion, and metadata validation.

**Tech Stack:** Flutter, Dart, Hive, `image_picker`, `geolocator`, Supabase sync path, existing FisherGO collection/domain services.

---

## File Structure

- Modify: `lib/features/catches/domain/catch_log_entry.dart`
  - Add explicit proof metadata fields used by real catch verification.
- Create: `lib/features/catches/data/real_catch_claim_service.dart`
  - Coordinates local queue insert + collection verified-real-catch promotion.
- Modify: `lib/features/catches/presentation/catch_log_screen.dart`
  - Use the service after form save; show clear verified catch feedback.
- Modify: `lib/features/fish/presentation/fish_encyclopedia_screen.dart`
  - Ensure verified-real-catch entries show the hook/photo-proof badge consistently.
- Modify: `lib/features/catches/data/catch_sync_service.dart`
  - Include proof metadata in Supabase catch payload without blocking local save.
- Test: `test/real_catch_claim_service_test.dart`
  - Verify service behavior with fake dependencies.
- Test: `test/fish_collection_service_test.dart`
  - Extend current proof badge coverage with metadata preservation.
- Test: `test/catch_sync_service_test.dart`
  - Verify metadata is passed to remote upload.

---

### Task 1: Make Real Catch Metadata Explicit

**Files:**
- Modify: `lib/features/catches/domain/catch_log_entry.dart`
- Test: `test/catch_log_local_data_source_test.dart`

- [x] **Step 1: Add metadata fields to `CatchLogEntry`**

Add fields to the constructor and class:

```dart
this.isRealCatchProof = false,
this.recognitionConfidence,
this.recognizedSpeciesId,
this.verifiedAt,
```

Add properties:

```dart
final bool isRealCatchProof;
final double? recognitionConfidence;
final String? recognizedSpeciesId;
final DateTime? verifiedAt;
```

Add to `toMap()`:

```dart
'isRealCatchProof': isRealCatchProof,
'recognitionConfidence': recognitionConfidence,
'recognizedSpeciesId': recognizedSpeciesId,
'verifiedAt': verifiedAt?.toIso8601String(),
```

Add to `fromMap()`:

```dart
isRealCatchProof: (map['isRealCatchProof'] as bool?) ?? false,
recognitionConfidence: (map['recognitionConfidence'] as num?)?.toDouble(),
recognizedSpeciesId: map['recognizedSpeciesId'] as String?,
verifiedAt: map['verifiedAt'] == null
    ? null
    : DateTime.tryParse(map['verifiedAt'] as String),
```

- [x] **Step 2: Add a serialization regression test**

In `test/catch_log_local_data_source_test.dart`, add:

```dart
test('persists real catch proof metadata in hive queue', () async {
  final entry = CatchLogEntry(
    speciesId: 'fish-063',
    speciesName: '烏頭',
    caughtAt: DateTime.utc(2026, 6, 24, 8),
    photoPath: '/local/photo.jpg',
    latitude: 22.45,
    longitude: 114.18,
    isRealCatchProof: true,
    recognitionConfidence: 0.82,
    recognizedSpeciesId: 'fish-063',
    verifiedAt: DateTime.utc(2026, 6, 24, 8, 1),
  );

  final restored = CatchLogEntry.fromMap(entry.toMap());

  expect(restored.isRealCatchProof, true);
  expect(restored.recognitionConfidence, 0.82);
  expect(restored.recognizedSpeciesId, 'fish-063');
  expect(restored.verifiedAt, DateTime.utc(2026, 6, 24, 8, 1));
});
```

- [x] **Step 3: Run the focused test**

Run:

```powershell
flutter test test\catch_log_local_data_source_test.dart
```

Expected: PASS.

---

### Task 2: Add `RealCatchClaimService`

**Files:**
- Create: `lib/features/catches/data/real_catch_claim_service.dart`
- Test: `test/real_catch_claim_service_test.dart`

- [x] **Step 1: Create service interfaces and result model**

Create `lib/features/catches/data/real_catch_claim_service.dart`:

```dart
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
```

- [x] **Step 2: Test that a photo claim is queued**

Create `test/real_catch_claim_service_test.dart`:

```dart
import 'package:fishergo/features/catches/data/catch_log_local_data_source.dart';
import 'package:fishergo/features/catches/data/real_catch_claim_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  setUp(() async {
    Hive.init('test_hive_real_catch');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('claim stores a real catch proof entry in pending queue', () async {
    final local = CatchLogLocalDataSource(
      boxName: 'real_catch_claim_test',
      itemsKey: 'items',
    );
    final service = RealCatchClaimService(localDataSource: local);

    final result = await service.claim(
      speciesId: 'fish-063',
      speciesName: '烏頭',
      caughtAt: DateTime.utc(2026, 6, 24, 8),
      photoPath: '/local/photo.jpg',
      latitude: 22.45,
      longitude: 114.18,
      recognitionConfidence: 0.82,
      recognizedSpeciesId: 'fish-063',
    );

    final pending = await local.loadPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, result.entry.id);
    expect(pending.single.isRealCatchProof, true);
    expect(pending.single.photoPath, '/local/photo.jpg');
    expect(pending.single.speciesId, 'fish-063');
  });
}
```

- [x] **Step 3: Run focused tests**

Run:

```powershell
flutter test test\real_catch_claim_service_test.dart test\fish_collection_service_test.dart
```

Expected: PASS.

---

### Task 3: Wire Catch Log Save to Verified Collection

**Files:**
- Modify: `lib/features/catches/presentation/catch_log_screen.dart`

- [x] **Step 1: Import the service**

Add:

```dart
import '../data/real_catch_claim_service.dart';
```

- [x] **Step 2: Replace direct queue save in `_save`**

Inside `_save`, after validation and species lookup, use:

```dart
final photoPath = _photoXFile?.path;
if (photoPath == null || photoPath.trim().isEmpty) {
  _showSnack('請先上載魚獲相片，才可記錄真實釣獲。');
  return;
}

final service = RealCatchClaimService(localDataSource: _localDataSource);
await service.claim(
  speciesId: selected.id,
  speciesName: selected.displayLocalName,
  caughtAt: _caughtAt,
  lengthCm: double.tryParse(_lengthController.text.trim()),
  weightKg: double.tryParse(_weightController.text.trim()),
  notes: _notesController.text.trim().isEmpty
      ? null
      : _notesController.text.trim(),
  photoPath: photoPath,
  latitude: _latitude,
  longitude: _longitude,
  checkpoints: List.unmodifiable(_checkpoints),
);
```

Then reload pending and show:

```dart
_showSnack('已加入待同步，圖鑑已標記為真實釣獲。');
```

- [x] **Step 3: Keep AI recognition user-confirmed**

Do not auto-save AI suggestions. `_recognizeFish` may set `_selectedSpeciesId`, but `_save` must still require the user to press save.

- [x] **Step 4: Run catch log tests**

Run:

```powershell
flutter test test\catch_log_local_data_source_test.dart test\real_catch_claim_service_test.dart
```

Expected: PASS.

---

### Task 4: Ensure Encyclopedia Hook Badge Is Visible

**Files:**
- Modify: `lib/features/fish/presentation/fish_encyclopedia_screen.dart`
- Test: `test/fish_collection_service_test.dart`

- [x] **Step 1: Confirm badge condition**

Use the existing domain condition:

```dart
entry?.showsPhotoProofBadge == true
```

The card should render a small hook icon at the top-left of the fish icon when true.

- [x] **Step 2: Use accessible tooltip text**

Wrap the icon:

```dart
Tooltip(
  message: '真實釣獲相片',
  child: Icon(
    Icons.phishing,
    size: 18,
    color: Colors.lightBlueAccent,
  ),
)
```

- [x] **Step 3: Keep game-caught color unlock unchanged**

The icon remains full color when:

```dart
entry?.status.showsColorIcon == true
```

Only verified real catches with `realCatchPhotoPath` show the hook badge.

- [x] **Step 4: Run service and widget tests**

Run:

```powershell
flutter test test\fish_collection_service_test.dart test\widget_test.dart
```

Expected: PASS.

---

### Task 5: Carry Proof Metadata Through Sync

**Files:**
- Modify: `lib/features/catches/data/catch_sync_service.dart`
- Test: `test/catch_sync_service_test.dart`

- [x] **Step 1: Add payload fields to Supabase insert**

In `SupabaseCatchRemoteDataSource.uploadCatch`, add:

```dart
'is_real_catch_proof': entry.isRealCatchProof,
'recognition_confidence': entry.recognitionConfidence,
'recognized_species_id': entry.recognizedSpeciesId,
'verified_at': entry.verifiedAt?.toIso8601String(),
```

- [x] **Step 2: Update fake remote test**

In `test/catch_sync_service_test.dart`, assert that an entry with:

```dart
isRealCatchProof: true,
recognitionConfidence: 0.82,
recognizedSpeciesId: 'fish-063',
verifiedAt: DateTime.utc(2026, 6, 24, 8, 1),
```

still syncs successfully and reaches the remote fake.

- [x] **Step 3: Run sync tests**

Run:

```powershell
flutter test test\catch_sync_service_test.dart
```

Expected: PASS.

---

### Task 6: Full Verification

**Files:**
- Verify whole project.

- [x] **Step 1: Format edited Dart files**

Run:

```powershell
dart format lib\features\catches\domain\catch_log_entry.dart lib\features\catches\data\real_catch_claim_service.dart lib\features\catches\presentation\catch_log_screen.dart lib\features\catches\data\catch_sync_service.dart lib\features\fish\presentation\fish_encyclopedia_screen.dart test\catch_log_local_data_source_test.dart test\real_catch_claim_service_test.dart test\catch_sync_service_test.dart test\fish_collection_service_test.dart
```

Expected: formatter completes without changes outside these files.

- [x] **Step 2: Run analyzer and tests**

Run:

```powershell
flutter analyze
flutter test
```

Expected: analyzer clean and all tests pass.

- [x] **Step 3: Build Android debug APK**

Run:

```powershell
flutter build apk --debug
```

Expected: `build\app\outputs\flutter-apk\app-debug.apk` is created.

- [x] **Step 4: Emulator smoke**

Run the existing Android smoke path:

```powershell
$sdk=Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb=Join-Path $sdk 'platform-tools\adb.exe'
$apk='build\app\outputs\flutter-apk\app-debug.apk'
& $adb -s emulator-5554 install -r $apk
& $adb -s emulator-5554 shell am force-stop com.fishergo.app
& $adb -s emulator-5554 logcat -c
& $adb -s emulator-5554 shell monkey -p com.fishergo.app -c android.intent.category.LAUNCHER 1
Start-Sleep -Seconds 25
& $adb -s emulator-5554 logcat -d -t 3000 | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime.*com\.fishergo|E/flutter|Can request only one|flutter_map|ClientException|Unable to load asset'
```

Expected: no matching app-level fatal/error lines.

---

## Self-Review

- Spec coverage: Covers native photo upload, collection verified-real-catch promotion, top-left hook badge, offline queue, and Supabase payload.
- Placeholder scan: No TBD/TODO/fill-later steps. Each code change has exact files and snippets.
- Type consistency: Uses existing `CatchLogEntry`, `CatchLogLocalDataSource`, `FishCollectionService`, `PlayerFishCollectionEntry`, and `FishDiscoveryStatus` names.
