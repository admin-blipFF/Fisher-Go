import 'package:hive/hive.dart';

import '../../../core/auth/local_account_service.dart';

class PlayerProgressState {
  const PlayerProgressState({
    required this.level,
    required this.xp,
    required this.totalCatches,
    required this.uniqueFishCaught,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.dailyCatches,
    required this.dailyUniqueFish,
    required this.dailyTasksCompleted,
    required this.dailyTasksClaimed,
    this.lastCatchDate,
    this.dailyDate,
  });

  final int level;
  final int xp;
  final int totalCatches;
  final int uniqueFishCaught;
  final int currentStreakDays;
  final int bestStreakDays;
  final int dailyCatches;
  final int dailyUniqueFish;
  final Set<String> dailyTasksCompleted;
  final Set<String> dailyTasksClaimed;
  final DateTime? lastCatchDate;
  final DateTime? dailyDate;

  static const empty = PlayerProgressState(
    level: 1,
    xp: 0,
    totalCatches: 0,
    uniqueFishCaught: 0,
    currentStreakDays: 0,
    bestStreakDays: 0,
    dailyCatches: 0,
    dailyUniqueFish: 0,
    dailyTasksCompleted: {},
    dailyTasksClaimed: {},
  );

  int get xpForNextLevel => level * 100;

  factory PlayerProgressState.fromMap(Map<dynamic, dynamic> raw) {
    DateTime? parseDate(Object? value) {
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return PlayerProgressState(
      level: (raw['level'] as num?)?.toInt() ?? 1,
      xp: (raw['xp'] as num?)?.toInt() ?? 0,
      totalCatches: (raw['totalCatches'] as num?)?.toInt() ?? 0,
      uniqueFishCaught: (raw['uniqueFishCaught'] as num?)?.toInt() ?? 0,
      currentStreakDays: (raw['currentStreakDays'] as num?)?.toInt() ?? 0,
      bestStreakDays: (raw['bestStreakDays'] as num?)?.toInt() ?? 0,
      dailyCatches: (raw['dailyCatches'] as num?)?.toInt() ?? 0,
      dailyUniqueFish: (raw['dailyUniqueFish'] as num?)?.toInt() ?? 0,
      dailyTasksCompleted:
          Set<String>.from((raw['dailyTasksCompleted'] as List?) ?? const []),
      dailyTasksClaimed:
          Set<String>.from((raw['dailyTasksClaimed'] as List?) ?? const []),
      lastCatchDate: parseDate(raw['lastCatchDate']),
      dailyDate: parseDate(raw['dailyDate']),
    );
  }

  Map<String, dynamic> toMap() => {
        'level': level,
        'xp': xp,
        'totalCatches': totalCatches,
        'uniqueFishCaught': uniqueFishCaught,
        'currentStreakDays': currentStreakDays,
        'bestStreakDays': bestStreakDays,
        'dailyCatches': dailyCatches,
        'dailyUniqueFish': dailyUniqueFish,
        'dailyTasksCompleted': dailyTasksCompleted.toList(growable: false),
        'dailyTasksClaimed': dailyTasksClaimed.toList(growable: false),
        'lastCatchDate': lastCatchDate?.toIso8601String(),
        'dailyDate': dailyDate?.toIso8601String(),
      };

  PlayerProgressState copyWith({
    int? level,
    int? xp,
    int? totalCatches,
    int? uniqueFishCaught,
    int? currentStreakDays,
    int? bestStreakDays,
    int? dailyCatches,
    int? dailyUniqueFish,
    Set<String>? dailyTasksCompleted,
    Set<String>? dailyTasksClaimed,
    DateTime? lastCatchDate,
    DateTime? dailyDate,
  }) {
    return PlayerProgressState(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      totalCatches: totalCatches ?? this.totalCatches,
      uniqueFishCaught: uniqueFishCaught ?? this.uniqueFishCaught,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      dailyCatches: dailyCatches ?? this.dailyCatches,
      dailyUniqueFish: dailyUniqueFish ?? this.dailyUniqueFish,
      dailyTasksCompleted: dailyTasksCompleted ?? this.dailyTasksCompleted,
      dailyTasksClaimed: dailyTasksClaimed ?? this.dailyTasksClaimed,
      lastCatchDate: lastCatchDate ?? this.lastCatchDate,
      dailyDate: dailyDate ?? this.dailyDate,
    );
  }
}

class PlayerCatchProgressResult {
  const PlayerCatchProgressResult({
    required this.state,
    required this.xpGained,
    required this.coinsGained,
    required this.leveledUp,
    required this.completedTasks,
  });

  final PlayerProgressState state;
  final int xpGained;
  final int coinsGained;
  final bool leveledUp;
  final Set<String> completedTasks;
}

class PlayerDailyTaskSummary {
  const PlayerDailyTaskSummary({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.isCompleted,
    required this.isClaimed,
    required this.rewardCoins,
  });

  final String id;
  final String title;
  final int current;
  final int target;
  final bool isCompleted;
  final bool isClaimed;
  final int rewardCoins;

  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);
  bool get canClaim => isCompleted && !isClaimed;
}

class PlayerDailyTaskClaimResult {
  const PlayerDailyTaskClaimResult({
    required this.state,
    required this.claimed,
    required this.rewardCoins,
  });

  final PlayerProgressState state;
  final bool claimed;
  final int rewardCoins;
}

class PlayerProgressService {
  PlayerProgressService._();

  static const _stateKey = 'player_progress_state';
  static const _dailyTaskRewards = {
    'catch_2_fish': 20,
    'catch_2_species': 30,
  };

