import 'dart:io';

enum MigrationActionKind { apply, revert }

class MigrationPlanAction {
  const MigrationPlanAction({required this.id, required this.kind});

  final String id;
  final MigrationActionKind kind;
}

/// Extracts only migration-shaped lines from Supabase CLI dry-run output.
///
/// The CLI has changed the surrounding prose between releases, so this keeps
/// the parser deliberately narrow: a migration id must either be attached to
/// a `.sql` filename or appear after an explicit migration action.
List<MigrationPlanAction> extractMigrationPlanActions(String plan) {
  final actions = <String, MigrationPlanAction>{};
  final filenamePattern = RegExp(
    r'\b(\d{3,})_[A-Za-z0-9][A-Za-z0-9._-]*\.sql\b',
  );
  final actionIdPattern = RegExp(
    r'\b(?:migration\s+)?(\d{3,})(?=[_\s.:-]|\z)',
    caseSensitive: false,
  );

  for (final rawLine in plan.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final kind = _actionKind(line);
    final filenameMatch = filenamePattern.firstMatch(line);
    final id = filenameMatch?.group(1) ??
        (kind == null ? null : actionIdPattern.firstMatch(line)?.group(1));
    if (id == null) continue;

    final resolvedKind = kind ?? MigrationActionKind.apply;
    final key = '${resolvedKind.name}:$id';
    actions[key] = MigrationPlanAction(id: id, kind: resolvedKind);
  }
  return actions.values.toList(growable: false);
}

String? validateMigrationPlan({
  required String plan,
  required Set<String> allowedMigrationIds,
}) {
  final actions = extractMigrationPlanActions(plan);
  if (actions.isEmpty) {
    if (_isNoOpPlan(plan)) return null;
    return 'No actionable migration entries were found in the dry-run output.';
  }

  final reverts = actions
      .where((action) => action.kind == MigrationActionKind.revert)
      .map((action) => action.id)
      .toSet();
  if (reverts.isNotEmpty) {
    return 'Migration plan contains a revert action: ${_sorted(reverts).join(', ')}';
  }

  final unexpected = actions
      .map((action) => action.id)
      .where((id) => !allowedMigrationIds.contains(id))
      .toSet();
  if (unexpected.isNotEmpty) {
    return 'Migration ids not allowed for this release: '
        '${_sorted(unexpected).join(', ')}';
  }
  return null;
}

MigrationActionKind? _actionKind(String line) {
  final lower = line.toLowerCase();
  if (RegExp(r'\b(revert|reverting|would\s+revert)\b').hasMatch(lower)) {
    return MigrationActionKind.revert;
  }
  if (RegExp(r'\b(apply|applying|would\s+apply)\b').hasMatch(lower)) {
    return MigrationActionKind.apply;
  }
  return null;
}

bool _isNoOpPlan(String plan) => RegExp(
      r'\b(up\s+to\s+date|no\s+migrations?\s+to\s+apply|'
      r'nothing\s+to\s+apply|no\s+pending\s+migrations?)\b',
      caseSensitive: false,
    ).hasMatch(plan);

List<String> _sorted(Iterable<String> values) => values.toList()..sort();

void main(List<String> args) {
  final planFile = _option(args, 'plan-file');
  final allowed = _option(args, 'allowed');
  if (planFile == null || allowed == null) {
    stderr.writeln(
      'Usage: dart run tool/verify_supabase_migration_plan.dart '
      '--plan-file=<path> --allowed=<id,id,...>',
    );
    exitCode = 64;
    return;
  }

  final file = File(planFile);
  if (!file.existsSync()) {
    stderr.writeln('Migration plan file does not exist: $planFile');
    exitCode = 64;
    return;
  }

  final allowedIds = allowed
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final plan = file.readAsStringSync();
  final error = validateMigrationPlan(
    plan: plan,
    allowedMigrationIds: allowedIds,
  );
  if (error != null) {
    stderr.writeln('Supabase migration plan rejected: $error');
    exitCode = 1;
    return;
  }

  final ids =
      extractMigrationPlanActions(plan).map((action) => action.id).toSet();
  stdout.writeln(
    'Supabase migration plan verified: '
    '${ids.isEmpty ? 'no-op' : _sorted(ids).join(', ')}',
  );
}

String? _option(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}
