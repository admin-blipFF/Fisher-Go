async (page) => {
  const mapTelemetry = [];
  const tileResponses = [];
  page.on('console', (message) => {
    const text = message.text();
    if (text.includes('FisherGO map performance:') ||
        text.includes('FisherGO map readiness:')) {
      mapTelemetry.push(text);
    }
  });
  page.on('response', (response) => {
    const url = response.url();
    if (/openfreemap|maplibre/i.test(url)) {
      tileResponses.push({url, status: response.status()});
    }
  });

  await page.reload();
  await page.locator('flutter-view').waitFor({
    state: 'attached',
    timeout: 30000,
  });
  const guestButton = page.getByRole('button', {
    name: '訪客遊玩',
    exact: true,
  });

  // Flutter can attach the semantics placeholder before it is ready to
  // promote the accessibility tree. Re-click it while waiting for the guest
  // action so a cold browser does not create a false startup failure.
  const enableSemanticsAndWaitForGuest = async () => {
    for (let semanticsAttempt = 0; semanticsAttempt < 60; semanticsAttempt += 1) {
      if (await guestButton.count() > 0 &&
          await guestButton.first().isVisible().catch(() => false)) {
        return;
      }
      const semanticsPlaceholder = page.locator('flt-semantics-placeholder');
      if (await semanticsPlaceholder.count() > 0) {
        await semanticsPlaceholder.first().evaluate((element) => element.click())
          .catch(() => {});
      }
      await page.waitForTimeout(250);
    }
    throw new Error('Semantics did not expose the guest action');
  };

  try {
    await enableSemanticsAndWaitForGuest();
    await guestButton.click();
  } catch (error) {
    throw new Error(`Guest gameplay entry failed: ${error}`);
  }
  const skipTutorial = page.getByRole('button', {
    name: '略過',
    exact: true,
  });
  try {
    await skipTutorial.waitFor({state: 'visible', timeout: 10000});
    await skipTutorial.click();
  } catch (error) {
    if (await page.getByText('下一步', {exact: true}).count() > 0) {
      throw error;
    }
  }
  const identityDialog = page.getByText('開始 FisherGO', {exact: true});
  const tutorialSkip = page.getByRole('button', {
    name: '略過',
    exact: true,
  });
  let startupOverlaysClosed = false;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const identityVisible = await identityDialog.count() > 0 &&
      await identityDialog.first().isVisible();
    const tutorialVisible = await tutorialSkip.count() > 0 &&
      await tutorialSkip.first().isVisible();
    if (!identityVisible && !tutorialVisible) {
      startupOverlaysClosed = true;
      break;
    }
    await page.waitForTimeout(250);
  }
  if (!startupOverlaysClosed) {
    throw new Error(
      'Identity choice dialog or tutorial overlay remained visible after guest entry',
    );
  }
  await page.locator('canvas.maplibregl-canvas').waitFor({
    state: 'attached',
    timeout: 30000,
  });
  await page.waitForTimeout(3500);
  await page.evaluate(() => {
    window.__fisherGoLongTasks = [];
    window.__fisherGoLongTaskSupported = false;
    if (typeof PerformanceObserver === 'undefined') return;
    try {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          window.__fisherGoLongTasks.push({
            duration_ms: Number(entry.duration.toFixed(2)),
            start_ms: Number(entry.startTime.toFixed(2)),
            name: entry.name,
          });
        }
      });
      observer.observe({type: 'longtask', buffered: true});
      window.__fisherGoLongTaskObserver = observer;
      window.__fisherGoLongTaskSupported = true;
    } catch (_) {
      // Older Chromium builds may not expose the longtask entry type.
    }
  });
  await page.evaluate(() => {
    window.__fisherGoFrameTimes = [];
    window.__fisherGoFrameStartedAt = performance.now();

    const collectFrame = (time) => {
      window.__fisherGoFrameTimes.push(time);
      if (time - window.__fisherGoFrameStartedAt < 5000) {
        requestAnimationFrame(collectFrame);
      } else {
        window.__fisherGoFrameFinishedAt = time;
      }
    };
    requestAnimationFrame(collectFrame);
  });

  const paths = [
    [240, 330, 700, 330],
    [700, 330, 240, 330],
    [260, 420, 680, 600],
    [680, 600, 260, 420],
    [220, 510, 720, 510],
    [720, 510, 220, 510],
    [350, 280, 350, 680],
    [350, 680, 350, 280],
    [650, 300, 280, 670],
    [280, 670, 650, 300],
    [240, 400, 700, 620],
    [700, 620, 240, 400],
  ];

  for (const [startX, startY, endX, endY] of paths) {
    await page.mouse.move(startX, startY);
    await page.mouse.down();
    await page.mouse.move(endX, endY, {steps: 8});
    await page.mouse.up();
    await page.waitForTimeout(450);
  }
  await page.waitForTimeout(1800);

  const metrics = await page.evaluate(() => {
    const times = window.__fisherGoFrameTimes ?? [];
    const startedAt = window.__fisherGoFrameStartedAt ?? 0;
    const finishedAt = window.__fisherGoFrameFinishedAt ?? performance.now();
    const deltas = [];
    for (let index = 1; index < times.length; index += 1) {
      deltas.push(times[index] - times[index - 1]);
    }
    deltas.sort((left, right) => left - right);
    const percentile = (value) => {
      if (deltas.length === 0) return 0;
      return deltas[Math.min(
        deltas.length - 1,
        Math.round((deltas.length - 1) * value),
      )];
    };
    const durationMs = Math.max(0, finishedAt - startedAt);
    return {
      viewport: `${window.innerWidth}x${window.innerHeight}`,
      frame_count: times.length,
      duration_ms: Math.round(durationMs),
      fps: durationMs === 0 ? 0 : Number((times.length / durationMs * 1000).toFixed(2)),
      p50_frame_ms: Number(percentile(0.50).toFixed(2)),
      p95_frame_ms: Number(percentile(0.95).toFixed(2)),
      janky_frames: deltas.filter((delta) => delta > 33.333).length,
      janky_rate: deltas.length === 0 ? 0 : Number((
        deltas.filter((delta) => delta > 33.333).length / deltas.length
      ).toFixed(4)),
    };
  });
  metrics.map_telemetry = mapTelemetry.slice(-5);
  metrics.tile_responses = tileResponses.slice(-20);
  metrics.main_thread_long_tasks = await page.evaluate(() => {
    window.__fisherGoLongTaskObserver?.disconnect();
    const entries = window.__fisherGoLongTasks ?? [];
    const startedAt = window.__fisherGoFrameStartedAt ?? 0;
    const finishedAt = window.__fisherGoFrameFinishedAt ?? performance.now();
    const boundedEntries = entries.filter((entry) =>
      entry.start_ms >= startedAt && entry.start_ms <= finishedAt,
    );
    const durations = boundedEntries.map((entry) => entry.duration_ms);
    return {
      supported: window.__fisherGoLongTaskSupported === true,
      count: boundedEntries.length,
      total_ms: Number(durations.reduce((sum, value) => sum + value, 0).toFixed(2)),
      max_ms: durations.length === 0 ? 0 : Math.max(...durations),
      top: boundedEntries
        .sort((left, right) => right.duration_ms - left.duration_ms)
        .slice(0, 8),
    };
  });

  await page.evaluate((value) => {
    document.title = `FisherGO_WEB_BENCHMARK:${JSON.stringify(value)}`;
  }, metrics);
  await page.screenshot({path: 'output/playwright/web-map-proof-benchmark.png'});
}
