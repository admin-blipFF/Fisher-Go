import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/features/profile/data/player_progress_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fishergo_progress_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    await PlayerProgressService.resetForTest();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('first game catch grants XP coins streak and daily task progress',
      () async {
    final result = await PlayerProgressService.recordGameCatch(
      fishId: 'fish-010',
      baseCoins: 8,
      rarity: 1,
      isFirstCatch: true,
      caughtAt: DateTime(2026, 6, 23, 10),
    );

    expect(result.xpGained, 40);
    expect(result.coinsGained, 18);
    expect(result.leveledUp, false);
    expect(result.state.level, 1);
    expect(result.state.xp, 40);
    expect(result.state.totalCatches, 1);
    expect(result.state.uniqueFishCaught, 1);
    expect(result.state.currentStreakDays, 1);
    expect(result.state.dailyCatches, 1);
    expect(result.state.dailyUniqueFish, 1);
    expect(result.state.dailyTasksCompleted, isEmpty);
  });

  test('repeat same-day catch keeps streak and completes daily catch task',
      () async {
    await PlayerProgressService.recordGameCatch(
      fishId: 'fish-010',
      baseCoins: 8,
      rarity: 1,
      isFirstCatch: true,
      caughtAt: DateTime(2026, 6, 23, 10),
    );

    final result = await PlayerProgressService.recordGameCatch(
      fishId: 'fish-010',
      baseCoins: 8,
      rarity: 1,
      isFirstCatch: false,
      caughtAt: DateTime(2026, 6, 23, 12),
    );

    expect(result.xpGained, 20);
    expect(result.coinsGained, 8);
    expect(result.state.currentStreakDays, 1);
    expect(result.state.totalCatches, 2);
    expect(result.state.uniqueFishCaught, 1);
    expect(result.state.dailyCatches, 2);
    expect(result.state.dailyUniqueFish, 1);
    expect(result.state.dailyTasksCompleted, contains('catch_2_fish'));
  });

  test('next-day catch increments streak and resets daily counters', () async {
    await PlayerProgressService.recordGameCatch(
      fishId: 'fish-010',
      baseCoins: 8,
      rarity: 1,
      isFirstCatch: true,
      caughtAt: DateTime(2026, 6, 23, 10),
    );

    final result = await PlayerProgressService.recordGameCatch(
      fishId: 'fish-011',
      baseCoins: 12,
      rarity: 2,
      isFirstCatch: true,
      caughtAt: DateTime(2026, 6, 24, 10),
    );

    expect(result.xpGained, 50);
    expect(result.coinsGained, 22);
    expect(result.state.currentStreakDays, 2);
    expect(result.state.dailyCatches, 1);
    expect(result.state.dailyUniqueFish, 1);
    expect(result.state.dailyTasksCompleted, isEmpty);
  });

  test('XP overflow levels up and carries remaining XP', () async {
    await PlayerProgressService.saveStateForTest(
      const PlayerProgressState(
        level: 1,
        xp: 90,
        totalCatches: 0,
        uniqueFishCaught: 0,
        currentStreakDays: 0,
        bestStreakDays: 0,
        dailyCatches: 0,
        dailyUniqueFish: 0,
        dailyTasksCompleted: {},
        dailyTasksClaimed: {},
      ),
    );

    final result = await PlayerProgressService.recordGameCatch(
      fishId: 'fish-099',
      baseCoins: 60,
      rarity: 4,
      isFirstCatch: true,
      caughtAt: DateTime(2026, 6, 23, 10),
    );

    expect(result.xpGained, 70);
    expect(result.leveledUp, true);
    expect(result.state.level, 2);
    expect(result.state.xp, 60);
  });

  test('daily task summaries expose progress and completion state', () {
    final summaries = PlayerProgressService.dailyTasksFor(
      const PlayerProgressState(
        level: 1,
        xp: 40,
        totalCatches: 3,
        uniqueFishCaught: 2,
        currentStreakDays: 1,
        bestStreakDays: 1,
        dailyCatches: 2,
        dailyUniqueFish: 1,
        dailyTasksCompleted: {'catch_2_fish'},
        dailyTasksClaimed: {},
      ),
    );

    expect(summaries, hasLength(2));
    expect(summaries[0].id, 'catch_2_fish');
    expect(summaries[0].title, '今日釣到 2 條魚');
    expect(summaries[0].current, 2);
    expect(summaries[0].target, 2);
    expect(summaries[0].isCompleted, true);
    expect(summaries[0].isClaimed, false);
    expect(summaries[0].canClaim, true);
    expect(summaries[0].rewardCoins, 20);
    expect(summaries[1].id, 'catch_2_species');
    expect(summaries[1].title, '今日解鎖 2 種魚');
    expect(summaries[1].current, 1);
    expect(summaries[1].target, 2);
    expect(summaries[1].isCompleted, false);
    expect(summaries[1].isClaimed, false);
    expect(summaries[1].canClaim, false);
    expect(summaries[1].rewardCoins, 30);
  });

  test('completed daily task can be claimed once for coin reward', () async {
    await PlayerProgressService.saveStateForTest(
      const PlayerProgressState(
        level: 1,
        xp: 40,
        totalCatches: 2,
        uniqueFishCaught: 1,
        currentStreakDays: 1,
        bestStreakDays: 1,
        dailyCatches: 2,
        dailyUniqueFish: 1,
        dailyTasksCompleted: {'catch_2_fish'},
        dailyTasksClaimed: {},
      ),
    );

    final result =
        await PlayerProgressService.claimDailyTaskReward('catch_2_fish');

    expect(result.claimed, true);
    expect(result.rewardCoins, 20);
    expect(result.state.dailyTasksClaimed, contains('catch_2_fish'));

    final summaries = PlayerProgressService.dailyTasksFor(result.state);
    expect(summaries.first.id, 'catch_2_fish');
    expect(summaries.first.isClaimed, true);
    expect(summaries.first.canClaim, false);
  });

  test('daily task cannot be claimed twice or before completion', () async {
    await PlayerProgressService.saveStateForTest(
      const PlayerProgressState(
        level: 1,
        xp: 40,
        totalCatches: 2,
        uniqueFishCaught: 1,
        currentStreakDays: 1,
        bestStreakDays: 1,
        dailyCatches: 2,
        dailyUniqueFish: 1,
        dailyTasksCompleted: {'catch_2_fish'},
        dailyTasksClaimed: {'catch_2_fish'},
      ),
    );

    final duplicate =
        await PlayerProgressService.claimDailyTaskReward('catch_2_fish');
    final incomplete =
        await PlayerProgressService.claimDailyTaskReward('catch_2_species');

    expect(duplicate.claimed, false);
    expect(duplicate.rewardCoins, 0);
    expect(incomplete.claimed, false);
    expect(incomplete.rewardCoins, 0);
  });
}