  static List<PlayerDailyTaskSummary> dailyTasksFor(
    PlayerProgressState state,
  ) {
    return [
      PlayerDailyTaskSummary(
        id: 'catch_2_fish',
        title: '今日釣到 2 條魚',
        current: state.dailyCatches.clamp(0, 2),
        target: 2,
        isCompleted: state.dailyTasksCompleted.contains('catch_2_fish'),
        isClaimed: state.dailyTasksClaimed.contains('catch_2_fish'),
        rewardCoins: _dailyTaskRewards['catch_2_fish']!,
      ),
      PlayerDailyTaskSummary(
        id: 'catch_2_species',
        title: '今日解鎖 2 種魚',
        current: state.dailyUniqueFish.clamp(0, 2),
        target: 2,
        isCompleted: state.dailyTasksCompleted.contains('catch_2_species'),
        isClaimed: state.dailyTasksClaimed.contains('catch_2_species'),
        rewardCoins: _dailyTaskRewards['catch_2_species']!,
      ),
    ];
  }

  static Future<PlayerProgressState> loadState() async {
    final box = await Hive.openBox(LocalAccountService.profileBoxName);
    final raw = box.get(_stateKey);
    if (raw is Map) return PlayerProgressState.fromMap(raw);
    return PlayerProgressState.empty;
  }

  static Future<PlayerCatchProgressResult> recordGameCatch({
    required String fishId,
    required int baseCoins,
    required int rarity,
    required bool isFirstCatch,
    DateTime? caughtAt,
  }) async {
    final now = caughtAt ?? DateTime.now();
    final today = _dateOnly(now);
    final previous = await loadState();
    final previousDailyDate =
        previous.dailyDate == null ? null : _dateOnly(previous.dailyDate!);
    final sameDailyWindow =
        previousDailyDate != null && previousDailyDate == today;

    final dailyCatches = (sameDailyWindow ? previous.dailyCatches : 0) + 1;
    final dailyUniqueFish = (sameDailyWindow ? previous.dailyUniqueFish : 0) +
        (isFirstCatch ? 1 : 0);
    final previousTasks = sameDailyWindow
        ? Set<String>.from(previous.dailyTasksCompleted)
        : <String>{};
    final previousClaims = sameDailyWindow
        ? Set<String>.from(previous.dailyTasksClaimed)
        : <String>{};
    final dailyTasks = Set<String>.from(previousTasks);
    if (dailyCatches >= 2) dailyTasks.add('catch_2_fish');
    if (dailyUniqueFish >= 2) dailyTasks.add('catch_2_species');

    final lastCatchDate = previous.lastCatchDate == null
        ? null
        : _dateOnly(previous.lastCatchDate!);
    final streak = _nextStreak(
      lastCatchDate: lastCatchDate,
      today: today,
      currentStreak: previous.currentStreakDays,
    );

    final xpGained =
        20 + (rarity - 1).clamp(0, 10) * 10 + (isFirstCatch ? 20 : 0);
    final coinsGained = baseCoins + (isFirstCatch ? 10 : 0);
    var level = previous.level;
    var xp = previous.xp + xpGained;
    var leveledUp = false;
    while (xp >= level * 100) {
      xp -= level * 100;
      level += 1;
      leveledUp = true;
    }

    final completedTasks = dailyTasks.difference(previousTasks);
    final updated = previous.copyWith(
      level: level,
      xp: xp,
      totalCatches: previous.totalCatches + 1,
      uniqueFishCaught: previous.uniqueFishCaught + (isFirstCatch ? 1 : 0),
      currentStreakDays: streak,
      bestStreakDays:
          streak > previous.bestStreakDays ? streak : previous.bestStreakDays,
      dailyCatches: dailyCatches,
      dailyUniqueFish: dailyUniqueFish,
      dailyTasksCompleted: dailyTasks,
      dailyTasksClaimed: previousClaims,
      lastCatchDate: today,
      dailyDate: today,
    );

    await _saveState(updated);
    return PlayerCatchProgressResult(
      state: updated,
      xpGained: xpGained,
      coinsGained: coinsGained,
      leveledUp: leveledUp,
      completedTasks: completedTasks,
    );
  }

  static Future<PlayerDailyTaskClaimResult> claimDailyTaskReward(
    String taskId,
  ) async {
    final state = await loadState();
    final reward = _dailyTaskRewards[taskId] ?? 0;
    final canClaim = reward > 0 &&
        state.dailyTasksCompleted.contains(taskId) &&
        !state.dailyTasksClaimed.contains(taskId);

    if (!canClaim) {
      return PlayerDailyTaskClaimResult(
        state: state,
        claimed: false,
        rewardCoins: 0,
      );
    }

    final claimedTasks = Set<String>.from(state.dailyTasksClaimed)..add(taskId);
    final updated = state.copyWith(dailyTasksClaimed: claimedTasks);
    await _saveState(updated);
    return PlayerDailyTaskClaimResult(
      state: updated,
      claimed: true,
      rewardCoins: reward,
    );
  }

  static Future<void> resetForTest() async {
    final box = await Hive.openBox(LocalAccountService.profileBoxName);
    await box.delete(_stateKey);
  }

  static Future<void> saveStateForTest(PlayerProgressState state) =>
      _saveState(state);

  static Future<void> _saveState(PlayerProgressState state) async {
    final box = await Hive.openBox(LocalAccountService.profileBoxName);
    await box.put(_stateKey, state.toMap());
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _nextStreak({
    required DateTime? lastCatchDate,
    required DateTime today,
    required int currentStreak,
  }) {
    if (lastCatchDate == null) return 1;
    if (lastCatchDate == today) return currentStreak == 0 ? 1 : currentStreak;
    if (today.difference(lastCatchDate).inDays == 1) {
      return currentStreak + 1;
    }
    return 1;
  }
}
